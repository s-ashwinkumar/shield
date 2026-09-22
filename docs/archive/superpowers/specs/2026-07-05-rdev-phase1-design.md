# rdev Phase 1 — Redesign Design Spec

**Date:** 2026-07-05
**Status:** Draft for review
**Supersedes/extends:** `docs/handover-2026-06-21.md`, `docs/plans/pipeline-redesign.md`
**Working notes:** `docs/refs/redesign-feedback.md` (raw feedback + decision log), `docs/refs/*-research.md` (herdr, alternatives, build-our-own, test-execution, no-mistakes, lavish, axi), `docs/refs/transcript-lessons.md`

---

## 1. Problem & motivation

The current rdev stack (tmux + git worktrees + shell scripts orchestrating Claude Code sessions) works but breaks down as the user routinely runs **10+ parallel streams**. The dominant pain is **cognitive: context-switching across many sessions**, plus a set of concrete daily frictions:

1. **Single local server / dev container** is heavy; only one full stack runs at a time. Per-worktree testing is ad-hoc (symlink-node_modules-or-copy-paste roulette). Tests are frequently run via `docker exec` against **main's** code, not the worktree → **silent wrong-code testing**.
2. **promote/unpromote is clunky** — the Claude session lives in the worktree; promoting drops the shell back to root and forces session restarts.
3. **Cursor indexing dies** because worktrees live inside the rhythms repo and Cursor tries to index all of them.
4. **Browser testing re-authenticates every time** — a fresh ephemeral profile per launch.
5. **Custom tmux plumbing** is fragile and unpleasant to maintain.
6. **No fleet triage** — nothing surfaces which of the N sessions is blocked/working/done.

## 2. Goals (Phase 1)

- Stand up a **fresh, parallel stack** (Alacritty + Herdr) alongside the live iTerm+tmux stack, with **zero disruption** to in-flight work; old stack stays as fallback.
- Make **every stream able to run unit + integration tests with low overhead**, testing the **right** code.
- Make **promote/unpromote seamless** (no session migration, no restarts).
- Restore **Cursor niceties** (indexing, go-to-def) without choking.
- **One persistent browser profile** — authenticate once, reuse forever.
- Provide **fleet triage** (blocked/working/done at a glance).
- Upgrade the review→PR pipeline with an **autonomous-QA evidence contract**.

## 3. Non-goals / deferred

- **Captain/firstmate orchestrator** → Phase 2.
- **gnhf-style capped autonomous loops** → Phase 2 or later.
- **Host-native execution** (worktrees outside the container, native LSP) → North Star for the Neovim era; not Phase 1.
- **TOON/AXI output format adoption** → not adopted (weak evidence, readability cost). Only *AXI ergonomics as a design rule* is taken.
- **Per-worktree test-DB isolation** → deferred until concurrent conflicts actually bite.
- `rwatch`, `rusage`, and the plan→build→review→PR pipeline stages / coordinator-builder-reviewer agents → carried over as-is (Phase 1 changes the substrate, not the pipeline shape).

## 4. Repo topology

Three repos, three concerns:

| Repo | Concern | Contents | Status |
|---|---|---|---|
| **essentials** (new, pushed up) | universal, cross-platform personal env | Alacritty config, Herdr config, root `AGENTS.md`, shell/dotfiles | to create |
| **rdev** | the workflow harness | substrate adapter, stream lifecycle, lease, dep-sharing, test runner, pipeline | exists (uncommitted) |
| **rhythms** | the product | app code | exists |

Bright line: anything rhythms-specific (docker/lease/promote/Linear/dev-container) lives in **rdev**, never essentials. essentials is portable and shareable; it may be referenced by rdev but stays independent.

## 5. Substrate: Alacritty + Herdr behind an adapter

- **Terminal emulator: Alacritty** (speed-focused). WezTerm dropped — its value was built-in multiplexing, which Herdr makes redundant.
- **Multiplexer + fleet awareness: Herdr** — provides persistent sessions, detach/reattach (incl. phone/ssh), workspaces/tabs/panes, and the **blocked/working/done/idle sidebar** that solves fleet triage. Install the Claude integration for native state reporting.
- **Substrate adapter (`rdev-mux`):** rdev scripts NEVER call herdr directly. They call a thin adapter with a small verb set (`spawn-pane`, `list-panes`, `send-text`, `label-pane`, `kill-pane`). Adapter targets herdr today; swapping to tmux/WezTerm-native later is an adapter change, not a rewrite. This bounds Herdr's solo-maintainer risk; the parallel iTerm+tmux stack is the ultimate fallback.
- **AXI ergonomics rule:** the adapter, the `rlocal` lease CLI, and all docker-exec wrappers emit **terse, single-turn, token-lean** output (no verbose JSON dumps into agent context). Design rule only — no TOON.

