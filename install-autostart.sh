#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$HOME/Library/LaunchAgents"
UID_VALUE="$(id -u)"

mkdir -p "$AGENTS_DIR" "$ROOT/logs"
chmod +x "$ROOT/tunnel-keeper.sh"

for label in com.luge.paodekuai.tunnel com.luge.paodekuai.scorekeeper; do
  /bin/launchctl bootout "gui/$UID_VALUE/$label" >/dev/null 2>&1 || true
done

pkill -f "node .*paodekuai-scorekeeper/server.js" >/dev/null 2>&1 || true
pkill -f "ssh .*localhost.run.*127.0.0.1:4180" >/dev/null 2>&1 || true
pkill -f "paodekuai-scorekeeper/tunnel-keeper.sh" >/dev/null 2>&1 || true

cp "$ROOT/launchd/com.luge.paodekuai.scorekeeper.plist" "$AGENTS_DIR/com.luge.paodekuai.scorekeeper.plist"
cp "$ROOT/launchd/com.luge.paodekuai.tunnel.plist" "$AGENTS_DIR/com.luge.paodekuai.tunnel.plist"

/bin/launchctl bootstrap "gui/$UID_VALUE" "$AGENTS_DIR/com.luge.paodekuai.scorekeeper.plist"
/bin/launchctl bootstrap "gui/$UID_VALUE" "$AGENTS_DIR/com.luge.paodekuai.tunnel.plist"
/bin/launchctl enable "gui/$UID_VALUE/com.luge.paodekuai.scorekeeper"
/bin/launchctl enable "gui/$UID_VALUE/com.luge.paodekuai.tunnel"

echo "已安装后台常驻服务。"
echo "本地服务: http://127.0.0.1:4180"
echo "公网地址生成中，稍后查看: $ROOT/public-url.txt"
