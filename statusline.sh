#!/bin/bash
# Claude Code Statusline Script
# Configurable via environment variables

# Read JSON input from stdin and close stdin to prevent consumption by subprocesses
input=$(cat)
exec 0</dev/null

# =============================================================================
# Configuration (via environment variables with defaults)
# =============================================================================
# CLAUDE_STATUSLINE_DEBUG: 1=show debug info, 0=hide (default: 0)
# CLAUDE_STATUSLINE_COLORS: 1=enabled, 0=disabled (default: 1)
# CLAUDE_STATUSLINE_ICONS: 1=enabled, 0=disabled (default: 1)
# CLAUDE_STATUSLINE_GIT: comma-separated list or 0 to disable
#   Options: branch,ahead_behind,staged,modified,untracked,stash,dirty,hash,add_remove
#   Default: "branch,ahead_behind,staged,modified,add_remove,stash"
# CLAUDE_STATUSLINE_CONTEXT_USAGE: comma-separated list or 0 to disable
#   Options: pct_remaining,pct_used,tokens_fraction,tokens_remaining,tokens_until_autocompact,tokens_used,battery_icon,context_size
#   Default: "battery_icon,pct_remaining"
# CLAUDE_STATUSLINE_COST: comma-separated list or 0 to disable
#   Options: total_usd,duration,lines_added,lines_removed,lines_changed
#   Default: 0 (disabled)
# CLAUDE_STATUSLINE_DAILY: comma-separated list or 0 to disable
#   Options: messages,sessions,tokens,tools
#   Default: 0 (disabled)
# CLAUDE_STATUSLINE_CONTEXT_REMAINING: comma-separated list or 0 to disable
#   Options: battery_icon,pct_remaining,tokens_remaining,tokens_fraction
#   Default: 0 (disabled)
# CLAUDE_STATUSLINE_CONTEXT_REMAINING_USE_AUTOCOMPACT: 1=subtract autocompact buffer, 0=raw values
#   Default: 1 (enabled)
# CLAUDE_STATUSLINE_SESSION: 1 to enable session reset timer, 0 to disable
#   Default: 1 (enabled)
# CLAUDE_STATUSLINE_GIT_CACHE_TTL: cache TTL in seconds (default: 5)
# CLAUDE_STATUSLINE_DAILY_CACHE_TTL: daily stats cache TTL in seconds (default: 60)
# CLAUDE_STATUSLINE_SESSION_CACHE_TTL: session stats cache TTL in seconds (default: 30)
# CLAUDE_STATUSLINE_VERBOSE: 1=show label text (e.g. "left", "until compact", "until reset"), 0=hide
#   Default: 1 (enabled)
# CLAUDE_STATUSLINE_AUTOCOMPACT_BUFFER: tokens reserved for autocompact (default: 45000)
#   Set to 0 to disable buffer adjustment in context calculations
# CLAUDE_STATUSLINE_DEBUG_TIME: override current time (unix timestamp) for testing

SHOW_DEBUG_INFO=${CLAUDE_STATUSLINE_DEBUG:-0}
DEBUG_TIME=${CLAUDE_STATUSLINE_DEBUG_TIME:-}
COLORS_ENABLED=${CLAUDE_STATUSLINE_COLORS:-1}
ICONS_ENABLED=${CLAUDE_STATUSLINE_ICONS:-1}
GIT_OPTIONS=${CLAUDE_STATUSLINE_GIT:-"branch,ahead_behind,staged,modified,add_remove,stash"}
CONTEXT_OPTIONS=${CLAUDE_STATUSLINE_CONTEXT_USAGE:-"tokens_fraction"}
COST_OPTIONS=${CLAUDE_STATUSLINE_COST:-1}
DAILY_OPTIONS=${CLAUDE_STATUSLINE_DAILY:-0}
CONTEXT_REMAINING_OPTIONS=${CLAUDE_STATUSLINE_CONTEXT_REMAINING:-"battery_icon,pct_remaining"}
CONTEXT_REMAINING_USE_AUTOCOMPACT=${CLAUDE_STATUSLINE_CONTEXT_REMAINING_USE_AUTOCOMPACT:-1}
VERBOSE=${CLAUDE_STATUSLINE_VERBOSE:-1}
SESSION_OPTIONS=${CLAUDE_STATUSLINE_SESSION:-1}
GIT_CACHE_TTL=${CLAUDE_STATUSLINE_GIT_CACHE_TTL:-5}
DAILY_CACHE_TTL=${CLAUDE_STATUSLINE_DAILY_CACHE_TTL:-60}
SESSION_CACHE_TTL=${CLAUDE_STATUSLINE_SESSION_CACHE_TTL:-30}
STATS_CACHE_FILE="${HOME}/.claude/stats-cache.json"
PROJECTS_DIR="${HOME}/.claude/projects"
AUTOCOMPACT_BUFFER=${CLAUDE_STATUSLINE_AUTOCOMPACT_BUFFER:-45000}

# Session duration in seconds (5 hours, matching Ruby script)
SESSION_DURATION_SECS=$((5 * 3600))

