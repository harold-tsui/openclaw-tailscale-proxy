#!/bin/bash
# ============================================================
# OpenClaw Tailscale Proxy Manager
# 统一管理 Tailscale VPN + Shadowrocket 规则
# ============================================================

set -e

# 路径配置
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 加载配置
source "$SCRIPT_DIR/config.sh"

# 确保目录存在
ensure_dirs() {
    mkdir -p "$CACHE_DIR" "$CONFIG_DIR" "$LOG_DIR"
}

# ============================================================
# 通用函数
# ============================================================

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" >> "$LOG_FILE"
    echo "$msg" >&2
}

# ============================================================
# VPN 相关命令
# ============================================================

# 检测直连
check_direct() {
    curl -s --connect-timeout $CHECK_TIMEOUT -o /dev/null -w "%{http_code}" "https://$CHECK_TARGET" 2>/dev/null || echo "000"
}

# 获取 Tailscale 状态
get_tailscale_status() {
    tailscale status --json 2>/dev/null | grep -o '"BackendState":"[^"]*"' | cut -d'"' -f4 || echo "unknown"
}

# 检查网络状态
cmd_check() {
    ensure_dirs
    local direct_result=$(check_direct)
    local tailscale_status=$(get_tailscale_status)
    
    echo "========================================" >&2
    echo "🌐 网络状态检查" >&2
    echo "========================================" >&2
    echo "直连 $CHECK_TARGET: HTTP $direct_result" >&2
    echo "Tailscale 状态: ${tailscale_status:-unknown}" >&2
    echo "" >&2
    
    if [ "$direct_result" = "200" ]; then
        echo "✅ 直连正常 - 不需要 VPN" >&2
        return 0
    else
        echo "❌ 直连失败 - 需要代理" >&2
        return 1
    fi
}

# 启用 Tailscale
cmd_up() {
    ensure_dirs
    log "启用 Tailscale..."
    tailscale up --accept-routes --accept-dns
    
    sleep 2
    local status=$(get_tailscale_status)
    echo "📡 Tailscale 状态: $status" >&2
    
    # 验证连接
    sleep 2
    if [ "$(check_direct)" = "200" ]; then
        echo "✅ 连接成功" >&2
        return 0
    else
        echo "⚠️ 连接可能不稳定" >&2
        return 1
    fi
}

# 关闭 Tailscale
cmd_down() {
    ensure_dirs
    log "关闭 Tailscale..."
    tailscale down
    echo "⏸️ Tailscale 已关闭" >&2
}

# 自动模式：检测并按需启用 VPN
cmd_auto() {
    ensure_dirs
    local direct_result=$(check_direct)
    
    if [ "$direct_result" = "200" ]; then
        echo "🌐 直连正常，无需 VPN" >&2
        return 0
    fi
    
    echo "❌ 直连失败 (HTTP $direct_result)，尝试启用 Tailscale..." >&2
    log "直连失败，启用 Tailscale..."
    
    tailscale up --accept-routes --accept-dns
    sleep 3
    
    if [ "$(check_direct)" = "200" ]; then
        echo "✅ Tailscale 已生效" >&2
        log "Tailscale 连接成功"
        return 0
    else
        echo "❌ Tailscale 无法访问网络" >&2
        log "Tailscale 连接失败"
        return 1
    fi
}

