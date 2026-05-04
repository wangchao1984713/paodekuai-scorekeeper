#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$HOME/Library/LaunchAgents"
APP_SUPPORT="$HOME/Library/Application Support/paodekuai-scorekeeper"
TUNNEL_LAUNCH_LOG="$APP_SUPPORT/tunnel.launchd.log"
TUNNEL_LAUNCH_ERR="$APP_SUPPORT/tunnel.launchd.err.log"
PUBLIC_URL_FILE="$ROOT/public-url.txt"
UID_VALUE="$(id -u)"

mkdir -p "$AGENTS_DIR" "$ROOT/logs" "$APP_SUPPORT"
: >"$TUNNEL_LAUNCH_LOG"
: >"$TUNNEL_LAUNCH_ERR"
cp "$ROOT/tunnel-launcher.sh" "$APP_SUPPORT/tunnel-launcher.sh"
chmod +x "$APP_SUPPORT/tunnel-launcher.sh"

for label in com.luge.paodekuai.tunnel com.luge.paodekuai.scorekeeper; do
  /bin/launchctl bootout "gui/$UID_VALUE/$label" >/dev/null 2>&1 || true
done

pkill -f "node .*paodekuai-scorekeeper/server.js" >/dev/null 2>&1 || true
pkill -f "ssh .*-R .*127.0.0.1:4180.*localhost.run" >/dev/null 2>&1 || true
pkill -f "paodekuai-scorekeeper/tunnel-keeper.sh" >/dev/null 2>&1 || true
pkill -f "paodekuai-scorekeeper/tunnel-launcher.sh" >/dev/null 2>&1 || true

cp "$ROOT/launchd/com.luge.paodekuai.scorekeeper.plist" "$AGENTS_DIR/com.luge.paodekuai.scorekeeper.plist"
cp "$ROOT/launchd/com.luge.paodekuai.tunnel.plist" "$AGENTS_DIR/com.luge.paodekuai.tunnel.plist"

/bin/launchctl bootstrap "gui/$UID_VALUE" "$AGENTS_DIR/com.luge.paodekuai.scorekeeper.plist"
/bin/launchctl bootstrap "gui/$UID_VALUE" "$AGENTS_DIR/com.luge.paodekuai.tunnel.plist"
/bin/launchctl enable "gui/$UID_VALUE/com.luge.paodekuai.scorekeeper"
/bin/launchctl enable "gui/$UID_VALUE/com.luge.paodekuai.tunnel"

PUBLIC_URL=""
for _ in $(seq 1 60); do
  PUBLIC_URL="$(grep -Eo 'https://[a-zA-Z0-9.-]+\.lhr\.life' "$TUNNEL_LAUNCH_LOG" | tail -1 || true)"
  if [ -n "$PUBLIC_URL" ]; then
    printf '%s\n' "$PUBLIC_URL" >"$PUBLIC_URL_FILE"
    break
  fi
  sleep 0.5
done

echo "已安装后台常驻服务。"
echo "本地服务: http://127.0.0.1:4180"
if [ -n "$PUBLIC_URL" ]; then
  echo "公网地址: $PUBLIC_URL"
  echo "地址文件: $PUBLIC_URL_FILE"
else
  echo "公网地址生成中，稍后查看: $TUNNEL_LAUNCH_LOG"
fi
