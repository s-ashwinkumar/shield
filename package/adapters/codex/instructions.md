# rdev — AI Development Pipeline

This project uses the rdev development pipeline. Process docs are in `docs/rdev/`.

## Pipeline

When asked to work on a ticket, follow these process docs in order:

1. `docs/rdev/start.md` — Fetch ticket, explore codebase, plan
2. `docs/rdev/build.md` — Implement the plan task by task
3. `docs/rdev/review.md` — Cross-model review (use a DIFFERENT model than yourself)
4. `docs/rdev/ship.md` — Push, create PR, handle bot comments

Additional tools:
- `docs/rdev/plan.md` — Re-plan or sub-plan without ticket fetching
- `docs/rdev/fix-pr.md` — Fix PR review comments
- `docs/rdev/fix-ci.md` — Fix CI failures
- `docs/rdev/qa.md` — Browser-based QA
- `docs/rdev/status.md` — Show current pipeline state

## State

Track pipeline state in `.rdev/state.json`. Save plans to `docs/plans/<ticket>.md`.

## Cross-Model Review

Since you are running on OpenAI, for the review step dispatch review to Claude (via API or ask the user). The code was written by one model family — review must come from another.