## 6. Execution model: container-centric (locked)

Rationale (see `redesign-feedback.md`): Cursor's LSP + the deps run **inside** the dev container; going host-native would mean rebuilding the polyglot dev environment on the host. Container-centric fixes every pain with far less to build.

- **Worktrees live inside the mount** (`~/code/rhythms/.claude/worktrees/<stream>`), visible to the container at `/workspaces/rhythms/.claude/worktrees/<stream>`.
- **Tests/lint run via `docker exec` into the worktree path** (not main) — this fixes silent wrong-code testing.
- **Cursor:** LSP stays in-container (unchanged). Fix the indexing overload with **`.cursorindexingignore`** (and/or workspace `files.exclude`) excluding `.claude/worktrees/` so only the active worktree is indexed. Leverage the existing `.cursor/setup-worktree.sh` / `worktrees.json` machinery.

## 7. Dependency sharing (new — `rstream` does none today)

A fresh worktree has no `node_modules`/`bundle` (gitignored, per-dir). rhythms' `setup-worktree.sh` does a full install per worktree (~1.6G + 707M each). Instead, **share mainline's deps** (safe because all-Linux in-container):

- **Ruby:** shared `BUNDLE_PATH` (one gem store; override the `.dev.env` per-worktree default). Bundler installs only missing gems; multiple `Gemfile.lock`s coexist.
- **Node:** symlink `node_modules → mainline` as the base; auto-detect when a worktree's `package-lock.json` diverges from mainline and run a scoped `npm ci` in that worktree only (replacing the symlink for just that stream).
- **Python (mlai):** shared base venv; per-worktree only on divergence.
- **rdev automates this on stream creation.** Near-zero for the common (unchanged-deps) case; scoped incremental install only when a branch changes its deps.

## 8. Testing & datastores