# =============================================================================
# Color Definitions (Terminal-themed ANSI codes that respect your color scheme)
# =============================================================================
if [[ "$COLORS_ENABLED" == "1" ]]; then
  # Formatting
  reset=$'\e[0m'
  bold=$'\e[1m'
  dim=$'\e[2m'

  # Basic colors (use terminal's configured colors)
  black=$'\e[30m'
  red=$'\e[31m'
  green=$'\e[32m'
  yellow=$'\e[33m'
  blue=$'\e[34m'
  magenta=$'\e[35m'
  cyan=$'\e[36m'
  white=$'\e[37m'

  # Bright colors (use terminal's bright/bold color variants)
  black_bright=$'\e[90m'
  red_bright=$'\e[91m'
  green_bright=$'\e[92m'
  yellow_bright=$'\e[93m'
  blue_bright=$'\e[94m'
  magenta_bright=$'\e[95m'
  cyan_bright=$'\e[96m'
  white_bright=$'\e[97m'

  # Semantic aliases (map to appropriate colors)
  orange=$'\e[33m'        # yellow (no orange in basic ANSI)
  violet=$'\e[35m'        # magenta
  gray=$'\e[39m'          # bright black (usually gray)
else
  reset=""
  bold=""
  dim=""
  black=""
  red=""
  green=""
  yellow=""
  blue=""
  magenta=""
  cyan=""
  white=""
  black_bright=""
  red_bright=""
  green_bright=""
  yellow_bright=""
  blue_bright=""
  magenta_bright=""
  cyan_bright=""
  white_bright=""
  orange=""
  violet=""
  gray=""
fi

# =============================================================================
# Icon Definitions
# =============================================================================
if [[ "$ICONS_ENABLED" == "1" ]]; then
  ICON_ROBOT="  "
  ICON_FOLDER="  "
  ICON_CLOCK=" "
  ICON_TIMER="󰔟 "
  ICON_BRANCH=" "
  ICON_AHEAD="↑"
  ICON_BEHIND="↓"
  ICON_STAGED=" "
  ICON_MODIFIED=" "
  ICON_UNTRACKED="…"
  ICON_STASH=" "
  ICON_DIRTY="●"
  ICON_CLEAN="✔"
  windows="󱇜 󱇛  󰖳 󰨡 "
  ICON_WINDOW="󱇛 "
  # Battery icons (Nerd Font)
  ICON_BATTERY_EMPTY="󱃍"
  ICON_BATTERY_10="󰁺"
  ICON_BATTERY_20="󰁻"
  ICON_BATTERY_30="󰁼"
  ICON_BATTERY_40="󰁽"
  ICON_BATTERY_50="󰁾"
  ICON_BATTERY_60="󰁿"
  ICON_BATTERY_70="󰂀"
  ICON_BATTERY_80="󰂁"
  ICON_BATTERY_90="󰂂"
  ICON_BATTERY_FULL="󰁹"
  ICON_BATTERY_CRITICAL="󱟩"
else
  ICON_ROBOT=""
  ICON_FOLDER=""
  ICON_CLOCK=""
  ICON_BRANCH=""
  ICON_AHEAD="^"
  ICON_BEHIND="v"
  ICON_STAGED="S"
  ICON_MODIFIED="M"
  ICON_UNTRACKED="?"
  ICON_STASH="$"
  ICON_DIRTY="*"
  ICON_CLEAN=""
  ICON_WINDOW=""
  ICON_BATTERY_EMPTY="[    ]"
  ICON_BATTERY_10="[=   ]"
  ICON_BATTERY_20="[==  ]"
  ICON_BATTERY_30="[==  ]"
  ICON_BATTERY_40="[=== ]"
  ICON_BATTERY_50="[=== ]"
  ICON_BATTERY_60="[====]"
  ICON_BATTERY_70="[====]"
  ICON_BATTERY_80="[====]"
  ICON_BATTERY_90="[====]"
  ICON_BATTERY_FULL="[====]"
  ICON_BATTERY_CRITICAL="[!!!!]"
fi

# =============================================================================
# Helper Functions - Time, JSON Extraction, Verbose Labels
# =============================================================================
# Returns label text if VERBOSE=1, empty string otherwise
verbose_label() { if [[ "$VERBOSE" == "1" ]]; then echo " $1"; fi; }
# Returns current time (or DEBUG_TIME if set for testing)
get_current_time() {
  if [[ -n "$DEBUG_TIME" ]]; then
    echo "$DEBUG_TIME"
  else
    date +%s
  fi
}

get_debug_info() { if [[ "$SHOW_DEBUG_INFO" == "1" ]]; then echo "$input"; fi; }
get_model_name() { echo "$input" | jq -r '.model.display_name // "Unknown"'; }
get_current_dir() { echo "$input" | jq -r '.workspace.current_dir // empty'; }
get_project_dir() { echo "$input" | jq -r '.workspace.project_dir // empty'; }
get_cwd() { echo "$input" | jq -r '.cwd // empty'; }
get_version() { echo "$input" | jq -r '.version // empty'; }
get_cost() { echo "$input" | jq -r '.cost.total_cost_usd // 0'; }
get_duration() { echo "$input" | jq -r '.cost.total_duration_ms // 0'; }
get_lines_added() { echo "$input" | jq -r '.cost.total_lines_added // 0'; }
get_lines_removed() { echo "$input" | jq -r '.cost.total_lines_removed // 0'; }
get_input_tokens() { echo "$input" | jq -r '.context_window.total_input_tokens // 0'; }
get_output_tokens() { echo "$input" | jq -r '.context_window.total_output_tokens // 0'; }
get_context_window_size() { echo "$input" | jq -r '.context_window.context_window_size // 200000'; }
get_context_window_pct_used() { echo "$input" | jq -r '.context_window.used_percentage // 0' | awk '{printf "%d", $1}'; }
get_context_window_pct_remaining() { echo "$input" | jq -r '.context_window.remaining_percentage // 100' | awk '{printf "%d", $1}'; }

