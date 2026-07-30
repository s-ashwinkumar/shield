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
2. **If it's a BUG: get the reproduction steps straight first.** Before any
   planning, establish concrete repro steps — from the ticket/comments if
   they're there, otherwise by reproducing it yourself end-to-end, as close
   to how the user hit it as possible (preview/dev environment, real
   interface). A bug you can't reproduce is a bug you can't prove fixed —
   the repro steps become the core of the plan's QA test plan. Only if
   reproduction is genuinely impossible (transient conditions, production
   data or access you don't have) record *why* and what evidence stands in
   instead (logs, traces, screenshots from the reporter) — and say so
   explicitly rather than quietly planning a fix from a description.
3. **Mark the ticket started** — move it to In Progress (or your tracker's
   equivalent) if it isn't already; don't rely on push-triggered automation,
   which fires much later than the work actually starts.
4. **Get on the ticket's branch.** Use the branch name Linear generated for
   the ticket (the "copy git branch name" value). Never work on `main`.
   - If a placeholder branch was created for you (e.g. `stream/<ticket-id>`),
     rename it to the Linear branch name: `git branch -m <old> <new>`.
   - If you (or the tool) already picked a deliberate custom name, keep it.
5. **Persist the context in the repo** so any tool or person can resume:
   - Ticket summary → keep it with your working notes or at the top of the
     plan file (next stage).
   - The plan itself lives at `docs/plans/<ticket-id>.md` (stage 1).
6. **Summarize back**: state the ticket's goal and your initial understanding
   in one or two sentences before planning. If that summary is wrong, better
   to find out now.

## Triage — classify the work before planning

State these four things explicitly; [stage 1](1-plan.md) uses them:

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

4. **Environment: ready / needs setup / CI-only.**
   Probe: can you run the smallest test + lint command for the services this
   ticket touches? Not ready → find the repo's documented environment path
   that matches *where you are standing* (devcontainer, worktree inside the
   repo, sibling worktree, bare host) and follow it — **never improvise
   installs package-by-package**. If the documented path doesn't converge in
   ~2 attempts, stop: declare **CI-only** (push early; green CI on the draft
   PR is how tests pass) or hand the human a specific ask. Record the call
   (and why) in Progress.

## Exit

You are on the ticket's branch, you can say in plain words what the ticket
needs and which services (webui / railsapi / mlai / mcpservers) it likely
touches, and the four triage calls are stated. → [Stage 1: Plan](1-plan.md)
