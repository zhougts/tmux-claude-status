#!/usr/bin/env bash
# badge.sh — aggregate Claude-state badge for status-right. Counts windows in the
# CURRENT session by @claude_state. Emits e.g. "🟡2 🟢1 🔴3 ". Empty when none.
# Use session_id (not #S): a numeric session name like "0" misparses as a window index.
sess="$(tmux display-message -p '#{session_id}' 2>/dev/null)" || exit 0
n=0; d=0; w=0
while IFS= read -r st; do
  case "$st" in
    needs)   n=$((n+1)) ;;
    done)    d=$((d+1)) ;;
    working) w=$((w+1)) ;;
  esac
done < <(tmux list-windows -t "$sess" -F '#{@claude_state}' 2>/dev/null)
# printf each group directly — accumulating emoji in a shell var mangles multibyte
# bytes under macOS bash 3.2. printf emits the literal format bytes safely.
[ "$n" -gt 0 ] && printf '🟡%d ' "$n"
[ "$d" -gt 0 ] && printf '🟢%d ' "$d"
[ "$w" -gt 0 ] && printf '🔴%d ' "$w"
