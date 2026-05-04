#!/usr/bin/env bash
set -euo pipefail

UID_VALUE="$(id -u)"

for label in com.luge.paodekuai.tunnel com.luge.paodekuai.scorekeeper; do
  /bin/launchctl bootout "gui/$UID_VALUE/$label" >/dev/null 2>&1 || true
done

rm -f "$HOME/Library/LaunchAgents/com.luge.paodekuai.scorekeeper.plist"
rm -f "$HOME/Library/LaunchAgents/com.luge.paodekuai.tunnel.plist"

echo "已卸载跑得快计分器后台常驻服务。"
