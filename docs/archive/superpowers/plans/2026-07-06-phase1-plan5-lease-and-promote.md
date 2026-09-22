# Phase 1 · Plan 5 — Local-server lease + promote/unpromote

**Status:** `rlocal` lease DONE. `rpromote`/`runpromote` herdr port **DEFERRED** — needs a hands-on session (live-server topology is uncertain + switching it is disruptive). This note records what's built, what was found, and the promote design to finish later.

## DONE — `rlocal` (committed)
One big lease over the whole local stack. `bin/rlocal`, tests `tests/rlocal.test.sh` (12/12), symlinked to `~/.local/bin`.
- `rlocal status [--json]` · `holder` · `claim <name> [--worktree P] [--ttl SEC]` · `release [<name>] [--force]` · `wait <name> [--timeout SEC]`
- Lease file: `$RHYTHMS_DIR/.rdev/local-lease.json` = `{holder, worktree, claimed_at, pid, user}`.
- **Policy (per spec):** stay-claimed until explicit release; `--ttl` opt-in for auto-stale. No dead-pid heuristic (recorded pid is the ephemeral CLI's, not the holder's).
- Per-worktree **tests don't need the lease** (Plan 4 made in-container worktree testing work); the lease only gates the live app server (e2e / lighthouse).

## Live-server topology findings (2026-07-06, read-only)
- `dev.Procfile` runs each service via `mise x -C $WORKSPACE_ROOT/<svc> -- ./bin/dev` under hivemind/overmind, from the **main checkout** (`$WORKSPACE_ROOT`).
- Ports 3000/4000/8000 on the host are held by **Cursor's port-forwarding** (anysphere extension), NOT the app directly.
- `docker exec fullstack-fullstack-1 ps` showed **no next/rails** at inspection time — so either the app wasn't running, runs under different process names, or runs elsewhere. **Unclear whether the live app runs in the fullstack container, on the host, or via `.devcontainer/unified/start-local.sh`.**
- The fullstack compose uses `network_mode: host` (base compose) with app `ports:` commented out.

**⇒ This must be clarified hands-on before automating promote.** Key questions for the user:
1. When you run the live app for a lighthouse ticket, what starts it — `rdev`/services tab (`rdu`+`rde ... dev`), `start-local.sh`, or native? In the container or host?
2. Are 3000/4000/8000 bound by the container (host-network) or forwarded by Cursor?

## Promote/unpromote design (to implement after clarification)
Container-centric model: worktrees never move; the ONE live app is pointed at whichever worktree holds the lease.
- **`rpromote <name>`** = `rlocal claim <name>` → (re)start the app servers pointed at the worktree's service dirs instead of main. Mechanically: run the Procfile with `$WORKSPACE_ROOT` = the worktree path (`.../.claude/worktrees/<name>`), i.e. `hivemind` from the worktree, after stopping the current app. Deps already shared (Plan 4), git works in-container (Plan 4 alias).
- **`runpromote <name>` / release** = stop the worktree's app, `rlocal release`, optionally restart main.
- Non-holder behavior: `rlocal wait`/`queue`; skills check `rlocal status` before doing live-UI/e2e.
- **Risk that mandates hands-on:** stopping/restarting the live app can leave services down; must be done where the user can watch. Do NOT automate blind.

## Until then
- Plain `rpromote`/`runpromote` remain the **tmux** versions (work in the tmux stack). `rtpromote`/`rtunpromote` are the frozen copies.
- For the herdr stack: use `rlocal` to coordinate; start/stop the live app manually for now.
