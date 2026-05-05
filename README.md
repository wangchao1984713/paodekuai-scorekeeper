# 跑得快计分

三个人打开同一个地址，系统自动分配 `A / B / C`。每个人只提交自己的分数，两个人提交后第三个人自动补差，单局合计保持为 `0`。

座位现在按在线状态占用：页面打开时自动保留座位，点 `离开座位` 会马上空出；如果旧手机关闭页面或太久没续租，约 90 秒后会自动释放，后面的手机可以继续进入。

手机页面内置完整计分键盘，包含 `0-9`、`00`、`-` 负号、退格和清零。

## 当前使用方式：免费 GitHub Pages 云端版

GitHub Pages 打开时会自动使用 MantleDB 云端 JSON 状态，不依赖本机电脑开机。云端状态桶：

```text
https://mantledb.sh/v2/paodekuai-scorekeeper-luge-1777905348/state
```

GitHub Pages 地址：

```text
https://wangchao1984713.github.io/paodekuai-scorekeeper/
```

当前结论：这是轻娱乐工具，不再为了它购买服务器。三个人直接用上面的 GitHub Pages 地址即可，电脑关机后也能继续使用云端数据。

已知边界：国内手机或微信里没有梯子时，`github.io` 和海外云端状态桶可能偶尔打不开。遇到打不开时，先判断是不是网络访问 GitHub Pages 不稳定；不要立刻改代码，也不要直接进入买服务器流程。

香港 / 国内 VPS 部署脚本已经保留为备用方案，但不是当前推荐路径。只有以后明确需要“国内直连长期稳定”，并且用户愿意自行付款购买服务器时，再看：

```text
DEPLOY.md
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

## Render / Node 在线部署备用

当前 GitHub Pages 版本已经能通过 MantleDB 保存云端状态，所以不需要为了普通牌局再部署 Node 服务。

如果未来要迁移到自有服务器，Render 只作为备用流程：

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