- **Shared datastore singleton:** all datastore containers (railsapi-postgres:4001, railsapi-es:4200, mlai-postgres:8002, mlai-es:8200, mlai-redis:8379, temporal, neo4j) run **once**, no app containers. ~4–5GB, fixed cost (machine already spec'd for 24GB per `LOCAL-DOCKER.md`).
- **Tests run via `docker exec` into the worktree path** (using the container's runtimes + shared deps), against the shared datastores — **without the app servers running** and **without sops secrets** (verified in `rhythms-test-execution.md`: CI runs these with no decryption; Rails test-env self-generates encryption keys). Note: the sibling *host-native* execution path was proven viable but is explicitly the Neovim-era North Star (§3), not Phase 1.
- **DB isolation: DEFERRED.** Only matters if two worktrees run DB-touching tests at the same instant. Start with the shared DB; if conflicts bite, add a simple "one DB-test at a time" lock before considering per-worktree DBs.

## 9. Live server + lease (`rlocal`)

- The **one live app server** = the dev container running the active worktree's app on ports 3000/4000/8000, for **e2e / lighthouse-of-the-week live UI only**. All other UI review → **Railway** preview envs.
- **Worktrees never move.** "Live" = whichever worktree currently holds the server. **Promote = claim lease + bring the app up on that worktree; unpromote = release.** No `cd`-to-root, no session restart. This dissolves the promote/unpromote clunk; `rpromote`/`runpromote` in their current branch-moving form are retired.
- **Lease design:** **one big lease** for the whole stack. **Stay-claimed until explicitly released**, with an opt-in `--ttl`. CLI: `rlocal status|claim|release|wait|queue`. Non-holders: `wait` (block) or `queue` (FIFO notify); note that **native/containerized tests still work without the lease** (lease only gates the live server ports).

## 10. Review → PR pipeline upgrades (no-mistakes borrowings — Phase 1)

Borrow into rdev's existing review/qa pipeline (do **not** swap wholesale; skip his bare-repo/daemon transport — rdev orchestrates and rpromote is gone). Details: `no-mistakes-research.md`.

1. **Autonomous-QA evidence contract** (the fix for "QA has always been manual"): the pipeline infers **intent from the agent session**, runs the baseline test command, and **requires the agent to capture reviewer-visible evidence** — screenshots / video / logs / rendered HTML — into an evidence dir attached to the PR. QA becomes self-driving via an intent + evidence prompt-contract, not a pinned browser dependency.
2. **Review-before-test ordering:** adversarial review (fresh context) runs *before* functional QA, so the reviewer reads fresh code, not code it may have just modified; QA then validates the possibly-fixed behavior.
3. **`risk_level` + human-gate-on-review:** review emits a structured risk level; obvious issues self-correct, ambiguous/product-implication ones escalate to the user. Auto-fix limit stays conservative (human gate).
4. **PR body carries** inferred intent, what changed, how tested, and the evidence links — so the user applies judgment on **proof**, not raw diffs.

## 11. Canonical plans store (unchanged)

Plans stay in the main **gitignored `docs/plans/`**, symlinked into each worktree — which `rstream` already does (`ln -sf "$RHYTHMS_DIR/docs/plans" "$WORK_DIR/docs/plans"`). One pool, survives teardown. No change.

## 12. Browser: one persistent profile

- Root cause of re-login pain: **Playwright MCP** launches with an ephemeral `--user-data-dir=…/mcp-chrome-<random>` each time.
- **Fix:** pin **one persistent profile path** (e.g. `~/.rdev/browser-profile`). Point Playwright MCP (`--user-data-dir=<fixed>`, non-isolated) and `start-chrome-cdp`'s user-data-dir at it. Log into Google SSO **once**; every subsequent agent/manual session reuses it. Works across local/Dev1/Railway (same SSO). Norm for **all** browser work: log in once, no new windows, no re-login.
- **Caveat:** a persistent Chrome profile is single-instance (profile lock). Start with one shared profile (browser automation serializes); if contention bites, move to a small pool of pre-authed profile clones.

## 13. Independent parallel workstreams (not part of the substrate build)

These are decoupled and can proceed anytime, in their own branches/sessions:

- **MCP→CLI audit** — `docs/prompts/mcp-to-cli-audit.md` (own PR). Grounded in the one well-supported AXI finding (CLI-beats-MCP). Not TOON.
- **AGENTS.md slimming + skills evaluation** — `docs/prompts/agents-md-and-skills-audit.md` (own PR).
- **lavish** — adopt as-is for interactive HTML planning: `npx skills add kunchenguid/lavish-axi --skill lavish`. Standalone; solves the plan→review→surgical-edit loop.

## 14. Open items to spike during planning

1. **Node dep-divergence detection** — exact mechanism to detect `package-lock.json` drift vs mainline and trigger scoped `npm ci` (and the equivalent for a shared `BUNDLE_PATH` + poetry base venv).
2. **Browser profile wiring** — exact Playwright MCP config change (`--user-data-dir`, isolation flag) and `start-chrome-cdp` edit; confirm profile-lock behavior with concurrent streams.
3. **Herdr adapter surface** — confirm herdr's CLI/socket verbs map cleanly to `rdev-mux` (spawn/list/send/label/kill) and Claude state detection is reliable on real sessions.
4. **Evidence-contract format** — where evidence lives, how it attaches to the PR, what the intent-inference reads (session JSONL?).
5. (If ever un-deferred) per-worktree test-DB naming scheme + `parallel:setup`/`conftest` pickup.

## 15. Rollout order (indicative — full plan comes next)

1. essentials repo: Alacritty + Herdr configs + root AGENTS.md; get Herdr running with Claude state detection.
2. `rdev-mux` adapter over Herdr; port stream create/teardown off raw tmux.
3. Dependency-sharing on stream creation (Ruby shared BUNDLE_PATH → Node symlink+divergence → Python).
4. `docker exec`-into-worktree test/lint runner; `.cursorindexingignore`.
5. `rlocal` lease + rework promote/unpromote to lease claim/release (retire branch-moving rpromote).
6. Browser persistent profile.
7. Pipeline upgrades: evidence contract, review-before-test, risk_level.
8. Pilot on 2–3 real streams in parallel with the old stack before retiring anything.

## 16. Success criteria

- A new stream: created in Herdr, deps ready in seconds (shared), runs unit+integration against the right code with one command, shows blocked/working/done in the sidebar.
- Promote/unpromote a stream to the live server with **no session restart**.
- Cursor indexing responsive with many worktrees present.
- Browser automation never asks for login twice.
- Review pipeline produces a PR with evidence artifacts, QA having run autonomously.
- Old iTerm+tmux stack untouched throughout.
