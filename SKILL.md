---
name: openclaw-tailscale-proxy
description: 统一管理 Tailscale VPN + Shadowrocket 规则，解决网络出海问题
---

# openclaw-tailscale-proxy

统一管理 Tailscale VPN 和 Shadowrocket 规则，解决 GitHub/API 等资源的访问问题。

## 功能概览

| 分类 | 命令 | 用途 |
|------|------|------|
| **VPN** | `check` | 检查网络状态 |
| | `up` | 启用 Tailscale |
| | `down` | 关闭 Tailscale |
| | `auto` | 自动检测并按需启用 |
| | `exec` | 执行命令，自动开关 VPN |
| **规则** | `fetch` | 获取规则（默认带缓存） |
| | `list` | 列出已缓存规则 |
| | `stats` | 查看规则统计 |
| | `extract` | 提取域名/IP 列表 |
| | `merge` | 合并+去重规则 |
| **定时** | `cron-add` | 设置自动更新定时任务 |
| | `cron-remove` | 移除定时任务 |
| | `cron-list` | 查看定时任务状态 |
| **自定义** | `custom-init` | 初始化自定义规则 |
| | `custom-add` | 添加自定义规则 |
| | `custom-list` | 查看自定义规则 |
| **配置** | `config-edit` | 编辑配置文件 |
| | `config-show` | 显示当前配置 |

---

## 文件结构

```
openclaw-tailscale-proxy/
├── SKILL.md         # 使用说明
├── proxy.sh         # 主脚本
├── config.sh        # 配置文件 ← 新增
└── .gitignore
```

---

## 配置文件

配置文件位于：`~/.config/openclaw-tailscale-proxy/config.sh`

### 查看配置

```bash
~/Workspaces/openclaw/main/skills/openclaw-tailscale-proxy/proxy.sh config-show
```

### 编辑配置

```bash
# 直接编辑配置文件
vim ~/.config/openclaw-tailscale-proxy/config.sh

# 或使用 proxy.sh
~/Workspaces/openclaw/main/skills/openclaw-tailscale-proxy/proxy.sh config-edit
```

### 配置项说明

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| `CHECK_TARGET` | api.github.com | 直连检测目标 |
| `CHECK_TIMEOUT` | 5 | 检测超时（秒） |
| `RULES_REPO` | Johnshall/Shadowrocket-ADBlock-Rules-Forever | 规则仓库 |
| `DEFAULT_BRANCH` | release | 默认获取的分支 |
| `TAILSCALE_ARGS` | --accept-routes --accept-dns | Tailscale 启动参数 |
| `AUTO_DISCONNECT` | false | 执行后自动关闭 VPN |

### 自定义规则源

修改 `RULES_SOURCES` 数组来自定义获取的规则：

```bash
RULES_SOURCES=(
    "release:sr_top500_banlist_ad.conf"   # 广告屏蔽
    "release:lazy.conf"                    # 懒人规则
    "release:sr_backcn.conf"              # 回国规则
)
```

---

## 快速开始

### 1. 基本检查

```bash
~/Workspaces/openclaw/main/skills/openclaw-tailscale-proxy/proxy.sh check
```

### 2. 自动模式（推荐）

```bash
~/Workspaces/openclaw/main/skills/openclaw-tailscale-proxy/proxy.sh exec curl https://api.github.com
```

### 3. 获取规则（带缓存）

```bash
# 默认：缓存24小时内不重新下载
~/Workspaces/openclaw/main/skills/openclaw-tailscale-proxy/proxy.sh fetch release

# 强制刷新（忽略缓存）
~/Workspaces/openclaw/main/skills/openclaw-tailscale-proxy/proxy.sh fetch --force release

# 自定义缓存时间（单位：秒，0 = 禁用缓存）
~/Workspaces/openclaw/main/skills/openclaw-tailscale-proxy/proxy.sh fetch --max-age 3600 release

# 不使用缓存
~/Workspaces/openclaw/main/skills/openclaw-tailscale-proxy/proxy.sh fetch --no-cache release
```

### 4. 添加自定义规则

```bash
# 添加代理域名
~/Workspaces/openclaw/main/skills/openclaw-tailscale-proxy/proxy.sh custom-add "DOMAIN-SUFFIX,github.com,Proxy"

# 添加直连域名
~/Workspaces/openclaw/main/skills/openclaw-tailscale-proxy/proxy.sh custom-add "DOMAIN-SUFFIX,baidu.com,DIRECT"
```

