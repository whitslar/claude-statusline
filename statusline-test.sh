#!/bin/bash
# Statusline Test Matrix
# Tests all possible options and displays sample output

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATUSLINE="$SCRIPT_DIR/statusline.sh"

# Sample JSON input with all fields populated
SAMPLE_JSON='{
  "model": {"display_name": "Opus 4.5"},
  "workspace": {"current_dir": "/Users/demo/projects/myapp"},
  "context_window": {
    "used_percentage": 42.5,
    "remaining_percentage": 57.5,
    "total_input_tokens": 85000,
    "total_output_tokens": 12000,
    "context_window_size": 200000
  },
  "cost": {
    "total_cost_usd": 0.42,
    "total_duration_ms": 135000,
    "total_lines_added": 156,
    "total_lines_removed": 23
  }
}'

# Low context JSON (for critical battery display)
LOW_CONTEXT_JSON='{
  "model": {"display_name": "Opus 4.5"},
  "workspace": {"current_dir": "/Users/demo/projects/myapp"},
  "context_window": {
    "used_percentage": 92,
    "remaining_percentage": 8,
    "total_input_tokens": 180000,
    "total_output_tokens": 4000,
    "context_window_size": 200000
  }
}'

# Colors for test output
BOLD=$'\e[1m'
DIM=$'\e[2m'
RESET=$'\e[0m'
CYAN=$'\e[36m'
YELLOW=$'\e[33m'
GREEN=$'\e[32m'

print_header() {
  echo ""
  echo "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
  echo "${BOLD}${CYAN}  $1${RESET}"
  echo "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
}

print_subheader() {
  echo ""
  echo "${YELLOW}▸ $1${RESET}"
}

print_test() {
  local name="$1"
  local env_vars="$2"
  local json="${3:-$SAMPLE_JSON}"

  echo "${DIM}  $name${RESET}"
  echo -n "    "
  echo "$json" | env $env_vars bash "$STATUSLINE" 2>/dev/null
}

# ==============================================================================
print_header "STATUSLINE TEST MATRIX"
echo ""
echo "Testing: $STATUSLINE"
echo "Date: $(date)"

# ==============================================================================
print_header "1. DEFAULT OUTPUT"
print_test "Default settings" ""

# ==============================================================================
print_header "2. COLORS (CLAUDE_STATUSLINE_COLORS)"
print_subheader "Colors enabled (default)"
print_test "COLORS=1" "CLAUDE_STATUSLINE_COLORS=1"

print_subheader "Colors disabled"
print_test "COLORS=0" "CLAUDE_STATUSLINE_COLORS=0"

# ==============================================================================
print_header "3. ICONS (CLAUDE_STATUSLINE_ICONS)"
print_subheader "Icons enabled (default)"
print_test "ICONS=1" "CLAUDE_STATUSLINE_ICONS=1"

print_subheader "Icons disabled"
print_test "ICONS=0" "CLAUDE_STATUSLINE_ICONS=0"

print_subheader "Both colors and icons disabled"
print_test "COLORS=0 ICONS=0" "CLAUDE_STATUSLINE_COLORS=0 CLAUDE_STATUSLINE_ICONS=0"

# ==============================================================================
print_header "4. CONTEXT USAGE (CLAUDE_STATUSLINE_CONTEXT_USAGE)"
print_subheader "Individual options"
print_test "battery_icon only" "CLAUDE_STATUSLINE_CONTEXT_USAGE=battery_icon"
print_test "pct_remaining only" "CLAUDE_STATUSLINE_CONTEXT_USAGE=pct_remaining"
print_test "pct_used only" "CLAUDE_STATUSLINE_CONTEXT_USAGE=pct_used"
print_test "tokens_fraction only" "CLAUDE_STATUSLINE_CONTEXT_USAGE=tokens_fraction"
print_test "tokens_remaining only" "CLAUDE_STATUSLINE_CONTEXT_USAGE=tokens_remaining"
print_test "tokens_used only" "CLAUDE_STATUSLINE_CONTEXT_USAGE=tokens_used"
print_test "context_size only" "CLAUDE_STATUSLINE_CONTEXT_USAGE=context_size"

