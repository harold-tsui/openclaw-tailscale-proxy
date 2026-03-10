#!/bin/bash
# ============================================================
# OpenClaw Tailscale Proxy Configuration
# ============================================================

# -----------------
# Network Check Config
# -----------------

# Target for direct connection test (backward compatibility)
CHECK_TARGET="google.com"

# Multiple targets for connection test (comma-separated)
# Will try each until one works
CHECK_TARGETS="google.com,youtube.com,api.github.com"

# Connection timeout in seconds
CHECK_TIMEOUT=5

# -----------------
# Rules Source Config
# -----------------

# Shadowrocket rules repository
RULES_REPO="Johnshall/Shadowrocket-ADBlock-Rules-Forever"

# Rules to fetch (format: branch:filename)
RULES_SOURCES=(
    "release:sr_top500_banlist_ad.conf"
    "release:sr_top500_whitelist_ad.conf"
    "release:lazy.conf"
    "release:sr_backcn.conf"
)

# Default branch to fetch from (release/master)
DEFAULT_BRANCH="release"

# -----------------
# Default Rules Config
# -----------------

# Primary rules file (used after fetch by default)
# Options: sr_top500_banlist_ad.conf, lazy.conf, sr_backcn.conf, etc.
PRIMARY_RULES="sr_top500_banlist_ad.conf"

# Merged rules output path (for use by other tools)
RULES_OUTPUT="$CACHE_DIR/rules.conf"

# -----------------
# Tailscale Config
# -----------------

# Tailscale up command arguments
TAILSCALE_ARGS="--accept-routes --accept-dns"

# Tailscale Exit Node (IP or hostname, empty = auto)
# Example: TAILSCALE_EXIT_NODE="100.100.100.100"
TAILSCALE_EXIT_NODE=""

# Tailscale config file path (empty = use default)
# Example: TAILSCALE_CONFIG="$HOME/.config/tailscale/config1.yaml"
TAILSCALE_CONFIG=""

# Wait seconds after enable before checking connection
TAILSCALE_WAIT=3

# Auto disconnect after exec (true/false)
AUTO_DISCONNECT=false

# -----------------
# Path Config (usually no need to change)
# -----------------

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cache directory for rules
CACHE_DIR="$HOME/.cache/openclaw-tailscale-proxy"

# Config directory for custom rules
CONFIG_DIR="$HOME/.config/openclaw-tailscale-proxy"

# Log directory
LOG_DIR="$HOME/logs"

# -----------------
# Rules Files
# -----------------

# Custom rules file
CUSTOM_RULES="$CONFIG_DIR/custom.conf"

# Merged rules file
MERGED_RULES="$CACHE_DIR/merged.conf"

# Rules output file
RULES_OUTPUT="$CACHE_DIR/rules.conf"

# Log file
LOG_FILE="$LOG_DIR/openclaw-tailscale-proxy.log"