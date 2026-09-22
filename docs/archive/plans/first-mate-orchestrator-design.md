# First Mate — the rdev orchestrator (design)

**Date:** 2026-07-12 · **Status:** approved in brainstorming (user waived written-spec gate; building)

## Purpose

One agent you talk to as captain, so >10 parallel streams stop fragmenting your attention.
V1 core = **attention routing** (B): the fleet's gates/escalations/follow-ups come TO you, with
context, in one conversation. Plus **A-lite dispatch**: "start USENG-1101" → it runs `rstream`.
NOT in v1: fleet board UI (C — the data feed is built here), gnhf capped loops, the daily-aid
agent (separate build; see docs/ideas.md), remote polish (free via Claude remote control).

Shape validated by Kun's "firstmate": an agent session whose instructions make it a dispatcher
over existing tools. We build our own on rdev's parts — NOT his repo.

## Decisions (from brainstorming, 2026-07-12)

- **Interaction: hybrid by weight.** Small decisions (approve/deny, guidance) relayed inline in
  the captain chat and piped into the stream's pane; heavy interactions (plan iteration, QA
  looks) redirect you to the stream tab.
- **Surface:** captain = persistent Claude session, window `captain` in the rdev herdr/tmux
  session, launched by `rcaptain`. Remote = Claude Code remote control / tmux attach (free).
- **Notifications: first mate is the voice, with a dead-man fallback.** Streams' state changes
  flow through the watcher → captain; a raw `terminal-notifier` fires only if an attention item
  goes unacked for N minutes. (Rollout switches below; coordinators unchanged until switch 3.)
- **Token economics:** detection is 100% programmatic (zero tokens). The captain spends only
  per turn (your messages + watcher wake-ups). Wake-ups are batched; enrichment is bounded;
  LLM polling is forbidden. Streams' own burn is accepted; harness overhead must stay small
  and MEASURED (rusage roles).

## Components

```
streams (coordinators)      rfleet (watcher daemon, bash+jq)      captain (Claude session)
state.json per stream  ──►  scan+diff every ~15s                  window "captain"
  + .attention flag         + herdr agent list/status        ──►  woken by injected line
                            │ writes ~/.rdev/attention/pending/   reads pending queue
                            │ injects wake-up into captain pane   acks (mv to acked/)
                            │ dead-man: unacked N min →           enriches (bounded reads)
                            │   terminal-notifier                 relays via rdev-mux send
                            └ heartbeat file each scan            or redirects you to the tab
```

### rfleet (bin/rfleet) — deterministic watcher, the only always-on piece
- Discovers streams like `rstatus` (worktrees + `.claude/rdev/state.json`).
- Diffs each state vs a cached copy (`~/.rdev/attention/.cache/<stream>.json`).
- Emits **attention items** (JSON files) to `~/.rdev/attention/pending/`:
  - `plan_gate` — stage became `plan` (plan ready for approval)
  - `done_followups` — stage became `done` (carries `demo_required`, `dev1_ready`)
  - coordinator-flagged items — coordinators write `state.attention = {type, summary}` whenever
    they stop/escalate (`review_escalation`, `qa_escalation`, `comments_stuck`, `blocked`, ...)
  - `stuck` — pane output matches rwatch's stuck-prompt patterns (via `rdev-mux read`)
  - `died` — state mid-pipeline but the stream's agent/pane is gone
- One **batched wake-up** per scan with new items: single line sent to the captain agent.
- **Dead-man**: pending item with `acked_at == null` older than `RFLEET_DEADMAN_MIN` (default 10)
  → raw `terminal-notifier`, item marked `escalated_raw`.
- **Auto-cancel**: pending item whose stream state has since moved past the triggering condition
  → moved to `done/` with `outcome: superseded`.
- Heartbeat: touch `~/.rdev/attention/heartbeat` each scan.
- Modes: `RFLEET_ONCE=1` (single scan, for tests), `RFLEET_SHADOW=1` (write items only — no
  wake-ups, no dead-man; rollout switch 1), `RDEV_MUX_BACKEND=echo` (dry-run substrate).

### Attention item schema
```json
{ "id": "<stream>-<type>-<epoch>", "stream": "...", "type": "...",
  "summary": "one line", "created_at": epoch, "acked_at": null,
  "deadman_after_min": 10, "state_snapshot": { "stage": "...", "ticket": "..." } }
```
Lifecycle: `pending/` → captain acks → `acked/` → resolved → `done/` (+outcome note).
Atomic `mv` between dirs; the queue doubles as the future fleet-board feed.

### captain (agents/captain.md) — the only token spender
- Consumes the queue on wake-up or on your message; **re-checks the stream's live state before
  presenting** (stale items die silently).
- Presents by weight: relay small (answer piped via `rdev-mux send --target rdev:<stream>`),
  redirect heavy ("USENG-1101 plan gate — worth a look; window rdev:USENG-1101").
- Dispatch: wraps `rstream` (and can create Linear tickets first per playbook stage 0).
- Cost discipline (hard rules in the agent file): never scan the fleet; bounded enrichment
  (plan summary + ~40 pane lines + the specific artifact); batch answers; keep own state in
  files (`~/.rdev/attention/captain-log.md`) so the session is restartable/`/clear`-safe.
- Reports harness overhead on request / daily one-liner via `rusage --roles`.
- Warns if the rfleet heartbeat is stale.

### rcaptain (bin/rcaptain) — launcher
Ensures `rfleet` is running (respawn if not) → ensures the captain window exists with
`claude --agent captain` (named `rdev:captain`) → prints status. Idempotent.

### rusage --roles — self-metering
Group sessions by name: `rdev:captain` = harness overhead; `rdev:<stream>` = work; other.
Tokens + est. $ per role per day. Pricing moves out of hardcoded constants.

## Coordinator change (small, shadow-safe)
v2 coordinator gains one binding: **whenever you stop to wait or escalate, also write
`state.attention = {type, summary}`; clear it when resuming.** Direct terminal-notifier calls
stay for now (removed at rollout switch 3).

## Failure modes
- Watcher dies → heartbeat stale; rcaptain respawns on next launch; captain warns in
  conversation. Worst case: detection gap, today's behavior on restart.
- Captain dies/compacts → wake-ups land nowhere → dead-man fires raw notifications (today's
  behavior); restart reads pending queue; no memory in the session to lose.
- Handled out-of-band → live-state re-check + auto-cancel.
- Double-processing → atomic mv. Misroute → herdr targets by name + captain echoes target.

## Rollout (3 reversible switches)
1. **Shadow**: `rfleet` in RFLEET_SHADOW; compare items vs today's notifications for a few days.
2. **Captain on top**: talk to it; direct notifications still on.
3. **Flip the voice**: coordinator terminal-notifier moves behind the dead-man.

## Build tasks
1. `bin/rfleet` (+ fixture smoke test, echo backend)
2. `agents/captain.md`
3. `bin/rcaptain`
4. `rusage --roles`
5. coordinator v2 attention-flag binding
6. handover/docs update
