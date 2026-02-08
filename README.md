# Claude Code Statusline

A configurable statusline script for [Claude Code](https://claude.ai/code) that displays git status, context window usage, session cost, daily stats, and session reset timers in your terminal.

![Claude Code Statusline](screenshot.png)

## Prerequisites

- **bash** and **jq** (used to parse JSON input from Claude Code)
- **A Nerd Font** (optional) — icons use [Nerd Font](https://www.nerdfonts.com/) glyphs by default. If you don't have one installed, set `CLAUDE_STATUSLINE_ICONS=0` to use ASCII fallbacks (see [Disabling Icons](#disabling-icons) below).

## Installation

1. Copy the script to your Claude config directory:

   ```bash
   cp statusline.sh ~/.claude/statusline.sh
   chmod +x ~/.claude/statusline.sh
   ```

2. Configure Claude Code to use it. Open (or create) your settings file at `~/.claude/settings.json` and add:

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/.claude/statusline.sh"
     }
   }
   ```

3. Restart Claude Code. The statusline should appear at the bottom of your terminal.

## Disabling Icons

If you don't have a Nerd Font installed, the default icons will render as missing-glyph boxes. Disable them by prepending the environment variable to the command in your `settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "CLAUDE_STATUSLINE_ICONS=0 ~/.claude/statusline.sh"
  }
}
```

This switches all icons to plain ASCII characters (e.g., `^`/`v` for ahead/behind, `S` for staged, `M` for modified, `[====]` for battery).

## Configuration

All options are set via environment variables, prepended to the command in `settings.json`. Set any combination by separating them with spaces:

```json
{
  "statusLine": {
    "type": "command",
    "command": "CLAUDE_STATUSLINE_ICONS=0 CLAUDE_STATUSLINE_COST=\"total_usd,duration\" CLAUDE_STATUSLINE_DAILY=\"messages,sessions\" ~/.claude/statusline.sh"
  }
}
```

### Environment Variables

| Variable | Default | Description |
|---|---|---|
| `CLAUDE_STATUSLINE_COLORS` | `1` | `1` = ANSI colors enabled, `0` = plain text |
| `CLAUDE_STATUSLINE_ICONS` | `1` | `1` = Nerd Font icons, `0` = ASCII fallbacks |
| `CLAUDE_STATUSLINE_VERBOSE` | `1` | `1` = show labels like "left", "until compact", `0` = hide |
| `CLAUDE_STATUSLINE_GIT` | `branch,ahead_behind,staged,modified,add_remove,stash` | Comma-separated list or `0` to disable. Options: `branch`, `ahead_behind`, `staged`, `modified`, `untracked`, `stash`, `dirty`, `hash`, `add_remove` |
| `CLAUDE_STATUSLINE_CONTEXT_USAGE` | `tokens_fraction` | Comma-separated list or `0`. Options: `battery_icon`, `pct_remaining`, `pct_used`, `tokens_fraction`, `tokens_remaining`, `tokens_until_autocompact`, `tokens_used`, `context_size` |
| `CLAUDE_STATUSLINE_CONTEXT_REMAINING` | `battery_icon,pct_remaining` | Comma-separated list or `0`. Options: `battery_icon`, `pct_remaining`, `tokens_remaining`, `tokens_fraction` |
| `CLAUDE_STATUSLINE_CONTEXT_REMAINING_USE_AUTOCOMPACT` | `1` | `1` = subtract autocompact buffer from remaining context, `0` = raw values |
| `CLAUDE_STATUSLINE_AUTOCOMPACT_BUFFER` | `45000` | Tokens reserved for autocompact. Set to `0` to disable buffer adjustment |
| `CLAUDE_STATUSLINE_COST` | `1` | Comma-separated list or `0`. Options: `total_usd`, `duration`, `lines_added`, `lines_removed`, `lines_changed` |
| `CLAUDE_STATUSLINE_DAILY` | `0` (disabled) | Comma-separated list or `0`. Options: `messages`, `sessions`, `tokens`, `tools`. Reads from `~/.claude/stats-cache.json` |
| `CLAUDE_STATUSLINE_SESSION` | `1` | `1` = show session reset countdown timer, `0` = hide |
| `CLAUDE_STATUSLINE_DEBUG` | `0` | `1` = show raw JSON input and session timing debug info |

### Cache TTLs

| Variable | Default | Description |
|---|---|---|
| `CLAUDE_STATUSLINE_GIT_CACHE_TTL` | `5` | Git data cache lifetime in seconds |
| `CLAUDE_STATUSLINE_DAILY_CACHE_TTL` | `60` | Daily stats cache lifetime in seconds |
| `CLAUDE_STATUSLINE_SESSION_CACHE_TTL` | `30` | Session stats cache lifetime in seconds |

## Example Configurations

**Minimal (no icons, context only):**
```json
"command": "CLAUDE_STATUSLINE_ICONS=0 CLAUDE_STATUSLINE_GIT=0 CLAUDE_STATUSLINE_CONTEXT_USAGE=pct_remaining ~/.claude/statusline.sh"
```

**Full monitoring:**
```json
"command": "CLAUDE_STATUSLINE_CONTEXT_USAGE=\"battery_icon,pct_remaining\" CLAUDE_STATUSLINE_COST=\"total_usd,lines_changed\" CLAUDE_STATUSLINE_DAILY=\"messages,sessions\" ~/.claude/statusline.sh"
```

**Developer focus (git + compact context):**
```json
"command": "CLAUDE_STATUSLINE_GIT=\"branch,dirty,add_remove\" CLAUDE_STATUSLINE_CONTEXT_USAGE=battery_icon ~/.claude/statusline.sh"
```

## Testing

Run the visual test matrix to preview all option combinations:

```bash
./statusline-test.sh
```

Or test manually with sample JSON:

```bash
echo '{"model":{"display_name":"Opus 4.5"},"workspace":{"current_dir":"/tmp/test"},"context_window":{"used_percentage":42,"remaining_percentage":58,"total_input_tokens":85000,"total_output_tokens":12000,"context_window_size":200000},"cost":{"total_cost_usd":0.42,"total_duration_ms":135000,"total_lines_added":156,"total_lines_removed":23}}' | ./statusline.sh
```
