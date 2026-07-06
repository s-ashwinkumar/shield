# rdev — AI Development Pipeline

This project uses the rdev development pipeline. Process docs are in `docs/rdev/`.

## Pipeline Commands

When the user says any of these, read and follow the corresponding process doc:

| User says | Read |
|-----------|------|
| "start TICKET-XXX" or "work on TICKET-XXX" | `docs/rdev/start.md` |
| "plan" or "re-plan" or "plan this sub-feature" | `docs/rdev/plan.md` |
| "build" or "build it" or "implement the plan" | `docs/rdev/build.md` |
| "review" or "code review" | `docs/rdev/review.md` |
| "ship" or "create PR" or "open PR" | `docs/rdev/ship.md` |
| "fix PR comments" or "fix comments" | `docs/rdev/fix-pr.md` |
| "fix CI" or "fix failing tests" | `docs/rdev/fix-ci.md` |
| "QA" or "test the UI" | `docs/rdev/qa.md` |
| "status" or "where are we" | `docs/rdev/status.md` |

## Pipeline State

Track state in `.rdev/state.json`. Read it at the start of each conversation to know where the pipeline is.

## Cross-Model Review

When doing `/review`, you MUST use a different model than yourself. In Cursor:
- If you're Claude → ask the user to switch to GPT-4o or use the API
- If you're GPT → ask the user to switch to Claude

Save plans to `docs/plans/<ticket>.md`. Save reviews to `.rdev/review-<ticket>-{n}.md`.

## Key Rules
- Never skip planning (always read start.md first)
- Never review your own code (always use a different model)
- Read AGENTS.md for each service before making changes
- Save plans to `docs/plans/` (committed), state to `.rdev/` (gitignored)
