# rdev → herdr migration ledger

Living record of the tmux→herdr port. **Two parallel stacks, no runtime detection:**
- **Plain names** (`rdev`, `rstream`, …) = **herdr** stack (the port, incremental). Source `bin/_rdev_lib.sh`.
- **`rt*` names** (`rtdev`, `rtstream`, …) = **tmux** stack, **frozen** — your working setup, untouched by herdr work. Source `bin/_rdev_lib_tmux.sh`.

The whole tmux stack was snapshotted to `rt*` on 2026-07-06, so `rt*` never needs to change again. To keep using the old setup: use the `rt*` commands (e.g. `rtdev` then `rtstream <ticket>`). Both stacks share worktrees/state/config; only the multiplexer differs.

## Status

| Command | herdr (plain) | tmux frozen | Notes |
|---|:--:|:--:|---|
| `rdev` | ✅ ported | `rtdev` | plain: creates/focuses the `rhythms` **workspace** |
| `rstream` | ✅ ported | `rtstream` | plain: stream = **tab** (coordinator L70% + shell R30%), via `rdev-mux` |
| `rclean` | ✅ ported | `rtclean` | plain: closes the Herdr **tab** (by label, in `rhythms` ws) + removes worktree + branch prompt |
| `rpromote` | ✅ ported ⚠ untested | `rtpromote` | claim lease → `rdev_serve` repoints in-container `dev` at the worktree. NOT live-tested (restarts the app). |
| `runpromote` | ✅ ported ⚠ untested | `rtunpromote` | `rdev_serve` main → release lease. NOT live-tested. |
| `rlocal` | ✅ new | — | lease CLI for the single local server (Plan 5, part). Tests 12/12. |
| `rforward` | ✅ ported | `rtforward` | plain: **types the instruction into the LIVE coordinator + Enter** (`rdev_coord_msg`) — no exit/relaunch |
| `rbuild` | ✅ ported | `rtbuild` | plain: **types "plan approved, build" into the LIVE coordinator + Enter** (`rdev_coord_msg`); blocked shows in sidebar if it prompts |
| `rresume` | ✅ ported | `rtresume` | plain: find-or-create tab (guarded so resume doesn't re-split), launch coordinator |
| `rstatus` | ✅ ported | `rtstatus` | plain: lists Herdr tabs+status via `stream-list` |
| `rwatch` | — | — | untouched (tmux pane-scraper); herdr sidebar replaces its role, no rt copy |
| `rusage` | — | — | backend-agnostic (token accounting); no rt copy |
| `rdev-mux` | ✅ new | — | herdr substrate adapter (no tmux equivalent) |

## Supporting files
- `bin/_rdev_lib.sh` — herdr stack lib (session helpers call `rdev-mux`).
- `bin/_rdev_lib_tmux.sh` — frozen tmux lib (original `rdev_ensure_session`/`rdev_maybe_attach`).
- `bin/rdev-mux` — the adapter (herdr | echo backends). Tests: `tests/rdev-mux.test.sh` (18/18).

## Porting rule (for each remaining command)
The tmux `rt*` copy already exists and is frozen — so porting = **edit the plain command only** to drive herdr via `rdev-mux` (never touch `rt*`). Update this table's status when done.

## Next up
Only **`rpromote`/`runpromote`** remain — the lease + live-server work (**Plan 5**), the hardest/riskiest piece. Everything else ported: `rdev`, `rstream`, `rbuild`, `rforward`, `rresume`, `rstatus`, `rclean`.

**Plan 4 DONE** (`9d63a89`): worktree-in-container correctness — git-path alias + mise-trust + dep-share, wired into `rstream`. Kills silent wrong-code testing (verified live). Plan 3's dep-share folded in here (mlai shares `POETRY_CACHE_DIR`, not `.venv`).

Known minor edge: `rstream` re-run on an *existing* ticket tab would re-split a 3rd pane (no `TAB_CREATED` guard like `rresume` has). Low priority — new work uses fresh tickets, resume uses `rresume`. Add the guard when convenient.
