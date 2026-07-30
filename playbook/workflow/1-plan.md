# Stage 1 — Plan

Goal: a written, human-approved plan in `docs/plans/<ticket-id>.md` before any
implementation. The [stage 0 triage](0-setup.md) picks the mode:

- **Size** picks Lightweight vs Design below.
- **Well-spec'd tickets** fast-path: skip the clarifying questions and
  translate the ticket's spec straight into the plan file. The plan file is
  never skipped — Build, QA, and Ship all read from it. The approval gate
  isn't skipped either, but a well-spec'd ticket can satisfy it via
  **spec-as-approval** (path 4 below): interactively it's a quick
  confirmation; headless, the agent posts the plan to the ticket and
  proceeds.
- No ticket? You shouldn't be here — go back to stage 0.

## Lightweight (bugs, small tickets, focused changes)

1. Explore the relevant code. Read the `AGENTS.md` of every service you'll
   touch (webui / railsapi / mlai / mcpservers) — they hold the conventions
   and test commands.
2. Ask the ticket owner **1–2 clarifying questions** if anything is ambiguous
   (not ten).
3. Propose **one recommended approach** — no need for alternatives.
4. Write the plan (template below).

## Design (larger features, multi-service changes)

1. Explore project context: code, docs, recent commits, `AGENTS.md` files.
2. Clarify purpose, constraints, and success criteria with the ticket owner —
   one question at a time.
3. Propose **2–3 approaches with trade-offs** and a recommendation; get
   agreement on one.
4. Write a short design doc (`docs/plans/<ticket-id>-design.md`), review it
   yourself for contradictions/placeholders, then have the owner review it.
5. Write the implementation plan from the design: bite-sized tasks, exact
   file paths, tests where they add real protection (builder's judgment),
   no placeholders (no TBD / "similar to task N").

## The plan file — `docs/plans/<ticket-id>.md`

Every plan, either size, contains:

- **Context** — one paragraph: what the ticket asks and why.
- **Approach** — the decided approach in a few sentences.
- **Tasks** — numbered, each independently completable and committable.
- **Definition of done** — the observable outcomes that mean "finished"
  (tests passing, behavior visible, etc.).
- **Progress** — the workflow's state, kept current from approval to done
  (this is what lets any fresh session resume instead of restarting; see
  [stage 0](0-setup.md)). Update it at **every stage transition and every
  loop round**, and commit it with the work:

  ```markdown
  ## Progress
  <!-- update at every stage transition and loop round -->
  - stage: 3-review (round 2 of 3)   <!-- or: done -->
  - mode: interactive                <!-- or: autonomous (see workflow.md) -->
  - plan approved: 2026-07-28, interactive (owner)
  - log:
    - 2026-07-28 plan approved; build started
    - 2026-07-28 build done (tests green); review round 1: 2 findings -> build
    - 2026-07-29 fixes in; review round 2 in progress
  ```

- **QA test plan** — required for **every** plan. It answers: "what would a
  careful manual tester do to prove this works?" — through the change's
  real interface (browser, API call, MCP client call, job trigger — see the
  method menu in [4-qa.md](4-qa.md)). Write steps for *every* interface the
  change touches. Not unit/integration tests — those belong to Build.
  Tag steps a human can verify faster than any automation (flicker,
  animation, subjective look/feel) as `human-verify` — stage 4 hands those
  to the human instead of grinding on them.

  UI change:
  ```
  ## QA Test Plan
  - Page: /path-to-test
  - Steps:
    1. Navigate to /path
    2. Do X
    3. Verify Y shows/changes/appears
  - Expected: [what correct looks like]
  ```

  API / MCP / job change:
  ```
  ## QA Test Plan
  - Interface: [endpoint / MCP tool / job / command under test]
  - Steps:
    1. Call X with realistic payload Y (or trigger job Z)
    2. Inspect response / resulting app state / logs
  - Expected: [status, payload shape, side effects]
  ```

## Exit — hard gate

**A human-approved plan must exist before Build starts.** The gate is a
state condition, not necessarily a live conversation.

**Raise the gate when — and only when — the plan is ready.** Once the plan
file is written and you are presenting it for approval (paths 1 and 3 below),
signal the human through whatever channel the harness provides — say so in
the live conversation, send a notification, or post the plan to the ticket.
Don't treat "I entered the plan stage" as having asked for approval; only an
explicit "plan ready for your review" counts. The pre-approved (2) and
spec-as-approval (4) paths proceed without waiting.

It can be satisfied four ways:

1. **Interactive**: the plan is drafted and approved live in the session
   (the common case for a person driving a tool).
2. **Pre-approved**: the work arrives with an approved plan already in
   `docs/plans/<ticket-id>.md` (e.g. a cloud/headless agent picking up a
   ticket where planning finished earlier). Triage finds it → gate already
   satisfied → go straight to Build.
3. **Asynchronous**: a headless agent drafts the plan, posts it to the
   ticket, and waits for a human to approve with a comment before building.
4. **Spec-as-approval** (the well-spec'd hatch): the ticket was authored or
   groomed by a human and already answers what, why, how, edge cases, and
   acceptance criteria — the human decision the gate protects has already
   happened. The agent translates the spec into the plan file, **posts the
   derived plan to the ticket as a comment** (transparency: humans can see
   it and interrupt, but the agent doesn't block), and proceeds to Build.
   This path is valid ONLY if nothing material had to be guessed during
   translation — one material guess or gap → downgrade to path 3 and wait.

If none of these can be met (no approved plan, ticket too thin to draft one
for async approval), **do not guess** — comment on the ticket with what's
missing and stop. → [Stage 2: Build](2-build.md)