# Get current context usage using official formula from docs:
# input_tokens + cache_creation_input_tokens + cache_read_input_tokens
get_current_usage_tokens() {
  local usage
  usage=$(echo "$input" | jq -r '.context_window.current_usage // null')
  if [[ "$usage" != "null" ]]; then
    echo "$usage" | jq -r '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens'
  else
    # Fallback to total_input_tokens if current_usage not available
    echo "$input" | jq -r '.context_window.total_input_tokens // 0'
  fi
}

get_curr_dir() {
  local dir
  dir=$(get_current_dir)
  # Abbreviate home directory to ~
  if [[ "$dir" == "${HOME}"* ]]; then
    echo "~${dir#"${HOME}"}"
  else
    echo "$dir"
  fi
}

# =============================================================================
# Git Caching
# =============================================================================
CACHE_DIR="${TMPDIR:-/tmp}/claude-statusline-cache"
mkdir -p "$CACHE_DIR" 2>/dev/null

get_cache_file() {
  local repo_path="$1"
  local hash
  hash=$(echo "$repo_path" | md5 2>/dev/null || echo "$repo_path" | md5sum 2>/dev/null | cut -d' ' -f1)
  echo "$CACHE_DIR/git-$hash"
}

is_cache_valid() {
  local cache_file="$1"
  if [[ ! -f "$cache_file" ]]; then
    return 1
  fi
  local cache_time file_age
  cache_time=$(stat -f %m "$cache_file" 2>/dev/null || stat -c %Y "$cache_file" 2>/dev/null)
  local now
  now=$(get_current_time)
  file_age=$((now - cache_time))
  [[ $file_age -lt $GIT_CACHE_TTL ]]
}

# =============================================================================
# Git Information Functions
# =============================================================================
is_git_repo() {
  git rev-parse --git-dir > /dev/null 2>&1
}

get_git_root() {
  git rev-parse --show-toplevel 2>/dev/null
}

get_git_branch() {
  git branch --show-current 2>/dev/null || git rev-parse --short HEAD 2>/dev/null
}

get_git_ahead_behind() {
  local upstream
  upstream=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)
  if [[ -z "$upstream" ]]; then
    echo ""
    return
  fi
  local ahead behind
  ahead=$(git rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo 0)
  behind=$(git rev-list --count 'HEAD..@{upstream}' 2>/dev/null || echo 0)
  local result=""
  [[ $ahead -gt 0 ]] && result+="${ICON_AHEAD}${ahead}"
  [[ $behind -gt 0 ]] && result+="${ICON_BEHIND}${behind}"
  echo "$result"
}

get_git_staged_count() {
  git diff --cached --numstat 2>/dev/null | wc -l | tr -d ' '
}

get_git_modified_count() {
  git diff --numstat 2>/dev/null | wc -l | tr -d ' '
}

get_git_untracked_count() {
  git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' '
}

get_git_stash_count() {
  git stash list 2>/dev/null | wc -l | tr -d ' '
}

get_git_short_hash() {
  git rev-parse --short HEAD 2>/dev/null
}

get_git_is_dirty() {
  [[ -n $(git status --porcelain 2>/dev/null) ]]
}

get_git_add_remove() {
  local stats
  stats=$(git diff --numstat 2>/dev/null; git diff --cached --numstat 2>/dev/null)
  if [[ -z "$stats" ]]; then
    echo ""
    return
  fi
  local added=0 removed=0
  while IFS=$'\t' read -r add rem _; do
    [[ "$add" =~ ^[0-9]+$ ]] && added=$((added + add))
    [[ "$rem" =~ ^[0-9]+$ ]] && removed=$((removed + rem))
  done <<< "$stats"
  local result=""
  [[ $added -gt 0 ]] && result+="${green}+${added}"
  [[ $removed -gt 0 ]] && result+=" ${red}-${removed}"
  echo "$result"
}

# Collect all git info with caching
collect_git_info() {
  if ! is_git_repo; then
    echo ""
    return
  fi

  local repo_root cache_file
  repo_root=$(get_git_root)
  cache_file=$(get_cache_file "$repo_root")

  # Check cache
  if is_cache_valid "$cache_file"; then
    cat "$cache_file"
    return
  fi

  # Collect fresh data
  local git_data=""
  git_data+="branch:$(get_git_branch)"$'\n'
  git_data+="ahead_behind:$(get_git_ahead_behind)"$'\n'
  git_data+="staged:$(get_git_staged_count)"$'\n'
  git_data+="modified:$(get_git_modified_count)"$'\n'
  git_data+="untracked:$(get_git_untracked_count)"$'\n'
  git_data+="stash:$(get_git_stash_count)"$'\n'
  git_data+="hash:$(get_git_short_hash)"$'\n'
  git_data+="add_remove:$(get_git_add_remove)"$'\n'
  if get_git_is_dirty; then
    git_data+="dirty:1"$'\n'
  else
    git_data+="dirty:0"$'\n'
  fi

  # Write cache
  echo "$git_data" > "$cache_file"
  echo "$git_data"
}

get_cached_git_value() {
  local key="$1"
  local git_data="$2"
  echo "$git_data" | grep "^${key}:" | cut -d: -f2-
}

