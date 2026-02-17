#!/usr/bin/env bash
# Async Claude Code statusline with caching
# Shows cached results immediately, updates in background
set -o pipefail

# Get stdin (Claude Code JSON context)
INPUT=$(cat)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)

# Cache directory
CACHE_DIR="${HOME}/.cache/claude-statusline"
mkdir -p "$CACHE_DIR"

# Cache files (keyed by CWD hash for repo-specific caching)
CWD_HASH=$(echo -n "$CWD" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "default")
GIT_CACHE="${CACHE_DIR}/git-${CWD_HASH}"
AWS_CACHE="${CACHE_DIR}/aws-sso"
K8S_CACHE="${CACHE_DIR}/k8s-token"

SCRIPT_DIR="${SCRIPT_DIR:-${HOME}/.claude}"

# Cache TTL (seconds)
GIT_TTL=30   # Git/GitLab updates every 30s
AUTH_TTL=60  # Auth checks every 60s

# Function to check if cache is fresh
is_fresh() {
    local cache_file="$1"
    local ttl="$2"

    [ ! -f "$cache_file" ] && return 1

    local mtime
    local now
    mtime=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null)
    now=$(date +%s)
    local age=$((now - mtime))

    [ "$age" -lt "$ttl" ]
}

# Function to update cache in background
update_cache_bg() {
    local cache_file="$1"
    local command="$2"

    # Use flock to prevent duplicate updates
    local lock_file="${cache_file}.lock"

    # shellcheck disable=SC2094
    (
        # Try to acquire lock (non-blocking)
        if command -v flock &>/dev/null; then
            flock -n 9 || exit 0
        else
            # macOS doesn't have flock, use mkdir as atomic lock
            mkdir "$lock_file" 2>/dev/null || exit 0
            trap 'rmdir "$lock_file" 2>/dev/null' EXIT
        fi

        # Update cache
        eval "$command" > "${cache_file}.tmp" 2>/dev/null
        mv "${cache_file}.tmp" "$cache_file" 2>/dev/null

    ) 9>"$lock_file" &

    disown
}

# 1. Git/GitLab status (cached per-repo)
if is_fresh "$GIT_CACHE" "$GIT_TTL"; then
    GIT_STATUS=$(cat "$GIT_CACHE" 2>/dev/null)
else
    # Return cached value (even if stale) or placeholder if missing
    if [ -f "$GIT_CACHE" ]; then
        GIT_STATUS=$(cat "$GIT_CACHE" 2>/dev/null)
    else
        GIT_STATUS="\e[90m🔄\e[0m"
    fi

    # Update in background
    update_cache_bg "$GIT_CACHE" "echo '$INPUT' | ${SCRIPT_DIR}/gitlab-status.sh"
fi

# 2. AWS SSO (global cache)
if is_fresh "$AWS_CACHE" "$AUTH_TTL"; then
    AWS_SSO=$(cat "$AWS_CACHE" 2>/dev/null)
else
    # Return cached value or placeholder if missing
    if [ -f "$AWS_CACHE" ]; then
        AWS_SSO=$(cat "$AWS_CACHE" 2>/dev/null)
    else
        AWS_SSO="\e[90maws:🔄\e[0m"
    fi
    update_cache_bg "$AWS_CACHE" "${SCRIPT_DIR}/aws-sso-status.sh"
fi

# 3. K8s token (global cache, but context-sensitive)
if is_fresh "$K8S_CACHE" "$AUTH_TTL"; then
    K8S_TOKEN=$(cat "$K8S_CACHE" 2>/dev/null)
else
    # Return cached value or placeholder if missing
    if [ -f "$K8S_CACHE" ]; then
        K8S_TOKEN=$(cat "$K8S_CACHE" 2>/dev/null)
    else
        K8S_TOKEN="\e[90m⛵🔄\e[0m"
    fi
    update_cache_bg "$K8S_CACHE" "${SCRIPT_DIR}/k8s-token-status.sh"
