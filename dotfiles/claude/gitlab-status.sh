#!/usr/bin/env bash
# Claude Code statusline: git + GitLab CI (with child pipeline tracking) + MR + auth expiry
set -o pipefail

# Consume stdin JSON, extract cwd
INPUT=$(cat)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$CWD" ] && cd "$CWD" 2>/dev/null || true

# ANSI colors
RST='\e[0m'
GRN='\e[32m'
YEL='\e[33m'
RED='\e[31m'
BLU='\e[34m'
GRY='\e[90m'
ORN='\e[38;5;208m'

# OSC 8 hyperlink: makes terminal text clickable
# Auto-detect support: if TERM supports it, use hyperlinks, otherwise plain text
mk_link() {
    local url="$1"
    local text="$2"

    # Check if terminal likely supports OSC 8 (most modern terminals do)
    # Disable if TERM is dumb, or if we're in a pipe/non-interactive context
    if [ -t 1 ] && [ "$TERM" != "dumb" ] && [ -n "$TERM" ]; then
        # Use OSC 8: ESC]8;;URL BEL text ESC]8;; BEL
        printf '\033]8;;%s\007%s\033]8;;\007' "$url" "$text"
    else
        # Fallback: just show text (plain)
        printf '%s' "$text"
    fi
}

# Not a git repo → show directory name
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    printf '%b' "${GRY}$(basename "${CWD:-$PWD}")${RST}"
    exit 0
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
[ -z "$BRANCH" ] && exit 0

# Green = clean, yellow = dirty
if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
    OUT="${GRN}${BRANCH}${RST}"
else
    OUT="${YEL}${BRANCH}${RST}"
fi

# GitLab CI/MR only for git.int.n7k.io repos
if git remote -v 2>/dev/null | grep -qi 'git\.int\.n7k\.io' && command -v glab &>/dev/null; then
    MR_TMP=$(mktemp)
    TOTAL_MR_TMP=$(mktemp)
    trap 'rm -f "$MR_TMP" "$TOTAL_MR_TMP"' EXIT

    # Get MR counts in parallel
    timeout 3 glab mr list --source-branch "$BRANCH" --state=opened --output=json >"$MR_TMP" 2>/dev/null &
    MR_PID=$!
    timeout 3 glab mr list --author=@me --state=opened --output=json >"$TOTAL_MR_TMP" 2>/dev/null &
    TOTAL_MR_PID=$!

    # Get pipeline info via API (more reliable than parsing ci status)
    PIPE_JSON=$(timeout 3 glab api "projects/:id/pipelines?ref=$BRANCH&per_page=1" 2>/dev/null)

    if [ -n "$PIPE_JSON" ]; then
        PIPE_ID=$(printf '%s' "$PIPE_JSON" | jq -r '.[0].id // empty' 2>/dev/null)
        PIPE_STATUS=$(printf '%s' "$PIPE_JSON" | jq -r '.[0].status // empty' 2>/dev/null)
        PIPE_URL=$(printf '%s' "$PIPE_JSON" | jq -r '.[0].web_url // empty' 2>/dev/null)

        if [ -n "$PIPE_ID" ] && [ -n "$PIPE_STATUS" ]; then
            # Map status to emoji
            case "$PIPE_STATUS" in
                success)          CI_ICON="${GRN}✅" ;;
                failed)           CI_ICON="${RED}❌" ;;
                running)          CI_ICON="${YEL}⏳" ;;
                pending|created)  CI_ICON="${ORN}⏳" ;;
                canceled|skipped) CI_ICON="${GRY}⚠️" ;;
                *)                CI_ICON="${GRY}⚪" ;;
            esac

            # Make pipeline ID clickable
            if [ -n "$PIPE_URL" ]; then
                CI="${CI_ICON}$(mk_link "$PIPE_URL" "$PIPE_ID")${RST}"
            else
                CI="${CI_ICON}${PIPE_ID}${RST}"
            fi

            # Check child pipelines for failures (only if parent failed or running)
            if [ "$PIPE_STATUS" = "failed" ] || [ "$PIPE_STATUS" = "running" ]; then
                BRIDGES=$(timeout 2 glab api "projects/:id/pipelines/$PIPE_ID/bridges?per_page=50" 2>/dev/null)
                if [ -n "$BRIDGES" ]; then
                    # Extract child pipeline IDs
                    CHILD_IDS=$(printf '%s' "$BRIDGES" | jq -r '.[] | select(.downstream_pipeline.id != null) | "\(.downstream_pipeline.id):\(.name)"' 2>/dev/null)

                    FAILED_CHILDREN=""
                    while IFS=: read -r child_id child_name; do
                        [ -z "$child_id" ] && continue
                        child_status=$(timeout 1 glab api "projects/:id/pipelines/$child_id" 2>/dev/null | jq -r '.status // empty' 2>/dev/null)
                        if [ "$child_status" = "failed" ]; then
                            child_url="https://git.int.n7k.io/neuralink/sw/-/pipelines/$child_id"
                            # Abbreviate child name (remove "-child" suffix)
                            child_short="${child_name%-child}"
                            FAILED_CHILDREN="${FAILED_CHILDREN} ${RED}$(mk_link "$child_url" "$child_short")${RST}"
                        fi
                    done <<< "$CHILD_IDS"

                    [ -n "$FAILED_CHILDREN" ] && CI="${CI} ${GRY}[${RST}${FAILED_CHILDREN}${GRY}]${RST}"
                fi
            fi
        else
            CI="${GRY}?${RST}"
        fi
    else
        CI="${GRY}?${RST}"
    fi

    # Wait for MR counts
    wait "$MR_PID" 2>/dev/null
    wait "$TOTAL_MR_PID" 2>/dev/null

    # Current branch MR count
    if [ -s "$MR_TMP" ]; then
        N=$(jq 'length' < "$MR_TMP" 2>/dev/null)
        [ -z "$N" ] || [ "$N" = "null" ] && N=0
    else
        N=0
    fi

    # Total MR count across all branches
    if [ -s "$TOTAL_MR_TMP" ]; then
        TOTAL=$(jq 'length' < "$TOTAL_MR_TMP" 2>/dev/null)
        [ -z "$TOTAL" ] || [ "$TOTAL" = "null" ] && TOTAL=0
    else
        TOTAL=0
    fi

    # Format: "N" or "N (T total)" if different
    if [ "$N" -gt 0 ] 2>/dev/null; then
        MR="${BLU}${N}${RST}"
    else
        MR="${GRY}0${RST}"
    fi

    # Add total count if different from branch count
    if [ "$TOTAL" -ne "$N" ] 2>/dev/null && [ "$TOTAL" -gt 0 ] 2>/dev/null; then
        MR="${MR}${GRY}(${TOTAL})${RST}"
    fi

    OUT="${OUT} ${GRY}|${RST} ${CI} ${GRY}|${RST} MR:${MR}"
fi

printf '%b\n' "$OUT"
