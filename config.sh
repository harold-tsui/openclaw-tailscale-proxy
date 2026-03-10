#!/bin/bash
# ============================================================
# OpenClaw Tailscale Proxy 配置
# ============================================================

# -----------------
# 网络检测配置
# -----------------

# 检测目标（直连检测用）
CHECK_TARGET="api.github.com"

# 检测超时（秒）
CHECK_TIMEOUT=5

# -----------------
# 规则源配置
# -----------------

# Shadowrocket 规则仓库
RULES_REPO="Johnshall/Shadowrocket-ADBlock-Rules-Forever"

# 要获取的规则列表 (格式: branch:filename)
RULES_SOURCES=(
    "release:sr_top500_banlist_ad.conf"
    "release:sr_top500_whitelist_ad.conf"
    "release:lazy.conf"
    "release:sr_backcn.conf"
)

# 默认获取的分支 (release/master)
DEFAULT_BRANCH="release"

# -----------------
# 路径配置（一般不需要修改）
# -----------------

# 脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 缓存目录（规则文件）
CACHE_DIR="$HOME/.cache/openclaw-tailscale-proxy"

# 配置目录（自定义规则）
CONFIG_DIR="$HOME/.config/openclaw-tailscale-proxy"

# 日志目录
LOG_DIR="$HOME/logs"

# -----------------
# 规则配置
# -----------------

# 自定义规则文件
CUSTOM_RULES="$CONFIG_DIR/custom.conf"

# 合并后的规则文件
MERGED_RULES="$CACHE_DIR/merged.conf"

# 规则输出文件（合并后的规则路径，供其他工具使用）
RULES_OUTPUT="$CACHE_DIR/rules.conf"

# 日志文件
LOG_FILE="$LOG_DIR/openclaw-tailscale-proxy.log"

# ----------------- 🎯 默认规则配置
# 主规则文件（fetch 后默认使用的规则）
# 可选: sr_top500_banlist_ad.conf, lazy.conf, sr_backcn.conf 等
PRIMARY_RULES="sr_top500_banlist_ad.conf"