---

## OpenClaw 集成

### 方式 1: 直接调用（推荐）

在 OpenClaw 对话中：

```
请检查网络状态，然后帮我克隆 https://github.com/some/repo
```

### 方式 2: 自动执行

```bash
~/Workspaces/openclaw/main/skills/openclaw-tailscale-proxy/proxy.sh exec <命令>
```

### 方式 3: 脚本开头调用

在需要网络的脚本开头添加：

```bash
~/Workspaces/openclaw/main/skills/openclaw-tailscale-proxy/proxy.sh auto
```

---

## 详细命令说明

### VPN 命令

#### check - 检查网络状态
```bash
proxy.sh check
```

#### up - 启用 Tailscale
```bash
proxy.sh up
```

#### down - 关闭 Tailscale
```bash
proxy.sh down
```

#### auto - 自动模式
```bash
proxy.sh auto
```

#### exec - 自动执行命令
```bash
proxy.sh exec git clone https://github.com/user/repo.git
proxy.sh exec gh pr list
```

---

### 规则命令

#### fetch - 获取规则（默认带缓存，24小时有效）
```bash
# 默认：使用缓存（24小时内不重新下载）
proxy.sh fetch release

# 强制刷新所有规则
proxy.sh fetch --force

# 指定规则分支
proxy.sh fetch --force release

# 自定义缓存时间（秒）
proxy.sh fetch --max-age 3600 release  # 1小时

# 禁用缓存
proxy.sh fetch --no-cache release
```

#### list - 列出规则
```bash
proxy.sh list
```

#### stats - 规则统计
```bash
proxy.sh stats
```

#### extract - 提取内容
```bash
proxy.sh extract proxy-domains   # 代理域名
proxy.sh extract direct-domains  # 直连域名
proxy.sh extract proxy-ips        # 代理 IP
```

#### merge - 合并规则
```bash
proxy.sh merge
```

---

### 自定义规则

#### custom-init - 初始化
```bash
proxy.sh custom-init
```

创建：`~/.config/openclaw-tailscale-proxy/custom.conf`

#### custom-add - 添加规则
```bash
proxy.sh custom-add "DOMAIN-SUFFIX,github.com,Proxy"
proxy.sh custom-add "DOMAIN-SUFFIX,baidu.com,DIRECT"
proxy.sh custom-add "DOMAIN,ads.example.com,REJECT"
proxy.sh custom-add "IP-CIDR,10.0.0.0/8,DIRECT"
proxy.sh custom-add "GEOIP,CN,DIRECT"
```

#### custom-list - 查看自定义规则
```bash
proxy.sh custom-list
```

---

### 配置命令

#### config-show - 显示当前配置
```bash
proxy.sh config-show
```

#### config-edit - 编辑配置
```bash
proxy.sh config-edit
```

---

## 文件位置汇总

| 类型 | 路径 |
|------|------|
| 主脚本 | `~/Workspaces/openclaw/main/skills/openclaw-tailscale-proxy/proxy.sh` |
| **配置文件** | `~/.config/openclaw-tailscale-proxy/config.sh` |
| 规则缓存 | `~/.cache/openclaw-tailscale-proxy/` |
| **自定义规则** | `~/.config/openclaw-tailscale-proxy/custom.conf` |
| 合并结果 | `~/.cache/openclaw-tailscale-proxy/merged.conf` |
| 日志 | `~/logs/openclaw-tailscale-proxy.log` |

---

## 在 OpenClaw 心跳中使用

```bash
# 自动检测并按需启用 VPN
~/Workspaces/openclaw/main/skills/openclaw-tailscale-proxy/proxy.sh auto
```

---

## 定时更新规则

```bash
openclaw cron add \
  --name "update-proxy-rules" \
  --schedule "0 8 * * *" \
  --script "~/Workspaces/openclaw/main/skills/openclaw-tailscale-proxy/proxy.sh fetch release"
```

---

## 故障排除

### Tailscale 未安装

```bash
# macOS
brew install tailscale

# Linux
curl -fsSL https://tailscale.com/install.sh | sh
```

### 规则获取失败

```bash
proxy.sh up
proxy.sh fetch
```

### 查看日志

```bash
tail -f ~/logs/openclaw-tailscale-proxy.log
```

---

## GitHub 仓库

https://github.com/harold-tsui/openclaw-tailscale-proxy

---