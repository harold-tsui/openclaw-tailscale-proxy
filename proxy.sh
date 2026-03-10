#!/bin/bash
# ============================================================
# OpenClaw Tailscale Proxy Manager
# Unified management for Tailscale VPN + Shadowrocket rules
# ============================================================

set -e

# Path configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$HOME/.config/openclaw-tailscale-proxy"

# Load skill defaults first, then user config (user config overrides)
source "$SCRIPT_DIR/config.sh"
source "$CONFIG_DIR/config.sh" 2>/dev/null || true

# Ensure directories exist
ensure_dirs() {
    mkdir -p "$CACHE_DIR" "$CONFIG_DIR" "$LOG_DIR"
}

# ============================================================
# Common Functions
# ============================================================

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" >> "$LOG_FILE"
    echo "$msg" >&2
}

# ============================================================
# VPN Commands
# ============================================================

# Check direct connection (supports multiple targets)
check_direct() {
    # Default targets if not set
    local targets="${CHECK_TARGETS:-api.github.com,github.com}"
    
    # Get the primary target (first in list)
    local primary_target=$(echo "$targets" | cut -d',' -f1)
    
    # Check primary target - this is what we really need
    local result=$(curl -s --connect-timeout $CHECK_TIMEOUT -o /dev/null -w "%{http_code}" "https://$primary_target" 2>/dev/null || echo "000")
    
    if [ "$result" = "200" ]; then
        echo "200:$primary_target"
        return 0
    fi
    
    # If primary fails, check fallbacks
    for target in $(echo "$targets" | tr ',' ' ' | tail -n +2); do
        result=$(curl -s --connect-timeout $CHECK_TIMEOUT -o /dev/null -w "%{http_code}" "https://$target" 2>/dev/null || echo "000")
        if [ "$result" = "200" ]; then
            echo "200:$target"
            return 0
        fi
    done
    
    echo "000:$primary_target"
    return 1
}

# Get Tailscale status
get_tailscale_status() {
    tailscale status --json 2>/dev/null | grep -o '"BackendState":"[^"]*"' | cut -d'"' -f4 || echo "unknown"
}

# Check network status
cmd_check() {
    ensure_dirs
    local direct_result=$(check_direct)
    local result_code="${direct_result%%:*}"
    local result_target="${direct_result##*:}"
    local tailscale_status=$(get_tailscale_status)
    
    echo "========================================" >&2
    echo "🌐 Network Status Check" >&2
    echo "========================================" >&2
    echo "Direct test: HTTP $result_code (via $result_target)" >&2
    echo "Tailscale status: ${tailscale_status:-unknown}" >&2
    echo "" >&2
    
    if [ "$result_code" = "200" ]; then
        echo "✅ Direct connection OK ($result_target) - VPN not needed" >&2
        return 0
    else
        echo "❌ Direct connection failed - Proxy needed" >&2
        return 1
    fi
}

# Enable Tailscale
cmd_up() {
    ensure_dirs
    log "Enabling Tailscale..."
    
    # Build Tailscale command
    local cmd="tailscale up $TAILSCALE_ARGS"
    
    # Add exit node
    if [ -n "$TAILSCALE_EXIT_NODE" ]; then
        cmd="$cmd --exit-node=$TAILSCALE_EXIT_NODE"
        echo "🎯 Using exit node: $TAILSCALE_EXIT_NODE" >&2
    fi
    
    # Add config file
    if [ -n "$TAILSCALE_CONFIG" ]; then
        cmd="$cmd --config=$TAILSCALE_CONFIG"
        echo "📄 Using config: $TAILSCALE_CONFIG" >&2
    fi
    
    eval $cmd
    
    sleep 2
    local status=$(get_tailscale_status)
    echo "📡 Tailscale status: $status" >&2
    
    # Verify connection
    sleep 2
    local conn_result=$(check_direct)
    local conn_code="${conn_result%%:*}"
    if [ "$conn_code" = "200" ]; then
        echo "✅ Connection successful" >&2
        return 0
    else
        echo "⚠️ Connection may be unstable" >&2
        return 1
    fi
}

# Disable Tailscale
cmd_down() {
    ensure_dirs
    log "Disabling Tailscale..."
    tailscale down
    echo "⏸️ Tailscale stopped" >&2
}

