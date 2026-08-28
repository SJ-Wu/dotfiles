#!/bin/bash
# Claude Code statusLine script
# Reads a JSON payload from stdin (see Claude Code docs for schema) and
# prints a (optionally multi-line, ANSI-colored) status line to stdout.
#
# Line 1: folder name | git branch | model | effort level
# Line 2 (dim gray): context remaining % | 5h quota remaining % | session name

set -euo pipefail

input=$(cat)

# --- colors -----------------------------------------------------------
RESET=$'\033[0m'
CYAN=$'\033[36m'
GREEN=$'\033[32m'
MAGENTA=$'\033[35m'
YELLOW=$'\033[33m'
DIM=$'\033[2m'
SEP="${DIM} | ${RESET}"

# --- folder name --------------------------------------------------------
cwd=$(jq -r '.workspace.current_dir // .cwd // empty' <<<"$input")
folder=$(basename "${cwd:-.}")
[ -z "$folder" ] && folder="?"

# --- git branch ----------------------------------------------------------
branch=""
if [ -n "$cwd" ] && git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
  if [ -z "$branch" ]; then
    # detached HEAD fallback
    branch=$(git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
    [ -n "$branch" ] && branch="detached@${branch}"
  fi
fi
[ -z "$branch" ] && branch="no-git"

# --- model / effort --------------------------------------------------------
model=$(jq -r '.model.display_name // "unknown-model"' <<<"$input")

effort=$(jq -r '.effort.level // empty' <<<"$input")
[ -z "$effort" ] && effort="n/a"

# --- context window remaining % --------------------------------------------
ctx_display="n/a"
remaining_ctx=$(jq -r '.context_window.remaining_percentage // empty' <<<"$input")
if [ -n "$remaining_ctx" ] && [ "$remaining_ctx" != "null" ]; then
  ctx_display=$(printf "%.0f%%" "$remaining_ctx")
fi

# --- 5h rate-limit remaining % ----------------------------------------------
five_display="n/a"
five_used=$(jq -r '.rate_limits.five_hour.used_percentage // empty' <<<"$input")
if [ -n "$five_used" ] && [ "$five_used" != "null" ]; then
  five_display=$(awk -v u="$five_used" 'BEGIN{printf "%.0f%%", (100 - u)}')
fi

# --- session name ------------------------------------------------------
session_name=$(jq -r '.session_name // empty' <<<"$input")
if [ -z "$session_name" ] || [ "$session_name" = "null" ]; then
  # Fallback: no /rename set. Use the short session id instead.
  session_id=$(jq -r '.session_id // empty' <<<"$input")
  if [ -n "$session_id" ]; then
    session_name="session-${session_id:0:8}"
  else
    session_name="unnamed session"
  fi
fi

# --- render ------------------------------------------------------------
printf '%s%s%s%s%s%s%s%s%s%s%s%s%s\n' \
  "$CYAN" "$folder" "$RESET" \
  "$SEP" \
  "$GREEN" "$branch" "$RESET" \
  "$SEP" \
  "$MAGENTA" "$model" "$RESET" \
  "$SEP" \
  "${YELLOW}${effort}${RESET}"

printf '%sctx:%s left | 5h:%s left | %s%s\n' \
  "$DIM" "$ctx_display" "$five_display" "$session_name" "$RESET"
