---
name: plan
description: Create or refine an implementation plan for the current branch — without ticket fetching or branch setup. Use when /start's plan is stale, when adding a sub-feature, or when there is no ticket.
argument-hint: "[--design] [topic or freeform description]"
---

## Plan

Arguments: $ARGUMENTS

Use this when:
- The plan from `/start` is stale and needs a rewrite
- You're adding a sub-feature within an existing branch
- There's no Linear ticket — you're planning something ad-hoc
- You want to re-plan after discovering the original approach won't work

If you need ticket fetching + branch setup too, use `/start` instead.

### Step 1: Locate or Create the Plan File

Determine the plan path:

1. Read `.claude/rdev/state.json` if it exists. Use `docs/plans/<ticket>.md` if `ticket` is set.
2. Otherwise, use the current branch name: `docs/plans/<branch-name>.md`.
3. If a topic is in arguments and no plan exists, use a slug of the topic: `docs/plans/<slug>.md`.

If the file already exists, **read it before planning** — don't overwrite without understanding what's there.

### Step 2: Gather Context

- Read `.claude/rdev/<ticket>.md` if it exists (ticket context from `/start`).
- Read `CLAUDE.md` / `AGENTS.md` for the services you're touching.
- Run `git diff main --stat` to see what's already changed on this branch.
- Read any reference files in `.claude/rdev/refs/` — these are stash files the user dropped for the planner/builder.

### Step 3: Plan

**Always use `superpowers:brainstorming`** (or your harness's equivalent brainstorming skill) to explore the problem before writing.

**Standard mode** (default): lightweight pass:
1. Explore the relevant code paths
2. Ask 1-2 clarifying questions if anything is ambiguous
3. Propose a recommended approach
4. Write the plan with clear tasks and a definition of done

**Design mode** (`--design`): full design process:
1. Explore context → clarifying questions → 2-3 candidate approaches
2. Write a short design doc section with trade-offs
3. Pick an approach (or ask the user to)
4. Write a TDD implementation plan with bite-sized tasks, exact code, no placeholders

### Step 4: Plan Format

Structure (matches what `/build` expects to consume):

```markdown
# <Ticket or Topic Title>

**Branch:** `<branch-name>`
**Mode:** Standard | Design

## Problem

What's broken or missing. 1-3 short paragraphs.

## Solution

Numbered, in order:
1. <First change> — <where>
2. <Second change> — <where>
3. ...

## Why this approach

Brief table of alternatives considered and why rejected (only if `--design`).

| Approach | Verdict | Why |
|---|---|---|
| ... | ❌ | ... |
| ... | ✅ | ... |

## Design

File-by-file changes with paths and (for `--design`) representative code.

## Tasks

Bite-sized, in execution order. Each task should be completable by a builder agent in one pass.

- [ ] Task 1: <action> — files: <paths>
- [ ] Task 2: ...

## Definition of Done

- [ ] All tasks above checked
- [ ] Tests pass: `<command>`
- [ ] Lint/typecheck pass: `<command>`
- [ ] (UI changes) QA Test Plan executed — see below

## QA Test Plan (only if UI changes)

- Page: /path
- Steps:
  1. Navigate to /path
  2. Do X
  3. Verify Y
- Expected: <what correct looks like>
```

### Step 5: Save and Update State

Save to the path determined in Step 1.

If `.claude/rdev/state.json` exists, update `"stage": "plan"`.

Tell the user: "Plan ready at `<path>`. Say `/build` to start building."

## Rules

- Read the existing plan if one exists — never overwrite blind.
- Always brainstorm before writing. No skipping planning.
- Plans go in `docs/plans/`, not `.claude/rdev/`. State stays in `.claude/rdev/`.
- Tasks must be bite-sized and ordered. Builder agents do one task at a time.
- Include file paths in tasks. "Add X" without a path is a bad task.
- If the change touches UI, the QA Test Plan section is mandatory.
- `--design` is for non-trivial work. Don't use it for one-file fixes.
