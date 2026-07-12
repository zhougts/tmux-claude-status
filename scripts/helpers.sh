#!/usr/bin/env bash
# Shared helpers for tmux-claude-status.

# get_tmux_option <option-name> <default> — global option value, or default when unset/empty.
get_tmux_option() {
  local value
  value="$(tmux show-option -gqv "$1" 2>/dev/null)"
  if [ -n "$value" ]; then printf '%s' "$value"; else printf '%s' "$2"; fi
}
