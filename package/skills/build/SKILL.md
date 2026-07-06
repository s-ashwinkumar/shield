---
name: build
description: Execute the plan — dispatch builder per task with review between tasks
argument-hint: "[--god]"
---

## Build

Arguments: $ARGUMENTS

If `--god` is present, set `god_mode: true` in `.claude/rdev/state.json`. All subsequent stages run without user gates.

### Step 1: Read Plan

Read the plan from `docs/plans/<ticket>*.md` (check `.claude/rdev/state.json` for ticket ID).

If no plan exists, tell the user to run `/start` first.

### Step 2: Execute Plan

Use the **subagent-driven development** pattern: a dedicated builder agent implements each task; a separate reviewer agent (ideally a different model) reviews between tasks.

Per-harness dispatch:
- **Claude Code**: `builder` and `reviewer` subagents from `.claude/agents/`
- **Codex CLI**: spawn a child Codex session with the builder/reviewer instruction blocks (see `adapters/codex/`)
- **Cursor**: run builder/reviewer as separate Composer sessions
- **No subagent support**: run two sequential prompts in the same session, prefixing each with the builder/reviewer instructions

**If the plan has numbered tasks:**

For each task:
1. Dispatch the **builder** with the full task text (not a reference — include actual steps and code)
2. After builder completes, dispatch the **reviewer** to review just this task's diff
3. If reviewer finds Critical or Important issues, send builder the findings to fix, then re-review
4. Mark task complete, move to next

**If no numbered tasks:**

Dispatch the builder with the full plan as a single task.

### Step 3: Check for UI Changes

Determine whether any frontend / UI files changed. Use the project's convention for where UI code lives — common patterns: `webui/`, `web/`, `frontend/`, `app/`, `client/`, or files matching `*.tsx`, `*.vue`, `*.svelte`. `docs/rdev/qa-context.md` may name the directory explicitly.

```bash
git diff main --name-only
```

**If UI files changed:**

- **God mode**: Tell user "UI changes detected. Run `/qa` to test, or `/review` to skip to code review."
- **Normal mode**: Tell user "Build complete. UI changes detected — test your changes, then run `/review` when ready."

⛔ **DO NOT proceed to review automatically when UI files changed (unless god mode).**

**If no UI files:**

Tell user "No UI changes. Run `/review` to start code review."

### Step 4: Update State

Update `.claude/rdev/state.json`: `"stage": "build_complete"`

## Rules
- Always read AGENTS.md for each service before dispatching builder
- Give builder the full task text — not just "implement Task 3"
- Don't write code yourself — dispatch the builder