format_git_info() {
  if [[ "$GIT_OPTIONS" == "0" ]]; then
    echo ""
    return
  fi

  if ! is_git_repo; then
    echo ""
    return
  fi

  local git_data
  git_data=$(collect_git_info)

  local result=""
  local sep=" "

  IFS=',' read -ra options <<< "$GIT_OPTIONS"
  for opt in "${options[@]}"; do
    local value
    value=$(get_cached_git_value "$opt" "$git_data")

    case "$opt" in
      branch)
        if [[ -n "$value" ]]; then
          result+="${bold}${ICON_BRANCH}${value}${reset}"
        fi
        ;;
      ahead_behind)
        if [[ -n "$value" ]]; then
          result+="${sep}${yellow}${value}${reset}"
        fi
        ;;
      staged)
        if [[ "$value" -gt 0 ]]; then
          result+="${sep}${bold}${cyan}${ICON_STAGED}${value}${reset}"
        fi
        ;;
      modified)
        if [[ "$value" -gt 0 ]]; then
          result+="${sep}${bold}${white}${ICON_MODIFIED}${value}${reset}"
        fi
        ;;
      untracked)
        if [[ "$value" -gt 0 ]]; then
          result+="${sep}${gray}${ICON_UNTRACKED}${value}${reset}"
        fi
        ;;
      stash)
        if [[ "$value" -gt 0 ]]; then
          result+="${sep}${magenta}${ICON_STASH}${value}${reset}"
        fi
        ;;
      dirty)
        if [[ "$value" == "1" ]]; then
          result+="${sep}${red}${ICON_DIRTY}${reset}"
        fi
        ;;
      hash)
        if [[ -n "$value" ]]; then
          result+="${sep}${gray}#${value}${reset}"
        fi
        ;;
      add_remove)
        if [[ -n "$value" ]]; then
          result+="${bold}${white}(${value}${bold}${white})${reset}"
        fi
        ;;
    esac
  done

  echo "$result"
}

# =============================================================================
# Context Window Functions
# =============================================================================
get_battery_icon() {
  local pct_remaining="$1"

  if [[ $pct_remaining -lt 10 ]]; then
    echo "${bold}${red_bright}${ICON_BATTERY_CRITICAL}${reset}"
  elif [[ $pct_remaining -lt 20 ]]; then
    echo "${red}${ICON_BATTERY_10}${reset}"
  elif [[ $pct_remaining -lt 30 ]]; then
    echo "${orange}${ICON_BATTERY_20}${reset}"
  elif [[ $pct_remaining -lt 40 ]]; then
    echo "${orange}${ICON_BATTERY_30}${reset}"
  elif [[ $pct_remaining -lt 50 ]]; then
    echo "${yellow}${ICON_BATTERY_40}${reset}"
  elif [[ $pct_remaining -lt 60 ]]; then
    echo "${yellow}${ICON_BATTERY_50}${reset}"
  elif [[ $pct_remaining -lt 70 ]]; then
    echo "${green}${ICON_BATTERY_60}${reset}"
  elif [[ $pct_remaining -lt 80 ]]; then
    echo "${green}${ICON_BATTERY_70}${reset}"
  elif [[ $pct_remaining -lt 90 ]]; then
    echo "${green}${ICON_BATTERY_80}${reset}"
  elif [[ $pct_remaining -lt 100 ]]; then
    echo "${green}${ICON_BATTERY_90}${reset}"
  else
    echo "${green}${ICON_BATTERY_FULL}${reset}"
  fi
}

format_tokens() {
  local tokens="$1"
  if [[ $tokens -ge 1000000 ]]; then
    printf "%.1fM" "$(echo "scale=1; $tokens/1000000" | bc)"
  elif [[ $tokens -ge 1000 ]]; then
    printf "%.1fk" "$(echo "scale=1; $tokens/1000" | bc)"
  else
    echo "$tokens"
  fi
}

format_context_usage() {
  if [[ "$CONTEXT_OPTIONS" == "0" ]]; then
    echo ""
    return
  fi

  local pct_remaining pct_used context_size current_tokens tokens_until_autocompact
  pct_remaining=$(get_context_window_pct_remaining)
  pct_used=$(get_context_window_pct_used)
  context_size=$(get_context_window_size)

  # Use official formula: input_tokens + cache_creation_input_tokens + cache_read_input_tokens
  current_tokens=$(get_current_usage_tokens)
  local tokens_remaining=$((context_size - current_tokens))

  # Adjust for autocompact buffer if enabled
  # Calculate "context left until auto-compact" = remaining - buffer
  if [[ $AUTOCOMPACT_BUFFER -gt 0 && $context_size -gt 0 ]]; then
    tokens_until_autocompact=$((tokens_remaining - AUTOCOMPACT_BUFFER))
  #   [[ $tokens_until_autocompact -lt 0 ]] && tokens_until_autocompact=0
  #   # Percentage of total context with rounding (add half divisor before dividing)
  #   # This ensures 0.5% rounds to 1% instead of truncating to 0%
  #   pct_remaining=$(( (tokens_until_autocompact * 100 + context_size / 2) / context_size ))
  #   pct_used=$((100 - pct_remaining))
  fi

  local result=""
  local sep=" "

  IFS=',' read -ra options <<< "$CONTEXT_OPTIONS"
  for opt in "${options[@]}"; do
    case "$opt" in
      battery_icon)
        result+=$(get_battery_icon "$pct_remaining")
        ;;
      pct_remaining)
        local color="$green"
        if [[ $pct_remaining -lt 20 ]]; then
          color="$red_bright"
        elif [[ $pct_remaining -lt 40 ]]; then
          color="$orange"
        elif [[ $pct_remaining -lt 60 ]]; then
          color="$yellow"
        fi
        result+="${sep}${color}${pct_remaining}%${reset}"
        ;;
      pct_used)
        local color="$green"
        if [[ $pct_used -gt 80 ]]; then
          color="$red_bright"
        elif [[ $pct_used -gt 60 ]]; then
          color="$orange"
        elif [[ $pct_used -gt 40 ]]; then
          color="$yellow"
        fi
        result+="${sep}${color}used:${pct_used}%${reset}"
        ;;
      tokens_fraction)
        local used_fmt total_fmt
        used_fmt=$(format_tokens "$current_tokens")
        total_fmt=$(format_tokens "$context_size")
        result+="${sep}${reset}${blue}${ICON_WINDOW}${used_fmt}/${total_fmt}${reset}"
        ;;
      tokens_remaining)
        local remaining_fmt
        remaining_fmt=$(format_tokens "$tokens_remaining")
        result+="${sep}${reset}${blue}${remaining_fmt}${reset}$(verbose_label "left")"
        ;;
      tokens_used)
        local used_fmt
        used_fmt=$(format_tokens "$current_tokens")
        result+="${sep}${reset}${blue}${used_fmt}${reset}$(verbose_label "used")"
        ;;
      context_size)
        local size_fmt
        size_fmt=$(format_tokens "$context_size")
        result+="${sep}${reset}(${blue}${size_fmt}${reset})"
        ;;
      tokens_until_autocompact)
        local autocompact_fmt
        autocompact_fmt=$(format_tokens "$tokens_until_autocompact")
        result+="${sep}${reset}${blue}${autocompact_fmt}${reset}$(verbose_label "until compact")"
        ;;
    esac
  done

  echo "$result"
}

