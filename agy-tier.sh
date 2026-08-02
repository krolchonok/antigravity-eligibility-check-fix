#!/usr/bin/env bash
# Запуск Antigravity CLI (agy) через локальный mitmproxy с аддоном tier-fix.py.
#
#   ./agy-tier.sh                # интерактивно
#   ./agy-tier.sh -p "say ok"    # разовый промпт
#
# Переменные (необязательные):
#   AGY_BIN        путь к agy (по умолчанию из PATH или ~/.local/bin/agy)
#   AGY_MITM_PORT  порт mitmproxy (по умолчанию 8085)
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${AGY_MITM_PORT:-8085}"
PROXY="http://127.0.0.1:$PORT"
CONF="$HOME/.mitmproxy"
CA="$DIR/ca-bundle-mitm.pem"
LOG="$DIR/mitm-tier.log"
PIDF="$DIR/mitm-tier.pid"

AGY_BIN="${AGY_BIN:-$(command -v agy || echo "$HOME/.local/bin/agy")}"
if [ ! -x "$AGY_BIN" ]; then
  echo "agy не найден. Задай AGY_BIN=/путь/к/agy" >&2; exit 1
fi

# 1) убедиться, что mitmproxy CA существует (создаётся при первом запуске mitmdump)
if [ ! -f "$CONF/mitmproxy-ca-cert.pem" ]; then
  echo "Генерирую mitmproxy CA…" >&2
  timeout 8 mitmdump --set confdir="$CONF" -q >/dev/null 2>&1 &
  for _ in $(seq 1 20); do [ -f "$CONF/mitmproxy-ca-cert.pem" ] && break; sleep 0.3; done
  kill %1 2>/dev/null
fi

# 2) собрать CA-бандл: системные корни + mitmproxy CA (agy должен доверять mitm)
if [ ! -f "$CA" ] || [ "$CONF/mitmproxy-ca-cert.pem" -nt "$CA" ]; then
  SYS=""
  for c in /etc/ssl/certs/ca-certificates.crt /etc/pki/tls/certs/ca-bundle.crt \
           /etc/ssl/ca-bundle.pem /etc/ssl/cert.pem; do
    [ -f "$c" ] && SYS="$c" && break
  done
  cat ${SYS:+"$SYS"} "$CONF/mitmproxy-ca-cert.pem" > "$CA"
fi

# 3) поднять mitmdump, если порт не слушается
SPAWNED_MITM=0
if ! ss -ltn 2>/dev/null | grep -q "127.0.0.1:$PORT "; then
  nohup mitmdump -s "$DIR/tier-fix.py" \
    --listen-host 127.0.0.1 --listen-port "$PORT" \
    --allow-hosts 'daily-cloudcode-pa\.googleapis\.com' \
    --set confdir="$CONF" > "$LOG" 2>&1 &
  echo $! > "$PIDF"
  SPAWNED_MITM=1
  for _ in $(seq 1 60); do
    ss -ltn 2>/dev/null | grep -q "127.0.0.1:$PORT " && break
    sleep 0.5
  done
  if ! ss -ltn 2>/dev/null | grep -q "127.0.0.1:$PORT "; then
    echo "mitmdump не поднялся, см. $LOG" >&2; tail -5 "$LOG" >&2; exit 1
  fi
fi

# 4) запустить agy через прокси, доверяя mitm-корню
export HTTP_PROXY="$PROXY"  http_proxy="$PROXY"
export HTTPS_PROXY="$PROXY" https_proxy="$PROXY"
export ALL_PROXY="$PROXY"   all_proxy="$PROXY"
export NO_PROXY="localhost,127.0.0.1,::1"
export no_proxy="$NO_PROXY"
export SSL_CERT_FILE="$CA"
export REQUESTS_CA_BUNDLE="$CA"
export GRPC_DEFAULT_SSL_ROOTS_FILE_PATH="$CA"
export NODE_EXTRA_CA_CERTS="$CONF/mitmproxy-ca-cert.pem"

if [ "$SPAWNED_MITM" -eq 1 ] && [ "${AGY_KEEP_MITM:-0}" -ne 1 ]; then
  trap 'kill $(cat "$PIDF" 2>/dev/null) 2>/dev/null || true; rm -f "$PIDF"' EXIT
fi

"$AGY_BIN" "$@"
