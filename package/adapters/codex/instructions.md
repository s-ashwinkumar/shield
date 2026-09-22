# shield — AI Development Pipeline

This project uses the shield development pipeline. Process docs are in `docs/shield/`.

## Pipeline

When asked to work on a ticket, follow these process docs in order:

1. `docs/shield/start.md` — Fetch ticket, explore codebase, plan
2. `docs/shield/build.md` — Implement the plan task by task
3. `docs/shield/review.md` — Cross-model review (use a DIFFERENT model than yourself)
4. `docs/shield/ship.md` — Push, create PR, handle bot comments

Additional tools:
- `docs/shield/plan.md` — Re-plan or sub-plan without ticket fetching
- `docs/shield/fix-pr.md` — Fix PR review comments
- `docs/shield/fix-ci.md` — Fix CI failures
- `docs/shield/qa.md` — Browser-based QA
- `docs/shield/status.md` — Show current pipeline state

## State

Track pipeline state in `.shield/state/state.json`. Save plans to `docs/plans/<ticket>.md`.

## Cross-Model Review

Since you are running on OpenAI, for the review step dispatch review to Claude (via API or ask the user). The code was written by one model family — review must come from another.
