# firstmate evaluation — adopt, borrow, or ignore? (2026-07-14)

Evaluated kunchenguid/firstmate (clone at /tmp/firstmate-eval, single squashed import
dated 2026-07-14, 68 test scripts, verification notes 2026-07-04..07-12). Full agent
report summarized here. Question: should SHIELD adopt it instead of coulson/rfleet?

## Verdict: BORROW, don't adopt. Keep SHIELD's own first mate.

Wholesale adoption fights the design: firstmate supervises *generic* crewmates that
speak its status-verb vocabulary (`done/failed/blocked/needs-decision/paused`) in
treehouse worktrees, shipping via its modes (no-mistakes/direct-PR/local-only). Our
value is the OPPOSITE end: crewmates are rstream streams running OUR
coordinator+playbook (plan gate, cross-model review, preview QA, Linear, demo/dev1
flags). The dispatch seam for a custom spawn command doesn't exist (deliberate
simplification) — we'd wrap/fork `fm-spawn.sh` and remap vocabularies, then keep
fighting it. Also: it wants to BE the repo you run in (agent distro, FM_HOME, its
AGENTS.md as law) — a second sovereign next to SHIELD.

Validation: its watcher architecture (bash poll loop + wake queue + heartbeat backstop
+ zero-token supervision) is the same shape as rfleet — we converged independently.

## The loot list (port into SHIELD, priority order)

1. **Turn-end guard** (`bin/fm-turnend-guard.sh` + `.claude/settings.json` Stop hook) —
   HIGH IMPACT. A Stop hook that blocks an agent ending its turn "blind" while work is
   in flight and no live watcher exists (exit 2 + stderr blocks; `stop_hook_active`
   loop guard; verified on Claude Code 2.1.204). Port targets: coulson (can't stop
   with unworked queue), coordinators (can't stop mid-stage without state.attention
   written). Their origin story: an unwatched gate sat 9 hours — exactly our dead-man
   scenario, solved deterministically at the harness layer.
2. **Absorb-if-provably-working** (`bin/fm-classify-lib.sh`) — before surfacing a
   silent/stale stream, check "provably busy" signals (backend busy state, active
   pipeline step). Kills false wakes. rfleet's stuck/died classification should adopt.
3. **Append-only status logs + durable wake queue** (`state/<id>.status`,
   `state/.wake-queue`) — wake events as append-only history vs our snapshot-diffing;
   more durable, no lost transitions between scans. Medium effort; consider when
   state.json diffing shows gaps.
4. **herdr native event push** (`docs/herdr-backend.md`) — subscribe
   `pane.agent_status_changed` (protocol ≥16) for sub-second blocked-escalation
   instead of pure 15s polling. rfleet upgrade when herdr backend stabilizes.
5. **Heartbeat with backoff** (600s→7200s) — rfleet's fixed 15s scan could back off
   when fleet is idle.
6. Patterns to remember, not port now: secondmate isolated homes (if we ever want
   domain supervisors), backend abstraction dispatcher (if we outgrow herdr),
   dispatch profiles as natural-language rules, hermetic test style
   (`fm-turnend-guard.test.sh`).

## Honest process note

We designed/built coulson+rfleet without reading this repo (only the video). The
integration-coupling instinct proved correct, but the watcher and its hardening
(turn-end guard especially) existed and were verified before we started — reading
first would have changed the build order (guard first, watcher borrowed). Lesson
already in memory: verify sources before build decisions.

Clone kept at /tmp/firstmate-eval (disposable; re-clone when porting loot).