# =============================================================================
# Context Remaining Functions (subset with own autocompact toggle)
# =============================================================================
format_context_remaining() {
  if [[ "$CONTEXT_REMAINING_OPTIONS" == "0" ]]; then
    echo ""
    return
  fi

  local context_size current_tokens tokens_remaining pct_remaining effective_size tokens_remaining_label
  context_size=$(get_context_window_size)
  current_tokens=$(get_current_usage_tokens)
  tokens_remaining=$((context_size - current_tokens))
  pct_remaining=$(get_context_window_pct_remaining)
  effective_size=$context_size
  tokens_remaining_label="left"

  # Adjust for autocompact buffer if enabled
  # Shrinks the effective window so values reflect "until autocompact" rather than raw remaining
  if [[ "$CONTEXT_REMAINING_USE_AUTOCOMPACT" == "1" && $AUTOCOMPACT_BUFFER -gt 0 && $context_size -gt 0 ]]; then
    effective_size=$((context_size - AUTOCOMPACT_BUFFER))
    tokens_remaining=$((effective_size - current_tokens))
    [[ $tokens_remaining -lt 0 ]] && tokens_remaining=0
    pct_remaining=$(( (tokens_remaining * 100 + effective_size / 2) / effective_size ))
    tokens_remaining_label="until compact"
  fi

  local result=""
  local sep=" "

  IFS=',' read -ra options <<< "$CONTEXT_REMAINING_OPTIONS"
  for opt in "${options[@]}"; do
    case "$opt" in
      battery_icon)
        result+=$(get_battery_icon "$pct_remaining")
        ;;
      pct_remaining)
        local color="$green"
        if [[ $pct_remaining -lt 20 ]]; then
          color="$red_bright"
        elif [[ $pct_remaining -lt 40 ]]; then
          color="$orange"
        elif [[ $pct_remaining -lt 60 ]]; then
          color="$yellow"
        fi
        result+="${sep}${color}${pct_remaining}%${reset}"
        ;;
      tokens_remaining)
        local remaining_fmt
        remaining_fmt=$(format_tokens "$tokens_remaining")
        result+="${sep}${reset}${blue}${remaining_fmt}${reset}$(verbose_label "$tokens_remaining_label")"
        ;;
      tokens_fraction)
        local used_fmt total_fmt
        used_fmt=$(format_tokens "$current_tokens")
        total_fmt=$(format_tokens "$effective_size")
        result+="${sep}${reset}${blue}${used_fmt}/${total_fmt}${reset}"
        ;;
    esac
  done

  echo "$result"
}

# =============================================================================
# Session Cost Functions
# =============================================================================
format_duration() {
  local ms="$1"
  local seconds=$((ms / 1000))
  local minutes=$((seconds / 60))
  local hours=$((minutes / 60))

  if [[ $hours -gt 0 ]]; then
    printf "%dh%dm" "$hours" "$((minutes % 60))"
  elif [[ $minutes -gt 0 ]]; then
    printf "%dm%ds" "$minutes" "$((seconds % 60))"
  else
    printf "%ds" "$seconds"
  fi
}

format_cost() {
  if [[ "$COST_OPTIONS" == "0" ]]; then
    echo ""
    return
  fi

  local total_usd duration lines_added lines_removed
  total_usd=$(get_cost)
  duration=$(get_duration)
  lines_added=$(get_lines_added)
  lines_removed=$(get_lines_removed)

  local result=""
  local sep=" "

  IFS=',' read -ra options <<< "$COST_OPTIONS"
  for opt in "${options[@]}"; do
    case "$opt" in
      total_usd)
        if [[ "$total_usd" != "0" && "$total_usd" != "null" ]]; then
          result+="${sep}${green}\$${total_usd}${reset}"
        fi
        ;;
      duration)
        if [[ "$duration" != "0" && "$duration" != "null" ]]; then
          local dur_fmt
          dur_fmt=$(format_duration "$duration")
          result+="${sep}${reset}${dur_fmt}${reset}"
        fi
        ;;
      lines_added)
        if [[ "$lines_added" != "0" && "$lines_added" != "null" ]]; then
          result+="${sep}${green}+${lines_added}${reset}"
        fi
        ;;
      lines_removed)
        if [[ "$lines_removed" != "0" && "$lines_removed" != "null" ]]; then
          result+="${sep}${red}-${lines_removed}${reset}"
        fi
        ;;
      lines_changed)
        local changed=""
        if [[ "$lines_added" != "0" && "$lines_added" != "null" ]]; then
          changed+="${green}+${lines_added}${reset}"
        fi
        if [[ "$lines_removed" != "0" && "$lines_removed" != "null" ]]; then
          changed+="${red}/-${lines_removed}${reset}"
        fi
        if [[ -n "$changed" ]]; then
          result+="${sep}${changed}"
        fi
        ;;
    esac
  done

  echo "$result"
}

