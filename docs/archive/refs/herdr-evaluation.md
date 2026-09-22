# Herdr vs. rdev custom tmux scripts — evaluation

> Evaluated 2026-07 during redesign brainstorm. Source: https://github.com/ogulcancelik/herdr (12k⭐, #1 GH trending Jun 30 2026). herdr.dev.

## What Herdr is

"tmux, rebuilt for agents." A single ~10MB Rust binary (macOS/Linux, Windows beta), no dependencies, runs inside your existing terminal. Not an Electron/GUI app.

**Core capabilities:**
- **Agent state at a glance** — sidebar rolls every pane up to 🔴 blocked / 🟡 working / 🔵 done / 🟢 idle. Zero config, no hooks. Detection via process-name + terminal-output heuristics; Claude Code fully supported (idle/working/blocked all ✓).
- **Real terminal per agent** — each agent gets a true PTY, full-screen TUIs render correctly (not a wrapper's imitation).
- **Persistent background server** — detach/reattach from any terminal, including phone over SSH. Nothing dies on disconnect.
- **Workspaces / tabs / panes** — organize by repo or folder, mouse-native + `ctrl+b` prefix keybindings (tmux-like).
- **Socket API + CLI** — a local socket protocol that *agents themselves can drive* to spawn/label/query panes. Plugins in any language.
- **Native integrations** — `herdr integration install claude` adds session restore + semantic state reporting for Claude Code (also codex, cursor, copilot, opencode, etc.).
- **Remote** — `herdr --remote host` makes local terminal a client of a remote server; preserves image paste (which ssh+tmux breaks).

## What rdev's scripts actually do (the layers)

| Script | Responsibility | Layer |
|---|---|---|
| `rdev` | bootstrap/attach tmux session + services window | **multiplexer** |
| `rwatch` | poll panes for stuck permission prompts ("Allow once", "[y/N]"…) | **agent-awareness** |
| `rstatus` | list workstreams + pipeline stage | awareness + **domain** |
| `rstream` | create worktree, launch coordinator agent, lay out panes | multiplexer + **domain** |
| `rbuild` / `rforward` / `rresume` | drive pipeline stages (plan→build→review→PR) | **domain** |
| `rpromote` / `runpromote` | move main repo ↔ worktree branch, local-server handoff | **domain** |
| `rclean` | teardown worktree + tmux window | multiplexer + **domain** |
| `rusage` | token/cost accounting from session JSONLs | **domain** |

## Verdict: adopt Herdr for the multiplexer + awareness layer; keep rdev's domain logic

Herdr is **not a full replacement** — it replaces the *plumbing*, not the *pipeline*. The split is clean:

### Herdr eats (delete/retire these concerns)
- **`rwatch` → gone.** The single biggest win. Herdr's blocked/working/done sidebar is exactly "which of my 10 sessions needs me right now," native and zero-config. Your `rwatch` is a fragile string-matcher for the same thing.
- **`rdev` session bootstrap + tmux pane plumbing** inside `rstream`/`rclean` → replaced by herdr workspaces/tabs and its CLI.
- **Session persistence / phone access** → native (your `tmux.conf` + custom wiring retire).
- **`rstatus`'s agent-state half** → the sidebar. (The *pipeline-stage* half stays — herdr doesn't know your stages.)

### Herdr does NOT eat (rdev keeps these)
- **Worktree lifecycle** (create/destroy) — herdr organizes *workspaces* but has no opinion on git worktrees.
- **Local-server lease + promote/unpromote** — pure rdev domain logic (feedback theme #1).
- **Pipeline state machine** (plan→build→review→PR, Linear integration) — rdev domain logic.
- **Token/cost accounting** (`rusage`) — unrelated.

### The strategic unlock: the socket API
Herdr's **socket API/CLI that agents can drive** is the foundation for the captain/firstmate layer from the L8 video. Instead of a firstmate shelling out raw `tmux` commands, it drives herdr: spawn a labelled pane per stream, read fleet state, route your attention. rdev's scripts get **rewritten to call `herdr` instead of `tmux`**, and the orchestrator becomes buildable on top.

## Migration shape (for the design phase, not committing yet)
1. Install herdr + `herdr integration install claude`. Verify Claude Code state detection.
2. Retire `rwatch`; retire the tmux bootstrap in `rdev`.
3. Re-target `rstream`/`rclean` pane creation from `tmux …` to `herdr` CLI.
4. Keep `rpromote`/`runpromote`/lease logic as-is initially (herdr-agnostic).
5. Later: expose rdev pipeline as a herdr plugin / socket client → path to a firstmate-style captain layer.

## Risks / open questions
- **Maturity**: v0.4.0, very new (fast-moving). Socket API surface may churn.
- **cwd-on-worktree-removal**: herdr keeps the pane alive, but a pane whose cwd was a deleted worktree still has a dead cwd — does NOT by itself solve the promote/unpromote "session gets orphaned" pain. That needs rdev-side design regardless.
- **Cursor coexistence**: herdr is terminal-only; the Cursor-indexing problem (theme #4) is orthogonal and unsolved by herdr.
- Learning-curve: `ctrl+b` prefix differs from muscle memory if remapped in current tmux.

## Bottom line
Yes — Herdr is a better foundation than the hand-rolled tmux layer, *specifically* because its agent-state sidebar and socket API attack your two hardest problems (fleet triage at 10+ sessions, and a scriptable substrate for an orchestrator). Adopt it as the substrate; keep rdev's domain scripts and re-point them at herdr.