print_subheader "Combinations"
print_test "battery_icon,pct_remaining (default)" "CLAUDE_STATUSLINE_CONTEXT_USAGE=battery_icon,pct_remaining"
print_test "battery_icon,pct_remaining,tokens_fraction" "CLAUDE_STATUSLINE_CONTEXT_USAGE=battery_icon,pct_remaining,tokens_fraction"
print_test "All options" "CLAUDE_STATUSLINE_CONTEXT_USAGE=battery_icon,pct_remaining,pct_used,tokens_fraction,tokens_remaining,context_size"

print_subheader "Disabled"
print_test "CONTEXT_USAGE=0" "CLAUDE_STATUSLINE_CONTEXT_USAGE=0"

print_subheader "Low context warning (8% remaining)"
print_test "Low context" "CLAUDE_STATUSLINE_CONTEXT_USAGE=battery_icon,pct_remaining" "$LOW_CONTEXT_JSON"

# ==============================================================================
print_header "5. COST (CLAUDE_STATUSLINE_COST)"
print_subheader "Individual options"
print_test "total_usd only" "CLAUDE_STATUSLINE_COST=total_usd"
print_test "duration only" "CLAUDE_STATUSLINE_COST=duration"
print_test "lines_added only" "CLAUDE_STATUSLINE_COST=lines_added"
print_test "lines_removed only" "CLAUDE_STATUSLINE_COST=lines_removed"
print_test "lines_changed only" "CLAUDE_STATUSLINE_COST=lines_changed"

print_subheader "Combinations"
print_test "total_usd,duration" "CLAUDE_STATUSLINE_COST=total_usd,duration"
print_test "total_usd,lines_changed" "CLAUDE_STATUSLINE_COST=total_usd,lines_changed"
print_test "All options" "CLAUDE_STATUSLINE_COST=total_usd,duration,lines_added,lines_removed"

# ==============================================================================
print_header "6. DAILY STATS (CLAUDE_STATUSLINE_DAILY)"
print_subheader "Individual options"
print_test "messages only" "CLAUDE_STATUSLINE_DAILY=messages"
print_test "sessions only" "CLAUDE_STATUSLINE_DAILY=sessions"
print_test "tokens only" "CLAUDE_STATUSLINE_DAILY=tokens"
print_test "tools only" "CLAUDE_STATUSLINE_DAILY=tools"

print_subheader "Combinations"
print_test "messages,sessions" "CLAUDE_STATUSLINE_DAILY=messages,sessions"
print_test "All options" "CLAUDE_STATUSLINE_DAILY=messages,sessions,tokens,tools"

# ==============================================================================
print_header "7. SESSION RESET TIMER (CLAUDE_STATUSLINE_SESSION)"
print_subheader "Enabled/Disabled"
print_test "Session timer enabled" "CLAUDE_STATUSLINE_SESSION=1"
print_test "Session timer disabled (default)" "CLAUDE_STATUSLINE_SESSION=0"

# ==============================================================================
print_header "8. GIT OPTIONS (CLAUDE_STATUSLINE_GIT)"
echo "${DIM}  Note: Git options only show when in a git repository${RESET}"
print_subheader "Individual options"
print_test "branch only (default)" "CLAUDE_STATUSLINE_GIT=branch"
print_test "Disabled" "CLAUDE_STATUSLINE_GIT=0"

print_subheader "Combinations (visible in git repos)"
echo "  ${DIM}Available: branch,ahead_behind,staged,modified,untracked,stash,dirty,hash,add_remove${RESET}"
print_test "branch,ahead_behind,dirty" "CLAUDE_STATUSLINE_GIT=branch,ahead_behind,dirty"
print_test "branch,staged,modified,untracked" "CLAUDE_STATUSLINE_GIT=branch,staged,modified,untracked"
print_test "All options" "CLAUDE_STATUSLINE_GIT=branch,ahead_behind,staged,modified,untracked,stash,dirty,hash,add_remove"

# ==============================================================================
print_header "9. COMBINED EXAMPLES"
print_subheader "Minimal"
print_test "Icons off, context only" "CLAUDE_STATUSLINE_ICONS=0 CLAUDE_STATUSLINE_CONTEXT_USAGE=pct_remaining CLAUDE_STATUSLINE_GIT=0"

print_subheader "Standard with cost"
print_test "Context + Cost" "CLAUDE_STATUSLINE_CONTEXT_USAGE=battery_icon,pct_remaining CLAUDE_STATUSLINE_COST=total_usd,duration"

