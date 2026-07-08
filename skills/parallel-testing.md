---
name: parallel-testing
description: How to test a change without colliding with the many other agents and the user who share one dev container and one local app
---

## Parallel testing — coexistence rules

Many streams run at once (10+), plus the user, all sharing **one dev container**
and **one local running app** (ports 3000/4000/8000). Tests must not step on each
other or on the user. Pick the **lowest tier that proves your change** — lower
tiers are cheaper and have no contention.

Actual test/lint/typecheck commands live in each touched service's `AGENTS.md`
(webui / railsapi / mlai / mcpservers). This skill only covers the *coordination*
layer that those commands don't.

### Tier 1 — Unit / component tests (no shared state)

Pure unit and component tests (e.g. webui component tests, rails specs that don't
touch the DB). **Run freely and in parallel — no coordination needed.** Always
prefer these; they cover most changes.

### Tier 2 — DB-backed tests (auto-isolated per worktree)

Integration tests that hit Postgres. Safe to run in parallel across worktrees
**because each worktree gets its own database**, keyed off `RDEV_DB_SUFFIX`
(set automatically in the worktree's `.local.env` by `rstream`). Never point tests
at mainline's database.

- **railsapi** — isolation is automatic. Run the standard test-DB prep in the
  worktree first (`RAILS_ENV=test bundle exec rake db:prepare`, or `db:reset` to
  rebuild), which reads the suffixed `database.yml` and creates
  `habits_rob_test<suffix>`. Then run rspec per railsapi/AGENTS.md.
- **mlai** — run **`rmlai`** once in the worktree first. It creates + migrates
  this worktree's isolated mlai dev DB (`rhythms_mlai_development<suffix>`). Then
  run the mlai test command from mlai/AGENTS.md. (mlai tests roll back their data,
  but the isolated DB is what prevents cross-branch *schema/migration* collisions.)
- If `RDEV_DB_SUFFIX` is empty you're on mainline — do NOT run destructive DB prep
  there; you'd be resetting the shared dev database.

### Tier 3 — The single live app (browser / e2e / lighthouse / manual QA)

Only **one** worktree can own the running app at a time (it's one server on fixed
ports). This is the only tier that needs a lease.

**Prefer a Railway preview deploy** for e2e / browser QA when the branch/PR has one
— it's a real, isolated environment with zero local contention. Use the local app
only when a preview isn't available or you need the un-pushed working tree.

To use the local app, coordinate via the lease (fair FIFO queue — no starvation):

1. `rlocal status` — see who holds it (could be another stream, or the user).
2. `rlocal wait <stream>` — queues you and blocks until it's your turn, then claims
   the lease for you. (If it's already free, `rpromote` alone will claim it.)
3. `rpromote <stream>` — repoints the live app at your worktree (restarts `dev`;
   self-reclaims the lease). Watch `dev.log` for startup; then test against
   `localhost:3000/4000/8000`.
4. `runpromote <stream>` — **always** run this when done: returns the app to main
   and releases the lease so the next queued stream (or the user) can go.

Rules: never bounce the live server without holding the lease (you'd yank it out
from under the user or another agent); never skip `runpromote` (others are waiting).

### Quick decision

- Change is logic/back-end only → Tier 1/2, done. No live server, no user needed.
- Change touches `webui/` UI → Tier 1/2 first, then Tier 3 (prefer Railway preview;
  else lease → `rpromote` → verify → `runpromote`).
