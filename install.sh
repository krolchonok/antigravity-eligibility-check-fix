#!/usr/bin/env bash
# install.sh - Полная установка agy-tier-fix на Linux/macOS
set -euo pipefail

INSTALL_DIR="${AGY_INSTALL_DIR:-$HOME/.local/share/agy-tier-fix}"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Установка agy-tier-fix (Linux/macOS) ==="
echo "Папка установки: $INSTALL_DIR"

mkdir -p "$INSTALL_DIR"

cp "$SOURCE_DIR/tier-fix.py" "$INSTALL_DIR/"
cp "$SOURCE_DIR/agy-tier.sh" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/agy-tier.sh"

for f in uninstall.sh uninstall.py; do
  if [ -f "$SOURCE_DIR/$f" ]; then
    cp "$SOURCE_DIR/$f" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/$f"
  fi
done

# Проверка mitmproxy
if ! command -v mitmdump &>/dev/null; then
  echo "mitmdump не найден. Устанавливаем mitmproxy..."
  # pip напрямую падает на externally-managed окружениях (PEP 668):
  # Debian 12+/Ubuntu 24.04+. Пробуем pipx, затем pip --user, затем override.
  if command -v pipx &>/dev/null; then
    pipx install mitmproxy
  elif ! (pip install --user mitmproxy || pip3 install --user mitmproxy); then
    pip install --user --break-system-packages mitmproxy \
      || pip3 install --user --break-system-packages mitmproxy
  fi
fi

if ! command -v mitmdump &>/dev/null; then
  echo "Ошибка: mitmdump так и не найден в PATH." >&2
  echo "Установите mitmproxy вручную (pipx install mitmproxy) и запустите install.sh снова." >&2
  exit 1
fi

# agy-tier.sh использует ss (iproute2) для проверки порта
if ! command -v ss &>/dev/null; then
  echo "Внимание: 'ss' не найден (пакет iproute2) — agy-tier.sh не сможет проверить порт." >&2
fi

if ! command -v agy &>/dev/null && [ ! -x "$HOME/.local/bin/agy" ]; then
  echo "Внимание: 'agy' не найден в PATH. Задайте AGY_BIN=/путь/к/agy при запуске." >&2
fi

# Генерация CA сертификата mitmproxy
CONF="$HOME/.mitmproxy"
if [ ! -f "$CONF/mitmproxy-ca-cert.pem" ]; then
  echo "Генерация CA-сертификата mitmproxy..."
  mitmdump --set confdir="$CONF" -q >/dev/null 2>&1 &
  ca_pid=$!
  for _ in $(seq 1 20); do [ -f "$CONF/mitmproxy-ca-cert.pem" ] && break; sleep 0.3; done
  kill "$ca_pid" 2>/dev/null || true
  wait "$ca_pid" 2>/dev/null || true
  if [ ! -f "$CONF/mitmproxy-ca-cert.pem" ]; then
    echo "Ошибка: не удалось сгенерировать CA в $CONF" >&2
    exit 1
  fi
fi

# Настройка алиаса в shell профилях
ALIAS_LINE="alias agys='$INSTALL_DIR/agy-tier.sh'"

add_alias() {
  local rc="$1"
  if [ -f "$rc" ] || [ "$(basename "$rc")" = ".bashrc" ]; then
    touch "$rc"
    if grep -qF "$ALIAS_LINE" "$rc"; then
      echo "Алиас 'agys' уже актуален в $rc"
    elif grep -q "^[[:space:]]*alias agys=" "$rc"; then
      # Алиас есть, но ведёт на другой путь (старая копия). Без обновления
      # переустановка не вступит в силу: agys продолжит запускать старое.
      local tmp
      tmp="$(mktemp)"
      awk -v new="$ALIAS_LINE" '
        /^[[:space:]]*alias agys=/ { if (!done) { print new; done = 1 } ; next }
        { print }
      ' "$rc" > "$tmp" && cat "$tmp" > "$rc"
      rm -f "$tmp"
      echo "Алиас 'agys' обновлён в $rc (вёл на другой путь)"
    else
      echo "" >> "$rc"
      echo "# === agy-tier-fix alias ===" >> "$rc"
      echo "$ALIAS_LINE" >> "$rc"
      echo "Алиас 'agys' добавлен в $rc"
    fi
  fi
}

add_alias "$HOME/.bashrc"
add_alias "$HOME/.zshrc"

echo ""
echo "Установка успешно завершена!"
echo "Перезапустите терминал или выполните: source ~/.bashrc"
echo "Использование: agys -p \"your prompt\""
echo "Удаление: $INSTALL_DIR/uninstall.sh"
