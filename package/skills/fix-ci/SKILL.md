---
name: fix-ci
description: Check failing CI jobs on the current PR, diagnose failures caused by this PR's changes, and fix them
argument-hint: "[pr-number (optional, defaults to current branch PR)]"
---

## Fix Failing CI

Arguments: $ARGUMENTS

### Step 0: Get PR and CI Status

Determine the PR number. If an argument was provided, use that. Otherwise:
```bash
gh pr view --json number -q .number
```

Get the list of failing checks:
```bash
gh pr checks --json name,state,detailsUrl --jq '.[] | select(.state == "FAILURE") | "\(.name) — \(.detailsUrl)"'
```

If no failing checks, report "All CI checks passing" and stop.

### Step 1: Fetch Failure Logs

For each failing check, get the logs:
```bash
gh run view <run-id> --log-failed 2>/dev/null | tail -100
```

If `gh run view` doesn't work (external CI), fetch the details URL and try to extract useful info.

### Step 2: Diagnose

For each failure, determine:
- **Caused by this PR**: failure references files/code changed in this PR → fix it
- **Pre-existing / flaky**: failure is in unrelated code, or the test is known-flaky → skip it
- **Infrastructure**: timeout, network error, resource limits → skip it

To check what this PR changed:
```bash
git diff main --name-only
```

Only fix failures that are **caused by this PR's changes**.

### Step 3: Fix

For each failure caused by this PR:
- Read the failing test or lint error
- Read the relevant source file
- Make the fix — keep it minimal and focused

**IMPORTANT: Verify fixes locally BEFORE committing.** Use the devcontainer to run the same checks CI runs:

```bash
# WebUI lint/typecheck/format
docker exec fullstack-fullstack-1 bash -lc "cd /workspaces/rhythms/webui && npm run lint:fix && npm run format:write && npx tsc --noEmit"

# RailsAPI lint/tests
docker exec fullstack-fullstack-1 bash -lc "cd /workspaces/rhythms/railsapi && bundle exec rubocop -A && bundle exec rspec <specific_test_file>"

# MLAI lint/tests
docker exec fullstack-fullstack-1 bash -lc "cd /workspaces/rhythms/mlai && ruff check --fix . && python -m pytest <specific_test_file>"
```

If the devcontainer isn't running (`docker exec` fails), fall back to host-level checks where possible.

Only commit after local verification passes. If your fix introduces new errors, revert it.

Commit fixes with clear messages:
```
fix: resolve CI failure in <check-name> — <brief description>
```

### Step 4: Push and Verify

Push all fixes:
```bash
git push
```

Then check if CI re-runs:
```bash
gh pr checks --json name,state --jq '.[] | select(.state == "FAILURE" or .state == "PENDING") | "\(.name): \(.state)"'
```

### Step 5: Summary

Print a summary:
- Total failing checks found
- How many were caused by this PR (fixed)
- How many were pre-existing/flaky (skipped)
- What commits were created
- Any failures that couldn't be fixed automatically

## Rules
- Only fix failures caused by this PR's changes — never fix pre-existing failures
- Keep fixes minimal — don't refactor while fixing CI
- If a test failure is ambiguous (could be this PR or pre-existing), check `git log` for when the test last passed
- If you can't determine the cause, report it and move on — don't guess
- Always push fixes so CI re-runs
