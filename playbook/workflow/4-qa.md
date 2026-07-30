# Stage 4 — QA

Goal: prove the change works in a real environment by executing the plan's
QA test plan. **Every change gets a QA round** — UI or backend; only the
method differs.

## The one rule: QA in whole rounds, never fix-by-fix

A QA round walks the **entire** QA test plan from `docs/plans/<ticket-id>.md`
and **notes every issue found without stopping to fix anything**. When the
round is complete, the batch of issues goes back to
[Build](2-build.md) as a requirements list, the fixes pass through
[Review](3-review.md), and then QA runs another **full** round.

Fixing bugs one at a time mid-round fragments testing, skips review, and
hides regressions the fix itself introduces. Batch, always.

## What QA is (and isn't)

QA is **what a careful manual tester would do, executed by the agent**:
exercise the change through its *real interface* — the one a user or a
client system actually hits — and observe real behavior. It is NOT a re-run
of the unit/integration tests (those already passed in Build). If your QA
round consists of "the tests pass", you haven't QA'd.

**Use the human when the human is cheaper.** Steps marked `human-verify` in
the QA test plan (flicker, animation, subjective look/feel) go to the human
as a crisp 20-second ask — don't automate them. Same stop-loss mid-round: if
verifying a step needs more than ~2 attempts or elaborate scaffolding, hand
that step to the human and continue the round.

## Method menu — test through whichever interfaces changed

A change can touch several of these; run every row that applies. Always
capture what you observe — it becomes the evidence in
[stage 5](5-ship.md): text outputs (responses, logs, test runs) go in the
PR body's "What was tested" section; screenshots/video get uploaded to the
Linear ticket as a QA comment (never committed to the repo).

| What changed | How to QA it |
|---|---|
| **webui** (pages, components) | Open a real browser on the Railway PR preview and walk the test plan like a user: navigate, click, type, verify what renders. Capture screenshots/video. |
| **HTTP API** (railsapi endpoints) | Call the changed endpoints for real, with realistic payloads — happy path plus the edge cases from the plan. Inspect responses, DB state, and logs. |
| **MCP tools** (mcpservers) | Point the `Rhythms-railway` MCP server at the **preview's** MCP endpoint, reconnect + auth (see **MCP-preview auth** below), then call the changed tools with realistic arguments. Verify the returned payloads AND the side effects in the app (did the document/goal actually change?). |
| **Jobs / pipelines** (mlai, background work) | Trigger the job with a realistic input and watch it run: outputs, logs, resulting state. |
| **CLI / scripts** | Run the command the way a user would, on a realistic case. |

**Environment:** QA runs against the branch's **Railway PR preview, never
a local server, unless the plan explicitly calls for local QA**. The
preview deploys the **whole stack** (webui, railsapi, mlai, mcpservers
from your branch), so every method row above runs against it — UI in the
browser at `https://webui-rhythms-pr-<PR>.up.railway.app/`, APIs/MCP/jobs
against the preview's services. Open a draft PR (if not already open) to
trigger the preview; wait a few minutes for it to deploy.

**Login:** use a browser with a **persistent profile** kept signed into a
test/QA Google account, so OAuth auto-completes on every preview domain
without a human (each PR preview is a new subdomain, but the profile's
Google session carries the flow). A harness whose profile session has
expired escalates once for a re-login rather than failing rounds.

**MCP-preview auth (for MCP-tool changes — do this yourself; escalate only
for the interactive login):** the browser/persistent-profile trick above is
for webui/HTTP QA. MCP QA against the preview needs its own auth flow — the
agent drives it:

1. Preview MCP endpoint = `https://mcpservers-rhythms-pr-<PR>.up.railway.app/rhythms/mcp`.
2. Repoint the **`Rhythms-railway`** MCP server's `url` to that endpoint (in the
   MCP config the session reads).
3. **Reconnect** so the new URL loads — restart the session, or `/mcp`.
4. **Auth (human-in-the-loop — WorkOS OAuth can't be scripted):** open the auth
   URL, complete the WorkOS login, then **select this preview's tenant from the
   dropdown.** Escalate to the human for this click; resume when done.
   - ⚠️ **Fresh-tenant gotcha:** a brand-new preview tenant may **not appear in
     the tenant dropdown** until it's been provisioned by a first webui login.
     If the tenant is missing, log into `https://webui-rhythms-pr-<PR>.up.railway.app/`
     **once** first (that provisions it), then redo the MCP auth — it'll now be
     in the list.
5. Call the changed MCP tools with realistic args; verify payloads AND side
   effects in the app. Point the `Rhythms-railway` MCP back at mainline when done.

**Shared browsers:** if the harness attaches multiple parallel work
streams to one browser instance, keep strict tab discipline — each
ticket's QA runs in its own tab(s), operate only in tabs you opened, and
close them when the round ends.

## Recording issues during a round

For each issue: what you did, what you expected, what actually happened,
and where (page/endpoint). Concrete enough that Build can act on it without
re-discovering it.

## Round limit

Maximum **3 QA rounds**. If the third round still finds issues, the
build↔QA cycle isn't converging — stop looping and escalate to a human
with the full issue history instead of grinding.

## Exit

A full QA round finds **nothing**. Record the round (and its outcome) in the
plan's **Progress** section — every round, clean or not, gets a log line.
→ [Stage 5: Ship](5-ship.md)
(Humans get involved here only via escalation — a non-converging loop —
not as a routine checkpoint; the captured evidence lands in the PR for
human judgment at review time.)