# 执行命令（自动 VPN）
cmd_exec() {
    ensure_dirs
    
    if [ $# -eq 0 ]; then
        echo "错误: 请指定要执行的命令" >&2
        return 1
    fi
    
    local cmd_str="$*"
    echo "📌 执行: $cmd_str" >&2
    log "执行命令: $cmd_str"
    
    # 先测试直连
    local direct_result=$(check_direct)
    
    if [ "$direct_result" = "200" ]; then
        echo "🌐 直连正常" >&2
        eval "$cmd_str"
        return $?
    fi
    
    # 直连失败，启用 Tailscale
    echo "❌ 直连失败，启用 Tailscale..." >&2
    log "直连失败，启用 Tailscale..."
    
    tailscale up --accept-routes --accept-dns
    sleep 3
    
    if [ "$(check_direct)" = "200" ]; then
        echo "📡 执行命令..." >&2
        eval "$cmd_str"
        return $?
    else
        echo "❌ Tailscale 无法访问" >&2
        log "Tailscale 无法访问"
        return 1
    fi
}

# ============================================================
# 规则相关命令
# ============================================================

# 获取规则
cmd_fetch() {
    ensure_dirs
    local target="$1"
    
    log "=== 开始获取规则 ==="
    
    for item in "${RULES_SOURCES[@]}"; do
        local branch="${item%%:*}"
        local file="${item##*:}"
        
        # 过滤
        if [ -n "$target" ]; then
            if [ "$target" != "$branch" ] && [ "$target" != "$file" ]; then
                continue
            fi
        fi
        
        log "获取 $branch/$file..."
        
        curl -sLH "Accept: application/vnd.github.v3.raw" \
            "https://api.github.com/repos/$RULES_REPO/contents/$file?ref=$branch" \
            -o "$CACHE_DIR/${branch}_${file}" 2>/dev/null
        
        if [ -s "$CACHE_DIR/${branch}_${file}" ]; then
            local size=$(wc -c < "$CACHE_DIR/${branch}_${file}")
            log "✅ $branch/$file -> $size bytes"
        else
            log "❌ Failed: $branch/$file"
        fi
    done
    
    echo "=== 规则获取完成 ===" >&2
    ls -lh "$CACHE_DIR" >&2
}

# 列出规则
cmd_list() {
    ensure_dirs
    echo "=== 缓存规则 ===" >&2
    ls -lh "$CACHE_DIR" 2>/dev/null || echo "(空)" >&2
    
    echo "" >&2
    echo "=== 自定义规则 ===" >&2
    ls -lh "$CONFIG_DIR" 2>/dev/null || echo "(空)" >&2
}

# 规则统计
cmd_stats() {
    ensure_dirs
    local file="${1:-$CACHE_DIR/release_sr_top500_banlist_ad.conf}"
    
    if [ ! -f "$file" ]; then
        echo "文件不存在: $file" >&2
        echo "可用: $(ls $CACHE_DIR)" >&2
        return 1
    fi
    
    echo "=== $(basename $file) 统计 ===" >&2
    echo "代理域名: $(grep -c ',Proxy$' "$file")" >&2
    echo "直连域名: $(grep -c ',DIRECT$' "$file")" >&2
    echo "拒绝规则: $(grep -c ',REJECT$' "$file")" >&2
    echo "代理IP段: $(grep -c 'IP-CIDR.*,Proxy' "$file")" >&2
    echo "总行数: $(wc -l < "$file")" >&2
}

# 提取域名/IP
cmd_extract() {
    ensure_dirs
    local type="$1"
    local file="${2:-$CACHE_DIR/release_sr_top500_banlist_ad.conf}"
    
    if [ ! -f "$file" ]; then
        echo "文件不存在: $file" >&2
        return 1
    fi
    
    case "$type" in
        proxy-domains)
            grep -E "^(DOMAIN-SUFFIX|DOMAIN),.*,Proxy$" "$file" | cut -d',' -f2
            ;;
        direct-domains)
            grep -E "^(DOMAIN-SUFFIX|DOMAIN),.*,DIRECT$" "$file" | cut -d',' -f2
            ;;
        proxy-ips)
            grep -E "^IP-CIDR,.*,Proxy" "$file" | cut -d',' -f2
            ;;
        all)
            cat "$file"
            ;;
        *)
            echo "未知类型: $type" >&2
            echo "可用: proxy-domains, direct-domains, proxy-ips, all" >&2
            ;;
    esac
}

