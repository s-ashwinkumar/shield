# rdev redesign — user feedback & common problems

> Running brain-dump from Ashwin, captured during brainstorming (2026-07). Raw problems, not solutions. Organized by theme; ordering ≈ priority as given.

## 1. Local server is a single scarce resource (BIGGEST PROBLEM)

- Dev container setup is **heavy**. Conclusion reached: only **one local set of servers** can run at a time (via dev containers).
- Work must continue in parallel anyway. Today that's done with **git worktrees** — tricky, but generally works.
- Alternative is to **wait for Railway** to come up and test/do everything there — viable, but requires *repeatedly reminding* the agent to do so. Not codified.
- **If not working on local, running tests is hard** and not codified into the process:
  - Sometimes: realize worktree is inside the same repo → symlink `node_modules` etc. → run tests locally. Works.
  - Sometimes: fall into a slow loop of **copy-pasting files into dev containers**. Painful and slow.
- **Goal:** every stream / every piece of work should be able to run **all test types (unit, integration, e2e)** without a lot of overhead — regardless of whether it holds the local server.
- **Accepts the constraint:** only ONE local server is fine. Happy to rely on **Railway for UI testing** etc.
- **But:** for the "lighthouse of the week" (main focus item), still wants to **work locally, view it locally**.

### Idea already discussed: local as a lockable resource
- Treat local like a **lockable resource**: worktrees can claim the local servers and release them when needed.
- Maintain **state** of which worktree/branch currently controls the local servers.
- **promote / unpromote must be VERY seamless.**

### promote/unpromote is clunky today
- Claude session runs **inside the worktree directory**.
- On promote, the shell/session ends up back in root → must **restart Claude sessions**. Very clunky.
- Want this to be genuinely seamless (no session restarts, no lost context).

## 2. Browser testing friction

- A **new browser opens every single time** we browser-test. Shouldn't happen.
- All environments — local, Dev1, Railway — use the **same Google SSO auth**.
- Want to **auth once and reuse that browser profile forever** for any browser testing, for any piece of work. **Norm regardless of tool (Playwright or otherwise): log in once, never re-open a new window, never re-login.**

### Investigated (2026-07-05)
- e2e TESTS use CDP (`start-chrome-cdp` → "Chrome for Testing", `--user-data-dir=/tmp/chrome-playwright-<port>`) and auth via cookie injection (`authenticateContext`) — not the re-login pain.
- **Culprit = Playwright MCP:** currently runs with `--user-data-dir=…/ms-playwright-mcp/mcp-chrome-<random>` — a fresh EPHEMERAL profile each launch → new window + re-login every time.
- **Fix:** pin ONE persistent profile path (e.g. `~/.rdev/browser-profile`); point Playwright MCP (`--user-data-dir`, non-isolated) AND `start-chrome-cdp` at it. Log into Google SSO once; all sessions reuse it. Works across local/Dev1/Railway (same SSO).
- **Caveat:** persistent Chrome profile is single-instance (profile lock) → concurrent browser automation serializes on one profile, OR use a small pool of pre-authed profile clones. One shared profile is simplest for "log in once."

## Terminal decision: Alacritty (NOT WezTerm) + Herdr

- **Drop WezTerm.** Its main draw was built-in multiplexing, which Herdr makes redundant. With Herdr providing mux + agent-awareness, the emulator only needs to be fast and out of the way → **Alacritty** (speed-focused).
- Consequence: the "WezTerm-native mux" herdr fallback is off the table. Real fallback = the parallel **iTerm + tmux** stack (stays alive) + the substrate adapter (herdr→tmux swap). Herdr risk still bounded.
- **essentials repo holds:** Alacritty config + Herdr config (+ AGENTS.md, dotfiles). No WezTerm.

## 3. Tmux orchestration — move off custom scripts

- Maintaining all the **custom tmux scripts is not working out well**. Wants to move to a better system.
- Candidate: **Herdr** — https://github.com/ogulcancelik/herdr
- **TODO:** evaluate Herdr against the current custom tmux scripts (rstream/rbuild/rclean/etc.). User feels it may be a better option.

## 4. Worktree location & IDE (Cursor) indexing

