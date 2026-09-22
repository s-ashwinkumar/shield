# shield — AI Development Pipeline

Automated ticket-to-PR pipeline. Works on Claude Code, Codex, Cursor, Gemini CLI, pi.dev — any harness that reads `.claude/` skills and agents.

## Install (30 seconds)

```bash
# Option 1: Clone and copy
git clone https://github.com/s-ashwinkumar/shield.git /tmp/shield
cp -r /tmp/shield/package/skills/* .claude/skills/
cp -r /tmp/shield/package/agents/* .claude/agents/

# Option 2: npx (coming soon)
npx shield-init
```

## Usage

```
/start ENG-500                Start a ticket — fetch from your tracker, plan
/start ENG-500 --design       Full design process for larger features
/build                        Execute the plan — builder per task + review
/review                       Cross-model code review (OpenAI reviews your code)
/ship                         Push, create/update PR, address bot comments
/fix-pr                       Triage and fix PR review comments
/fix-ci                       Diagnose and fix CI failures
/qa                           Browser-based QA testing
/status                       Show pipeline state
```

## The Pipeline

```
/start → /build → /review → /ship → done
```

Each step updates `.claude/shield/state.json`. You can stop and resume at any point. The pipeline remembers where you are.

## Cross-Model Review

The `/review` skill automatically uses a different model family to review your code. Claude writes, OpenAI reviews — genuine second-opinion review.

## State

Pipeline state lives in `.claude/shield/state.json`. Plans persist in `docs/plans/<ticket>.md`.