# 初始化自定义规则
cmd_custom_init() {
    ensure_dirs
    local custom_file="$CONFIG_DIR/custom.conf"
    
    if [ -f "$custom_file" ]; then
        echo "自定义规则已存在: $custom_file" >&2
        cat "$custom_file"
        return
    fi
    
    cat > "$custom_file" << 'EOF'
# ============================================
# 自定义规则补充
# 在此添加你的个性化规则
# ============================================

[Rule]
# 添加需要代理的域名
# DOMAIN-SUFFIX,github.com,Proxy
# DOMAIN,openai.com,Proxy

# 添加直连域名
# DOMAIN-SUFFIX,baidu.com,DIRECT
# DOMAIN-SUFFIX,qq.com,DIRECT

# 添加拒绝规则
# DOMAIN,ads.example.com,REJECT

# IP 规则
# IP-CIDR,192.168.0.0/16,DIRECT
# GEOIP,CN,DIRECT

# 兜底策略
# FINAL,Proxy
EOF
    
    log "创建自定义规则: $custom_file"
    echo "✅ 已创建: $custom_file" >&2
    echo "请编辑添加你的规则" >&2
}

# 添加自定义规则
cmd_custom_add() {
    ensure_dirs
    local rule="$*"
    local custom_file="$CONFIG_DIR/custom.conf"
    
    if [ -z "$rule" ]; then
        echo "用法: proxy.sh custom-add 'DOMAIN-SUFFIX,example.com,Proxy'" >&2
        return 1
    fi
    
    # 如果文件不存在，先创建
    if [ ! -f "$custom_file" ]; then
        cmd_custom_init
    fi
    
    # 检查是否重复
    if grep -q "^${rule}$" "$custom_file" 2>/dev/null; then
        echo "规则已存在: $rule" >&2
        return 1
    fi
    
    # 添加到 [Rule] 部分之后
    sed -i '' "s/^\[Rule\]$/[Rule]\n$rule/" "$custom_file"
    log "添加规则: $rule"
    echo "✅ 已添加: $rule" >&2
}

# 列出自定义规则
cmd_custom_list() {
    ensure_dirs
    local custom_file="$CONFIG_DIR/custom.conf"
    
    if [ ! -f "$custom_file" ]; then
        echo "无自定义规则 (运行 custom-init 初始化)" >&2
        return
    fi
    
    echo "=== 自定义规则 ===" >&2
    grep -v "^#" "$custom_file" | grep -v "^$" | grep -v "^\[" 
}

# 显示配置
cmd_config_show() {
    echo "=== 当前配置 ===" >&2
    echo "" >&2
    echo "配置文件: $CONFIG_DIR/config.sh" >&2
    echo "" >&2
    
    # 显示关键配置
    echo "检测目标: $CHECK_TARGET" >&2
    echo "检测超时: ${CHECK_TIMEOUT}秒" >&2
    echo "规则仓库: $RULES_REPO" >&2
    echo "默认分支: $DEFAULT_BRANCH" >&2
    echo "Tailscale 参数: $TAILSCALE_ARGS" >&2
    echo "自动断开: $AUTO_DISCONNECT" >&2
    echo "" >&2
    echo "缓存目录: $CACHE_DIR" >&2
    echo "配置目录: $CONFIG_DIR" >&2
    echo "日志文件: $LOG_FILE" >&2
    echo "" >&2
    
    # 显示规则源
    echo "=== 规则源 ===" >&2
    for item in "${RULES_SOURCES[@]}"; do
        echo "  $item" >&2
    done
}

# 编辑配置
cmd_config_edit() {
    ensure_dirs
    local config_file="$CONFIG_DIR/config.sh"
    
    # 如果配置文件不存在，从默认复制
    if [ ! -f "$config_file" ]; then
        cp "$SCRIPT_DIR/config.sh" "$config_file"
        echo "✅ 已创建配置文件: $config_file" >&2
    fi
    
    # 使用默认编辑器打开
    ${EDITOR:-vim} "$config_file"
}