- Today, `rstream` creates a worktree **inside the Rhythms code directory**. Good side: lets the dev container be used one way or another.
- But **moving in/out of the worktree ↔ main and back is not clean**. Needs addressing (related to the promote/unpromote clunkiness in #1).
- **Cursor indexing is broken** since worktree dirs live inside the Rhythms codebase:
  - Cursor is used to read code — has indexing plugins, go-to-definition, ctrl+click, etc.
  - Assumption: Cursor tries to **index every worktree** → never scales → kills indexing, everything is *really, really slow*.
  - Want indexing + go-to-def (ctrl+click into methods) to **just work**.
- Plans to **slowly move to Neovim** for faster search/ops, but **for now Cursor must work**.
- Design question raised: **where should the worktree live**, and how do you operate with it (esp. Cursor) given it can't be a sibling dir inside the indexed repo without breaking indexing?

---

## Decisions made during brainstorm

- **Herdr: adopt.** Replaces the multiplexer + agent-awareness layer (retires `rwatch`, tmux bootstrap). Keeps rdev domain logic (worktree/lease/promote/pipeline). See `herdr-evaluation.md`.
- **Greenfield parallel stack.** Build the NEW stack as **Alacritty + Herdr** (see terminal decision below), standing up alongside the CURRENT stack (**iTerm + tmux**) which stays fully alive. Fresh start, zero disruption to in-flight work. Old stack = fallback + exit path, which bounds all of Herdr's maturity risk. New stack proves itself on real streams before anything is retired.

## Execution model: CONTAINER-CENTRIC for Phase 1 (host-native = North Star, later)

Corrected after discovering the Cursor/devcontainer wiring:
- Cursor opens a **multi-root `.code-workspace` attached to the fullstack devcontainer** → **all LSP + plugins run INSIDE the container.** The container is the IDE environment, not just a test runner.
- Root folder = repo root with **no `.claude/worktrees/` exclude** → Cursor indexes every worktree → the slowdown. Existing machinery: `.cursor/setup-worktree.sh`, `.cursor/worktrees.json`, per-worktree `.cursor/projects/*`.
- Host-native worktrees do NOT get Cursor niceties for free — LSP would need re-hosting natively (TS works off node_modules; ruby-lsp/pyright need native gems/venv per worktree). Real cost.

**Decision: container-centric Phase 1** — keep worktrees inside the mount; fixes every pain without rebuilding the dev env:
- Cursor overload → `.cursorindexingignore` for `.claude/worktrees/` (index only active worktree); LSP untouched.
- Wrong-code testing → `docker exec` INTO THE WORKTREE PATH (not main); multiple worktrees can exec concurrently.
  - **Dep story (corrected — "zero install" was wrong):** fresh worktree has NO node_modules/bundle (gitignored, per-dir). `rstream` sets up none today (only plans/.claude/skills symlinks); rhythms' `setup-worktree.sh` does a FULL install per worktree (~1.6G+707M each = the pain). **Fix = share from mainline (works because all-Linux in-container):** Ruby → shared `BUNDLE_PATH` (one gem store; bundler adds only missing gems; multiple locks coexist); Node → symlink `node_modules→mainline` base + scoped `npm ci` in-worktree only when `package-lock.json` diverges; Python → shared base venv, per-worktree on divergence. Near-zero for unchanged-deps case; scoped incremental only when a branch changes deps. **rdev automates this on stream creation** (the gap `rstream` leaves today). This sharing is an A-only advantage (B can't share Linux deps to a darwin host worktree).
- Promote clunk → worktrees never move; "live" = whichever worktree's app holds ports 3000/4000/8000; lease governs only that; session stays put.
- Plans → symlink store (works inside).
- DB isolation (per-worktree test DB names): **DEFERRED — not a Phase-1 pillar** (user pushback). Only matters if two worktrees run DB-touching tests (railsapi rspec / mlai integration) at the SAME instant against the shared datastore. Unit tests are always parallel-safe. Today everything shares one DB and it hasn't blocked. Start with shared DB; add isolation (or a simple "one DB-test at a time" lock — far less work than per-worktree DBs) ONLY if concurrent conflicts actually bite.
- Tradeoff accepted: streams share one container's CPU/RAM for tests (contention when many run at once).

**Host-native (worktrees outside) = North Star**, revisited when the user moves to Neovim (native LSP lighter to stand up, no Cursor-in-container dependency). Not either/or; it's the later evolution. The native-test spike findings (`rhythms-test-execution.md`) stay valuable for that phase.

## Requirement: canonical cross-stream artifact store (plans, etc.)

- Today: worktree's `docs/plans/` is **symlinked to the mainline `docs/plans/`** so all plans pool centrally and survive worktree teardown — plans available regardless of where work happened. User wants to KEEP this.
- **Independent of inside/outside:** plain-text symlinks work host-side either way. Only *platform-specific binaries* (node_modules) broke across host/container; markdown plans don't. → moving worktrees outside does NOT cost centralized plans.
- **Design element:** rdev owns a **canonical artifact store** (plans + proposals + learnings + handovers), auto-symlinked into every stream at the conventional path on creation, NOT torn down with the worktree. Improves on the manual per-worktree symlink (rdev does it automatically, every stream).
- **FINAL DECISION:** since worktrees stay inside (container-centric), **leave this as-is** — plans live in the main gitignored `docs/plans/`, worktree symlinks to it. `rstream` ALREADY does this (`ln -sf "$RHYTHMS_DIR/docs/plans" "$WORK_DIR/docs/plans"`). No change; single main plans pool. (Earlier "external store" idea dropped.)

