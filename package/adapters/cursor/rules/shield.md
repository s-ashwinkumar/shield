# shield — AI Development Pipeline

This project uses the shield development pipeline. Process docs are in `docs/shield/`.

## Pipeline Commands

When the user says any of these, read and follow the corresponding process doc:

| User says | Read |
|-----------|------|
| "start TICKET-XXX" or "work on TICKET-XXX" | `docs/shield/start.md` |
| "plan" or "re-plan" or "plan this sub-feature" | `docs/shield/plan.md` |
| "build" or "build it" or "implement the plan" | `docs/shield/build.md` |
| "review" or "code review" | `docs/shield/review.md` |
| "ship" or "create PR" or "open PR" | `docs/shield/ship.md` |
| "fix PR comments" or "fix comments" | `docs/shield/fix-pr.md` |
| "fix CI" or "fix failing tests" | `docs/shield/fix-ci.md` |
| "QA" or "test the UI" | `docs/shield/qa.md` |
| "status" or "where are we" | `docs/shield/status.md` |

## Pipeline State

Track state in `.shield/state/state.json`. Read it at the start of each conversation to know where the pipeline is.

## Cross-Model Review

When doing `/review`, you MUST use a different model than yourself. In Cursor:
- If you're Claude → ask the user to switch to GPT-4o or use the API
- If you're GPT → ask the user to switch to Claude

Save plans to `docs/plans/<ticket>.md`. Save reviews to `.shield/state/review-<ticket>-{n}.md`.

## Key Rules
- Never skip planning (always read start.md first)
- Never review your own code (always use a different model)
- Read AGENTS.md for each service before making changes
- Save plans to `docs/plans/` (committed), state to `.shield/state/` (gitignored)
