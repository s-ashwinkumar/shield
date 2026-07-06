---
name: start
description: Start working on a ticket — fetch context, explore codebase, plan the approach
argument-hint: "<ticket-id> [--design]"
---

## Start a Ticket

Arguments: $ARGUMENTS

### Step 1: Initialize State

Parse the ticket ID from arguments. If `--design` is present, enable design mode.

Create or read `.claude/rdev/state.json`:
```json
{
  "stage": "plan",
  "ticket": "<ticket-id>",
  "design": false,
  "started_at": "<timestamp>",
  "review_loops_done": 0,
  "max_review_loops": 3
}
```

If state already exists for this ticket, read it and resume from the current stage.

### Step 2: Fetch Ticket

Try to fetch the ticket from Linear using MCP `get_issue` with the ticket ID. Save details to `.claude/rdev/<ticket-id>.md`.

If Linear MCP is not available, ask the user to describe the task.

### Step 3: Set Up Branch

Check if a branch exists for this ticket. If Linear provided a `gitBranchName`, use that. Otherwise check for existing branches:
```bash
git branch -a | grep -i "<ticket-id-lowercase>"
```

If no branch exists, create one from main:
```bash
git checkout -b <branch-name> main
```

If a branch exists, check it out.

### Step 4: Plan

**Always use `superpowers:brainstorming`** to explore the problem and plan.

**Standard mode** (default): Keep it lightweight:
1. Explore codebase + read AGENTS.md for touched services
2. Ask 1-2 clarifying questions
3. Propose your recommended approach
4. Write plan with clear tasks and definition of done

**Design mode** (`--design`): Full superpowers process:
1. Explore context → clarifying questions → 2-3 approaches
2. Write design doc → self-review → user review
3. Write TDD implementation plan (bite-sized tasks, exact code, no placeholders)

If the ticket involves UI changes, include a **QA Test Plan** section:
```
## QA Test Plan
- Page: /path-to-test
- Steps:
  1. Navigate to /path
  2. Do X
  3. Verify Y
- Expected: [what correct looks like]
```

### Step 5: Save Plan

Save the plan to `docs/plans/<ticket-id>.md`.

Update state: `"stage": "plan"`

Tell the user: "Plan ready. Say `/build` to start building, or `/build --god` for fully autonomous."

## Rules
- Always fetch the ticket first — don't start blind
- Always use superpowers brainstorming — no skipping planning
- Save plans to `docs/plans/` (not `.claude/rdev/`)
