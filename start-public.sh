#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${PORT:-4180}"
LOG_DIR="$ROOT/logs"
SERVER_LOG="$LOG_DIR/server.log"
TUNNEL_LOG="$LOG_DIR/tunnel.log"
PUBLIC_URL_FILE="$ROOT/public-url.txt"
NODE_BIN="${NODE_BIN:-$(command -v node)}"

mkdir -p "$LOG_DIR"

if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  pkill -f "node .*paodekuai-scorekeeper/server.js" >/dev/null 2>&1 || true
  sleep 1
fi

nohup "$NODE_BIN" "$ROOT/server.js" >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!

for _ in $(seq 1 30); do
  if curl -sS --max-time 1 "http://127.0.0.1:$PORT/api/state" >/dev/null 2>&1; then
    break
  fi
  sleep 0.3
done

pkill -f "ssh .*localhost.run.*127.0.0.1:$PORT" >/dev/null 2>&1 || true
sleep 1
: >"$TUNNEL_LOG"
nohup ssh \
  -o StrictHostKeyChecking=accept-new \
  -o ServerAliveInterval=30 \
  -o ExitOnForwardFailure=yes \
  -R "80:127.0.0.1:$PORT" \
  nokey@localhost.run >"$TUNNEL_LOG" 2>&1 &
TUNNEL_PID=$!

PUBLIC_URL=""
for _ in $(seq 1 60); do
  PUBLIC_URL="$(grep -Eo 'https://[a-zA-Z0-9.-]+\.lhr\.life' "$TUNNEL_LOG" | tail -1 || true)"
  if [ -n "$PUBLIC_URL" ]; then
    break
  fi
  sleep 0.5
done

if [ -z "$PUBLIC_URL" ]; then
  echo "公网地址还没生成，查看日志：$TUNNEL_LOG" >&2
  echo "server_pid=$SERVER_PID tunnel_pid=$TUNNEL_PID" >&2
  exit 1
fi

printf '%s\n' "$PUBLIC_URL" >"$PUBLIC_URL_FILE"
echo "服务 PID: $SERVER_PID"
echo "隧道 PID: $TUNNEL_PID"
echo "公网地址: $PUBLIC_URL"
echo "地址文件: $PUBLIC_URL_FILE"