# Auto mode: check and enable VPN if needed
cmd_auto() {
    ensure_dirs
    local direct_result=$(check_direct)
    local result_code="${direct_result%%:*}"
    
    if [ "$result_code" = "200" ]; then
        echo "🌐 Direct connection OK, no VPN needed" >&2
        return 0
    fi
    
    echo "❌ Direct failed (HTTP $result_code), trying Tailscale..." >&2
    log "Direct failed, enabling Tailscale..."
    
    # Call cmd_up logic
    cmd_up_inner
    sleep 3
    
    local retry_result=$(check_direct)
    local retry_code="${retry_result%%:*}"
    if [ "$retry_code" = "200" ]; then
        echo "✅ Tailscale active" >&2
        log "Tailscale connected"
        return 0
    else
        echo "❌ Tailscale cannot access network" >&2
        log "Tailscale connection failed"
        return 1
    fi
}

# Internal function: start Tailscale (called by cmd_up and cmd_auto)
cmd_up_inner() {
    # Build Tailscale command
    local ts_cmd="tailscale up $TAILSCALE_ARGS"
    
    # Add exit node
    if [ -n "$TAILSCALE_EXIT_NODE" ]; then
        ts_cmd="$ts_cmd --exit-node=$TAILSCALE_EXIT_NODE"
        echo "🎯 Using exit node: $TAILSCALE_EXIT_NODE" >&2
    fi
    
    # Add config file
    if [ -n "$TAILSCALE_CONFIG" ]; then
        ts_cmd="$ts_cmd --config=$TAILSCALE_CONFIG"
        echo "📄 Using config: $TAILSCALE_CONFIG" >&2
    fi
    
    eval $ts_cmd
}

# Execute command with auto VPN
cmd_exec() {
    ensure_dirs
    
    if [ $# -eq 0 ]; then
        echo "Error: Please specify command to execute" >&2
        return 1
    fi
    
    local cmd_str="$*"
    echo "📌 Executing: $cmd_str" >&2
    log "Executing: $cmd_str"
    
    # Test direct connection first
    local direct_result=$(check_direct)
    local result_code="${direct_result%%:*}"
    
    if [ "$result_code" = "200" ]; then
        echo "🌐 Direct OK" >&2
        eval "$cmd_str"
        return $?
    fi
    
    # Direct failed, enable Tailscale
    echo "❌ Direct failed, enabling Tailscale..." >&2
    log "Direct failed, enabling Tailscale..."
    
    tailscale up --accept-routes --accept-dns
    sleep 3
    
    local retry_result=$(check_direct)
    local retry_code="${retry_result%%:*}"
    if [ "$retry_code" = "200" ]; then
        echo "📡 Executing command..." >&2
        eval "$cmd_str"
        return $?
    else
        echo "❌ Tailscale cannot access" >&2
        log "Tailscale cannot access"
        return 1
    fi
}

# ============================================================
# Rules Commands
# ============================================================

# Fetch rules (with caching)
cmd_fetch() {
    ensure_dirs
    local force=false
    local max_age=86400  # Default: 24 hours in seconds
    local target=""
    
    # Parse arguments
    while [[ "$1" == --* ]]; do
        case "$1" in
            --force)
                force=true
                shift
                ;;
            --max-age)
                max_age="$2"
                shift 2
                ;;
            --no-cache)
                max_age=0
                shift
                ;;
            *)
                break
                ;;
        esac
    done
    
    # Remaining argument is target
    target="$1"
    
    log "=== Starting to fetch rules (force=$force, max_age=${max_age}s) ==="
    
    for item in "${RULES_SOURCES[@]}"; do
        local branch="${item%%:*}"
        local file="${item##*:}"
        local cache_file="$CACHE_DIR/${branch}_${file}"
        
        # Filter
        if [ -n "$target" ]; then
            if [ "$target" != "$branch" ] && [ "$target" != "$file" ]; then
                continue
            fi
        fi
        
        # Check cache
        if [ -f "$cache_file" ] && [ "$force" = "false" ]; then
            local file_age=$(($(date +%s) - $(stat -f %m "$cache_file" 2>/dev/null || stat -c %Y "$cache_file" 2>/dev/null || echo 0)))
            if [ "$file_age" -lt "$max_age" ]; then
                local size=$(wc -c < "$cache_file")
                log "⏭️  Skipping $branch/$file (cache age: ${file_age}s, max: ${max_age}s) -> $size bytes"
                continue
            fi
        fi
        
        log "Fetching $branch/$file..."
        
        curl -sLH "Accept: application/vnd.github.v3.raw" \
            "https://api.github.com/repos/$RULES_REPO/contents/$file?ref=$branch" \
            -o "$cache_file" 2>/dev/null
        
        if [ -s "$cache_file" ]; then
            local size=$(wc -c < "$cache_file")
            log "✅ $branch/$file -> $size bytes"
        else
            log "❌ Failed: $branch/$file"
        fi
    done
    
    echo "=== Rules fetch complete ===" >&2
    ls -lh "$CACHE_DIR" >&2
}

