#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/luzhiqiang/Documents/Playground/projects/paodekuai-scorekeeper"
APP_SUPPORT="$HOME/Library/Application Support/paodekuai-scorekeeper"
PORT="${PORT:-4180}"
TUNNEL_LOG="$APP_SUPPORT/tunnel.launchd.log"
PUBLIC_URL_FILE="$ROOT/public-url.txt"

mkdir -p "$APP_SUPPORT"

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
