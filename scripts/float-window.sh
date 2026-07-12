#!/usr/bin/env bash
# Float ONLY the given task windows (the ones that need you) in this popup. Builds a
# temporary session and `link-window`s just those windows into it — link *shares* the
# window, it does not move it — so the popup lists exactly these tasks and nothing else
# (no conversation / working / done windows). Status bar on → Alt+num / Ctrl-b n/p switch
# between them; answer each in place. Closing the popup kills the temp session; the real
# windows (still linked in your main session) survive untouched.
#   Args: <window_id> [<window_id> ...]   (opens on the first)
# Runs inside `tmux display-popup -E`.
target_count=$#
[ "$target_count" -eq 0 ] && exit 0

peek="_cpeek_$$"
# Kill only the temp session on exit — never the real windows (they remain in the main
# session, so killing this session just unlinks them here).
trap 'tmux kill-session -t "$peek" 2>/dev/null' EXIT

tmux new-session -d -s "$peek" 2>/dev/null || exit 0
placeholder="$(tmux list-windows -t "$peek" -F '#{window_id}' 2>/dev/null | head -1)"
tmux set-option -t "$peek" status on 2>/dev/null            # show the list — but only these needs windows
tmux set-option -t "$peek" detach-on-destroy on 2>/dev/null

linked=0
for wid in "$@"; do
  tmux link-window -s "$wid" -t "$peek:" 2>/dev/null && linked=$((linked + 1))
done
[ "$linked" -eq 0 ] && exit 0                               # nothing linked; trap kills the temp session

[ -n "$placeholder" ] && tmux kill-window -t "$placeholder" 2>/dev/null   # drop the throwaway shell
firstidx="$(tmux list-windows -t "$peek" -F '#{window_index}' 2>/dev/null | head -1)"
[ -n "$firstidx" ] && tmux select-window -t "$peek:$firstidx" 2>/dev/null # open on the first task that needs you
tmux attach-session -t "$peek"                             # interactive; Alt+num / Ctrl-b n/p to switch, answer in place
exit 0
