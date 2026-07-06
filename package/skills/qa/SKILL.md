---
name: qa
description: Browser-based QA testing — test the app like a real user, find bugs, fix them, write regression tests, produce a health-scored report
argument-hint: "[--quick | --standard | --exhaustive] [--report-only] [url]"
---

## Browser QA Testing

Arguments: $ARGUMENTS

You are a QA engineer AND a bug-fix engineer. Test the app like a real user — click, fill forms, check states. When you find bugs, fix them and re-verify. End with a health-scored report.

Requires a browser-automation tool (Playwright MCP, Puppeteer MCP, or equivalent) and a running local app.

## Modes

| Flag | Severities fixed | When to use |
|------|------------------|-------------|
| `--quick` | critical + high | PR-readiness check, fast feedback |
| `--standard` (default) | critical + high + medium | Pre-merge gate |
| `--exhaustive` | all incl. low / cosmetic | Release candidate, weekly sweep |
| `--report-only` | (find but never fix) | Audit, handing off to author |

## Phase 0: Gather Context

Read these in order before opening the browser:

1. **Plan's QA Test Plan** — `docs/plans/<ticket>*.md`, "QA Test Plan" section. Primary source: tells you what pages, what steps, what "correct" looks like.
2. **Ticket context** — `.claude/rdev/<ticket>.md` for acceptance criteria.
3. **App QA context** — `docs/rdev/qa-context.md`. Describes app URL, auth, navigation, common patterns. (If the file is missing or still a template, ask the user for the missing pieces before testing.)
4. **Diff-aware inference** (fallback): `git diff main --name-only` → map changed files to routes using the project's routing convention.
5. **Ask the user** if none of the above tell you what to test.

## Phase 1: Auth Check

Navigate to the app URL (default `http://localhost:3000`, or from `docs/rdev/qa-context.md`).

- App not running (connection refused) → tell the user and stop.
- Landed on a login page → **ask the user to log in manually** in the browser window. Wait for confirmation. Do not automate auth.
- Snapshot to confirm you're on an authenticated page.

## Phase 2: Execute Test Plan

**With a QA Test Plan**, follow it step by step. Screenshot before/after each key action.

**Without one** (inference mode), for each identified page:

1. Navigate
2. Snapshot the accessibility tree
3. Screenshot
4. Run the checklist:
   - [ ] Page loads without console errors
   - [ ] Key elements from the change are visible
   - [ ] Click buttons related to the change — do they work?
   - [ ] Fill forms related to the change — submit works?
   - [ ] Check loading / empty / error states if relevant
   - [ ] Check console after interactions

## Phase 3: Triage

For each issue, classify by severity and category (see `references/issue-taxonomy.md`):

```markdown
### ISSUE-NNN: [Brief title]
**Severity**: critical / high / medium / low
**Category**: Visual / Functional / UX / Content / Performance / Accessibility
**Page**: /path
**Steps to reproduce**:
1. Navigate to /path
2. Click X
3. Observe Y
**Expected**: [what should happen]
**Actual**: [what happens]
**Screenshot**: <path>
```

## Phase 4: Fix Loop (skip in `--report-only`)

For each issue at or above the tier's threshold:

1. **Locate** — grep for error messages, component names; read the source.
2. **Fix** — minimal change. No refactoring while fixing.
3. **Commit** — `fix(qa): <brief description> [ISSUE-NNN]`
4. **Re-verify** — navigate back, repeat the steps, screenshot confirming the fix.
5. **Self-regulate** — after every 5 fixes, STOP and evaluate: are you fixing real bugs or creating new ones? If churn is rising, hand back to the user.

## Phase 5: Regression Tests

For each critical/high fix:

1. Read 1-2 nearby test files to match the project's testing style.
2. Write a test that reproduces the bug and asserts correct behavior.
3. Run it with the project's test command (detect from `package.json`, `Makefile`, `pyproject.toml`, etc.).
4. Passes → `test(qa): regression test for ISSUE-NNN`
5. Fails after one attempt → skip, note in report.

## Phase 6: Final QA

Re-run the test plan top-to-bottom against the fixed code. Confirm no regressions. Snapshot final state.

## Phase 7: Report

Write the report to `docs/qa/<ticket>-<date>.md` using `references/report-template.md`. Include the health score.

## Health Score Rubric

| Category | Weight | Scoring |
|----------|--------|---------|
| Console | 15% | 100 = no errors; -10 per error, -3 per warning |
| Links | 10% | 100 = no broken; -20 per broken link |
| Visual | 15% | -25 critical, -10 high, -5 medium, -1 low |
| Functional | 25% | -40 critical, -15 high, -5 medium, -1 low |
| UX | 10% | -20 high, -8 medium, -2 low |
| Performance | 10% | 100 = LCP <2.5s; -10 per second over |
| Accessibility | 15% | -15 per critical a11y issue, -5 per high |

Final score = weighted sum, clamped 0-100.

| Score | Verdict |
|-------|---------|
| 90-100 | Ship it |
| 75-89 | Ship with caveats noted |
| 50-74 | Fix highs before merge |
| <50 | Block merge |

Push all fixes when done: `git push`

## Rules

- Read the plan's QA Test Plan FIRST. Don't ignore it.
- If not logged in, ask the user. Never automate auth.
- Take screenshots as evidence — they go in the report.
- Re-verify every fix in the browser before moving on.
- Tier dictates what you fix:
  - `--quick`: critical + high
  - `--standard`: + medium
  - `--exhaustive`: all
- Don't refactor while fixing. Minimal changes.
- If you can't determine what to test, ask. Don't guess.
- If the app isn't running, stop immediately.
- In `--report-only` mode, **never edit source files**.
