#!/usr/bin/env bash
# Open the Claude TODO as ONE popup (no two-step picker), owning the one-popup lock:
#   0 needs → nothing (or a short note when opened manually via Option+s)
#   1+ needs → ONE popup that links in ONLY the tasks that need you (not conversation /
#              working / done); opens on the first, and its status bar lists just those, so
#              you switch between them (Alt+num / Ctrl-b n/p) and answer each right there.
# Bound to Option+s (arg: manual) and called by state.sh when a task needs you.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
. "$DIR/helpers.sh"

# one-popup lock (the whole TODO flow counts as one popup; state.sh checks this)
lock="$(tmux show-option -gqv @claude_popup_open 2>/dev/null)"; now="$(date +%s)"
if [ -n "$lock" ] && [ "$((now - lock))" -lt 3600 ]; then exit 0; fi
tmux set-option -g @claude_popup_open "$now" 2>/dev/null
trap 'tmux set-option -gu @claude_popup_open 2>/dev/null' EXIT

sess="$(tmux display-message -p '#{session_id}' 2>/dev/null)"
manual="${1:-}"

# All windows that need you, MOST-RECENTLY-notified FIRST (by @claude_state_at — the epoch
# state.sh stamped when the window entered 'needs'). The popup links exactly these — nothing
# else — and opens on the first (= newest need); switch among them in-popup with
# Alt+num / Ctrl-b n/p. Ties (same second) keep window order.
ids="$(
  for wid in $(tmux list-windows -t "$sess" -F '#{window_id}' 2>/dev/null); do
    [ "$(tmux show-options -wqv -t "$wid" @claude_state 2>/dev/null)" = "needs" ] || continue
    at="$(tmux show-options -wqv -t "$wid" @claude_state_at 2>/dev/null)"
    printf '%s\t%s\n' "${at:-0}" "$wid"
  done | sort -rn -k1,1 | cut -f2 | tr '\n' ' '
)"

if [ -z "$ids" ]; then
  [ "$manual" = "manual" ] && tmux display-popup -w 46% -h 20% -E "printf '\n  ✓ 没有需要你回答的任务。\n\n  按 Esc / q 关闭。'; read -r -n1 _ 2>/dev/null"
  exit 0
fi

# shellcheck disable=SC2086
tmux display-popup -w 90% -h 85% -E "$DIR/float-window.sh $ids"
exit 0
