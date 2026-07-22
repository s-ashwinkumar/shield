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

## 2026-07-21 · Browser QA can't parallelize (shared-profile lock)
Streams doing browser QA all contend for the single shared QA Chrome profile
(`~/.rdev/qa-chrome`, :9222) — one stream holds it, the rest block. With ~15
concurrent streams this recurs constantly: USENG-1014, USENG-888, USENG-1132,
OKR-4983 all stalled a QA round on "browser profile locked by another stream."
Fix options: per-stream browser profiles (each stream its own :92xx + profile
dir), or a QA-browser lease/queue so streams serialize cleanly instead of racing
(and killing each other's sessions during cleanup — that's how the Playwright MCP
got killed mid-run once). Pairs with the playwright-fallthrough item below.

## 2026-07-21 · Streams fall through to Playwright and hit the OAuth wall
The qa skill (Phase 0.5) orders browser mechanisms: **chrome-devtools MCP preferred**
(attached to the shared, already-authed QA Chrome via `rqa-browser`), **playwright
only as fallback** — and playwright "may launch without the shared profile," i.e. it
hits the WorkOS/Google login wall. But streams keep reaching for playwright anyway
(OKR-4983: "isolated mode hits the OAuth wall"; USENG-1014 same), turning a should-be-
authed QA into a manual-login escalation. Likely root cause: chrome-devtools MCP isn't
reliably available in the stream session, so they silently fall through to option 2.
Fix: make chrome-devtools MCP reliably present in every stream session (register it in
the stream's `.mcp.json` / sync-skills-style, like the flat-skills fix), so the
preferred authed path actually works and playwright stays a true last resort. Sharpen
the skill wording so a fall-through is loud (say *why* it fell through), not silent.
