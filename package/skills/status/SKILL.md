---
name: status
description: Show current pipeline state — what stage, which ticket, what's been done
argument-hint: ""
---

## Pipeline Status

Read `.claude/rdev/state.json` and print a summary:

```bash
cat .claude/rdev/state.json 2>/dev/null
```

If no state file, report "No active pipeline. Run `/start <ticket>` to begin."

Otherwise, print:

```
Pipeline Status
═══════════════
Ticket:     <ticket-id>
Stage:      <current stage>
Branch:     <git branch>
Started:    <date>
Review loops: <done> / <max>
God mode:   <yes/no>

Plan:       docs/plans/<ticket>.md
Reviews:    .claude/rdev/review-<ticket>-*.md
```

Also check for any review files and summarize findings.