fi

# 4. Extract Claude Code metrics from JSON
RST='\e[0m'
GRN='\e[32m'
YEL='\e[33m'
ORN='\e[38;5;208m'
RED='\e[31m'
GRY='\e[90m'

CLAUDE_METRICS=""

# Context window usage (always shown)
CTX_PCT=$(printf '%s' "$INPUT" | jq -r '.context_window.used_percentage // 0' 2>/dev/null)
if [ -n "$CTX_PCT" ] && [ "$CTX_PCT" != "0" ] && [ "$CTX_PCT" != "null" ]; then
    CTX_INT=$(printf '%.0f' "$CTX_PCT" 2>/dev/null)
    # Color based on usage: green <50%, yellow 50-79%, orange 80-89%, red 90%+
    if [ "$CTX_INT" -ge 90 ]; then
        CTX_COLOR="$RED"
        CTX_ICON="🔴"
    elif [ "$CTX_INT" -ge 80 ]; then
        CTX_COLOR="$ORN"
        CTX_ICON="⚠️"
    elif [ "$CTX_INT" -ge 50 ]; then
        CTX_COLOR="$YEL"
        CTX_ICON=""
    else
        CTX_COLOR="$GRN"
        CTX_ICON=""
    fi
    CLAUDE_METRICS="${CTX_COLOR}ctx:${CTX_INT}%${CTX_ICON}${RST}"
fi

# Session cost (show when >= $0.01)
COST=$(printf '%s' "$INPUT" | jq -r '.cost.total_cost_usd // 0' 2>/dev/null)
if [ -n "$COST" ] && [ "$COST" != "0" ] && [ "$COST" != "null" ]; then
    # Convert to cents for comparison
    COST_CENTS=$(printf '%.0f' "$(echo "$COST * 100" | bc 2>/dev/null)" 2>/dev/null)
    if [ -n "$COST_CENTS" ] && [ "$COST_CENTS" -ge 1 ]; then
        # Color: normal <$0.50, orange >=$0.50
        if [ "$COST_CENTS" -ge 50 ]; then
            COST_STR="${ORN}\$$(printf '%.2f' "$COST")${RST}"
        else
            COST_STR="\$$(printf '%.2f' "$COST")"
        fi
        CLAUDE_METRICS="${CLAUDE_METRICS:+$CLAUDE_METRICS }${COST_STR}"
    fi
fi

# Model indicator (show when non-default)
MODEL=$(printf '%s' "$INPUT" | jq -r '.model // empty' 2>/dev/null)
if [ -n "$MODEL" ] && [ "$MODEL" != "null" ]; then
    # Check if it's not the default (Opus 4.6 / sonnet)
    if [[ "$MODEL" != *"opus"* ]] && [[ "$MODEL" != *"sonnet"* ]]; then
        # Abbreviate model name
        if [[ "$MODEL" == *"haiku"* ]]; then
            MODEL_SHORT="[H]"
        else
            MODEL_SHORT="[${MODEL:0:3}]"
        fi
        CLAUDE_METRICS="${CLAUDE_METRICS:+$CLAUDE_METRICS }${GRY}${MODEL_SHORT}${RST}"
    fi
fi

# Build output from cached values
OUTPUT="$GIT_STATUS"

AUTH_PARTS=""
[ -n "$AWS_SSO" ] && AUTH_PARTS="$AWS_SSO"
[ -n "$K8S_TOKEN" ] && AUTH_PARTS="${AUTH_PARTS:+$AUTH_PARTS }$K8S_TOKEN"

if [ -n "$AUTH_PARTS" ]; then
    OUTPUT="$OUTPUT \e[90m|\e[0m $AUTH_PARTS"
fi

if [ -n "$CLAUDE_METRICS" ]; then
    OUTPUT="$OUTPUT \e[90m|\e[0m $CLAUDE_METRICS"
fi

# Show cached output immediately (fast!)
printf '%b\n' "$OUTPUT"
