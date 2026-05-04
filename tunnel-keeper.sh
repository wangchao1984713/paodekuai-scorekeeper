#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${PORT:-4180}"
LOG_DIR="$ROOT/logs"
TUNNEL_LOG="$LOG_DIR/tunnel.log"
PUBLIC_URL_FILE="$ROOT/public-url.txt"

mkdir -p "$LOG_DIR"

while true; do
  {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] starting localhost.run tunnel"
    /usr/bin/ssh \
      -o StrictHostKeyChecking=accept-new \
      -o ServerAliveInterval=30 \
      -o ExitOnForwardFailure=yes \
      -R "80:127.0.0.1:$PORT" \
      nokey@localhost.run
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] tunnel exited"
  } 2>&1 | while IFS= read -r line; do
    printf '%s\n' "$line" >>"$TUNNEL_LOG"
    url="$(printf '%s\n' "$line" | grep -Eo 'https://[a-zA-Z0-9.-]+\.lhr\.life' | tail -1 || true)"
    if [ -n "$url" ]; then
      printf '%s\n' "$url" >"$PUBLIC_URL_FILE"
    fi
  done
  sleep 3
done
