#!/usr/bin/env bash
# AWS SSO session expiry checker for statusline/prompt
set -o pipefail

# ANSI colors
RST='\e[0m'
GRN='\e[32m'
YEL='\e[33m'
RED='\e[31m'

# Check if cache directory exists
SSO_CACHE="${HOME}/.aws/sso/cache"
[ ! -d "$SSO_CACHE" ] && exit 0

# Find all cache files
CACHE_FILES=("$SSO_CACHE"/*.json)
[ ! -e "${CACHE_FILES[0]}" ] && exit 0

# Get current epoch time
NOW=$(date +%s)

# Track shortest expiry
SHORTEST_EXPIRY=9999999999

# Parse each cache file for expiresAt
for file in "${CACHE_FILES[@]}"; do
    # Fast JSON parse: {"expiresAt": "2026-02-16T23:59:59Z",...}
    # Handle both "expiresAt":"..." and "expiresAt": "..." formats
    EXPIRES_AT=$(grep -o '"expiresAt"[: ]*"[^"]*"' "$file" 2>/dev/null | grep -o '[0-9T:Z-]*Z')

    [ -z "$EXPIRES_AT" ] && continue

    # Convert ISO 8601 to epoch (GNU/BSD date compatible)
    if date --version >/dev/null 2>&1; then
        # GNU date (Linux)
        EXPIRES_EPOCH=$(date -d "$EXPIRES_AT" +%s 2>/dev/null)
    else
        # BSD date (macOS)
        EXPIRES_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$EXPIRES_AT" +%s 2>/dev/null)
    fi

    [ -z "$EXPIRES_EPOCH" ] && continue

    # Track shortest expiry
    if [ "$EXPIRES_EPOCH" -lt "$SHORTEST_EXPIRY" ]; then
        SHORTEST_EXPIRY="$EXPIRES_EPOCH"
    fi
done

# No valid expiry found
[ "$SHORTEST_EXPIRY" -eq 9999999999 ] && exit 0

# Calculate time remaining
REMAINING=$((SHORTEST_EXPIRY - NOW))

# Check if expired
if [ "$REMAINING" -le 0 ]; then
    printf '%b' "${RED}aws:expired${RST}"
    exit 0
fi

# Convert seconds to human-readable
HOURS=$((REMAINING / 3600))
MINUTES=$(((REMAINING % 3600) / 60))

# Format output
if [ "$HOURS" -gt 0 ]; then
    TIME_STR="${HOURS}h${MINUTES}m"
else
    TIME_STR="${MINUTES}m"
fi

# Color based on thresholds
if [ "$REMAINING" -gt 1800 ]; then
    # >30 min: green
    COLOR="$GRN"
elif [ "$REMAINING" -gt 600 ]; then
    # 10-30 min: yellow
    COLOR="$YEL"
else
    # <10 min: red
    COLOR="$RED"
fi

printf '%b' "${COLOR}aws:${TIME_STR}${RST}"
