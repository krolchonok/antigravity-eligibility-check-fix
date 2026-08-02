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

if [ -f "$SOURCE_DIR/uninstall.sh" ]; then
  cp "$SOURCE_DIR/uninstall.sh" "$INSTALL_DIR/"
  chmod +x "$INSTALL_DIR/uninstall.sh"
fi

# Проверка mitmproxy
if ! command -v mitmdump &>/dev/null; then
  echo "mitmdump не найден. Устанавливаем mitmproxy через pip..."
  pip install mitmproxy || pip3 install mitmproxy
fi

# Генерация CA сертификата mitmproxy
CONF="$HOME/.mitmproxy"
if [ ! -f "$CONF/mitmproxy-ca-cert.pem" ]; then
  echo "Генерация CA-сертификата mitmproxy..."
  timeout 8 mitmdump --set confdir="$CONF" -q >/dev/null 2>&1 &
  for _ in $(seq 1 20); do [ -f "$CONF/mitmproxy-ca-cert.pem" ] && break; sleep 0.3; done
  kill %1 2>/dev/null || true
fi

# Настройка алиаса в shell профилях
ALIAS_LINE="alias agys='$INSTALL_DIR/agy-tier.sh'"

add_alias() {
  local rc="$1"
  if [ -f "$rc" ] || [ "$(basename "$rc")" = ".bashrc" ]; then
    touch "$rc"
    if ! grep -q "alias agys=" "$rc"; then
      echo "" >> "$rc"
      echo "# === agy-tier-fix alias ===" >> "$rc"
      echo "$ALIAS_LINE" >> "$rc"
      echo "Алиас 'agys' добавлен в $rc"
    else
      echo "Алиас 'agys' уже есть в $rc"
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