## Scope decision (phasing)

- **Phase 1 (now): substrate + fixes.** Recreate the current plan→build→review→PR pipeline on **WezTerm + Herdr(-or-alternative)**. Solve the feedback themes (worktree placement/Cursor, local-server lease, seamless promote/unpromote, one persistent browser profile). **Retire homegrown scripts** where the new substrate subsumes them.
  - **`rwatch` stays untouched** for now (explicit).
- **Phase 2 (later): captain/firstmate orchestrator.** The layer that attacks the >10-sessions context-switching pain. Deferred until Phase 1 proves out.

## Substrate decision: ADOPT HERDR, keep exit warm

- **Herdr is the daily driver.** Best-in-class terminal-native agent-awareness; serves the deeper goal of shedding homegrown plumbing. Research: `herdr-alternatives.md`, `build-our-own-feasibility.md`.
- Research corrections: herdr is **v0.7.1 / 66 releases / 12k⭐ / pushed today** (not stale) — real risk is **bus factor (~solo, 885/1000 commits one person)**, not abandonment. No *terminal-native + agent-aware + more-stable* alternative exists (competitors are closed/Electron GUIs).
- **Bounded exit:** WezTerm's native mux + `wezterm cli` (spawn/list --json/send-text/get-text) + Claude Code `Notification`/`Stop` hooks reach herdr-parity for a Claude-only fleet in ~a weekend. So the fallback is real and cheap.
- **Design principle:** rdev scripts talk to a **thin substrate adapter**, NOT herdr directly — so herdr↔WezTerm-native is a swap, not a rewrite.

## Test-execution model (investigated) — big unlock for theme #1

- **Verdict (a):** unit + integration run **natively per-worktree** via `mise`; only **e2e/live-UI** needs the running stack. Details: `rhythms-test-execution.md`.
- Native commands: webui `npm run test:unit` (no services); railsapi `bundle exec rspec` (needs PG:4001 + ES:4200); mlai `pytest tests/ --ignore=integration --ignore=evals -n auto` (unit, no svcs) / `pytest tests/integration` (PG:8002, Redis:8379, ES:8200, Temporal).
- **Catch:** host ports are fixed/shared → concurrent worktrees contend on **data**, not the container. Fix = per-worktree DB names or remapped ports + overridden env. (Data isolation, solvable.)
- **Architectural consequence:** most testing decouples from the single local server. **Lease only gates e2e + lighthouse-of-the-week live UI.** Theme #1 shrinks dramatically.

## 5. Personal "essentials" repo + root AGENTS.md  (new requirement)

- Want a **root `AGENTS.md`** with *minimal* instructions on how the user wants to work (cross-harness: Claude Code / Codex / Cursor).
- Want the **most fundamental, machine-level (not rhythms-specific) config in a dedicated "essentials" repo, pushed up** (committed to a remote).
- Essentials repo should include: **WezTerm config, Herdr config**, the root AGENTS.md, and similar personal "how I work" fundamentals — the environment layer that is about *the user*, not about any product repo.
- Emerging repo topology to design around:
  - **essentials** (NEW, personal env: AGENTS.md + wezterm/herdr/tooling configs, pushed up)
  - **rdev** (the workflow harness: scripts/skills/agents — currently uncommitted)
  - **rhythms** (the product)
- **DECIDED: separate repos.** essentials = environment (AGENTS.md + wezterm/herdr/tooling configs, shareable), rdev = workflow harness. rdev may reference essentials but stays its own repo.
- **essentials = universal, cross-platform, env-agnostic.** Everything the user wants on ANY machine, any environment, rhythms-work-or-not. The bright line: anything rhythms-specific (docker/lease/promote/Linear/dev-container) lives in **rdev**, NEVER essentials. essentials is the portable personal setup (wezterm/herdr configs, AGENTS.md, shell/dotfiles, cross-platform tooling).

## (superseded) Open: substrate choice is NOT settled

- User is **not 100% committed to adopting the herdr author's repo/approach.**
- Wants **deep research** on: (a) more *stable* alternatives to herdr (broader governance, not solo-maintainer), and (b) whether we could **build our own** (esp. leaning on WezTerm's native multiplexing).
- Evaluation criteria (derived from feedback): agent-awareness (blocked/working/done), persistence + detach/reattach, scriptable API (for future Phase-2 orchestrator), terminal-native (no Electron/GUI-only), macOS-first, git-worktree-friendly, healthy maintenance/governance, bounded exit cost.

---
<!-- more feedback to come; user will say "that's it" when done -->