# List rules
cmd_list() {
    ensure_dirs
    echo "=== Cached rules ===" >&2
    ls -lh "$CACHE_DIR" 2>/dev/null || echo "(empty)" >&2
    
    echo "" >&2
    echo "=== Custom rules ===" >&2
    ls -lh "$CONFIG_DIR" 2>/dev/null || echo "(empty)" >&2
}

# Rules stats
cmd_stats() {
    ensure_dirs
    local file="${1:-$CACHE_DIR/release_sr_top500_banlist_ad.conf}"
    
    if [ ! -f "$file" ]; then
        echo "File not found: $file" >&2
        echo "Available: $(ls $CACHE_DIR)" >&2
        return 1
    fi
    
    echo "=== $(basename $file) Stats ===" >&2
    echo "Proxy domains: $(grep -c ',Proxy$' "$file")" >&2
    echo "Direct domains: $(grep -c ',DIRECT$' "$file")" >&2
    echo "Reject rules: $(grep -c ',REJECT$' "$file")" >&2
    echo "Proxy IPs: $(grep -c 'IP-CIDR.*,Proxy' "$file")" >&2
    echo "Total lines: $(wc -l < "$file")" >&2
}

# Extract domain/IP
cmd_extract() {
    ensure_dirs
    local type="$1"
    local file="${2:-$CACHE_DIR/release_sr_top500_banlist_ad.conf}"
    
    if [ ! -f "$file" ]; then
        echo "File not found: $file" >&2
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
            echo "Unknown type: $type" >&2
            echo "Available: proxy-domains, direct-domains, proxy-ips, all" >&2
            ;;
    esac
}

# Initialize custom rules
cmd_custom_init() {
    ensure_dirs
    local custom_file="$CONFIG_DIR/custom.conf"
    
    if [ -f "$custom_file" ]; then
        echo "Custom rules already exist: $custom_file" >&2
        cat "$custom_file"
        return
    fi
    
    cat > "$custom_file" << 'EOF'
# ============================================
# Custom Rules Supplement
# Add your personalized rules here
# ============================================

[Rule]
# Add proxy domains
# DOMAIN-SUFFIX,github.com,Proxy
# DOMAIN,openai.com,Proxy

# Add direct domains
# DOMAIN-SUFFIX,baidu.com,DIRECT
# DOMAIN-SUFFIX,qq.com,DIRECT

# Add reject rules
# DOMAIN,ads.example.com,REJECT

# IP rules
# IP-CIDR,192.168.0.0/16,DIRECT
# GEOIP,CN,DIRECT

# Fallback strategy
# FINAL,Proxy
EOF
    
    log "Created custom rules: $custom_file"
    echo "✅ Created: $custom_file" >&2
    echo "Please edit to add your rules" >&2
}

# Add custom rule
cmd_custom_add() {
    ensure_dirs
    local rule="$*"
    local custom_file="$CONFIG_DIR/custom.conf"
    
    if [ -z "$rule" ]; then
        echo "Usage: proxy.sh custom-add 'DOMAIN-SUFFIX,example.com,Proxy'" >&2
        return 1
    fi
    
    # If file doesn't exist, create it first
    if [ ! -f "$custom_file" ]; then
        cmd_custom_init
    fi
    
    # Check for duplicates
    if grep -q "^${rule}$" "$custom_file" 2>/dev/null; then
        echo "Rule already exists: $rule" >&2
        return 1
    fi
    
    # Add after [Rule] section
    sed -i '' "s/^\[Rule\]$/[Rule]\n$rule/" "$custom_file"
    log "Added rule: $rule"
    echo "✅ Added: $rule" >&2
}

# List custom rules
cmd_custom_list() {
    ensure_dirs
    local custom_file="$CONFIG_DIR/custom.conf"
    
    if [ ! -f "$custom_file" ]; then
        echo "No custom rules (run custom-init to initialize)" >&2
        return
    fi
    
    echo "=== Custom rules ===" >&2
    grep -v "^#" "$custom_file" | grep -v "^$" | grep -v "^\[" 
}

