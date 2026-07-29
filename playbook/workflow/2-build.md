# Stage 2 — Build

Goal: implement the approved plan, task by task, with tests at the cheapest
tier that proves the change.

Build is the **only stage that writes code**. It runs whatever batch is in
front of it:
- **First pass:** the tasks in `docs/plans/<ticket-id>.md`.
- **Review loop-back:** the Critical/Important findings from a review round
  ([stage 3](3-review.md)), as one batch.
- **QA loop-back:** the batched issues from a QA round ([stage 4](4-qa.md)).

Whatever the source, treat the batch like plan tasks: implement all of it,
then the work flows forward through Review again. Never trickle fixes out
one at a time.

## Per task

1. Implement exactly what the task specifies. **Use judgment on tests** —
   write them where they add real protection (behavior changes, bug fixes,
   tricky logic) and skip them where they'd be ceremony (pure refactors
   already covered, trivial copy changes). Test-first is a technique
   available to you, not a mandate. Whatever you write must pass, and the
   existing suites for touched services must stay green.
2. Follow the conventions in the touched service's `AGENTS.md` — that's also
   where the real test/lint/typecheck commands live.
3. Commit when the task is done (one task ≈ one commit).
4. **Stay in scope.** Don't fix unrelated problems you notice along the
   way — note them (a ticket, or a comment on this one) and move on. Review
   enforces in-scope-only; don't hand it out-of-scope diffs.
5. If the task reveals the plan is wrong, stop and re-plan
   (see the re-plan loop in [workflow.md](../workflow.md)) — don't silently
   diverge from the approved plan.

## QA-issue batches: every bug fix carries a regression test

When the batch is QA loop-back, judgment doesn't apply — each bug being
fixed **must** include a test that would have caught it. These bugs
demonstrably escaped the existing tests once; the fix isn't done until it
can't escape silently again.

## Testing tiers — pick the lowest that proves the change

Many branches are worked in parallel against one shared dev container, so
local tests must not collide.

- **Tier 1 — unit/component tests.** No shared state; run freely, always
  prefer these.
- **Tier 2 — DB-backed tests.** Safe in parallel **only because each
  worktree gets its own database**, keyed off `RDEV_DB_SUFFIX` in the
  worktree's env:
  - railsapi: `RAILS_ENV=test bundle exec rake db:prepare` first (reads the
    suffixed `database.yml`), then rspec per railsapi/AGENTS.md.
  - mlai: create/migrate the worktree's isolated dev DB first, then the mlai
    test command from mlai/AGENTS.md.
  - If `RDEV_DB_SUFFIX` is empty you are on the shared mainline database —
    **never run destructive DB prep there.**
- **Tier 3 — real environment (running app / browser / API).** Not run
  locally against shared servers; that's what [stage 4: QA](4-qa.md) is for.

## Verifying tests — local run or CI, depending on where you are

Whatever tests exist — the ones you chose to write plus the touched
services' existing suites — must demonstrably pass; *where they execute*
depends on the environment:

- **Local environment with the dev container** (a local worktree, a teammate's
  machine): run Tier 1/2 directly — fastest feedback, respect the isolation
  rules above.
- **Remote/cloud agent with no local test environment**: push the branch and
  open a **draft PR early** so CI runs the suites; "tests pass" means the
  CI checks on the branch are green. Don't claim tests pass without one of
  these two proofs. (The early draft PR also warms up the Railway preview
  that [stage 4 QA](4-qa.md) needs.)

## Exit

All tasks (or all batched issues) implemented and committed, and the tests
for the touched services are **demonstrably passing** — local Tier 1/2
output, or green CI on the pushed branch. Update the plan's **Progress**
section (stage + a log line for the batch) and commit it with the work.
→ [Stage 3: Review](3-review.md)