# =============================================================================
# Daily Stats Functions (from ~/.claude/stats-cache.json)
# =============================================================================
DAILY_STATS_CACHE_FILE="$CACHE_DIR/daily-stats"

get_daily_stats() {
  # Check if stats file exists
  if [[ ! -f "$STATS_CACHE_FILE" ]]; then
    echo ""
    return
  fi

  # Check cache
  if is_cache_valid "$DAILY_STATS_CACHE_FILE"; then
    cat "$DAILY_STATS_CACHE_FILE"
    return
  fi

  # Get today's date
  local today
  today=$(date +%Y-%m-%d)

  # Extract today's stats
  local daily_data
  daily_data=$(jq -r --arg date "$today" '
    (.dailyActivity[] | select(.date == $date) | "messages:\(.messageCount)\nsessions:\(.sessionCount)\ntools:\(.toolCallCount)") // "",
    (.dailyModelTokens[] | select(.date == $date) | .tokensByModel | to_entries | map("tokens_\(.key):\(.value)") | .[]) // ""
  ' "$STATS_CACHE_FILE" 2>/dev/null)

  # Add total tokens calculation
  local total_tokens
  total_tokens=$(jq -r --arg date "$today" '
    (.dailyModelTokens[] | select(.date == $date) | .tokensByModel | to_entries | map(.value) | add) // 0
  ' "$STATS_CACHE_FILE" 2>/dev/null)
  daily_data+=$'\n'"tokens_total:${total_tokens}"

  # Write cache
  echo "$daily_data" > "$DAILY_STATS_CACHE_FILE"
  echo "$daily_data"
}

get_cached_daily_value() {
  local key="$1"
  local data="$2"
  echo "$data" | grep "^${key}:" | cut -d: -f2- | head -1
}

format_daily_stats() {
  if [[ "$DAILY_OPTIONS" == "0" ]]; then
    echo ""
    return
  fi

  local daily_data
  daily_data=$(get_daily_stats)

  if [[ -z "$daily_data" ]]; then
    echo ""
    return
  fi

  local result=""
  local sep=" "

  IFS=',' read -ra options <<< "$DAILY_OPTIONS"
  for opt in "${options[@]}"; do
    local value
    case "$opt" in
      messages)
        value=$(get_cached_daily_value "messages" "$daily_data")
        if [[ -n "$value" && "$value" != "0" ]]; then
          result+="${sep}${cyan}${value}msg${reset}"
        fi
        ;;
      sessions)
        value=$(get_cached_daily_value "sessions" "$daily_data")
        if [[ -n "$value" && "$value" != "0" ]]; then
          result+="${sep}${blue}${value}sess${reset}"
        fi
        ;;
      tokens)
        value=$(get_cached_daily_value "tokens_total" "$daily_data")
        if [[ -n "$value" && "$value" != "0" ]]; then
          local tokens_fmt
          tokens_fmt=$(format_tokens "$value")
          result+="${sep}${magenta}${tokens_fmt}tok${reset}"
        fi
        ;;
      tools)
        value=$(get_cached_daily_value "tools" "$daily_data")
        if [[ -n "$value" && "$value" != "0" ]]; then
          result+="${sep}${reset}${value}tools${reset}"
        fi
        ;;
    esac
  done

  echo "$result"
}

# =============================================================================
# Session Usage Functions (from ~/.claude/projects/*.jsonl)
# Matches Ruby statusline.rb logic for 5-hour session blocks
# =============================================================================
SESSION_STATS_CACHE_FILE="$CACHE_DIR/session-stats"

# Parse ISO timestamp (UTC) to epoch seconds
parse_timestamp() {
  local ts="$1"
  # Handle ISO 8601 format: 2026-01-27T20:48:00.000Z
  # Timestamps are UTC so we need TZ=UTC for correct parsing
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS date command - parse as UTC
    TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "${ts%%.*}" "+%s" 2>/dev/null
  else
    # GNU date handles Z suffix correctly
    date -d "$ts" "+%s" 2>/dev/null
  fi
}

# Round timestamp to start of hour
round_to_hour() {
  local ts="$1"
  echo $(( (ts / 3600) * 3600 ))
}

