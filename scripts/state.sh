#!/usr/bin/env bash
# state.sh <working|needs|done|clear> — set the current Claude window's state; on 'needs'
# auto-float the task window in a popup so you can answer it directly (B).
#
# Claude Code hooks inherit the Claude process environment, so $TMUX_PANE is set
# whenever Claude runs inside tmux. Outside tmux this is a harmless no-op.
# Runs as a bash script (not the interactive shell) so a `tmux` alias never applies.

[ -z "$TMUX_PANE" ] && exit 0
# Only track windows the launcher explicitly marked (it exports CLAUDE_TASK_WINDOW=1
# for the claude it starts). Hooks inherit the Claude process env, so the main /
# dispatcher session — started without this — is excluded from badge + coloring.
[ -n "${CLAUDE_TASK_WINDOW:-}" ] || exit 0
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
. "$DIR/helpers.sh"

win="$(tmux display-message -p -t "$TMUX_PANE" '#{window_id}' 2>/dev/null)" || exit 0
[ -z "$win" ] && exit 0

state="${1:-done}"

# clear: the Claude session ended (SessionEnd hook) — drop the state so the window
# stops showing a stale color / inflating the badge once its claude is gone.
if [ "$state" = "clear" ]; then
  tmux set-option -wu -t "$win" @claude_state 2>/dev/null
  tmux set-option -wu -t "$win" @claude_state_at 2>/dev/null
  exit 0
fi

tmux set-option -w -t "$win" @claude_state "$state"
tmux set-option -w -t "$win" @claude_state_at "$(date +%s)"

# B: surface a task that needs YOU. todo.sh owns the one-popup lock and decides:
# 1 need → big float (answer in place); 2+ → small picker → big float. Never stacks.
if [ "$state" = "needs" ] && [ "$(get_tmux_option @claude_notify on)" = "on" ]; then
  "$DIR/todo.sh" >/dev/null 2>&1 &
fi
exit 0
