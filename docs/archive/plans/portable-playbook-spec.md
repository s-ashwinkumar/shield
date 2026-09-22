# Spec: Portable dev-workflow playbook for the rhythms repo

**Date:** 2026-07-09 · **Status:** draft, awaiting user review

## Goal

Extract the "how we ship a ticket" recipe out of rdev's `agents/coordinator.md` into a
tool-neutral document inside the rhythms repo, so anyone — in Cursor, Codex, or Claude Code —
can follow the same workflow. rdev keeps only the Claude-specific machinery (subagent dispatch,
`state.json`, `rt*` scripts, notifications, god mode) and *references* the playbook instead of
containing it.

## Rollout: opt-in (decided 2026-07-09)

- The playbook ships as `rhythms/docs/workflow.md` but is **NOT referenced from AGENTS.md**
  and has **no per-tool entry points** (no Cursor rule, no Codex prompt).
- Ashwin drives it via the rdev scripts; teammates invoke it explicitly
  ("follow docs/workflow.md for this ticket").
- Promote to standard (add the AGENTS.md pointer) only after a few people adopt it.

## Deliverable 1: the playbook (thin flow doc + one detail file per stage)

Structure (decided 2026-07-09 — flow separate from details):

```
rhythms/docs/workflow.md            # THIN: the flow only — stage sequence, gates,
                                    # entry/exit criteria, links to stage files
rhythms/docs/workflow/
  0-setup.md                        # ticket intake, branch naming, context persistence
  1-plan.md                         # lightweight vs design planning, QA test plan, DoD
  2-build.md                        # task-by-task, TDD, testing tiers / DB isolation
  3-review.md                       # fresh-eyes review, severity levels, fix loop, exits
  4-qa.md                           # webui check, draft PR → Railway preview, human confirm
  5-ship.md                         # PR contents, evidence artifact, comment rounds
```

**Plain markdown, NOT skills** (decided): skills are Claude-centric and auto-trigger, which
conflicts with tool-neutrality and the opt-in rollout. Plain files are readable by every
harness (Cursor, Codex, Claude). If the playbook becomes the standard later, stage files can
be wrapped as skills without rewriting — the content is the same.

Tool-neutral, plain-English stages. Content extracted from `coordinator.md` with two changes
approved 2026-07-09 (from `docs/refs/transcript-lessons.md`):

- **Review before QA** (was: QA before review). Rationale: reviewer reads fresh code before
  it's declared working; QA validates the final state once, after review fixes land.
- **Evidence artifact required in every PR** — screenshot/video for UI changes, test output or
  log for backend. Reviewers judge proof, not just diffs.

Refinements added during review (2026-07-09, user):

- **QA is for every change, not just UI.** Every plan carries a QA test plan; backend changes
  QA by exercising real behavior (API/jobs/logs), UI changes QA on the Railway preview.
- **Batched outer QA loop:** a QA round notes ALL issues without fixing; the batch goes back
  to Build as requirements → Review → another full QA round. Never fix one-by-one mid-round.
- **3-round caps with human escalation** on BOTH the review-fix loop and the outer QA loop.
- Loops are documented explicitly in workflow.md (plan-approval, task, review-fix, outer QA,
  comment rounds, re-plan escape hatch).

From the user's flow diagram (2026-07-09):

- **Build is the only stage that writes code** — review findings and QA issues both loop back
  into Build as batches; Review/QA are pure detectors.
- **One human gate: plan approval.** No QA confirm gate — QA clean flows straight to Ship;
  humans engage via escalation (non-converging loops) and PR review of the evidence.
- **Ticket optional** in Setup — ad-hoc work follows the same flow with a written one-line goal.
- **Comment rounds uncapped** — run until a round brings no new comments (rdev: the fix-pr
  skill); comment fixes also get a fresh-eyes review before push.
- Re-plan hatch kept: for "the approach is wrong" discoveries, not for tasks taking longer.

### Stages

**Stage 0 — Set up.** Read the ticket fully (Linear). Branch named to match the ticket's
Linear branch name; never work on main. Keep ticket context + plan in the repo so any tool
can resume.

**Stage 1 — Plan.** Two sizes:
- *Lightweight* (bugs, small changes): explore code + AGENTS.md for touched services, 1-2
  clarifying questions, one recommended approach.
- *Design* (larger/multi-service): 2-3 approaches with trade-offs → design doc → detailed
  step-by-step implementation plan (no placeholders, test-first steps).
Either way: concrete tasks, definition of done, and — if UI is touched — a QA test plan
(page, steps, expected result). Save to `docs/plans/<ticket>.md`. Human approves before build.

**Stage 2 — Build.** Task by task from the plan. Tests first where practical. Local tests use
per-worktree isolated DBs (Tier 1/2 — `RDEV_DB_SUFFIX`; see testing tiers section). Commit
per task. Definition of done from the plan must hold.

**Stage 3 — Independent review.** Fresh eyes: a different model, or at minimum a fresh
session that hasn't seen the implementation. Input = diff vs main + 1-2 sentence ticket scope.
Flag Critical / Important / Minor, in-scope only. Fix Critical+Important, re-review; exit when
clean, or when the same issues repeat (escalate to human).

**Stage 4 — QA on the preview.** Only if `webui/` files changed (`git diff main --name-only |
grep ^webui/`). Open a **draft PR** to trigger the Railway preview build; QA the plan's test
steps on `https://webui-rhythms-pr-<PR>.up.railway.app/`. Human confirms before shipping.
Backend-only changes skip this stage.

**Stage 5 — Ship.** Push; open or un-draft the PR. Description: ticket link, summary, key
changes, **evidence artifact** (screenshot/video for UI, test output/log for backend). Follow
CONTRIBUTING.md conventions. Then handle PR comments in rounds until quiet: fix real issues,
respond to every comment, resolve threads.

## Deliverable 2: rdev coordinator changes

- `agents/coordinator.md` slims down: stages now say "follow `docs/workflow.md` stage N" and
  keep only harness mechanics — state.json transitions, builder/reviewer/codex-rescue dispatch,
  gates, god mode, terminal-notifier.
- **Stage reorder to match the playbook:** build → code review (codex loop) → QA gate →
  PR/ship. (Today QA is at the end of Stage 2, before review.)
- **Evidence step added** to the PR stage (attach screenshot/test output).
- `skills/parallel-testing.md` checked for consistency with the new ordering; update if needed.

## Where the rhythms change lands

Branch `rdev/parallel-dev-infra` (worktree `~/code/rhythms-rdev-infra`), which already holds
3 rhythms infra changes. **Freshen with `git merge origin/main` before writing.** No PR yet.

## Out of scope (parked / later)

- AGENTS.md pointer and per-tool entry points (post-adoption).
- gnhf-style capped autonomous loops (Phase 2).
- lavish HTML planning (standalone quick-win, separate).
- local promote/lease (`rpromote`/`rlocal`) — parked.