# Calculate session reset time from most recent activity
# Optimized: only parses the most recent timestamp (not all timestamps)
calculate_session_usage() {
  # Debug output helper
  local session_debug=""
  debug_session() {
    if [[ "$SHOW_DEBUG_INFO" == "1" ]]; then
      session_debug+="$1"$'\n'
    fi
  }

  if [[ ! -d "$PROJECTS_DIR" ]]; then
    echo "reset_secs:$SESSION_DURATION_SECS"$'\n'"debug:"
    return
  fi

  # Skip cache when debugging
  if [[ "$SHOW_DEBUG_INFO" != "1" && -f "$SESSION_STATS_CACHE_FILE" ]]; then
    local cache_time now file_age
    cache_time=$(stat -f %m "$SESSION_STATS_CACHE_FILE" 2>/dev/null || stat -c %Y "$SESSION_STATS_CACHE_FILE" 2>/dev/null)
    now=$(get_current_time)
    file_age=$((now - cache_time))
    if [[ $file_age -lt $SESSION_CACHE_TTL ]]; then
      cat "$SESSION_STATS_CACHE_FILE"
      return
    fi
  fi

  local now
  now=$(get_current_time)
  debug_session "now_utc: $(date -u -r "$now" "+%Y-%m-%dT%H:%M:%S" 2>/dev/null || date -u -d "@$now" "+%Y-%m-%dT%H:%M:%S" 2>/dev/null)"

  # Find the most recently modified .jsonl file
  local recent_file
  recent_file=$(find "$PROJECTS_DIR" -name "*.jsonl" -type f -print0 2>/dev/null | \
    xargs -0 stat -f '%m %N' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
  # Fallback for GNU stat
  if [[ -z "$recent_file" ]]; then
    recent_file=$(find "$PROJECTS_DIR" -name "*.jsonl" -type f -printf '%T@ %p\n' 2>/dev/null | \
      sort -rn | head -1 | cut -d' ' -f2-)
  fi
  debug_session "recent_file: ${recent_file##*/}"

  if [[ -z "$recent_file" || ! -f "$recent_file" ]]; then
    echo "reset_secs:$SESSION_DURATION_SECS"$'\n'"debug:$session_debug"
    return
  fi

  # Get just the most recent timestamp (last line with timestamp, much faster than parsing all)
  local last_ts_str
  last_ts_str=$(grep -ohE '"timestamp":"[^"]*"' "$recent_file" 2>/dev/null | \
    tail -1 | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}')
  debug_session "last_timestamp: $last_ts_str"

  if [[ -z "$last_ts_str" ]]; then
    debug_session "no_timestamps_found"
    echo "reset_secs:$SESSION_DURATION_SECS"$'\n'"debug:$session_debug"
    return
  fi

  # Parse the most recent timestamp to get session timing
  local last_ts
  last_ts=$(parse_timestamp "$last_ts_str")
  if [[ -z "$last_ts" ]]; then
    debug_session "parse_failed"
    echo "reset_secs:$SESSION_DURATION_SECS"$'\n'"debug:$session_debug"
    return
  fi

  # Session starts at the hour of the most recent activity
  local session_start session_end
  session_start=$(round_to_hour "$last_ts")
  session_end=$((session_start + SESSION_DURATION_SECS))

  debug_session "last_activity: $last_ts"
  debug_session "session_start: $session_start"
  debug_session "session_end: $session_end"

  # Calculate time until reset
  local reset_secs=$((session_end - now))

  # If session has expired, show full duration
  [[ $reset_secs -lt 0 ]] && reset_secs=$SESSION_DURATION_SECS
  [[ $reset_secs -gt $SESSION_DURATION_SECS ]] && reset_secs=$SESSION_DURATION_SECS

  # Convert debug newlines to pipe separators for single-line output
  local debug_oneline="${session_debug//$'\n'/ | }"
  local result="reset_secs:${reset_secs}"$'\n'"debug:${debug_oneline}"
  if [[ "$SHOW_DEBUG_INFO" != "1" ]]; then
    echo "$result" > "$SESSION_STATS_CACHE_FILE"
  fi
  echo "$result"
}

get_session_value() {
  local key="$1"
  local data="$2"
  echo "$data" | grep "^${key}:" | head -1 | cut -d: -f2-
}

# Temp file for session debug output (subshell workaround)
SESSION_DEBUG_FILE="$CACHE_DIR/session-debug"

format_session_usage() {
  if [[ "$SESSION_OPTIONS" == "0" ]]; then
    echo ""
    return
  fi

  local session_data
  session_data=$(calculate_session_usage)

  local reset_secs
  reset_secs=$(get_session_value "reset_secs" "$session_data")

  # Write debug output to file for parent shell to read
  if [[ "$SHOW_DEBUG_INFO" == "1" ]]; then
    get_session_value "debug" "$session_data" > "$SESSION_DEBUG_FILE"
  fi

  local hours=$((reset_secs / 3600))
  local mins=$(((reset_secs % 3600) / 60))
  echo "${yellow}${ICON_TIMER}${hours}h${mins}m${reset}$(verbose_label "until reset")"
}

# =============================================================================
# Main Output
# =============================================================================

# Timing helper (returns milliseconds since epoch)
get_ms() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS: use python for millisecond precision
    python3 -c 'import time; print(int(time.time() * 1000))' 2>/dev/null || echo $(($(date +%s) * 1000))
  else
    # Linux: date supports %N for nanoseconds
    echo $(($(date +%s%N) / 1000000))
  fi
}

# Time a calculation and store result
DEBUG_TIMINGS=""
time_calc() {
  local name="$1"
  local start end elapsed
  start=$(get_ms)
  eval "$2"
  end=$(get_ms)
  elapsed=$((end - start))
  if [[ "$SHOW_DEBUG_INFO" == "1" ]]; then
    DEBUG_TIMINGS+="${name}: ${elapsed}ms | "
  fi
}

DEBUG_INFO=$(get_debug_info)

# Always run calculations directly (time_calc with eval has issues on macOS)
MODEL=$(get_model_name)
CURRENT_DIR=$(get_curr_dir)
GIT_INFO=$(format_git_info)
CONTEXT_USAGE=$(format_context_usage)
CONTEXT_REMAINING=$(format_context_remaining)
COST_INFO=$(format_cost)
DAILY_STATS=$(format_daily_stats)
SESSION_USAGE=$(format_session_usage)

