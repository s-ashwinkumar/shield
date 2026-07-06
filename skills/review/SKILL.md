---
name: review
description: Run code review loop using Codex (OpenAI) for independent review, fix issues, then create/update PR
argument-hint: "[--base <branch>] [--max-loops <n>]"
---

## Code Review + PR Pipeline

Run an autonomous code review loop using the Codex plugin (OpenAI models) for genuine cross-model review, then create or update a PR.

Arguments: $ARGUMENTS

Default base branch: `main`
Default max loops: `3`

### Step 1: Review with Codex (adversarial)

**MANDATORY: cross-model review via codex-companion's `adversarial-review` command.** Do NOT review the code yourself — the whole point is that a different model (OpenAI) reviews. Do NOT dispatch the `codex:codex-rescue` subagent — its own rules forbid review work ("Do not call review, adversarial-review, status, result, or cancel"). Call the companion script directly via Bash.

Run, capturing stdout:

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs" adversarial-review --wait --base main
```

Why `adversarial-review` and not plain `review`:
- Adversarial is tuned to *break confidence in the change* — targets auth, data loss, race conditions, migration hazards, observability gaps
- Explicitly skips style, naming, low-value cleanup → less noise to triage
- Better fit for a pre-PR quality gate

Notes on the invocation:
- `${CLAUDE_PLUGIN_ROOT}` is set by Claude Code when the codex plugin is loaded; fall back to `~/.claude/plugins/cache/openai-codex/codex/<version>/` if the env var isn't present
- `--wait` blocks until the review completes (use `--background` only if explicitly asked)
- Pass `--base <branch>` only if reviewing against something other than `main` (per the user's `--base` argument)
- If the user passed a focus, append it as positional text: `adversarial-review --wait --base main <focus text>`
- If codex fails (auth, model unavailable, etc.), STOP and tell the user — do not silently fall back to self-review

Save the codex output to `.claude/rdev/review-<ticket-id>-{n}.md` (increment n for each round).

### Step 2: Analyze Findings

Categorize the review findings:
- **Critical**: Must fix (bugs, security, data loss)
- **Important**: Should fix (architecture, missing tests, error handling)
- **Minor**: Nice to have (style, optimization)

### Step 3: Fix Critical and Important Issues

If Critical or Important issues were found:
- Spawn the `builder` subagent with the findings and instructions to fix them
- The builder should commit fixes separately from implementation commits
- After fixes, run `adversarial-review` again (Step 1) for the re-review — same Bash invocation, increment the file suffix
- Repeat until clean or max loops reached

If only Minor issues or clean: proceed to Step 4.

### Step 4: Push and Create/Update PR

Push the branch:
```bash
git push -u origin $(git rev-parse --abbrev-ref HEAD)
```

Check if a PR already exists:
```bash
gh pr view --json number,url 2>/dev/null
```

**If PR exists**: Update the description with `gh pr edit`.
**If no PR exists**: Create one with `gh pr create`.

PR description should include:
- Link to the ticket (check `.claude/rdev/state.json` for ticket ID)
- Summary from `docs/plans/<ticket-id>.md` if it exists
- Key changes made
- Number of review rounds completed

### Step 5: Update State

Update `.claude/rdev/state.json`:
- Set `"stage": "pr_comments"`
- Increment `"review_loops_done"`

### Step 6: Address Bot Comments

Get the PR number:
```bash
gh pr view --json number -q .number
```

Run up to 3 rounds of bot comment triage:

1. **Wait for bots**: `sleep 300` on round 1, `sleep 180` on rounds 2-3
2. **Fetch comments**: Check for new review comments and threads
3. **Triage each comment**: Fix (valid issues) / Acknowledge (minor/out of scope) / Dismiss (noise)
4. **Fix issues** by spawning the builder subagent
5. **Respond to ALL comments** on the PR
6. **Resolve addressed threads** using GitHub MCP or GraphQL
7. **Push fixes**: `git push`

If no comments after waiting, or no fixes needed, stop looping.

### Step 7: Done

Update `.claude/rdev/state.json` with `"stage": "done"`.

Notify the user:
```bash
terminal-notifier -title "rdev" -message "PR ready: <url>. All comments addressed." -sound default -group rdev
```

Print summary: PR URL, comments addressed (fixed/acknowledged/dismissed), review rounds.

## Rules
- Never skip the codex review — the whole point is cross-model review
- Use `codex-companion.mjs adversarial-review` (NOT the `codex:codex-rescue` subagent — it rejects review tasks by design)
- If codex fails, STOP and surface the error — do not silently self-review (that defeats cross-model review)
- Fix Critical issues before proceeding, always
- Don't rubber-stamp — if codex finds real issues, fix them
- Always push before creating/updating PR
- Always respond to every bot comment