print_subheader "Full monitoring"
print_test "All sections" "CLAUDE_STATUSLINE_CONTEXT_USAGE=battery_icon,pct_remaining CLAUDE_STATUSLINE_COST=total_usd,lines_changed CLAUDE_STATUSLINE_DAILY=messages,sessions CLAUDE_STATUSLINE_SESSION=1"

print_subheader "Developer focus"
print_test "Git + Session" "CLAUDE_STATUSLINE_GIT=branch,dirty,add_remove CLAUDE_STATUSLINE_SESSION=1 CLAUDE_STATUSLINE_CONTEXT_USAGE=battery_icon"

print_subheader "Compact"
print_test "Just essentials" "CLAUDE_STATUSLINE_CONTEXT_USAGE=battery_icon CLAUDE_STATUSLINE_SESSION=1 CLAUDE_STATUSLINE_GIT=0"

# ==============================================================================
print_header "10. MIDNIGHT BOUNDARY TESTS"
echo ""
echo "  ${DIM}Tests session window behavior around midnight boundaries${RESET}"
echo "  ${DIM}Session windows are calculated in UTC, so midnight crossings matter${RESET}"
echo ""

print_subheader "UTC Midnight Boundaries"

# Calculate timestamps for UTC midnight boundaries
UTC_BEFORE_MIDNIGHT=$(TZ=UTC date -j -f "%Y-%m-%d %H:%M:%S" "$(date -u +%Y-%m-%d) 23:55:00" "+%s" 2>/dev/null || date -d "$(date -u +%Y-%m-%d) 23:55:00 UTC" "+%s")
UTC_AFTER_MIDNIGHT=$(TZ=UTC date -j -f "%Y-%m-%d %H:%M:%S" "$(date -u -v+1d +%Y-%m-%d) 00:05:00" "+%s" 2>/dev/null || date -d "$(date -u -d '+1 day' +%Y-%m-%d) 00:05:00 UTC" "+%s")

echo "  ${DIM}5 minutes before midnight UTC (23:55 UTC)${RESET}"
echo "    Simulated time: $(TZ=UTC date -r "$UTC_BEFORE_MIDNIGHT" "+%Y-%m-%d %H:%M:%S %Z" 2>/dev/null || TZ=UTC date -d "@$UTC_BEFORE_MIDNIGHT" "+%Y-%m-%d %H:%M:%S %Z")"
echo -n "    "
echo "$SAMPLE_JSON" | env CLAUDE_STATUSLINE_SESSION=1 CLAUDE_STATUSLINE_DEBUG_TIME="$UTC_BEFORE_MIDNIGHT" bash "$STATUSLINE" 2>/dev/null
echo ""

echo "  ${DIM}5 minutes after midnight UTC (00:05 UTC)${RESET}"
echo "    Simulated time: $(TZ=UTC date -r "$UTC_AFTER_MIDNIGHT" "+%Y-%m-%d %H:%M:%S %Z" 2>/dev/null || TZ=UTC date -d "@$UTC_AFTER_MIDNIGHT" "+%Y-%m-%d %H:%M:%S %Z")"
echo -n "    "
echo "$SAMPLE_JSON" | env CLAUDE_STATUSLINE_SESSION=1 CLAUDE_STATUSLINE_DEBUG_TIME="$UTC_AFTER_MIDNIGHT" bash "$STATUSLINE" 2>/dev/null
echo ""

print_subheader "EST Midnight Boundaries (converted to UTC)"
echo "  ${DIM}EST midnight = 05:00 UTC (EST is UTC-5)${RESET}"

# Calculate timestamps for EST midnight boundaries (EST midnight = 05:00 UTC)
EST_BEFORE_MIDNIGHT=$(TZ=UTC date -j -f "%Y-%m-%d %H:%M:%S" "$(date -u +%Y-%m-%d) 04:55:00" "+%s" 2>/dev/null || date -d "$(date -u +%Y-%m-%d) 04:55:00 UTC" "+%s")
EST_AFTER_MIDNIGHT=$(TZ=UTC date -j -f "%Y-%m-%d %H:%M:%S" "$(date -u +%Y-%m-%d) 05:05:00" "+%s" 2>/dev/null || date -d "$(date -u +%Y-%m-%d) 05:05:00 UTC" "+%s")

