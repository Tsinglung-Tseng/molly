# Molly

macOS 菜单栏应用，用于 Obsidian 知识库自动化。基于 Swift 6 / SwiftUI 构建。

Molly 管理一组 **watchers**（监视器）—— 在后台监控你的知识库并执行操作（NER 标注、剪藏处理、笔记索引、自定义 Shell 命令等）。

## 前置要求

- macOS 14+
- Swift 6.0+ 工具链
- 一个 Obsidian 知识库

## 构建

```bash
swift build            # 调试构建
./build_app.sh         # 发布 .app 包
```

## 配置

### `config.json`

复制示例文件并填入你的路径和密钥：

```bash
cp config.json.example config.json
```

主要字段：

| 字段 | 说明 |
|---|---|
| `vaultPath` | Obsidian 知识库的绝对路径 |
| `claudeBin` | `claude` CLI 二进制文件路径 |
| `llm.apiKey` | SiliconFlow（或兼容服务）API 密钥 |
| `watchers[]` | 监视器定义数组 —— 启用/禁用并配置各个监视器 |

完整结构参见 `config.json.example`。

### `.mcp.json`（Claude Code MCP 服务器）

如果你在此项目中使用 [Claude Code](https://claude.ai/code)，可以配置 MCP 服务器以获得编辑器内工具访问（如 `pageindex` 搜索服务）。

```bash
cp .mcp.json.example .mcp.json
```

编辑 `.mcp.json` 并设置：

- `command` / `args` —— MCP 服务器入口路径
- `VAULT_PATH` / `VAULT_NAME` —— Obsidian 知识库位置和名称
- `LLM_API_KEY` —— SiliconFlow API 密钥

> `.mcp.json` 已被 git 忽略 —— 其中包含密钥和本地路径，请勿提交。

## 许可证

私有 / 保留所有权利。
