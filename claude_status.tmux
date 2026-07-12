#!/usr/bin/env bash
# tmux-claude-status — color tmux windows by Claude Code state, show an aggregate
# badge in the status bar, and fire a strong (persistent, silent) notification when
# a Claude window needs you. Reusable tmux plugin.
#
# TPM:    set -g @plugin 'youruser/tmux-claude-status'
# Local:  run-shell /path/to/tmux-claude-status/claude_status.tmux   (in ~/.tmux.conf)
#
# State is written per-window by scripts/state.sh, driven by Claude Code hooks
# (see scripts/install-claude-hooks.sh). States: working | needs | done.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/helpers.sh
. "$CURRENT_DIR/scripts/helpers.sh"

badge_enabled="$(get_tmux_option @claude_badge 'on')"

# Per-window state marker. @claude_state is window-scoped, so it resolves per window in the
# list. State shows via the glyph only; the current window is a rounded blue bubble matching
# Catppuccin 'rounded'. Blue is resolved to hex now (catppuccin.tmux already ran).
thm_crust="$(get_tmux_option @thm_crust '#dce0e8')"
thm_blue="$(get_tmux_option @thm_blue '#1e66f5')"
# Rounded caps for the current-window bubble, injected as raw UTF-8 bytes so the source
# encoding can't strip them: U+E0B6 = EE 82 B6, U+E0B4 = EE 82 B4 (same glyphs Catppuccin
# 'rounded' uses).
capL="$(printf '\356\202\266')"   # left half-circle
capR="$(printf '\356\202\264')"   # right half-circle

# State is shown by the GLYPH alone (🟡 needs · 🔴 working · 🟢 done) — no background fill.
# Only the CURRENT window gets a colored (blue) rounded bubble.
# NB: the commas in #{?...} are branch separators; keep them OUT of any #[...] tag.
glyph='#{?#{==:#{@claude_state},needs},🟡 ,#{?#{==:#{@claude_state},done},🟢 ,#{?#{==:#{@claude_state},working},🔴 ,}}}'

tmux set -g window-status-separator ' '
# inactive windows: glyph + index + name, no background
tmux set -g window-status-format " ${glyph}#I #W "
# current window: a single blue rounded bubble (glyph inside if it has a state)
tmux set -g window-status-current-format "#[bg=default]#[fg=${thm_blue}]${capL}#[bg=${thm_blue}]#[fg=${thm_crust}] ${glyph}#I #W #[bg=default]#[fg=${thm_blue}]${capR}"

# Aggregate badge prepended to status-right. Idempotent (guarded by the path token)
# and non-destructive (keeps whatever status-right the theme already set).
if [ "$badge_enabled" = "on" ]; then
  existing="$(tmux show-option -gqv status-right)"
  case "$existing" in
    *tmux-claude-status*) : ;;                       # already installed
    *) tmux set -g status-right "#($CURRENT_DIR/scripts/badge.sh)$existing" ;;
  esac
fi

# Floating task picker popup: needs-first list + live preview + Enter-to-jump.
# Prefix-free key (default Option+s / M-s). Set @claude_popup_key '' to disable.
popup_key="$(get_tmux_option @claude_popup_key 'M-s')"
[ -n "$popup_key" ] && tmux bind -n "$popup_key" run-shell -b "$CURRENT_DIR/scripts/todo.sh manual"

# Optional one-key close/detach binding — OFF by default (bind your own in tmux.conf,
# e.g. `bind -n M-q detach-client`). Set @claude_close_key to a key to enable it here.
close_key="$(get_tmux_option @claude_close_key '')"
if [ -n "$close_key" ]; then tmux bind -n "$close_key" detach-client; fi
exit 0
