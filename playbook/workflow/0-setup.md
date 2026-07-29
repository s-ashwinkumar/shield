# Stage 0 — Set up

Goal: turn "some ask" into classified, tracked, workspace-ready work —
before anyone forms an opinion about solutions. This stage is orientation
and triage; nothing here is about *how* to solve anything.

## Steps

0. **Resume check — before anything else.** If `docs/plans/<ticket-id>.md`
   exists and its **Progress** section (see [stage 1](1-plan.md)) is not
   `stage: done`, this work is already mid-pipeline: read the plan and the
   Progress log, then **resume at the recorded stage and round — do not
   restart**. In particular, code that exists but whose Progress shows no
   clean review round is *unreviewed* — it goes through stage 3 before
   anything else moves forward. Only when there is no plan file (or no
   Progress section) is this a fresh start.
1. **Read the ticket fully** — title, description, **comments**, labels,
   linked docs from Linear. Don't start from the title alone; comments often
   change the scope. ⚠️ Fetching the issue usually does NOT include its
   comments (Linear's `get_issue` returns only the description) — fetch the
   comment thread explicitly (`list_comments` or your integration's
   equivalent) and read all of it before forming a view of the work.
2. **Mark the ticket started** — move it to In Progress (or your tracker's
   equivalent) if it isn't already; don't rely on push-triggered automation,
   which fires much later than the work actually starts.
3. **Get on the ticket's branch.** Use the branch name Linear generated for
   the ticket (the "copy git branch name" value). Never work on `main`.
   - If a placeholder branch was created for you (e.g. `stream/<ticket-id>`),
     rename it to the Linear branch name: `git branch -m <old> <new>`.
   - If you (or the tool) already picked a deliberate custom name, keep it.
4. **Persist the context in the repo** so any tool or person can resume:
   - Ticket summary → keep it with your working notes or at the top of the
     plan file (next stage).
   - The plan itself lives at `docs/plans/<ticket-id>.md` (stage 1).
5. **Summarize back**: state the ticket's goal and your initial understanding
   in one or two sentences before planning. If that summary is wrong, better
   to find out now.

## Triage — classify the work before planning

State these three things explicitly; [stage 1](1-plan.md) uses them:

1. **Ticket: exists / missing.**
   Missing → stop and ask the requester for a ticket to be created (or
   offer to create it in Linear). Branch names, the plan file, and the PR
   all key off the ticket ID — don't proceed without one.

2. **Spec quality: well-spec'd / needs clarification.**
   Well-spec'd = the ticket already answers what, why, how, and the edge
   cases. → Stage 1 skips clarifying questions and translates the spec
   straight into the plan file (the human plan-approval gate still applies).
   Otherwise → normal planning with 1–2 clarifying questions.

3. **Size: lightweight / design.**
   Lightweight = bug or small focused change. Design = larger feature or
   multi-service change. → picks the stage 1 planning mode.

## Exit

You are on the ticket's branch, you can say in plain words what the ticket
needs and which services (webui / railsapi / mlai / mcpservers) it likely
touches, and the three triage calls are stated. → [Stage 1: Plan](1-plan.md)
