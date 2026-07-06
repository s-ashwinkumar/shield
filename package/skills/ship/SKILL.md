---
name: ship
description: Push branch, create or update PR, wait for bot comments and address them
argument-hint: ""
---

## Ship

### Step 1: Push

```bash
git push -u origin $(git rev-parse --abbrev-ref HEAD)
```

### Step 2: Create or Update PR

Check if a PR already exists:
```bash
gh pr view --json number,url 2>/dev/null
```

**If PR exists**: Update description with `gh pr edit`.
**If no PR**: Create with `gh pr create`.

PR description should include:
- Link to ticket (from `.claude/rdev/state.json`)
- Summary from `docs/plans/<ticket>.md`
- Key changes made
- Number of review rounds completed

### Step 3: Wait for Bot Comments

Wait for CI and bots to run:
```bash
sleep 300
```

Check for comments:
```bash
gh pr view --json reviewRequests,comments --jq '.comments | length'
```

If no comments after waiting, skip to Step 5.

### Step 4: Fix PR Comments

Run `/fix-pr` to handle all bot comments. This skill:
- Fetches and triages comments (fix / acknowledge / dismiss)
- Fixes real bugs conservatively (runs tests after each fix)
- Responds to all comments
- Resolves addressed threads

Push fixes: `git push`

If fixes were pushed, wait again (3 min) for another round of bot comments. Max 3 rounds.

### Step 5: Done

Update state: `"stage": "done"`

Send notification (if terminal-notifier available):
```bash
terminal-notifier -title "rdev" -message "PR ready: <url>" -sound default -group rdev 2>/dev/null || true
```

Print summary: PR URL, review rounds, comments addressed.

Append learnings to `.claude/rdev/memory/learnings.md` if anything notable happened during this ticket.

## Rules
- Always push before creating PR
- Always check for existing PR before creating
- Default to acknowledging bot comments, not fixing — tested code is valuable
