# Build-Our-Own WezTerm Agent Multiplexer — Feasibility

**Verdict: BUILD OUR OWN. Roughly a WEEKEND (2–3 focused days) to reach herdr-parity on the four things that matter, because WezTerm ships the hard 80% (mux server, persistence, workspaces, a scriptable `wezterm cli`) natively, and our existing `rwatch` state-scraper ports 1:1.**

Legend: **[V]** = verified from docs/code this session. **[A]** = assumed / needs a 10-min local spike.

---

## 1. WezTerm native multiplexing — persistence & headless

**[V]** WezTerm multiplexes via *multiplexing domains*. A **unix domain** is a connection to a mux server over a unix socket (`https://wezterm.org/multiplexing.html`). Minimal config:

```lua
config.unix_domains = { { name = 'unix' } }
config.default_gui_startup_args = { 'connect', 'unix' }
```

- **[V] Persistence across disconnect/reattach**: yes. The mux server holds windows/tabs/panes; the GUI is just a client. Docs state the connection "will automatically reconnect ... and resume your remote terminal session." This is the tmux-equivalent persistence.
- **[V] Headless / background**: yes — a dedicated **`wezterm-mux-server`** binary exists (separate crate in the repo), invoked with `--daemonize`. It runs with no GUI. `wezterm connect unix` spawns it on demand if not already running.
- **[V] macOS**: unix domains are "supported on all systems." The macOS-specific caveats in docs are only about *WSL* AF_UNIX interop (irrelevant here). **[A]** No known hard blocker on macOS beyond the usual: the mux server keeps agents alive, but on full logout/reboot it dies (same as tmux without extra tooling). Assume fine for a solo dev workflow.

## 2. `wezterm cli` surface (verified subcommand list)

**[V]** from `https://wezterm.org/cli/cli/`. Exact subcommands:
`activate-pane-direction, activate-pane, adjust-pane-size, get-pane-direction, get-text, kill-pane, list-clients, list, move-pane-to-new-tab, rename-workspace, send-text, set-tab-title, set-window-title, spawn, split-pane, zoom-pane`.

Targeting: `--pane-id N`, or `$WEZTERM_PANE` / `$WEZTERM_UNIX_SOCKET`, or `--prefer-mux`.

- **Spawn** — **[V]** `wezterm cli spawn [--cwd DIR] [--domain-name D] [--new-window] [--workspace W] [--window-id N] -- PROG...`. **Prints the new pane-id to stdout** (critical for scripting). `split-pane` similarly splits within a pane.
- **List** — **[V]** `wezterm cli list --format json` returns per-pane objects with fields: `window_id, tab_id, pane_id, workspace, size{rows,cols}, title, cwd`. This is our fleet inventory in one JSON call.
- **Send text** — **[V]** `wezterm cli send-text --pane-id N` (drive an agent, e.g. auto-answer a prompt).
- **Read pane contents** — **[V, THE key capability]** `wezterm cli get-text --pane-id N [--start-line --end-line] [--escapes]`. Captures the live screen (and scrollback via negative line numbers). This is the direct analogue of `tmux capture-pane -p` — so state-scraping is fully supported.

## 3. Workspaces → one-per-stream/worktree

**[V]** (`https://wezterm.org/recipes/workspaces.html`) Every MuxWindow has a `workspace` label; the GUI shows the active workspace and swaps contents on switch. Maps cleanly to **one named workspace per worktree/stream**:
- Spawn a stream: `wezterm cli spawn --new-window --workspace "stream-<name>" --cwd <worktree> -- claude`.
- Switch: `SwitchToWorkspace` key assignment or `ShowLauncher` picker; rename via `wezterm cli rename-workspace`.
- Pre-seed layouts via `gui-startup` / `mux-startup` Lua events.
The `workspace` field is already in `list --format json`, so grouping the fleet view by stream is free.

## 4. Agent-state detection — how hard?

**Two signal sources; use both.**

**(a) Scrape (proven, zero new deps).** **[V]** The existing `bin/rwatch` already does exactly this against tmux: it runs `tmux capture-pane -t ... -p -l 5` and string-matches `"Allow once"` (line 12) and `"[y/N]"` (line 19) to flag blocked panes. **Porting is a find-and-replace**: swap `tmux capture-pane -t $win -p` → `wezterm cli get-text --pane-id $id`, and drive the pane list from `wezterm cli list --format json` instead of `tmux list-windows`. Classify:
  - `blocked` — screen matches permission prompts (`Allow once`, `[y/N]`, `Do you want to proceed`, `❯ 1. Yes`).
  - `working` — presence of the Claude "esc to interrupt" / spinner / token-count line.
  - `idle`/`done` — prompt box present with no spinner (last output stable across two polls).

