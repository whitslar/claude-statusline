# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A custom statusline script for Claude Code's `statusLine` setting. It renders a rich, configurable terminal status bar showing git info, context window usage, session cost, daily stats, and session reset timers. It reads JSON from stdin (provided by Claude Code) and outputs ANSI-formatted text.

## Files

- **`statusline.sh`** — The main statusline script. Installed by copying to `~/.claude/statusline.sh` and configuring in Claude Code's `settings.json`.
- **`statusline-test.sh`** — Visual test matrix that exercises all configuration combinations with sample JSON data.

## Running

```bash
# Test with sample JSON piped to stdin
echo '{"model":{"display_name":"Opus 4.5"},"workspace":{"current_dir":"/Users/test/project"},"context_window":{"used_percentage":42.5,"remaining_percentage":57.5,"total_input_tokens":85000,"total_output_tokens":12000,"context_window_size":200000},"cost":{"total_cost_usd":0.42,"total_duration_ms":135000,"total_lines_added":156,"total_lines_removed":23}}' | ./statusline.sh

# Run the full visual test matrix
./statusline-test.sh

# Test with specific env overrides
CLAUDE_STATUSLINE_COST="total_usd,duration" CLAUDE_STATUSLINE_GIT=0 ./statusline.sh < test.json

# Debug mode (dumps raw JSON input and session timing info)
CLAUDE_STATUSLINE_DEBUG=1 ./statusline.sh < test.json
```

## Architecture

The script follows a pipeline pattern: **read JSON → extract fields → collect data → format sections → join output**.

### Input
Reads a JSON blob from stdin containing `model`, `workspace`, `context_window`, and `cost` objects. Immediately closes stdin (`exec 0</dev/null`) to prevent subprocess consumption.

### Configuration
All behavior is driven by `CLAUDE_STATUSLINE_*` environment variables. Each feature section (git, context, cost, daily, session) has a corresponding env var that accepts either `0` (disabled) or a comma-separated list of display options. See the header block in `statusline.sh` (lines 9-41) for the full reference.

### Section Pipeline
Each section has a `format_*` function that returns empty string when disabled:
- **Git** (`format_git_info`) — Runs git commands, caches results per-repo in `$TMPDIR/claude-statusline-cache/` with configurable TTL
- **Context Usage** (`format_context_usage`) — Token counts and percentages from the JSON input
- **Context Remaining** (`format_context_remaining`) — Separate section with optional autocompact buffer adjustment (subtracts `AUTOCOMPACT_BUFFER` tokens from effective window)
- **Cost** (`format_cost`) — Session cost, duration, lines changed from JSON
- **Daily Stats** (`format_daily_stats`) — Reads from `~/.claude/stats-cache.json`, cached with its own TTL
- **Session Timer** (`format_session_usage`) — Parses `.jsonl` files in `~/.claude/projects/` to find last activity timestamp, calculates time until 5-hour session window expires

### Caching Strategy
Three independent caches in `$TMPDIR/claude-statusline-cache/`:
- Git data: per-repo file keyed by md5 of repo path, default 5s TTL
- Daily stats: single file, default 60s TTL
- Session stats: single file, default 30s TTL

### Output Assembly
Non-empty sections are joined with ` | ` separators. Colors use standard ANSI escape codes (no 256-color or truecolor), icons use Nerd Font glyphs with ASCII fallbacks when `ICONS=0`.

## Key Design Decisions

- The `CONTEXT_REMAINING` section is separate from `CONTEXT_USAGE` to allow independent autocompact-aware calculations (controlled by `CONTEXT_REMAINING_USE_AUTOCOMPACT`)
- Session timer matches the Ruby `statusline.rb` logic: 5-hour windows starting at the rounded hour of the most recent activity
- Timestamps in `.jsonl` files are UTC; `parse_timestamp` uses `TZ=UTC` on macOS to avoid local timezone offset errors
- `stat` commands have macOS (`-f %m`) and Linux (`-c %Y`) fallbacks throughout
