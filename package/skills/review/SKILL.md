---
name: review
description: Cross-model code review — dispatches a different model to review your code, builder fixes findings
argument-hint: "[--max-loops N]"
---

## Code Review

Arguments: $ARGUMENTS

**MANDATORY: Dispatch a different model for review.** Do NOT review the code yourself. The whole point is cross-model review.

### Review-Fix Loop

Read max loops from `.claude/rdev/state.json` (default: 3).

For each iteration:

1. **Dispatch review to a different model.** Try in order based on your harness:

   | Harness | How to get a different model |
   |---------|------------------------------|
   | Claude Code + Codex plugin | **Bash:** `node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs" adversarial-review --wait --base main` (do NOT use `codex:codex-rescue` — it rejects review tasks by design) |
   | Claude Code (no plugin) | `superpowers:code-reviewer` subagent (fallback — same model family, weaker signal) |
   | Codex CLI | Call out to Claude via API (see `adapters/codex/`) |
   | Cursor | Switch model in settings, run review, switch back |
   | Any harness with MCP | An MCP server that calls a different model's API |
   | Last resort | Ask the user to paste the diff into a different AI tool |

   For Codex via `codex-companion.mjs`, use `adversarial-review` (not plain `review`) — it targets material risk (auth, data loss, races, migration hazards) and skips style/naming nits. Append the ticket scope as positional focus text if available: `adversarial-review --wait --base main "Ticket scope: <1-2 sentence summary>. Only flag issues caused by this change."`

2. **Save review** to `.claude/rdev/review-<ticket>-{n}.md`

3. **If Critical or Important issues**: pass findings directly to the **builder** — "Fix all Critical and Important issues from this review: <paste findings>". No triage. Trust the review.

4. **Builder commits fixes** → go back to step 1

**Exit when:**
- No Critical or Important issues (only Minor or clean)
- Max iterations reached
- Same issues repeat from previous round

Update state: `"stage": "review_complete"`, increment `"review_loops_done"`

Tell user: "Review complete. Run `/ship` to create/update PR."

## Rules
- NEVER review code yourself — always dispatch to a different model
- On Claude Code + Codex plugin: use `codex-companion.mjs adversarial-review` directly, NOT the `codex:codex-rescue` subagent (rescue is forbidden from review tasks by its own rules)
- Include ticket scope in the review prompt so reviewer doesn't flag pre-existing issues
- If the reviewer fails (auth, model unavailable), STOP and surface the error — do not silently self-review
- Save every review to a file for future analysis
