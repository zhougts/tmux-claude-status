#!/usr/bin/env bash
# install-claude-hooks.sh — wire Claude Code hooks so this plugin gets window state.
# Idempotent: strips any prior tmux-claude-status OR tmux-claude-session-manager state
# hooks first, then adds ours. Preserves all other hooks. Backs up settings.json.
#
#   UserPromptSubmit          -> state.sh working
#   PreToolUse AskUserQuestion-> state.sh needs   (bypass-mode "needs you" signal)
#   Notification              -> state.sh needs   (permission prompts; rare under bypass)
#   Stop                      -> state.sh done
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE="$DIR/state.sh"
SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required" >&2; exit 1; }
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
cp "$SETTINGS" "$SETTINGS.bak-claude-status"

tmp="$(mktemp)"
jq --arg s "$STATE" '
  def clean(a): [ (a // [])[] | select( ([.hooks[]?.command] | map(test("tmux-claude-status/scripts/state.sh|tmux-claude-session-manager/scripts/state.sh")) | any | not) ) ];
  .hooks //= {}
  | .hooks.UserPromptSubmit = (clean(.hooks.UserPromptSubmit) + [ {hooks:[{type:"command",command:($s+" working")}]} ])
  | .hooks.PreToolUse       = (clean(.hooks.PreToolUse)       + [ {matcher:"AskUserQuestion",hooks:[{type:"command",command:($s+" needs")}]} ])
  | .hooks.Notification     = (clean(.hooks.Notification)     + [ {matcher:"",hooks:[{type:"command",command:($s+" needs")}]} ])
  | .hooks.Stop             = (clean(.hooks.Stop)             + [ {hooks:[{type:"command",command:($s+" done")}]} ])
  | .hooks.SessionEnd       = (clean(.hooks.SessionEnd)       + [ {hooks:[{type:"command",command:($s+" clear")}]} ])
' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"

echo "OK: hooks point at $STATE"
echo "backup: $SETTINGS.bak-claude-status"
