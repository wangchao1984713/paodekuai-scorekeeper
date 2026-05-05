# 在线部署说明

## 结论

- 当前不买服务器。这个项目只是轻娱乐计分工具，继续使用免费 GitHub Pages 版本即可。
- GitHub Pages 地址：`https://wangchao1984713.github.io/paodekuai-scorekeeper/`
- GitHub Pages 会读写 MantleDB 云端状态桶，电脑关机后也能继续用。
- 已知缺点：国内手机 / 微信没有梯子时，`github.io` 和海外云端状态桶可能偶尔打不开。
- 如果只是偶尔打不开，优先判断为国内网络访问 GitHub Pages 不稳定，不要立刻改代码，也不要直接购买服务器。

## 什么时候才考虑服务器

只有同时满足这些条件，才重新考虑香港 / 国内 VPS：

- 三个人经常在国内手机或微信里打不开 GitHub Pages。
- 这个工具已经变成高频刚需，而不是偶尔娱乐。
- 用户明确接受服务器成本，并且付款 / 下单由用户自己操作。

如果涉及付款、下单、购买云服务器，必须停住，让用户自己操作。

## 备用购买配置

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
