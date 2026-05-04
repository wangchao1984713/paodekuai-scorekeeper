# 在线部署说明

## 结论

- 国内手机没梯子时，不建议继续依赖 `GitHub Pages` 或 Render 这类海外默认域名。
- 给牌友稳定使用，推荐：香港轻量服务器 + Node 服务 + Nginx。
- `GitHub Pages` 只能当临时静态版；真正稳定多人同步要跑 `server.js`。

## 推荐购买配置

买腾讯云 / 阿里云 / 华为云的香港轻量服务器都可以，配置不用高：

- 地区：香港
- 系统：Ubuntu 24.04 LTS
- 配置：1 核 1G 内存起步即可
- 磁盘：20G 起步即可
- 安全组 / 防火墙：放行 `22`、`80`，如果配域名和 HTTPS 再放行 `443`

没有域名也能先用：

```text
http://服务器IP
```

有域名会更好发给别人，后面可以补 HTTPS。

## 香港 VPS 一键部署

在服务器 SSH 里执行：

```bash
sudo apt-get update
sudo apt-get install -y git
git clone https://github.com/wangchao1984713/paodekuai-scorekeeper.git
cd paodekuai-scorekeeper
sudo bash deploy/install-hk-vps.sh
```

如果已经绑定域名，把域名写进去：

```bash
sudo SERVER_NAME=score.example.com bash deploy/install-hk-vps.sh
```

部署完成后访问：

```text
http://服务器IP
```

或：

```text
http://你的域名
```

## 常用维护命令

查看状态：

```bash
systemctl status paodekuai-scorekeeper --no-pager
```

看实时日志：

```bash
journalctl -u paodekuai-scorekeeper -f
```

更新代码后重新部署：

```bash
cd paodekuai-scorekeeper
git pull
sudo bash deploy/install-hk-vps.sh
```

分数数据保存在：

```text
/var/lib/paodekuai-scorekeeper/scorekeeper-state.json
```

## 配 HTTPS

有域名并解析到服务器 IP 后，可以执行：

```bash
sudo apt-get install -y certbot python3-certbot-nginx
sudo certbot --nginx -d 你的域名
```

## Render 备用方案

Render 也能跑这个项目，但国内手机访问不一定稳定。`render.yaml` 默认使用 `starter` 实例并挂载 1GB 持久磁盘，这是为了让分数 JSON 在服务重启后还在。Render 免费 Web Service 可以跑 Node，但不支持持久磁盘，且空闲会休眠。
