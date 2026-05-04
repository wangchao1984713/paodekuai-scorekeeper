#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${APP_NAME:-paodekuai-scorekeeper}"
APP_USER="${APP_USER:-paodekuai}"
APP_DIR="${APP_DIR:-/opt/paodekuai-scorekeeper}"
DATA_DIR="${DATA_DIR:-/var/lib/paodekuai-scorekeeper}"
PORT="${PORT:-4180}"
SERVER_NAME="${SERVER_NAME:-_}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ "${EUID}" -ne 0 ]]; then
  echo "请用 sudo 执行：sudo bash deploy/install-hk-vps.sh"
  exit 1
fi

if [[ ! -f "$SOURCE_DIR/server.js" || ! -f "$SOURCE_DIR/index.html" ]]; then
  echo "没有找到 server.js / index.html，请在项目目录里执行本脚本。"
  exit 1
fi

echo "==> 安装系统依赖"
apt-get update
apt-get install -y ca-certificates curl nginx nodejs rsync

NODE_BIN="$(command -v node || true)"
if [[ -z "$NODE_BIN" ]]; then
  echo "没有找到 node。请使用 Ubuntu 24.04 LTS，或先安装 Node.js 18+。"
  exit 1
fi

NODE_MAJOR="$("$NODE_BIN" -p "Number(process.versions.node.split('.')[0])")"
if (( NODE_MAJOR < 18 )); then
  echo "当前 Node.js 版本是 $("$NODE_BIN" -v)，本项目需要 Node.js 18+。"
  echo "建议服务器系统选择 Ubuntu 24.04 LTS 后重新执行。"
  exit 1
fi

echo "==> 创建运行用户和目录"
if ! id -u "$APP_USER" >/dev/null 2>&1; then
  useradd --system --create-home --home-dir "/var/lib/$APP_USER" --shell /usr/sbin/nologin "$APP_USER"
fi

mkdir -p "$APP_DIR" "$DATA_DIR"

echo "==> 发布项目到 $APP_DIR"
rsync -a --delete \
  --exclude ".git" \
  --exclude "data" \
  --exclude "node_modules" \
  --exclude "public-url.txt" \
  "$SOURCE_DIR"/ "$APP_DIR"/

chown -R root:root "$APP_DIR"
chown -R "$APP_USER:$APP_USER" "$DATA_DIR"

echo "==> 写入 systemd 服务"
cat >"/etc/systemd/system/${APP_NAME}.service" <<SERVICE
[Unit]
Description=Paodekuai Scorekeeper
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${APP_DIR}
Environment=NODE_ENV=production
Environment=HOST=127.0.0.1
Environment=PORT=${PORT}
Environment=DATA_DIR=${DATA_DIR}
ExecStart=${NODE_BIN} ${APP_DIR}/server.js
Restart=always
RestartSec=2
User=${APP_USER}
Group=${APP_USER}
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=full
ReadWritePaths=${DATA_DIR}

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable --now "$APP_NAME"

echo "==> 写入 Nginx 反向代理"
cat >"/etc/nginx/sites-available/${APP_NAME}" <<NGINX
server {
    listen 80;
    server_name ${SERVER_NAME};

    client_max_body_size 1m;

    location / {
        proxy_pass http://127.0.0.1:${PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Connection "";
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 1h;
        proxy_send_timeout 1h;
    }
}
NGINX

ln -sfn "/etc/nginx/sites-available/${APP_NAME}" "/etc/nginx/sites-enabled/${APP_NAME}"
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx

echo "==> 健康检查"
curl -fsS "http://127.0.0.1:${PORT}/healthz" >/dev/null
curl -fsS "http://127.0.0.1/healthz" >/dev/null

PUBLIC_HINT="http://服务器IP"
if [[ "$SERVER_NAME" != "_" ]]; then
  PUBLIC_HINT="http://${SERVER_NAME}"
fi

cat <<DONE

部署完成。

服务状态：
  systemctl status ${APP_NAME} --no-pager

日志：
  journalctl -u ${APP_NAME} -f

公网入口：
  ${PUBLIC_HINT}

数据目录：
  ${DATA_DIR}

如果绑定了域名，再执行 certbot 配 HTTPS。
DONE
