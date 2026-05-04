#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-4180}"
UID_VALUE="$(id -u)"

for label in com.luge.paodekuai.tunnel com.luge.paodekuai.scorekeeper; do
  /bin/launchctl bootout "gui/$UID_VALUE/$label" >/dev/null 2>&1 || true
done

pkill -f "ssh .*localhost.run.*127.0.0.1:$PORT" >/dev/null 2>&1 || true
pkill -f "node .*paodekuai-scorekeeper/server.js" >/dev/null 2>&1 || true

echo "跑得快计分器后台服务已停止"
