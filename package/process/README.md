# rdev — AI Development Pipeline

A ticket-to-PR pipeline that works with any AI coding tool. The process is defined in plain markdown — your tool reads it and follows it.

## The Pipeline

```
/start <ticket> → /build → /review → /ship → done
```

| Step | What happens | File |
|------|-------------|------|
| `/start` | Fetch ticket, explore codebase, plan | [start.md](start.md) |
| `/plan` | Re-plan or sub-plan without ticket fetching | [plan.md](plan.md) |
| `/build` | Builder implements plan task by task | [build.md](build.md) |
| `/review` | Different model reviews the code | [review.md](review.md) |
| `/ship` | Push, create/update PR, handle bot comments | [ship.md](ship.md) |
| `/fix-pr` | Triage and fix PR review comments | [fix-pr.md](fix-pr.md) |
| `/fix-ci` | Diagnose and fix CI failures | [fix-ci.md](fix-ci.md) |
| `/qa` | Browser-based QA testing | [qa.md](qa.md) |
| `/status` | Show current pipeline state | [status.md](status.md) |

## State

Pipeline state lives in `.rdev/state.json` (gitignored). Plans persist in `docs/plans/<ticket>.md` (committed).

## Cross-Model Review

The review step MUST use a different model than the one that wrote the code. This is the core quality gate — same-model review catches significantly fewer bugs.

## Install

Run `./setup` from the rdev package root, or `npx rdev-init` from your project. The installer detects your AI tool and drops the right adapter in place.

Manual install:
- **Claude Code**: skills + agents land in `.claude/`
- **Cursor**: a rules file lands in `.cursor/rules/rdev.md`
- **Codex CLI**: an instructions block lands in `.codex/instructions.md`
- **Any other tool**: point it at `docs/rdev/` and tell it to follow the named step.