# Show config
cmd_config_show() {
    echo "=== Current Config ===" >&2
    echo "" >&2
    echo "Config file: $CONFIG_DIR/config.sh" >&2
    echo "" >&2
    
    # Show key config
    echo "Check target: $CHECK_TARGET" >&2
    echo "Check timeout: ${CHECK_TIMEOUT}s" >&2
    echo "" >&2
    
    # Rules config
    echo "=== Rules Config ===" >&2
    echo "Rules repo: $RULES_REPO" >&2
    echo "Default branch: $DEFAULT_BRANCH" >&2
    echo "Primary rules: $PRIMARY_RULES" >&2
    echo "Rules output: $RULES_OUTPUT" >&2
    echo "" >&2
    
    # Tailscale config
    echo "=== Tailscale Config ===" >&2
    echo "Args: $TAILSCALE_ARGS" >&2
    echo "Exit node: ${TAILSCALE_EXIT_NODE:-(auto)}" >&2
    echo "Config file: ${TAILSCALE_CONFIG:-(default)}" >&2
    echo "Auto disconnect: $AUTO_DISCONNECT" >&2
    echo "" >&2
    
    # Path config
    echo "=== Path Config ===" >&2
    echo "Cache dir: $CACHE_DIR" >&2
    echo "Config dir: $CONFIG_DIR" >&2
    echo "Log file: $LOG_FILE" >&2
    echo "" >&2
    
    # 显示规则源
    echo "=== 规则源列表 ===" >&2
    for item in "${RULES_SOURCES[@]}"; do
        echo "  $item" >&2
    done
}

# Edit config
cmd_config_edit() {
    ensure_dirs
    local config_file="$CONFIG_DIR/config.sh"
    
    # If config doesn't exist, copy from default
    if [ ! -f "$config_file" ]; then
        cp "$SCRIPT_DIR/config.sh" "$config_file"
        echo "✅ Created config file: $config_file" >&2
    fi
    
    # Open with default editor
    ${EDITOR:-vim} "$config_file"
}

# Merge rules with deduplication
cmd_merge() {
    ensure_dirs
    local dedup=true
    local output_file=""
    
    # Parse arguments
    while [[ "$1" == --* ]]; do
        case "$1" in
            --no-dedup)
                dedup=false
                shift
                ;;
            --output|-o)
                output_file="$2"
                shift 2
                ;;
            *)
                break
                ;;
        esac
    done
    
    local base="$CACHE_DIR/release_sr_top500_banlist_ad.conf"
    local custom="$CONFIG_DIR/custom.conf"
    local output="${output_file:-$CACHE_DIR/merged.conf}"
    
    if [ ! -f "$base" ]; then
        echo "Base rules not found, run fetch first" >&2
        return 1
    fi
    
    echo "=== Merging rules ===" >&2
    
    # Copy base rules to temp file
    local temp=$(mktemp)
    cp "$base" "$temp"
    
    # Append custom rules
    if [ -f "$custom" ]; then
        local rule_section=$(grep -n "^\[Rule\]" "$custom" | cut -d: -f1)
        
        if [ -n "$rule_section" ]; then
            tail -n +$rule_section "$custom" >> "$temp"
            echo "📝 Added custom rules" >&2
        fi
    fi
    
    # Deduplicate if enabled
    if [ "$dedup" = "true" ]; then
        local before=$(wc -l < "$temp")
        
        # Sort and remove duplicates (keep order)
        local deduped=$(mktemp)
        awk '!seen[$0]++' "$temp" > "$deduped"
        
        local after=$(wc -l < "$deduped")
        local removed=$((before - after))
        
        mv "$deduped" "$temp"
        
        echo "🧹 Deduplication: removed $removed duplicate rules" >&2
    fi
    
    # Move to output
    mv "$temp" "$output"
    
    local final_count=$(wc -l < "$output")
    echo "✅ Merge complete: $output ($final_count rules)" >&2
    
    # Show stats
    cmd_stats "$output"
    
    log "Merged rules: $output (dedup=$dedup)"
}

# ============================================================
# Cron / Auto Update Commands
# ============================================================

