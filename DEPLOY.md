# 在线部署说明

## 结论

- `GitHub Pages` 不适合这个计分器，因为它只能托管静态网页，不能运行多人同步后端。
- 可行方案是 `GitHub + Render`：GitHub 放代码，Render 跑 Node 服务。

## 操作路径

1. 新建一个 GitHub 仓库，只放 `projects/paodekuai-scorekeeper` 这个目录里的文件。
2. 打开 Render，选择 `New +` -> `Blueprint`。
3. 选择这个 GitHub 仓库。
4. Render 会读取 `render.yaml`，创建 Web Service。
5. 部署成功后，把 Render 给出的 HTTPS 地址发给三个人。

## 注意

`render.yaml` 默认使用 `starter` 实例并挂载 1GB 持久磁盘，这是为了让分数 JSON 在服务重启后还在。Render 免费 Web Service 可以跑 Node，但不支持持久磁盘，且空闲会休眠。
