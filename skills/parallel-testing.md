---
name: parallel-testing
description: How to test a change without colliding with the many other agents and the user who share one dev container and one local app
---

## Parallel testing — coexistence rules

Many streams run at once (10+), plus the user, all sharing **one dev container**.
Local tests must not step on each other; the running app is QA'd on **per-PR
Railway previews**, not a shared local server. Pick the **lowest tier that proves
your change** — lower tiers are cheaper and have no contention.

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

### Tier 3 — Running app / browser / e2e / lighthouse / UX QA

QA the running app on its **Railway preview**, not a local server. Opening a
**draft PR** auto-creates a per-PR Railway environment — isolated, real, zero
local contention (no shared server, no lease). Derive the URL straight from the
PR number, no lookup needed:

- webui: `https://webui-rhythms-pr-<PR>.up.railway.app/`

To QA a UI change:
1. Ensure a **draft PR** is open for the branch (open one if needed) — that
   triggers the Railway build.
2. Wait for the preview to finish deploying (a few minutes after the push).
3. Point `/qa` / the browser at `https://webui-rhythms-pr-<PR>.up.railway.app/`.

There is **no local live-server promote** here — `rpromote`/`runpromote`/`rlocal`
are parked. Fast local multi-port app servers may return later; until then,
Railway is the QA path.

### Quick decision

- Change is logic / back-end only → Tier 1/2 locally, done. No app, no QA env needed.
- Change touches `webui/` UI → Tier 1/2 locally first, then Tier 3: open a draft PR
  and QA on `https://webui-rhythms-pr-<PR>.up.railway.app/`.