# Add cron job for auto update
cmd_cron_add() {
    local schedule="${1:-0 8 * * *}"  # Default: 8 AM daily
    
    echo "=== Setting up auto-update cron ===" >&2
    echo "Schedule: $schedule" >&2
    
    # Create the cron script
    local cron_script="$CONFIG_DIR/cron-update.sh"
    local proxy_sh="$SCRIPT_DIR/proxy.sh"
    local config_sh="$SCRIPT_DIR/config.sh"
    
    cat > "$cron_script" << EOF
#!/bin/bash
# Auto-update rules - Generated by openclaw-tailscale-proxy
# Schedule: $schedule

# Use absolute paths
PROXY_SH="$proxy_sh"
CONFIG_SH="$config_sh"

source "\$CONFIG_SH"

LOG_DIR="\$HOME/logs"
mkdir -p "\$LOG_DIR"

exec >> "\$LOG_DIR/openclaw-tailscale-proxy-cron.log" 2>&1

echo "=== [\$(date)] Starting auto-update ==="

# Fetch rules (use cache, force if > 24h)
"\$PROXY_SH" fetch release

# Merge rules
"\$PROXY_SH" merge

echo "=== [\$(date)] Auto-update complete ==="
EOF
    
    chmod +x "$cron_script"
    
    # Add to system crontab using temp file (more reliable on macOS)
    local full_path=$(realpath "$cron_script")
    local temp=$(mktemp)
    
    echo "" >&2
    echo "Cron script: $cron_script" >&2
    echo "" >&2
    
    # Store current crontab and add new job
    crontab -l 2>/dev/null > "$temp" || true
    grep -v "proxy-update" "$temp" > "${temp}.2" || true
    echo "$schedule $full_path" >> "${temp}.2"
    crontab < "${temp}.2"
    rm -f "$temp" "${temp}.2"
    
    echo "✅ Cron job added to system crontab" >&2
    
    echo "✅ Cron job added" >&2
    cmd_cron_list
}

# Remove cron job
cmd_cron_remove() {
    echo "=== Removing auto-update cron ===" >&2
    
    # Remove from system crontab
    crontab -l 2>/dev/null | grep -v "proxy-update" | crontab - 2>/dev/null || true
    
    echo "✅ Cron job removed" >&2
}

# List cron jobs
cmd_cron_list() {
    echo "=== Auto-update cron status ===" >&2
    
    # Check system crontab
    echo "" >&2
    echo "System crontab:" >&2
    crontab -l 2>/dev/null | grep "proxy-update" || echo "  (none)" >&2
    
    # Show next run time
    echo "" >&2
    echo "Next scheduled runs:" >&2
    for job in $(crontab -l 2>/dev/null | grep "proxy-update"); do
        echo "  $job" >&2
    done
}

# ============================================================
# Main Entry
# ============================================================

cmd_help() {
    echo "========================================" >&2
    echo "OpenClaw Tailscale Proxy Manager" >&2
    echo "========================================" >&2
    echo "" >&2
    echo "Usage: $0 <command> [args]" >&2
    echo "" >&2
    echo "VPN Commands:" >&2
    echo "  check              Check network status" >&2
    echo "  up                 Enable Tailscale" >&2
    echo "  down               Disable Tailscale" >&2
    echo "  auto               Auto detect and enable if needed" >&2
    echo "  exec <command>     Execute command with auto VPN" >&2
    echo "" >&2
    echo "Rules Commands:" >&2
    echo "  fetch [target]       Fetch rules (optional: release, master)" >&2
    echo "  list                List cached rules" >&2
    echo "  stats [file]        Show rules statistics" >&2
    echo "  extract <type>      Extract domains/IPs (proxy-domains/direct-domains/proxy-ips/all)" >&2
    echo "  merge               Merge base+custom rules with deduplication" >&2
    echo "  cron-add [schedule] Setup auto-update cron (default: 8 AM daily)" >&2
    echo "  cron-remove         Remove auto-update cron" >&2
    echo "  cron-list           Show cron status" >&2
    echo "" >&2
    echo "Custom Rules:" >&2
    echo "  custom-init        Initialize custom rules file" >&2
    echo "  custom-add <rule>  Add custom rule" >&2
    echo "  custom-list       List custom rules" >&2
    echo "" >&2
    echo "Config Commands:" >&2
    echo "  config-show         Show current config" >&2
    echo "  config-edit         Edit config file" >&2
    echo "" >&2
    echo "Examples:" >&2
    echo "  $0 check                   # Check network" >&2
    echo "  $0 exec curl https://api.github.com  # Auto execute" >&2
    echo "  $0 fetch release           # Fetch rules (with cache)" >&2
    echo "  $0 fetch --force release   # Force refresh rules" >&2
    echo "  $0 merge                    # Merge rules with deduplication" >&2
    echo "  $0 merge --no-dedup        # Merge without deduplication" >&2
    echo "  $0 cron-add '0 8 * * *'    # Auto-update daily at 8 AM" >&2
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
            cmd_fetch "$@"
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
            cmd_merge "$@"
            ;;
        cron-add)
            cmd_cron_add "$1"
            ;;
        cron-remove)
            cmd_cron_remove
            ;;
        cron-list)
            cmd_cron_list
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
            echo "Unknown command: $cmd" >&2
            echo "" >&2
            cmd_help
            exit 1
            ;;
    esac
}

main "$@"