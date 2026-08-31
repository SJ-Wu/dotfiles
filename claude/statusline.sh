#!/bin/bash
# Claude Code statusLine script
# Reads a JSON payload from stdin (see code.claude.com/docs/en/statusline for
# the schema) and prints a three-line ANSI-colored status line to stdout.
#
# Line 1: folder | git branch | model · effort | IDE
# Line 2: context remaining | 5h quota (reset time) | 7d quota (reset time)
# Line 3 (dim): session cost | lines +/- | cache hit | duration | session name
#
# Note on `set -e`: every command substitution below that can legitimately fail
# (git in an odd state, a malformed IDE lock, `date` on a bad epoch) is given an
# explicit `|| true`. Without it a single failure aborts the script and the
# status line silently renders blank, which is far worse than one missing field.

set -euo pipefail

input=$(cat)

# --- colors -----------------------------------------------------------
RESET=$'\033[0m'
CYAN=$'\033[36m'
GREEN=$'\033[32m'
MAGENTA=$'\033[35m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
BLUE=$'\033[34m'
DIM=$'\033[2m'
SEP="${DIM} | ${RESET}"

jqr() { jq -r "$1 // empty" <<<"$input" 2>/dev/null || true; }

# Color for a "remaining %" value: green >= 50, yellow >= 20, red below.
pct_color() {
  awk -v p="$1" 'BEGIN { if (p >= 50) printf "\033[32m"; else if (p >= 20) printf "\033[33m"; else printf "\033[31m" }'
}

# --- line 1: folder | branch | model · effort | IDE ----------------------
cwd=$(jqr '.workspace.current_dir // .cwd')
folder=$(basename "${cwd:-.}")
[ -z "$folder" ] && folder="?"

branch=""
if [ -n "$cwd" ] && git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null || true)
  if [ -z "$branch" ]; then
    # detached HEAD fallback
    branch=$(git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null || true)
    [ -n "$branch" ] && branch="detached@${branch}"
  fi
fi
[ -z "$branch" ] && branch="no-git"

model=$(jqr '.model.display_name')
[ -z "$model" ] && model="unknown-model"
model_part="${MAGENTA}${model}${RESET}"
effort=$(jqr '.effort.level')
[ -n "$effort" ] && model_part="${model_part}${DIM} · ${RESET}${YELLOW}${effort}${RESET}"

# --- IDE detection (same discovery as /ide: ~/.claude/ide/*.lock) --------
# Each lock holds {pid, ideName, workspaceFolders}. Show the IDE name only when
# the process is still alive *and* one of its workspace folders contains this
# project, so a stale lock or an unrelated window never shows up here.
ide_part=""
proj=$(jqr '.workspace.project_dir // .cwd')
if [ -n "$proj" ] && [ -d "$HOME/.claude/ide" ]; then
  for lock in "$HOME"/.claude/ide/*.lock; do
    [ -e "$lock" ] || continue
    pid=$(jq -r '.pid // empty' "$lock" 2>/dev/null || true)
    { [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; } || continue
    # Bind each folder to $f first: inside startswith(...) the argument is
    # evaluated against startswith's own input ($d), so a bare `. + "/"` there
    # would expand to $d + "/" and never match a parent folder.
    if jq -e --arg d "$proj" \
      '[.workspaceFolders[]? | . as $f | select($d == $f or ($d | startswith($f + "/")))] | length > 0' \
      "$lock" >/dev/null 2>&1; then
      ide_name=$(jq -r '.ideName // "IDE"' "$lock" 2>/dev/null || true)
      case "$ide_name" in
        "Visual Studio Code") ide_name="VS Code" ;;
        "IntelliJ IDEA") ide_name="IntelliJ" ;;
        "") ide_name="IDE" ;;
      esac
      ide_part="${BLUE}${ide_name}${RESET}"
      break
    fi
  done
fi

line1="${CYAN}${folder}${RESET}${SEP}${GREEN}${branch}${RESET}${SEP}${model_part}"
[ -n "$ide_part" ] && line1="${line1}${SEP}${ide_part}"

# --- line 2: ctx | 5h quota | 7d quota -----------------------------------
ctx_part="ctx n/a"
ctx=$(jqr '.context_window.remaining_percentage')
if [ -n "$ctx" ]; then
  ctx_part="ctx $(pct_color "$ctx")$(printf '%.0f%%' "$ctx")${RESET}"
fi

# quota_part <label> <used_pct> <resets_at_epoch> <date_fmt>
# The payload gives *used* percentage and an epoch reset time; we show what is
# left, since that is the number worth reacting to.
quota_part() {
  local label=$1 used=$2 resets=$3 fmt=$4 remain out when
  if [ -z "$used" ]; then
    printf '%s n/a' "$label"
    return 0
  fi
  remain=$(awk -v u="$used" 'BEGIN{printf "%.0f", 100 - u}')
  out="${label} $(pct_color "$remain")${remain}%${RESET}"
  if [ -n "$resets" ]; then
    when=$(date -r "$resets" "+$fmt" 2>/dev/null || true)
    [ -n "$when" ] && out="${out}${DIM}→${when}${RESET}"
  fi
  printf '%s' "$out"
}

five_part=$(quota_part "5h" "$(jqr '.rate_limits.five_hour.used_percentage')" \
  "$(jqr '.rate_limits.five_hour.resets_at')" "%H:%M")
seven_part=$(quota_part "7d" "$(jqr '.rate_limits.seven_day.used_percentage')" \
  "$(jqr '.rate_limits.seven_day.resets_at')" "%m/%d")

line2="${ctx_part}${SEP}${five_part}${SEP}${seven_part}"

# --- line 3 (dim): cost | lines +/- | cache | duration | session name ----
parts=()

cost=$(jqr '.cost.total_cost_usd')
[ -n "$cost" ] && parts+=("$(awk -v c="$cost" 'BEGIN{printf "$%.2f", c}')")

added=$(jqr '.cost.total_lines_added')
removed=$(jqr '.cost.total_lines_removed')
if [ -n "$added" ] || [ -n "$removed" ]; then
  parts+=("${GREEN}+${added:-0}${RESET}${DIM}/${RED}-${removed:-0}${RESET}${DIM}")
fi

# hit_ratio is a 0..1 fraction, not a percentage.
cache_ratio=$(jqr '.prompt_cache.hit_ratio')
if [ -n "$cache_ratio" ]; then
  parts+=("cache $(awk -v r="$cache_ratio" 'BEGIN{printf "%.0f%%", r * 100}')")
fi

dur_ms=$(jqr '.cost.total_duration_ms')
if [ -n "$dur_ms" ]; then
  parts+=("$(awk -v ms="$dur_ms" 'BEGIN{
    s = int(ms / 1000)
    if (s < 60) printf "%ds", s
    else if (s < 3600) printf "%dm", s / 60
    else printf "%dh%02dm", s / 3600, (s % 3600) / 60
  }')")
fi

session_name=$(jqr '.session_name')
if [ -z "$session_name" ]; then
  # Fallback: no /rename set. Use the short session id instead.
  session_id=$(jqr '.session_id')
  if [ -n "$session_id" ]; then
    session_name="session-${session_id:0:8}"
  else
    session_name="unnamed session"
  fi
fi
parts+=("$session_name")

line3="${DIM}"
first=1
for p in "${parts[@]}"; do
  if [ "$first" = 1 ]; then first=0; else line3="${line3} | "; fi
  line3="${line3}${p}"
done
line3="${line3}${RESET}"

# --- render ------------------------------------------------------------
printf '%s\n%s\n%s\n' "$line1" "$line2" "$line3"