# Helper to trim leading/trailing whitespace
trim() {
  local var="$1"
  var="${var#"${var%%[![:space:]]*}"}"  # trim leading
  var="${var%"${var##*[![:space:]]}"}"  # trim trailing
  echo "$var"
}

# Build sections array and join with " | "
# Each section is added only if non-empty
sections=()

# Directory (with optional folder icon)
if [[ -n "$ICON_FOLDER" ]]; then
  sections+=("${cyan}${ICON_FOLDER}${CURRENT_DIR}${reset}")
else
  sections+=("${cyan}${CURRENT_DIR}${reset}")
fi

# Git info
GIT_INFO_TRIMMED=$(trim "$GIT_INFO")
if [[ -n "$GIT_INFO_TRIMMED" ]]; then
  sections+=("${violet}${GIT_INFO_TRIMMED}${reset}")
fi

# Model name
sections+=("${bold}${white}${ICON_ROBOT}${MODEL}${reset}")

# Context remaining
CONTEXT_REMAINING_TRIMMED=$(trim "$CONTEXT_REMAINING")
if [[ -n "$CONTEXT_REMAINING_TRIMMED" ]]; then
  sections+=("$CONTEXT_REMAINING_TRIMMED")
fi

# Context usage
CONTEXT_TRIMMED=$(trim "$CONTEXT_USAGE")
if [[ -n "$CONTEXT_TRIMMED" ]]; then
  sections+=("$CONTEXT_TRIMMED")
fi

# Cost info
COST_TRIMMED=$(trim "$COST_INFO")
if [[ -n "$COST_TRIMMED" ]]; then
  sections+=("$COST_TRIMMED")
fi

# Daily stats
DAILY_TRIMMED=$(trim "$DAILY_STATS")
if [[ -n "$DAILY_TRIMMED" ]]; then
  sections+=("$DAILY_TRIMMED")
fi

# Session usage
SESSION_TRIMMED=$(trim "$SESSION_USAGE")
if [[ -n "$SESSION_TRIMMED" ]]; then
  sections+=("$SESSION_TRIMMED")
fi

# Join sections with " | " separator
output=""
for i in "${!sections[@]}"; do
  if [[ $i -eq 0 ]]; then
    output="${sections[$i]}"
  else
    output+=" ${reset}|${reset} ${sections[$i]}"
  fi
done

# Add debug info at the end if present
if [[ -n "$DEBUG_INFO" ]]; then
  if [[ -f "$SESSION_DEBUG_FILE" ]]; then
    session_debug=$(cat "$SESSION_DEBUG_FILE" 2>/dev/null)
    if [[ -n "$session_debug" ]]; then
      output+=$'\n'"${reset}Session: ${session_debug}${reset}"
    fi
  fi
  output+=$'\n'"${reset}Input: ${DEBUG_INFO}${reset}"
fi

printf "%s\\n" "$output"

# =============================================================================
# Test Commands
# =============================================================================
# Basic test:
# echo '{"model":{"display_name":"Opus 4.5"},"workspace":{"current_dir":"/Users/demo/projects/myapp"},"context_window":{"used_percentage":42.5,"remaining_percentage":57.5,"total_input_tokens":85000,"total_output_tokens":12000,"context_window_size":200000},"cost":{"total_cost_usd":0.42,"total_duration_ms":135000,"total_lines_added":156,"total_lines_removed":23}}' | ./statusline.sh

# Test with low context:
# echo '{"model":{"display_name":"Opus 4.5"},"workspace":{"current_dir":"/Users/demo/projects/myapp"},"context_window":{"used_percentage":92,"remaining_percentage":8,"total_input_tokens":180000,"total_output_tokens":4000,"context_window_size":200000}}' | ./statusline.sh

# Test with custom git options:
# CLAUDE_STATUSLINE_GIT="branch,ahead_behind,staged,modified,dirty" ./statusline.sh < test.json

# Test with context + cost:
# CLAUDE_STATUSLINE_CONTEXT_USAGE="battery_icon,pct_remaining,tokens_fraction" CLAUDE_STATUSLINE_COST="total_usd,duration,lines_changed" ./statusline.sh < test.json

# Test with daily stats:
# CLAUDE_STATUSLINE_DAILY="messages,sessions,tokens" ./statusline.sh < test.json

# Test with session usage (5-hour window):
# CLAUDE_STATUSLINE_SESSION="tokens,messages,reset_time" ./statusline.sh < test.json

# Test with different plan:
# CLAUDE_STATUSLINE_SESSION="tokens,messages,reset_time" CLAUDE_STATUSLINE_PLAN="pro" ./statusline.sh < test.json

# Test with everything:
# CLAUDE_STATUSLINE_GIT="branch,ahead_behind,staged,dirty" \
# CLAUDE_STATUSLINE_CONTEXT_USAGE="battery_icon,pct_remaining" \
# CLAUDE_STATUSLINE_COST="total_usd,lines_changed" \
# CLAUDE_STATUSLINE_DAILY="messages,tokens" \
# ./statusline.sh < test.json

# Test with colors disabled:
# CLAUDE_STATUSLINE_COLORS=0 ./statusline.sh < test.json

# Test with icons disabled:
# CLAUDE_STATUSLINE_ICONS=0 ./statusline.sh < test.json

# Test with context remaining (autocompact-adjusted):
# CLAUDE_STATUSLINE_CONTEXT_REMAINING="battery_icon,pct_remaining,tokens_remaining" ./statusline.sh < test.json

# Test with context remaining (raw, no autocompact adjustment):
# CLAUDE_STATUSLINE_CONTEXT_REMAINING="battery_icon,pct_remaining" CLAUDE_STATUSLINE_CONTEXT_REMAINING_USE_AUTOCOMPACT=0 ./statusline.sh < test.json

# Test with git disabled:
# CLAUDE_STATUSLINE_GIT=0 ./statusline.sh < test.json
