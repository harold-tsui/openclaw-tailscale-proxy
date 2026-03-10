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
| **规则** | `fetch` | 获取 Shadowrocket 规则 |
| | `list` | 列出已缓存规则 |
| | `stats` | 查看规则统计 |
| | `extract` | 提取域名/IP 列表 |
| | `merge` | 合并基础+自定义规则 |
| **自定义** | `custom-init` | 初始化自定义规则 |
| | `custom-add` | 添加自定义规则 |
| | `custom-list` | 查看自定义规则 |

---

## 快速开始

### 1. 基本检查

```bash
~/Workspaces/openclaw/main/skills/openclaw-tailscale-proxy/proxy.sh check
```

输出示例：
```
========================================
🌐 网络状态检查
========================================
直连 api.github.com: HTTP 200
Tailscale 状态: Running

✅ 直连正常 - 不需要 VPN
```

### 2. 自动模式（推荐）

直连正常时直接执行，直连失败时自动启用 Tailscale：

```bash
~/Workspaces/openclaw/main/skills/openclaw-tailscale-proxy/proxy.sh exec curl https://api.github.com
```

### 3. 获取规则

```bash
# 获取所有规则
~/Workspaces/openclaw/main/skills/openclaw-tailscale-proxy/proxy.sh fetch

# 仅获取 release 分支
~/Workspaces/openclaw/main/skills/openclaw-tailscale-proxy/proxy.sh fetch release
```

---

## OpenClaw 集成

### 方式 1: 直接调用（推荐）

在 OpenClaw 对话中直接使用完整路径：

```
请检查网络状态，然后帮我克隆 https://github.com/some/repo
```

OpenClaw 会调用 `proxy.sh check` 检测网络，如果需要会自动启用 Tailscale。

### 方式 2: 自动 VPN 执行

```bash
# OpenClaw 执行需要网络的命令时自动启用 VPN
~/Workspaces/openclaw/main/skills/openclaw-tailscale-proxy/proxy.sh exec <你的命令>
```

### 方式 3: 在其他 Skill 中调用

在需要网络的 skill 脚本开头添加：

```bash
# 自动检测并按需启用 VPN
~/Workspaces/openclaw/main/skills/openclaw-tailscale-proxy/proxy.sh auto
```

---

## 详细命令说明

### VPN 命令

#### check - 检查网络状态

```bash
proxy.sh check
```

返回：
- 直连状态（HTTP 200 = 正常）
- Tailscale 运行状态

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

检测直连是否正常，不正常则自动启用 Tailscale。适合在脚本开头调用。

#### exec - 自动执行命令

```bash
proxy.sh exec <command>
```

1. 检测直连
2. 正常 → 直接执行
3. 失败 → 启用 Tailscale → 执行

示例：
```bash
proxy.sh exec git clone https://github.com/user/repo.git
proxy.sh exec gh pr list
proxy.sh exec curl -s https://api.github.com
```

---

### 规则命令

#### fetch - 获取规则

```bash
# 获取所有源
proxy.sh fetch

# 仅获取 release
proxy.sh fetch release

# 仅获取特定文件
proxy.sh fetch lazy.conf
```

**规则源：**
- `release:sr_top500_banlist_ad.conf` - 广告屏蔽（推荐）
- `release:lazy.conf` - 懒人规则（推荐）
- `release:sr_backcn.conf` - 回国规则
- `release:sr_top500_whitelist_ad.conf` - 白名单

#### list - 列出规则

```bash
proxy.sh list
```

#### stats - 规则统计

```bash
# 默认统计主规则
proxy.sh stats

# 统计指定文件
proxy.sh stats ~/.cache/openclaw-tailscale-proxy/release_lazy.conf
```

#### extract - 提取内容

```bash
# 提取代理域名
proxy.sh extract proxy-domains

# 提取直连域名
proxy.sh extract direct-domains

# 提取代理 IP
proxy.sh extract proxy-ips

# 导出全部规则
proxy.sh extract all > rules.conf
```

#### merge - 合并规则

```bash
proxy.sh merge
```

合并 `基础规则 + 自定义规则` → `~/.cache/openclaw-tailscale-proxy/merged.conf`

---

### 自定义规则

#### custom-init - 初始化

```bash
proxy.sh custom-init
```

创建 `~/.config/openclaw-tailscale-proxy/custom.conf`

#### custom-add - 添加规则

```bash
# 添加代理域名
proxy.sh custom-add "DOMAIN-SUFFIX,github.com,Proxy"

# 添加直连域名
proxy.sh custom-add "DOMAIN-SUFFIX,baidu.com,DIRECT"

# 添加拒绝规则
proxy.sh custom-add "DOMAIN,ads.example.com,REJECT"

# 添加 IP 段
proxy.sh custom-add "IP-CIDR,10.0.0.0/8,DIRECT"

# 添加 geo 规则
proxy.sh custom-add "GEOIP,CN,DIRECT"
```

#### custom-list - 查看自定义规则

```bash
proxy.sh custom-list
```

---

## 文件位置

| 类型 | 路径 |
|------|------|
| 主脚本 | `~/Workspaces/openclaw/main/skills/openclaw-tailscale-proxy/proxy.sh` |
| 规则缓存 | `~/.cache/openclaw-tailscale-proxy/` |
| 自定义规则 | `~/.config/openclaw-tailscale-proxy/custom.conf` |
| 合并结果 | `~/.cache/openclaw-tailscale-proxy/merged.conf` |
| 日志 | `~/logs/openclaw-tailscale-proxy.log` |

---

## 在 OpenClaw 心跳中使用

添加到 `HEARTBEAT.md` 自动检测：

```bash
# 检查网络状态（如果失败会自动启用 Tailscale）
~/Workspaces/openclaw/main/skills/openclaw-tailscale-proxy/proxy.sh auto
```

---

## 定时更新规则

使用 OpenClaw cron 每天自动更新规则：

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

### 直连正常但 exec 失败

检查日志：
```bash
tail -f ~/logs/openclaw-tailscale-proxy.log
```

### 规则获取失败

可能需要 VPN：
```bash
proxy.sh up
proxy.sh fetch
```

---

## GitHub 仓库

发布前确保：
1. 移除日志文件中的敏感信息
2. 自定义规则默认是空的（用户自己添加）
3. 脚本有执行权限

```bash
chmod +x proxy.sh
```

---