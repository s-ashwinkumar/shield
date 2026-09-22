# Herdr customizability — complete reference (v0.7.1)

Config file: `~/.config/herdr/config.toml`. Seed a full copy with `herdr --default-config > ~/.config/herdr/config.toml`. Reload a running server with `herdr server reload-config` (or `prefix+shift+r`, or global menu → reload config). Invalid values fall back to a safe default + a startup warning. `HERDR_CONFIG_PATH` overrides the path.

> ⭐ = directly relevant to the rdev design (flagged inline).

## `[theme]`
- `name` — built-in theme. Options: `catppuccin`, `catppuccin-latte`, `terminal`, `tokyo-night`, `tokyo-night-day`, `dracula`, `nord`, `gruvbox`, `gruvbox-light`, `one-dark`, `one-light`, `solarized`, `solarized-light`, `kanagawa`, `kanagawa-lotus`, `rose-pine`, `rose-pine-dawn`, `vesper`. `terminal` = follow the host terminal's ANSI palette.
- `auto_switch` (default false) + `light_name` / `dark_name` — switch UI theme when the host terminal reports light/dark change.
- `[theme.custom]` — override individual tokens on top of the base theme. Documented tokens: `panel_bg`, `accent`, and named ANSI colors (`red`, `green`, `blue`, `yellow`, …). Values: hex `#rrggbb`, named colors, `rgb(r,g,b)`, or reset aliases (`reset`, `default`, `none`, `transparent`). *(Note: a single "foreground/text" token isn't documented; to force white text, easiest is a white-on-dark built-in like `vesper`, or `terminal` to follow Alacritty.)*

## `[terminal]`
- `default_shell` — executable for new interactive panes (unset → `$SHELL` → `/bin/sh`).
- ⭐ `shell_mode` — `"auto"` (login shells on macOS so PATH/Homebrew/mise init runs — **we want this**), `"login"`, `"non_login"`.
- `new_cwd` — cwd policy for new panes/tabs/workspaces: `"follow"` (inherit source), `"home"`, `"current"`, or a fixed path. Explicit `--cwd` always wins.

## `[keys]` (keybindings)
- Prefix model like tmux; default `prefix = "ctrl+b"`. `prefix+n` = prefix then n; `ctrl+alt+n` = direct chord. Every binding configurable, including the prefix.
- A binding value can be a **list** for multiple chords: `focus_pane_left = ["prefix+h", "ctrl+alt+h"]`.
- Defaults incl.: `detach=prefix+q`, `workspace_picker=prefix+w`, `goto=prefix+g`, `new_workspace=prefix+shift+n`, ⭐`new_worktree=prefix+shift+g`, `new_tab=prefix+c`, `next/previous_tab=prefix+n/p`, `switch_tab=prefix+1..9`, `split_vertical=prefix+v`, `split_horizontal=prefix+minus`, `close_pane=prefix+x`, `zoom=prefix+z`, `resize_mode=prefix+r`, `toggle_sidebar=prefix+b`, `copy_mode=prefix+[`, focus panes `prefix+h/j/k/l`, swap `prefix+shift+h/j/k/l`, `reload_config=prefix+shift+r`, `settings=prefix+s`, `help=prefix+?`, `open_notification_target` (unset).
- Optional-unset actions: ⭐`open_worktree`, ⭐`remove_worktree`, `previous/next_workspace`, `previous/next_agent`, `focus_agent` (indexed, e.g. `prefix+alt+1..9`), `switch_workspace`, `last_pane`.
- **Prefix-free**: bind direct chords; `ctrl+alt+…` is the safest family across terminals/OSes (Herdr benchmarked Alacritty/iTerm/Ghostty/etc.).
- `[[keys.command]]` — custom command bindings: `key`, `type` (`pane` = temp pane, `shell` = detached, `plugin_action`), `command`, optional `description`. Custom commands receive `HERDR_SOCKET_PATH`, `HERDR_BIN_PATH`, `HERDR_ACTIVE_WORKSPACE_ID`, `HERDR_ACTIVE_TAB_ID`, `HERDR_ACTIVE_PANE_ID`, `HERDR_ACTIVE_PANE_CWD`. ⭐ (hook point for rdev actions bound to keys)
- `[keys.indexed]` — legacy indexed shortcuts (`tabs`, `workspaces`, `agents`).
- `config reset-keys` backs up config and removes custom keybindings.

## `[worktrees]`  ⭐⭐ (central to the container-centric model)
- `directory` — root for sidebar-created git worktrees. Checkouts land at `<directory>/<repo>/<branch-slug>`. Default `~/.herdr/worktrees`.
  - **For rdev container-centric:** point this INSIDE the mount, e.g. `~/code/rhythms/.claude/worktrees`, so herdr-created worktrees are visible to the dev container. (Or use `herdr worktree create --path …` per-call.)
- Sidebar actions: `New worktree` (creates/opens branch as a grouped child workspace), `Open worktree…`, `Delete worktree checkout…` (runs `git worktree remove`, safe-then-forced, never deletes branches). Closing the parent workspace closes the group but does NOT delete checkouts/branches.

## `[ui]` (sidebar & layout)
- `sidebar_width` (auto-scaled default ~26/32), `sidebar_min_width` (18), `sidebar_max_width` (36), `mobile_width_threshold` (64).
- `mouse_capture` (true), `right_click_passthrough_modifier` (""), `redraw_on_focus_gained` (true), `mouse_scroll_lines` (3).
- `confirm_close` (true), `prompt_new_tab_name` (true), `pane_borders` (true), `pane_gaps` (true), `show_agent_labels_on_pane_borders` (false).
- ⭐ `agent_panel_sort` — `"spaces"` (grouped) or `"priority"` (attention queue: blocked → done → working → idle). **We want `"priority"` for fleet triage.**
- `accent` — highlight/border/nav color (hex / named / rgb).

## `[ui.toast]` (notifications)  ⭐ (fleet "who needs me")
- `delivery` — `"off"` (default), `"herdr"` (in-app toast; clickable / `open_notification_target`), `"terminal"` (desktop notification via escape seq — supports iTerm2, Ghostty, Kitty, **WezTerm**; useful over SSH), `"system"` (macOS `terminal-notifier`→`osascript`; Linux `notify-send`).
- `delay_seconds` (0–3600, default 1) — waits before finished/needs-input notifications; only fires if still in that state. `0` = instant.
- `[ui.toast.herdr] position` — `top/bottom` × `left/right`.
- `[ui.toast.clipboard]` — `enabled` (true), `position` (adds `*-center`). Confirms foreground copy; never sent via terminal/system.
- **rdev note:** `delivery = "terminal"` or `"system"` gives desktop pings when any of your 10 agents needs input — directly attacks the context-switching pain. (Alacritty isn't in the escape-seq list for `terminal`; use `system` on macOS.)

## `[ui.sound]`  ⭐
- `enabled` (true). macOS uses `afplay`. Custom mp3s: `path` (all), `done_path`, `request_path` (relative to config dir).
- `[ui.sound.agents]` — per-agent `default|on|off` by label (`claude`, `codex`, `devin`, `droid`…); droid muted by default. Env `HERDR_DISABLE_SOUND` also disables.

## `[session]`  ⭐
- `resume_agents_on_restore` (true) — restart supported agent panes into native conversation sessions after a server restart (Claude Code, Codex, Cursor, Copilot, Droid, Kimi, Qoder, Pi, Hermes, OpenCode, Kilo). Requires the official integration.

## `[update]`
- `channel` (`stable` | `preview`), `version_check` (true), `manifest_check` (true — remote agent-detection manifests). Homebrew/mise/Nix installs ignore preview and update via their package manager.

## `[remote]`
- `manage_ssh_config` (true) — herdr wraps bridge ssh with your `~/.ssh/config` + keepalive fallback for `herdr --remote`.

## `[experimental]`
- `allow_nested` (false) — launch herdr inside a herdr pane.
- `kitty_graphics` (false) — local Kitty graphics for attached clients.
- `pane_history` (false) — save recent pane screen contents across full server restarts (⚠ may contain secrets; stored in `session-history.json`).
- CJK/IME: `switch_ascii_input_source_in_prefix`, `reveal_hidden_cursor_for_cjk_ime` (+ `cjk_ime_agents`, `cjk_ime_cursor_shape`).

## `[advanced]`
- `scrollback_limit_bytes` (default 10_000_000) — per-pane scrollback cap.

## Onboarding & env
- `onboarding = false` skips first-run setup. Env: `HERDR_CONFIG_PATH`, `HERDR_SESSION`, `HERDR_SOCKET_PATH`, `HERDR_LOG` (e.g. `herdr=debug`), `HERDR_DISABLE_SOUND`.

## Session-state model (not config, but shapes expectations)
| Case | Processes live | Layout | Recent screen | Agent convo resumes |
|---|---|---|---|---|
| Detach/reattach | ✅ | ✅ | ✅ (live) | ✅ (never stopped) |
| Server restart | ❌ | ✅ | only w/ `pane_history` | only w/ native session restore |
| Update w/o `--handoff` | maybe | ✅ | only w/ `pane_history` | only w/ native restore |
| Update w/ `--handoff` | best-effort | ✅ | ✅ | ✅ |

## Recommended rdev-relevant settings (for the essentials herdr config)
```toml
onboarding = false
[terminal]
shell_mode = "auto"          # PATH/mise/Homebrew init in panes
[ui]
agent_panel_sort = "priority" # blocked → done → working → idle triage
[ui.toast]
delivery = "system"          # desktop pings when an agent needs input (macOS)
[ui.sound]
enabled = true
[ui.sound.agents]
claude = "on"
[session]
resume_agents_on_restore = true
[worktrees]
directory = "~/code/rhythms/.claude/worktrees"  # inside the dev-container mount (container-centric)
```