# 合并规则
cmd_merge() {
    ensure_dirs
    local base="$CACHE_DIR/release_sr_top500_banlist_ad.conf"
    local custom="$CONFIG_DIR/custom.conf"
    local output="$CACHE_DIR/merged.conf"
    
    if [ ! -f "$base" ]; then
        echo "基础规则不存在，请先运行 fetch" >&2
        return 1
    fi
    
    # 复制基础规则
    cp "$base" "$output"
    
    # 追加自定义规则
    if [ -f "$custom" ]; then
        local rule_section=$(grep -n "^\[Rule\]" "$custom" | cut -d: -f1)
        
        if [ -n "$rule_section" ]; then
            tail -n +$rule_section "$custom" >> "$output"
            log "合并完成: $output"
        fi
    fi
    
    echo "✅ 合并完成: $output" >&2
    cmd_stats "$output"
}

# ============================================================
# 主入口
# ============================================================

cmd_help() {
    echo "========================================" >&2
    echo "OpenClaw Tailscale Proxy Manager" >&2
    echo "========================================" >&2
    echo "" >&2
    echo "用法: $0 <命令> [参数]" >&2
    echo "" >&2
    echo "VPN 命令:" >&2
    echo "  check              检查网络状态" >&2
    echo "  up                 启用 Tailscale" >&2
    echo "  down               关闭 Tailscale" >&2
    echo "  auto               自动检测并按需启用" >&2
    echo "  exec <command>     执行命令，自动开关 VPN" >&2
    echo "" >&2
    echo "规则命令:" >&2
    echo "  fetch [target]     获取规则 (可选: release, master)" >&2
    echo "  list               列出已缓存规则" >&2
    echo "  stats [file]       查看规则统计" >&2
    echo "  extract <type>     提取域名/IP (proxy-domains/direct-domains/proxy-ips/all)" >&2
    echo "  merge              合并基础+自定义规则" >&2
    echo "" >&2
    echo "自定义规则:" >&2
    echo "  custom-init        初始化自定义规则文件" >&2
    echo "  custom-add <rule>  添加自定义规则" >&2
    echo "  custom-list        查看自定义规则" >&2
    echo "" >&2
    echo "配置命令:" >&2
    echo "  config-show         显示当前配置" >&2
    echo "  config-edit         编辑配置文件" >&2
    echo "" >&2
    echo "示例:" >&2
    echo "  $0 check                   # 检查网络" >&2
    echo "  $0 exec curl https://api.github.com  # 自动执行" >&2
    echo "  $0 fetch release           # 获取规则" >&2
    echo "  $0 custom-add 'DOMAIN-SUFFIX,github.com,Proxy'" >&2
}

main() {
    ensure_dirs
    
    local cmd="${1:-help}"
    shift || true
    
    case "$cmd" in
        check)
            cmd_check
            ;;
        up)
            cmd_up
            ;;
        down)
            cmd_down
            ;;
        auto)
            cmd_auto
            ;;
        exec)
            cmd_exec "$@"
            ;;
        fetch)
            cmd_fetch "$1"
            ;;
        list)
            cmd_list
            ;;
        stats)
            cmd_stats "$1"
            ;;
        extract)
            cmd_extract "$1" "$2"
            ;;
        merge)
            cmd_merge
            ;;
        custom-init)
            cmd_custom_init
            ;;
        custom-add)
            cmd_custom_add "$@"
            ;;
        custom-list)
            cmd_custom_list
            ;;
        config-show)
            cmd_config_show
            ;;
        config-edit)
            cmd_config_edit
            ;;
        help|--help|-h)
            cmd_help
            ;;
        *)
            echo "未知命令: $cmd" >&2
            echo "" >&2
            cmd_help
            exit 1
            ;;
    esac
}

main "$@"