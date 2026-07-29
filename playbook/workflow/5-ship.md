# Stage 5 — Ship

Goal: a PR that a reviewer can judge on evidence, and a comment loop run to
completion.

## Open (or un-draft) the PR

1. Push the branch: `git push -u origin <branch>`.
2. If a draft PR exists from QA, mark it ready; otherwise create one.
   Follow the PR conventions in CONTRIBUTING.md.
3. The description must include:
   - **Ticket link** (Linear).
   - **Summary** — what changed and why, from the plan.
   - **Key changes** — the notable files/decisions.
   - **Evidence** — proof it works, captured during QA. Required, not
     optional — reviewers judge proof, not just diffs:
     - **In the PR body**: a "What was tested" section — which interfaces
       were exercised, the steps walked, and the results — with text
       evidence inline (API/MCP responses, log excerpts, test output).
     - **Images/video go to the ticket, not the repo**: upload screenshots
       or recordings as a QA comment on the Linear ticket, and link that
       comment from the PR's evidence section. Never commit evidence files
       into the repository.

## Comment rounds

Bots and humans will review. Handle comments in rounds, **until a round
brings no new comments** — no fixed cap. (In Claude Code setups this loop
is the `fix-pr` skill.)

1. **Wait** for reviews to land (bots take a few minutes after each push).
2. **Triage every comment** with the `receiving-code-review` discipline
   (repo skill) — verify against the code before acting, no performative
   agreement, push back with reasons when a reviewer is wrong: real issue →
   fix it; misunderstanding → explain; out of scope → say so and link the
   ticket that should own it.
3. **Review the fixes** — fresh eyes, same as stage 3. No unreviewed code
   moves forward, even here. If a fix could affect functionality, re-run
   the relevant QA test plan steps too (The Rule from workflow.md).
4. **Respond to every comment** and resolve settled threads — no silent
   ignores.
5. **Push the fixes** in one batch, which triggers the next review round.

If rounds keep producing comments without converging, escalate to a human
rather than looping forever.

## Done — the closing move

Update the plan's **Progress** section every comment round (rounds span
sessions by design — the Progress log is how the next session knows which
rounds already ran). When comment rounds go quiet, set `stage: done` in
Progress, then: **request review from a human on GitHub**
(the ticket owner or the repo's reviewer conventions) so the PR lands in
someone's queue rather than floating. Ticket lifecycle automation handles
phase movement via the PR–ticket link.

The agent **never merges**. Merge is a human decision (and branch
protection enforces it).

## After dev-verified — two human follow-ups the agent tees up

1. **Demo video (Supercut)** — if the change has a user-experience
   component (feature of any size, or a UX-affecting bug fix), the
   developer records a short demo on the **Railway preview** using
   Supercut and posts it. The agent doesn't record it — it *tees it up*:
   flag "demo needed" in its closing hand-off to the human, and persist
   that it's pending so a later session knows.
2. **Dogfood on dev1** — the work is dogfooded in the dev1 environment.
   Once the demo (if needed) is posted and review is underway, the work
   can be called **ready for dev1** per team convention.

Done = comments addressed, evidence attached, CI green, human review
requested, demo/dev1 follow-ups flagged.