**(b) Claude Code hooks (cleaner, semantic — recommended primary).** **[V]** (`https://docs.claude.com/en/docs/claude-code/hooks`) Two events give ground-truth state without heuristics:
  - **`Notification`** with matcher **`permission_prompt`** → *blocked* (Claude needs approval). Matcher `idle_prompt` → *done/waiting*.
  - **`Stop`** → turn finished (*idle/done*).
  - `UserPromptSubmit` / first `PreToolUse` after Stop → *working*.
  Each hook is a shell command receiving JSON on stdin (incl. `session_id`, `cwd`). Handler writes state to a file keyed by cwd/worktree: `echo blocked > ~/.rdev/state/<worktree>`. **[A]** Mapping a hook's `cwd` → wezterm `pane_id` is done by joining on the `cwd` field from `list --format json` (worktree path is unique per stream).

Hooks are the clean signal; scraping is the fallback for TUI states hooks don't emit. herdr itself does the same combo ("process-name matching plus terminal-output heuristics," official integrations "report semantic state").

## 5. Lua config / status display

**[V]** WezTerm's Lua config supports event hooks (`update-status` / right-status, `gui-startup`, `mux-startup`, `format-tab-title`). A **right-status bar or per-tab title** can be driven from the state files written in §4: an `update-status` callback reads `~/.rdev/state/*` and renders `🔴 stream-a  🟡 stream-b  🟢 stream-c`. Per-tab color via `format-tab-title`. This is the "sidebar at a glance" equivalent, in-terminal, no external app.

## 6. Effort estimate to herdr-parity (the four things)

| Capability | Source | New work | Effort |
|---|---|---|---|
| Persistence + detach/reattach | WezTerm unix domain + `wezterm-mux-server --daemonize` | config only | ~1 hr **[V]** |
| Workspace-per-stream | `spawn --workspace`, `SwitchToWorkspace` | wrap in `rstream`/`rstatus` | ~half day **[V]** |
| Scriptable spawn/query | `wezterm cli spawn/list/send-text/get-text` | swap tmux calls in existing `bin/` scripts | ~half day **[V]** |
| State awareness | Claude hooks (`Notification`,`Stop`) + `get-text` fallback → state files → `update-status` | port `rwatch`, add hooks, Lua status | ~1 day **[V/A]** |

**Total: a weekend.** We already own the harder-to-replace half (the `r*` script suite: rstream/rclean/rpromote/rwatch). We are swapping the tmux backend for the `wezterm cli` backend and adding hook-driven state files.

---

## Concrete sketch of the home-grown layer

1. **Config (`~/.wezterm.lua`)**: define `unix_domains = {{name='unix'}}`; `update-status` reads `~/.rdev/state/<stream>` files and renders the fleet status bar; `format-tab-title` colors per state.
2. **Spawn (`rstream` rewrite)**: `id=$(wezterm cli spawn --new-window --workspace "$stream" --cwd "$worktree" -- claude); echo "$id" > ~/.rdev/panes/$stream`.
3. **Claude hooks** (project/user `settings.json`), each a 3-line script writing a state file:
   - `Notification` matcher `permission_prompt` → `blocked`; `idle_prompt` → `idle`.
   - `Stop` → `done`; `UserPromptSubmit` → `working`.
   - Key state on `$cwd` (the worktree), joined to `pane_id` via `wezterm cli list --format json`.
4. **Poll loop (ported `rwatch`)**: every 2s, `wezterm cli list --format json` → for each pane `wezterm cli get-text --pane-id $id | grep -E 'Allow once|\[y/N\]|esc to interrupt'` as a fallback classifier; reconcile with hook state files; optionally auto-notify (macOS `osascript`) on `blocked`.
5. **Query/UI**: `rstatus` = `wezterm cli list --format json` joined with state files → tabular fleet view; WezTerm's own `ShowLauncher` for workspace switching.

## Biggest capability gap vs herdr

**Zero-config, agent-agnostic state detection.** herdr rolls *any* of ~16 agents up to blocked/working/done/idle out of the box (its own heuristics + optional per-agent integrations). Our layer is **hand-tuned to Claude Code's specific prompt strings and hooks** — cheap and reliable for a Claude-only workflow, but every new agent type (Codex, etc.) means adding match patterns ourselves. Everything else herdr offers (persistence, workspaces, panes, socket/CLI orchestration) is matched by WezTerm-native `mux-server` + `wezterm cli` + a thin script layer we largely already have.
