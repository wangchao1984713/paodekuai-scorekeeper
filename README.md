# 跑得快计分

三个人打开同一个地址，系统自动分配 `A / B / C`。每个人只提交自己的分数，两个人提交后第三个人自动补差，单局合计保持为 `0`。

## 本地运行

```bash
npm start
```

默认地址：

```text
http://127.0.0.1:4180
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