echo ""
echo "  ${DIM}5 minutes before midnight EST (04:55 UTC = 11:55pm EST)${RESET}"
echo "    Simulated time: $(TZ=UTC date -r "$EST_BEFORE_MIDNIGHT" "+%Y-%m-%d %H:%M:%S %Z" 2>/dev/null || TZ=UTC date -d "@$EST_BEFORE_MIDNIGHT" "+%Y-%m-%d %H:%M:%S %Z") (= $(TZ=America/New_York date -r "$EST_BEFORE_MIDNIGHT" "+%H:%M:%S %Z" 2>/dev/null || TZ=America/New_York date -d "@$EST_BEFORE_MIDNIGHT" "+%H:%M:%S %Z"))"
echo -n "    "
echo "$SAMPLE_JSON" | env CLAUDE_STATUSLINE_SESSION=1 CLAUDE_STATUSLINE_DEBUG_TIME="$EST_BEFORE_MIDNIGHT" bash "$STATUSLINE" 2>/dev/null
echo ""

echo "  ${DIM}5 minutes after midnight EST (05:05 UTC = 12:05am EST)${RESET}"
echo "    Simulated time: $(TZ=UTC date -r "$EST_AFTER_MIDNIGHT" "+%Y-%m-%d %H:%M:%S %Z" 2>/dev/null || TZ=UTC date -d "@$EST_AFTER_MIDNIGHT" "+%Y-%m-%d %H:%M:%S %Z") (= $(TZ=America/New_York date -r "$EST_AFTER_MIDNIGHT" "+%H:%M:%S %Z" 2>/dev/null || TZ=America/New_York date -d "@$EST_AFTER_MIDNIGHT" "+%H:%M:%S %Z"))"
echo -n "    "
echo "$SAMPLE_JSON" | env CLAUDE_STATUSLINE_SESSION=1 CLAUDE_STATUSLINE_DEBUG_TIME="$EST_AFTER_MIDNIGHT" bash "$STATUSLINE" 2>/dev/null
echo ""

print_subheader "Cross-day date pattern verification"
echo "  ${DIM}These tests verify the date pattern handles day boundaries correctly${RESET}"
echo "  ${DIM}The session window looks back up to 12 hours, which may cross dates${RESET}"
echo ""

# ==============================================================================
print_header "11. ENVIRONMENT VARIABLE REFERENCE"
echo ""
echo "  ${BOLD}Variable${RESET}                              ${BOLD}Default${RESET}              ${BOLD}Options${RESET}"
echo "  ─────────────────────────────────────────────────────────────────────────────"
echo "  CLAUDE_STATUSLINE_COLORS               1                    0, 1"
echo "  CLAUDE_STATUSLINE_ICONS                1                    0, 1"
echo "  CLAUDE_STATUSLINE_GIT                  branch               0, or comma-separated:"
echo "                                                              branch,ahead_behind,staged,"
echo "                                                              modified,untracked,stash,"
echo "                                                              dirty,hash,add_remove"
echo "  CLAUDE_STATUSLINE_CONTEXT_USAGE        battery_icon,        0, or comma-separated:"
echo "                                         pct_remaining        battery_icon,pct_remaining,"
echo "                                                              pct_used,tokens_fraction,"
echo "                                                              tokens_remaining,tokens_used,"
echo "                                                              context_size"
echo "  CLAUDE_STATUSLINE_COST                 0                    0, or comma-separated:"
echo "                                                              total_usd,duration,"
echo "                                                              lines_added,lines_removed,"
echo "                                                              lines_changed"
echo "  CLAUDE_STATUSLINE_DAILY                0                    0, or comma-separated:"
echo "                                                              messages,sessions,tokens,tools"
echo "  CLAUDE_STATUSLINE_SESSION              0                    0, 1 (shows reset timer)"
echo "  CLAUDE_STATUSLINE_GIT_CACHE_TTL        5                    seconds"
echo "  CLAUDE_STATUSLINE_DAILY_CACHE_TTL      60                   seconds"
echo "  CLAUDE_STATUSLINE_SESSION_CACHE_TTL    30                   seconds"
echo ""

# ==============================================================================
print_header "12. TEST COMPLETE"
echo ""
echo "  To use in settings.json:"
echo ""
echo '  "statusLine": {'
echo '    "type": "command",'
echo '    "command": "CLAUDE_STATUSLINE_DAILY=\"messages,sessions\" ~/.claude/statusline.sh"'
echo '  }'
echo ""
