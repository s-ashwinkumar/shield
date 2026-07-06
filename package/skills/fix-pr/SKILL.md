---
name: fix-pr
description: Fetch open PR review comments, triage them, fix what's worth fixing, and respond to all comments
argument-hint: "[pr-number (optional, defaults to current branch PR)]"
---

## PR Review Comment Triage

Arguments: $ARGUMENTS

## Step 0: Fetch PR Data

First, determine the PR number. If an argument was provided above, use that. Otherwise, run:
```bash
gh pr view --json number -q .number
```

Get the repo owner and name:
```bash
gh repo view --json owner,name -q '.owner.login + "/" + .name'
```

Then use the GitHub MCP to fetch:
1. **PR details**: `get_pull_request` with the owner, repo, and PR number
2. **Review comments**: `list_pull_request_reviews` to get all reviews
3. **Changed files**: `gh pr diff PR --name-only`

## Step 1: Triage

**Be conservative.** This code has already been built, tested, and reviewed. Any change you make now risks introducing regressions. Bot comments are often noisy, outdated, or wrong.

For each comment, critically evaluate:
1. **Is the bot correct?** Read the actual code — not just the diff snippet the bot shows. Bots often flag things without understanding the full context.
2. **Would this fix break anything?** Think about callers, tests, downstream effects. If the fix touches logic, it's risky.
3. **Is this a real bug or a style preference?** Don't change working code for style.

Categorize each comment as:
- **Fix**: Genuinely broken (real bug, actual security issue, will crash in production). You must be confident the fix is safe.
- **Acknowledge**: Valid observation but not worth changing tested code — explain why it's intentional or out of scope.
- **Dismiss**: Bot noise, false positive, already addressed, or style nit — dismiss with brief explanation.

**Default to Acknowledge, not Fix.** Only fix if you're certain it's a real bug AND the fix won't break anything.

## Step 2: Fix (only confirmed bugs)

For comments categorized as "Fix":
- **Read the surrounding code first** — understand why it was written that way
- Make the **minimal** change — do not refactor, do not "improve" nearby code
- **Run tests after every fix** using the project's test command (detect from `package.json`, `Makefile`, `pyproject.toml`, `Gemfile`, etc.)
- If tests fail after your fix, **revert it** — the bot was wrong or your fix introduced a regression
- Commit fixes separately with a clear message

If a fix involves more than ~10 lines or touches logic/control flow, STOP and ask the user.

## Step 3: Respond to ALL comments

For every comment, reply using the GitHub MCP `create_review_reply` tool or:

```bash
gh api repos/OWNER/REPO/pulls/PR/comments/COMMENT_ID/replies -f body="<response>"
```

Response format:
- For fixes: "Fixed in <commit-sha>."
- For acknowledged: "Acknowledged — <brief explanation>."
- For dismissed: "<brief explanation>."

## Step 4: Resolve

After responding, resolve all addressed comment threads using the GitHub MCP `resolve_review_thread` tool. If the MCP tool isn't available, use:

```bash
gh api graphql -f query='
  query($owner: String!, $repo: String!, $pr: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        reviewThreads(first: 100) {
          nodes {
            id
            isResolved
            comments(first: 1) {
              nodes { body databaseId }
            }
          }
        }
      }
    }
  }
' -f owner=OWNER -f repo=REPO -F pr=PR_NUMBER

# Then resolve each thread:
gh api graphql -f query='
  mutation($threadId: ID!) {
    resolveReviewThread(input: {threadId: $threadId}) {
      thread { isResolved }
    }
  }
' -f threadId=THREAD_NODE_ID
```

## Step 5: Push & Summary

Push all fixes to the branch, then print a summary:
- How many comments total
- How many fixed, acknowledged, dismissed
- What commits were created
- Any comments that need user attention

## Rules
- Never ignore a comment — every one gets a response
- Be respectful in responses, even to bot comments
- **If unsure whether to fix something, err toward acknowledging — not fixing.** Tested code is more valuable than addressing a bot nit.
- **Revert any fix that causes test failures** — the existing behavior was correct
- Do not change code that is working just because a bot suggested a "better" way
- Push fixes to the branch after all changes are made
