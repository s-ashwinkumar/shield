---
name: qa
description: Test changed UI pages in a real browser, find bugs, fix them, and generate regression tests
argument-hint: "[url (optional, defaults to diff-aware mode)]"
---

## Browser QA Testing

Arguments: $ARGUMENTS

You are a QA engineer AND a bug-fix engineer. Test the app like a real user — click, fill forms, check states. When you find bugs, fix them and re-verify.

### Phase 0: Gather Context

Before touching the browser, read these sources **in order** to understand what to test:

1. **QA Test Plan from the plan doc** — check `docs/plans/<ticket>*.md` for a "QA Test Plan" section. This is the primary source — it tells you exactly what pages to test, what steps to follow, and what "correct" looks like. If this exists, follow it.

2. **Ticket context** — check `.claude/rdev/<ticket>.md` for the ticket description and acceptance criteria.

3. **App context** — read the QA context file (check for `qa-context.md` in the skills/qa/ directory, or `.claude/rdev/qa-context.md`). This tells you how to navigate the app, common patterns, and test data.

4. **Diff-aware inference** (fallback if no QA Test Plan):
   ```bash
   git diff main --name-only | grep "^webui/"
   ```
   Map changed files to routes:
   - `webui/src/app/<path>/page.tsx` → `/<path>`
   - `webui/src/app/<path>/layout.tsx` → `/<path>` and child routes
   - `webui/src/components/<feature>/` → find which pages import this component

5. **Ask the user** (last resort) — if you can't determine what to test from any source above, ask: "I can see these files changed: <list>. Which pages should I test and what should I verify?"

### Phase 1: Auth Check

Navigate to the app URL. **Default: the branch's Railway preview** — `https://webui-rhythms-pr-<PR>.up.railway.app/` (get `<PR>` from `gh pr view --json number -q .number`; the draft PR should already exist per the workflow). Use `http://localhost:3000` only if the user explicitly asked for local QA.

- If the preview isn't up yet (build in progress), wait a few minutes and retry before reporting.
- If redirected to login: click through Google OAuth — the browser runs with a persistent profile (`~/.rdev/browser-profile`) that stays logged into Google, so the flow should complete without credentials (click the account if an account-chooser appears).
- Only if Google itself asks for credentials (profile session expired), **ask the user**: "The browser profile's Google session has expired — please log in once in the browser window; future runs won't need this." Wait for confirmation.
- Take a snapshot to confirm you're on an authenticated page.

### Phase 2: Execute Test Plan

**If QA Test Plan exists in the plan doc**, follow it step by step:
- Navigate to each specified page
- Perform each listed step
- Verify each expected result
- Screenshot before and after key actions

**If no QA Test Plan** (inference mode), for each identified page:

1. **Navigate**: `browser_navigate` to the URL
2. **Snapshot**: `browser_snapshot` to get the accessibility tree
3. **Screenshot**: `browser_take_screenshot` for visual state

Then run this checklist:
- [ ] Page loads without errors (check console)
- [ ] Key elements from the change are visible
- [ ] Click buttons related to the change — do they work?
- [ ] Fill forms related to the change — submit works?
- [ ] Check loading/empty/error states if relevant
- [ ] Check console for JS errors after interactions

### Phase 3: Document Issues

For each bug found:

```markdown
### ISSUE-NNN: [Brief title]
**Severity**: Critical / Major / Minor / Cosmetic
**Page**: /path
**Steps to reproduce**:
1. Navigate to /path
2. Click X
3. Observe Y
**Expected**: [what should happen]
**Actual**: [what happens]
```

Severity guide:
- **Critical**: App crashes, data loss, security issue, broken core flow
- **Major**: Feature doesn't work, broken form, JS error on interaction
- **Minor**: UI glitch, alignment issue, missing loading state
- **Cosmetic**: Spacing, color, font issues

### Phase 4: Fix Bugs

For each Critical and Major issue:

1. **Locate**: Read the source file, trace the bug
2. **Fix**: Make the minimal change
3. **Commit**: `fix(qa): <brief description> [ISSUE-NNN]`
4. **Re-verify**: Navigate back, repeat the steps, screenshot confirming the fix

For Minor: fix if quick (<2 min), otherwise note in report.
For Cosmetic: skip, note in report.

### Phase 5: Regression Tests

For each fixed bug:

1. Read 1-2 nearby test files to match the project's testing style
2. Write a test that reproduces the bug scenario and asserts correct behavior
3. Run: `cd webui && npx vitest run <test-file> --reporter=verbose`
4. If passes, commit: `test(qa): regression test for ISSUE-NNN`
5. If fails after one attempt, skip and note in report

### Evidence capture (required — reviewers judge on proof, not the diff)

Collect reviewer-visible proof the change works, into `.claude/rdev/evidence/<ticket>/`:
- Screenshots of each key state (before/after the changed behavior), named by step.
- For a flow, a numbered screenshot sequence (or a short screen recording if available).
- For non-visual changes, the relevant command output / logs.

Reference these artifact paths in the QA Report **and** in the PR body, so a reviewer
(or you, later) can see the change working without re-running it. This evidence is what
lets QA stand on its own instead of being a live manual step.

### Phase 6: Report

```
## QA Report

**Context**: [ticket ID] — [brief description of what was tested]
**Pages tested**: N
**Issues found**: N (X Critical, Y Major, Z Minor, W Cosmetic)
**Issues fixed**: N
**Regression tests added**: N
**Issues deferred**: N

### Test Plan Results
- [x] Step 1: [description] — PASS
- [x] Step 2: [description] — PASS
- [ ] Step 3: [description] — FAIL (ISSUE-001)

### Fixed Issues
- ISSUE-001: [title] — fixed in <commit>

### Deferred Issues
- ISSUE-003: [title] — [reason]
```

Push all fixes: `git push`

## Rules
- Read the plan's QA Test Plan FIRST — don't ignore it
- If not logged in, ask the user — don't try to automate auth
- Capture evidence into `.claude/rdev/evidence/<ticket>/` and link it in the PR (see Evidence capture)
- Re-verify every fix in the browser before moving on
- Don't fix cosmetic issues
- Don't refactor while fixing — minimal changes only
- If you can't determine what to test, ask the user
- If the app isn't running, stop immediately
