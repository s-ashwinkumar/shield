# Stage 3 — Review

Goal: an independent, fresh-eyes review of everything on the branch before it
is QA'd or shipped. Every pass through Build — the first one and every batch
of QA fixes — goes through this stage.

## Fresh eyes — the one non-negotiable

The reviewer must not be the author. An author reviewing its own
just-written code rubber-stamps its own assumptions.

In agent terms, the standard is a **different model family** than the one
that wrote the code — every harness can do this:

- An agent harness that dispatches subagents: dispatch the review to a
  different provider's model (e.g. Claude wrote it → an OpenAI model
  reviews it).
- A harness with a model switcher (Cursor, local or remote): switch to a
  different model family for the review turn, in a fresh conversation.
- Only when a different family is genuinely unavailable, the minimum bar is
  a **fresh session/context** of the same model that has not seen the
  implementation happen.

## What the reviewer gets

- The diff: `git diff main...HEAD`
- The ticket scope in 1–2 sentences (from the plan)
- Nothing else — no implementation narrative, no "here's why I did it this
  way". The code has to stand on its own.

## What the reviewer produces

Findings categorized by severity, each with `file:line`:

- **Critical** — must fix: bugs, security issues, data loss.
- **Important** — should fix: broken logic, missing error handling in new code.
- **Minor** — nice to have.

Scope discipline: only flag issues **within or directly caused by this
change**. Pre-existing problems and out-of-scope improvements are noted at
most as a footnote, never as findings.

## The fix loop

1. Review produces findings.
2. Send **all Critical and Important** findings back to
   [Build](2-build.md) as one batch — no triage, no cherry-picking; trust
   the review. Build (the builder agent, in agent setups) fixes and commits.
   When implementing, apply the `receiving-code-review` discipline (repo
   skill): verify each finding against the code before implementing —
   reviewers can be wrong. A refuted finding gets a documented pushback in
   the round notes, never a silent omission.
3. Re-review (fresh eyes again).

**Exit the loop when any of these holds:**
- Clean: no Critical/Important findings (Minor-only counts as clean).
- The same Critical/Important findings repeat two rounds in a row — the fix
  isn't landing; stop looping and escalate to a human.
- A sensible max round count (default 3) is reached — escalate.

## Exit

Review is clean. Record the round in the plan's **Progress** section —
every review round gets a log line (findings count, or clean + the commit
it cleared). → [Stage 4: QA](4-qa.md) — every change gets a QA round;
only the method differs by change type.
