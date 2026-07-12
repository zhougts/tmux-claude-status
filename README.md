# tmux-claude-status

See and act on multiple **Claude Code** sessions running as tmux windows: each task
window is colored by state in the status bar, and — when one needs your answer — its
window **floats in front** so you answer it directly and pop back where you were.

Built for fanning out tasks (e.g. one Claude per Todoist item) into tmux windows.
Works in bypass-permissions mode: "needs you" comes from `AskUserQuestion` (and idle
`Notification`), not permission prompts.

## What you get

- **Status-bar glyphs** — each task window shows its state via a glyph (no background fill):
  🟡 needs you · 🔴 working · 🟢 done. Only the current window gets a colored (blue) rounded
  bubble. Non-task windows are unmarked.
- **Aggregate badge** in `status-right`, e.g. `🟡2 🟢1 🔴3` — glance and know how many
  need you.
- **TODO** (`Option+s`) — opens **one** popup containing **only the tasks that need your
  answer** (conversation / working / done windows are not shown). It opens on the first, and
  its status bar lists just those needs tasks, so you **switch between them in the popup**
  (`Alt+num` / `Ctrl-b n/p`) and answer each in place — no second popup, no picker step.
  `Option+q` closes it. If nothing needs you it just says so.
- **Auto-surface on needs** — when a task needs you, that same one popup pops automatically.
  One popup at a time, never stacked: while it's open, new needs just update the badge (close
  and re-open to pull them in).
- **Close the popup** with **`Option+q`** (bind your own; same as `Ctrl-b d`).

## States & Claude hooks

| State | Set by (Claude hook) | Status bar | Badge |
|-------|----------------------|-----------|-------|
| `working` | `UserPromptSubmit` | 🔴 | 🔴 |
| `needs`   | `AskUserQuestion` (+ `Notification`) | 🟡 + **auto-float** | 🟡 |
| `done`    | `Stop` | 🟢 | 🟢 |
| (cleared) | `SessionEnd` | unmarked | — |

State lives in the per-window `@claude_state` option — no window renames, so
window-name-based dispatchers keep working.

## Install

**Plugin** — TPM (once published) `set -g @plugin 'youruser/tmux-claude-status'`, or local
in `~/.tmux.conf` (load AFTER your theme / status-right):
```tmux
run-shell ~/.config/tmux/plugins/tmux-claude-status/claude_status.tmux
```

**Claude hooks** (required for state) — run once; merges 5 hooks into
`~/.claude/settings.json` (UserPromptSubmit→working, AskUserQuestion→needs,
Notification→needs, Stop→done, SessionEnd→clear), idempotent, backs up, keeps your others:
```sh
~/.config/tmux/plugins/tmux-claude-status/scripts/install-claude-hooks.sh
```

**Recommended tmux setting** — so dispatched task window titles stick (tmux won't rename
them to the running process):
```tmux
set -g automatic-rename off
```

**Scope** — a window is tracked only if its Claude was launched with `CLAUDE_TASK_WINDOW=1`
in the environment. Your launcher sets it for task windows; your main interactive session
(started without it) is excluded from the glyphs, badge, list, and auto-float:
```sh
CLAUDE_TASK_WINDOW=1 claude --name "my task" "..."
```

## How the float works (no session-per-task needed)

Tasks stay as **windows** in your session. To surface the ones that need you, the plugin
spins up a temporary session (`_cpeek_*`) and **`link-window`s only the needs windows into
it** — `link-window` *shares* a window (it does not move it), so the popup lists exactly
those tasks and nothing else. It attaches inside a `display-popup` with the status bar on,
so you switch among them (`Alt+num` / `Ctrl-b n/p`) and answer each without leaving the
popup. Your main client's active window never changes; closing the popup kills the temp
session, and the real windows — still linked in your main session — survive untouched.

## Options (set before the plugin loads)

```tmux
set -g @claude_badge      'on'        # aggregate status-right badge
set -g @claude_notify     'on'        # B: auto-float a task when it needs you
set -g @claude_popup_key  'M-s'       # A: open the floating task list (prefix-free)
set -g @claude_close_key  ''          # off by default — bind your own, e.g. `bind -n M-q detach-client`
```
Set any key option to `''` to disable that binding; `@claude_notify off` disables auto-float.

## Files

```
claude_status.tmux          entry: window glyphs + badge + keybindings
scripts/state.sh            hook target: set per-window state; on needs opens the popup (B)
scripts/todo.sh             opens the one popup (float first needs; switch in-popup); owns the one-popup lock
scripts/float-window.sh     float ONLY the needs windows (link-window into a temp session; switchable, status bar on)
scripts/badge.sh            status-right aggregate count
scripts/install-claude-hooks.sh   wire/repoint the 5 Claude hooks
scripts/helpers.sh          get_tmux_option
```

## Notes / gotchas (learned the hard way)

- **No comma inside a `#[...]` color** used in the window format — a comma is read as the
  `#{?...}` branch separator and truncates the format. Use `@claude_needs_bg` +
  `@claude_needs_fg` separately, not `bg=x,fg=y`.
- **badge.sh uses `printf` per group**, not string concatenation — macOS bash 3.2 mangles
  multibyte emoji when you accumulate them in a variable.
- **badge/list target the session by `#{session_id}`**, not `#S` — a numeric session name
  like `0` otherwise misparses as a window index.
- `automatic-rename off` matters: otherwise tmux renames task windows to the running
  process and your task titles disappear.
