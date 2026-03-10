# openclaw-tailscale-proxy

> OpenClaw Skill: 统一管理 Tailscale VPN + Shadowrocket 规则

解决 GitHub/API 等资源的访问问题。

## 功能

- **VPN 管理**: 自动检测网络状态，按需启用/关闭 Tailscale
- **规则获取**: 从 Shadowrocket 规则仓库获取最新规则
- **自定义规则**: 支持添加个人规则，合并到主规则
- **OpenClaw 集成**: 开箱即用，自动处理网络问题

## 快速开始

```bash
# 1. 检查网络状态
./proxy.sh check

# 2. 自动执行（直连失败自动启用 Tailscale）
./proxy.sh exec curl https://api.github.com

# 3. 获取规则
./proxy.sh fetch release

# 4. 添加自定义规则
./proxy.sh custom-add "DOMAIN-SUFFIX,github.com,Proxy"
```

## 安装

### 方式 1: 克隆仓库

```bash
git clone https://github.com/harold-tsui/openclaw-tailscale-proxy.git ~/skills/openclaw-tailscale-proxy
```

### 方式 2: OpenClaw Skill

（如果发布到 ClawHub）

## 配置

所有配置在 `config.sh` 中，运行时配置保存在：

- `~/.config/openclaw-tailscale-proxy/config.sh`
- `~/.config/openclaw-tailscale-proxy/custom.conf`

### 查看配置

```bash
./proxy.sh config-show
```

### 编辑配置

```bash
./proxy.sh config-edit
# 或
vim ~/.config/openclaw-tailscale-proxy/config.sh
```

## 命令

| 命令 | 用途 |
|------|------|
| `./proxy.sh check` | 检查网络状态 |
| `./proxy.sh up` | 启用 Tailscale |
| `./proxy.sh down` | 关闭 Tailscale |
| `./proxy.sh auto` | 自动检测并按需启用 |
| `./proxy.sh exec <cmd>` | 执行命令，自动开关 VPN |
| `./proxy.sh fetch` | 获取规则 |
| `./proxy.sh custom-add <rule>` | 添加自定义规则 |

完整命令见 [SKILL.md](./SKILL.md)

## OpenClaw 使用

在 OpenClaw 对话中直接使用：

```
请帮我克隆 https://github.com/some/repo
```

OpenClaw 会自动调用本工具处理网络问题。

## 文件结构

```
openclaw-tailscale-proxy/
├── proxy.sh          # 主脚本
├── config.sh         # 配置文件
├── SKILL.md          # OpenClaw Skill 说明
├── README.md         # 本文件
├── LICENSE           # MIT License
└── .gitignore
```

## 依赖

- `curl` - 网络请求
- `tailscale` - VPN 客户端
- `gh` (可选) - GitHub CLI

## 日志

- 位置: `~/logs/openclaw-tailscale-proxy.log`

## 相关项目

- [Shadowrocket-ADBlock-Rules-Forever](https://github.com/Johnshall/Shadowrocket-ADBlock-Rules-Forever) - 规则来源

## License

MIT License - see [LICENSE](./LICENSE)

---

作者: Harold Tsui  
GitHub: https://github.com/harold-tsui/openclaw-tailscale-proxy