---
name: parallel-testing
description: How to test a change without colliding with the many other agents and the user who share one dev container and one local app
---

## Parallel testing — coexistence rules

Many streams run at once (10+), plus the user, often sharing **one dev machine
or dev container**. Local tests must not step on each other; the running app is
QA'd on **per-PR preview deployments** when the project has them, otherwise
locally per the repo's docs. Pick the **lowest tier that proves your change** —
lower tiers are cheaper and have no contention.

Actual test/lint/typecheck commands live in each touched service/package's
`AGENTS.md` / `CLAUDE.md`. This skill only covers the *coordination* layer that
those commands don't.

### Tier 1 — Pure unit tests (no shared state)

Pure unit and component tests (no DB, no network, no fixed ports). **Run freely
and in parallel, anywhere — no coordination needed.** Always prefer these; they
cover most changes.

### Tier 2 — Tests with shared mutable state (DBs, ports)

Integration tests that hit a database, bind a port, or write shared files. Safe
to run in parallel across worktrees **only if each worktree is isolated** — its
own database, its own ports. The repo's `.shield/setup` hook (run in each new
worktree; path set by `SETUP_HOOK` in `.shield/config`) is the place to provide
that, e.g. derive a per-worktree DB name from `$SHIELD_STREAM` and write it into
the worktree's env file.

- **Isolated** → run the test-DB prep and tests per the service's `AGENTS.md`
  (in the dev container if `.shield/config` sets `CONTAINER`).
- **No isolation** (no setup hook, or the worktree points at the shared dev DB)
  → do NOT run destructive DB prep (reset / drop / re-migrate); you'd be
  resetting everyone's database. Tell the user, and fall back to Tier 1 plus CI
  on the pushed branch.

### Tier 3 — Running app / browser / e2e / UX QA

- **Preview deployments** (`preview_url_pattern` set in `.claude/shield/state.json`,
  e.g. `https://myapp-pr-{pr}.example.com`) → QA the PR's preview — isolated,
  real, zero local contention. Derive the URL straight from the PR number
  (`gh pr view --json number -q .number`), no lookup needed.
  1. Ensure a **draft PR** is open for the branch (open one if needed) — that
     usually triggers the preview build.
  2. Wait for the preview to finish deploying (a few minutes after the push).
  3. Point `/qa` / the browser at the preview URL.
- **No preview** → run the app locally from the worktree, started per the repo's
  docs, on ports no other stream is using; don't reuse or restart another
  stream's server.

### Quick decision

Every change gets a QA round (coordinator Stage 4) — the tiers only decide *how*:

- Change is logic / back-end only → Tier 1/2 locally, then QA by exercising the
  real behavior (API calls / jobs / logs) — preview env where available,
  otherwise the worktree's isolated Tier 2 setup. Capture outputs as PR evidence.
- Change touches UI → Tier 1/2 locally first, then Tier 3: the PR's preview (open
  a draft PR) or the local app. Capture screenshots as PR evidence.
