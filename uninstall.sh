#!/usr/bin/env bash
# uninstall.sh - Полное удаление agy-tier-fix с Linux/macOS
set -euo pipefail

INSTALL_DIR="${AGY_INSTALL_DIR:-$HOME/.local/share/agy-tier-fix}"

echo "=== Удаление agy-tier-fix ==="

# Завершение процессов mitmdump
if [ -f "$INSTALL_DIR/mitm-tier.pid" ]; then
  kill "$(cat "$INSTALL_DIR/mitm-tier.pid" 2>/dev/null)" 2>/dev/null || true
fi
pkill -f "mitmdump -s .*tier-fix.py" 2>/dev/null || true

# Удаление алиасов из .bashrc и .zshrc
remove_alias() {
  local rc="$1"
  if [ -f "$rc" ]; then
    sed -i '/# === agy-tier-fix alias ===/d' "$rc" 2>/dev/null || true
    sed -i '/alias agys=/d' "$rc" 2>/dev/null || true
    echo "Алиас 'agys' удалён из $rc"
  fi
}

remove_alias "$HOME/.bashrc"
remove_alias "$HOME/.zshrc"

# Удаление папки установки
if [ -d "$INSTALL_DIR" ]; then
  rm -rf "$INSTALL_DIR"
  echo "Папка $INSTALL_DIR удалена."
fi

echo "agy-tier-fix успешно удалён!"
