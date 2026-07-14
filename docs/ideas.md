# Ideas parking lot

Not commitments — things worth revisiting. Date each entry.

## 2026-07-12 · Remote captain access
The first mate / captain is a plain Claude Code session in tmux window 0, so
remote access comes free two ways: (1) `tmux attach` from any device over SSH,
(2) **Claude Code remote control** — attach to the same live session from
claude.ai/code on another device. Design attention items so they read well on
a small screen (short summary + inline-answerable). No build needed until we
want push-to-phone.

## 2026-07-12 · Daily-aid agent (separate from first mate)
The "D" role deliberately kept OUT of the first mate: a standing personal
agent for Linear triage, Slack conversation digestion, daily prep ("what
should I look at today?"). Different context, tools, and trust envelope than
fleet management. Candidate substrate: **Hermes agent** (research what it
actually offers before building — don't assume). Builds on Kun's pattern of
role-separated agents.

## 2026-07-14 · Firstmate loot list (from docs/refs/firstmate-evaluation.md)
Verdict was borrow-don't-adopt; the borrowing is parked here, priority order:
1. **Turn-end guard** (highest impact): Claude Code Stop hook that BLOCKS an agent
   ending its turn while work is in flight and no live watcher exists (exit 2 +
   stderr; `stop_hook_active` loop guard). Port to coulson (unworked queue) and
   coordinators (mid-stage without state.attention). ~1-2 days.
2. Absorb-if-provably-working classification in rfleet (kill false stuck/died wakes).
3. Append-only status logs + durable wake queue (replace snapshot diffing if it
   ever drops transitions).
4. herdr `pane.agent_status_changed` event push in rfleet (sub-second escalation).
5. Idle-backoff heartbeat (15s → minutes when fleet quiet).
Reference clone: re-clone kunchenguid/firstmate when porting (bin/fm-turnend-guard.sh,
bin/fm-classify-lib.sh, bin/fm-wake-lib.sh, docs/herdr-backend.md).

## 2026-07-14 · Linux portability shim
~90% of SHIELD is portable by construction (bash+jq+git+gh+claude, markdown agents/
playbook, JSON queue, python rusage). The macOS crust is four items, all localized:
terminal-notifier (→ notify-send), launchd plist/launchctl in rcaptain (→ systemd
user unit, Restart=always), BSD `stat -f %m` (→ GNU `stat -c %Y`), Chrome app path
in rqa-browser (→ google-chrome/chromium on PATH). Plan: add a platform shim to
_rdev_lib.sh — rdev_notify(), rdev_mtime(), rdev_chrome_bin(), rdev_install_service()
— and switch all callers. ~1 day. Real unknowns: herdr on Linux (else rdev-mux needs
its tmux backend), and the target machine's dev-container setup. Pairs with the
remote-captain idea: a Linux box running the fleet 24/7, attached via Claude Code
remote control.
