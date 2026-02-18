#!/usr/bin/env bash
# Kubernetes OIDC token expiry checker for statusline/prompt
set -o pipefail

# ANSI colors
RST='\e[0m'
GRN='\e[32m'
YEL='\e[33m'
RED='\e[31m'
GRY='\e[90m'

# Find kubeconfig (respect $KUBECONFIG env var, handle colon-separated lists)
if [ -n "$KUBECONFIG" ]; then
    # Use existing $KUBECONFIG (may be colon-separated list)
    KUBE_CFG="$KUBECONFIG"
elif [ -f "$HOME/.kube/config" ]; then
    KUBE_CFG="$HOME/.kube/config"
elif [ -d "$HOME/.nlk" ]; then
    # Auto-detect nlk kubeconfig (use most recently modified)
    KUBE_CFG=$(find "$HOME/.nlk" -maxdepth 2 -name "kube.config" -type f -exec stat -c '%Y %n' {} \; 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2)
    [ -z "$KUBE_CFG" ] && exit 0
else
    exit 0
fi

# For multi-file $KUBECONFIG, kubectl merges them automatically
# Just check if at least one file exists
if [ "$KUBE_CFG" = "$KUBECONFIG" ] && [[ "$KUBECONFIG" == *:* ]]; then
    # Colon-separated list - check if any file exists
    HAS_FILE=0
    IFS=':' read -ra FILES <<< "$KUBECONFIG"
    for f in "${FILES[@]}"; do
        [ -f "$f" ] && HAS_FILE=1 && break
    done
    [ "$HAS_FILE" -eq 0 ] && exit 0
elif [ ! -f "$KUBE_CFG" ]; then
    exit 0
fi

# Set KUBECONFIG for kubectl commands below
export KUBECONFIG="$KUBE_CFG"

# Fast path: use kubectl if available
if command -v kubectl &>/dev/null; then
    CONTEXT=$(kubectl config current-context 2>/dev/null)
    # If no current context, pick the first available one
    if [ -z "$CONTEXT" ]; then
        CONTEXT=$(kubectl config get-contexts -o name 2>/dev/null | head -n1)
        [ -z "$CONTEXT" ] && exit 0
    fi
    USER=$(kubectl config view --context="$CONTEXT" --output jsonpath='{.contexts[?(@.name=="'"$CONTEXT"'")].context.user}' 2>/dev/null)
else
    # Fallback: parse YAML manually
    CONTEXT=$(grep 'current-context:' "$KUBECONFIG" | awk '{print $2}' | tr -d '\n\r')
    if [ -z "$CONTEXT" ]; then
        CONTEXT=$(grep -E '^\s*name:' "$KUBECONFIG" | grep -A1 '^contexts:' | grep 'name:' | head -n1 | awk '{print $2}' | tr -d '\n\r')
        [ -z "$CONTEXT" ] && exit 0
    fi
    USER=$(grep -A 3 "name: $CONTEXT" "$KUBECONFIG" | grep 'user:' | awk '{print $2}' | tr -d '\n\r')
fi

[ -z "$USER" ] && exit 0

# Extract exp from JWT (without jq)
jwt_exp() {
    local token="$1"
    local payload
    payload=$(echo "$token" | cut -d. -f2)

    # Add base64 padding if needed
    local padded="$payload"
    case $((${#payload} % 4)) in
        2) padded="${payload}==" ;;
        3) padded="${payload}=" ;;
    esac

    # Decode and extract exp
    echo "$padded" | base64 -d 2>/dev/null | grep -o '"exp":[0-9]*' | cut -d: -f2
}

# Format duration
format_duration() {
    local seconds=$1
    [ "$seconds" -lt 0 ] && seconds=0

    local hours=$((seconds / 3600))
    local mins=$(((seconds % 3600) / 60))

    if [ "$hours" -gt 0 ]; then
        echo "${hours}h${mins}m"
    else
        echo "${mins}m"
    fi
}

# Try to find token
TOKEN=""

# Method 1: Check exec-based auth cache
CACHE_DIRS=(
    "$HOME/.kube/cache/oidc-login"
    "$HOME/.kube/cache"
)

for cache_dir in "${CACHE_DIRS[@]}"; do
    [ ! -d "$cache_dir" ] && continue

    # Find most recent token file
    # oidc-login cache doesn't contain context/user in file content, just find latest .json
    if [[ "$cache_dir" == *"oidc-login"* ]]; then
        token_file=$(find "$cache_dir" -type f -name "*.json" -o -name "[a-f0-9]*" 2>/dev/null | \
                     grep -v '\.lock$' | head -1)
    else
        token_file=$(find "$cache_dir" -type f \( -name "*.json" -o -name "*token*" \) -print0 2>/dev/null | \
                     xargs -0 grep -l "$USER\|$CONTEXT" 2>/dev/null | head -1)
    fi

    if [ -n "$token_file" ] && [ -f "$token_file" ]; then
        TOKEN=$(grep -o '"id_token":"[^"]*' "$token_file" | cut -d'"' -f4)
        [ -z "$TOKEN" ] && TOKEN=$(grep -o '"access_token":"[^"]*' "$token_file" | cut -d'"' -f4)
        [ -n "$TOKEN" ] && break
    fi
done

# Method 2: Embedded token in kubeconfig
if [ -z "$TOKEN" ] && command -v kubectl &>/dev/null; then
    TOKEN=$(kubectl config view --minify --output jsonpath="{.users[?(@.name=='$USER')].user.token}" 2>/dev/null)
fi

# Abbreviate context name for space (remove k3s-, eks- prefixes)
CTX_SHORT=$(echo "$CONTEXT" | sed 's/^k3s-//;s/^eks-//;s/^arn:aws:eks:[^:]*:[^:]*:cluster\///')

# If no token found, show AUTH NEEDED
if [ -z "$TOKEN" ]; then
    printf '%b' "${GRY}⛵${RED}${CTX_SHORT}:AUTH${RST}"
    exit 0
fi

# Extract expiry from JWT
EXP=$(jwt_exp "$TOKEN")
if [ -z "$EXP" ] || [ "$EXP" = "null" ]; then
    printf '%b' "${GRY}⛵${RED}${CTX_SHORT}:AUTH${RST}"
    exit 0
fi

# Calculate remaining time
NOW=$(date +%s)
REMAINING=$((EXP - NOW))
DURATION=$(format_duration "$REMAINING")

# Determine color based on remaining time
if [ "$REMAINING" -gt 3600 ]; then
    COLOR="$GRN"  # >1h = green
elif [ "$REMAINING" -gt 900 ]; then
    COLOR="$YEL"  # 15min-1h = yellow
elif [ "$REMAINING" -gt 0 ]; then
    COLOR="$RED"  # 0-15min = red
else
    COLOR="$RED"
    DURATION="expired"
fi

printf '%b' "${GRY}⛵${COLOR}${CTX_SHORT}:${DURATION}${RST}"
