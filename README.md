# 跑得快计分

三个人打开同一个地址，系统自动分配 `A / B / C`。每个人只提交自己的分数，两个人提交后第三个人自动补差，单局合计保持为 `0`。

手机页面内置完整计分键盘，包含 `0-9`、`00`、`-` 负号、退格和清零。

## 真云端静态版

GitHub Pages 打开时会自动使用 MantleDB 云端 JSON 状态，不依赖本机电脑开机。云端状态桶：

```text
https://mantledb.sh/v2/paodekuai-scorekeeper-luge-1777905348/state
```

GitHub Pages 地址：

```text
https://wangchao1984713.github.io/paodekuai-scorekeeper/
```

## 本地运行

```bash
npm start
```

默认地址：

```text
http://127.0.0.1:4180
```

## 本机后台公网入口

```bash
./install-autostart.sh
```

这个命令会把本地 Node 服务和公网隧道交给 macOS 后台常驻，终端关掉也继续运行。生成的公网地址会写到：

```text
public-url.txt
```

这个本机后台方案要求这台 Mac 保持开机和联网。免费隧道地址可能变化，后台脚本会把最新地址持续写回 `public-url.txt`。

停止后台服务：

```bash
./stop-public.sh
```

## Render 在线部署

这个项目需要一个能长期运行的 Node 服务，所以不能只用 GitHub Pages。推荐流程：

1. 把本目录推到 GitHub 仓库。
2. 在 Render 新建 Blueprint/Web Service，选择仓库里的 `render.yaml`。
3. 部署完成后，Render 会给一个 `https://...onrender.com` 地址。

`render.yaml` 已配置：

- Node Web Service
- `npm start`
- `/healthz` 健康检查
- `DATA_DIR=/var/data`
- 1GB 持久化磁盘用于保存分数 JSON
- `starter` 实例；免费 Web Service 不支持持久磁盘，且空闲会休眠

## 数据文件

默认本地数据在：

```text
data/scorekeeper-state.json
```

云端部署时由 `DATA_DIR` 控制。
