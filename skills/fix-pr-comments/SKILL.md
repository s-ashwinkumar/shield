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

**Be conservative.** This code has already been built, tested, and reviewed. Any change you make now risks introducing regressions.

Apply the `receiving-code-review` discipline (available in the rhythms repo's `.agents/skills/`): verify every comment against the actual code before acting, no performative agreement, push back with reasons when a reviewer is wrong.

First, separate comments by source:

### Bot comments (cursor[bot], claude[bot], sonarcloud, etc.)
- Often noisy, outdated, or wrong
- Read the actual code — not just the diff snippet the bot shows
- Default to **Acknowledge** or **Dismiss**
- Only **Fix** if it's a genuine bug (will crash in production, security issue)

### Human comments (teammates, reviewers)
- Take these seriously — a human took time to write it
- Categorize by scope:

| Type | Action |
|------|--------|
| **Small fix** (typo, naming, missing null check) | Fix it |
| **Medium fix** (refactor a function, add error handling) | Fix if <10 lines, otherwise discuss |
| **Architectural / design feedback** ("this should be a separate service", "wrong pattern") | ⛔ **DO NOT FIX.** Reply acknowledging, explain your reasoning, and ask the user what they want to do |
| **Questions** ("why did you do X?") | Reply with explanation, don't change code |

### Categorize each comment as:
- **Fix**: Genuinely broken OR small human-requested change you're confident about
- **Discuss**: Architectural, design, or large scope — needs human decision. Reply on PR and **ask the user**.
- **Acknowledge**: Valid observation but out of scope or intentional — explain why
- **Dismiss**: Bot noise, false positive, already addressed

**Default to Acknowledge for bots. Default to Discuss for large human feedback.**

## Step 2: Fix (only confirmed safe changes)

For comments categorized as "Fix":
- **Read the surrounding code first** — understand why it was written that way
- Make the **minimal** change — do not refactor, do not "improve" nearby code
- **Run tests after every fix** (use devcontainer if available):
  ```bash
  docker exec fullstack-fullstack-1 bash -lc "cd /workspaces/rhythms/<service> && <test command>"
  ```
- If tests fail after your fix, **revert it** — the comment was wrong or your fix introduced a regression
- Commit fixes separately with a clear message

⛔ **STOP and ask the user if:**
- A fix involves more than ~10 lines
- A fix touches logic/control flow
- Multiple comments suggest a design change
- You're unsure whether the reviewer or the code is right

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
