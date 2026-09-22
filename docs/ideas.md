# Ideas parking lot

Not commitments — things worth revisiting. Date each entry. (Entries before the
2026-09 rename use the old `r*` command names; mapped to `shield <verb>` below.)

## 2026-07-12 · Remote captain access
The first mate / captain is a plain Claude Code session in a Herdr tab, so
remote access comes free two ways: (1) attach to Herdr from any device over SSH,
(2) **Claude Code remote control** — attach to the same live session from
claude.ai/code on another device. Design attention items so they read well on
a small screen (short summary + inline-answerable). No build needed until we
want push-to-phone.

## 2026-07-12 · Daily-aid agent (separate from first mate)
The "D" role deliberately kept OUT of the first mate: a standing personal
agent for ticket triage, Slack conversation digestion, daily prep ("what
should I look at today?"). Different context, tools, and trust envelope than
fleet management. Candidate substrate: **Hermes agent** (research what it
actually offers before building — don't assume). Builds on Kun's pattern of
role-separated agents.

## 2026-07-14 · Firstmate loot list (from docs/archive/refs/firstmate-evaluation.md)
Verdict was borrow-don't-adopt; the borrowing is parked here, priority order:
1. **Turn-end guard** (highest impact): Claude Code Stop hook that BLOCKS an agent
   ending its turn while work is in flight and no live watcher exists (exit 2 +
   stderr; `stop_hook_active` loop guard). Port to coulson (unworked queue) and
   coordinators (mid-stage without state.attention). ~1-2 days.
2. Absorb-if-provably-working classification in the watcher (kill false stuck/died wakes).
3. Append-only status logs + durable wake queue (replace snapshot diffing if it
   ever drops transitions).
4. herdr `pane.agent_status_changed` event push in the watcher (sub-second escalation).
5. Idle-backoff heartbeat (15s → minutes when fleet quiet).
Reference clone: re-clone kunchenguid/firstmate when porting (bin/fm-turnend-guard.sh,
bin/fm-classify-lib.sh, bin/fm-wake-lib.sh, docs/herdr-backend.md).

## 2026-07-14 · Linux portability shim
~90% of SHIELD is portable by construction (bash+jq+git+gh+claude, markdown agents/
playbook, JSON queue, python rusage). The macOS crust is four items, all localized:
terminal-notifier (→ notify-send), launchd plist/launchctl in shield-coulson (→ systemd
user unit, Restart=always), BSD `stat -f %m` (→ GNU `stat -c %Y`), Chrome app path
in shield-browser (→ google-chrome/chromium on PATH). Plan: add a platform shim to
libexec/_lib.sh — shield_notify(), shield_mtime(), shield_chrome_bin(), shield_install_service()
— and switch all callers. ~1 day. Real unknowns: herdr on Linux (else shield mux needs
another backend), and the target machine's dev-container setup. Pairs with the
remote-captain idea: a Linux box running the fleet 24/7, attached via Claude Code
remote control.

## 2026-07-21 · Browser QA can't parallelize (shared-profile lock)
Streams doing browser QA all contend for the single shared QA Chrome profile
(`~/.shield/qa-chrome`, :9222) — one stream holds it, the rest block. With ~15
concurrent streams this recurs constantly: four streams in one week stalled a QA
round on "browser profile locked by another stream."
Fix options: per-stream browser profiles (each stream its own :92xx + profile
dir), or a QA-browser lease/queue so streams serialize cleanly instead of racing
(and killing each other's sessions during cleanup — that's how the Playwright MCP
got killed mid-run once). Pairs with the playwright-fallthrough item below.

## 2026-07-21 · Streams fall through to Playwright and hit the OAuth wall
The qa skill (Phase 0.5) orders browser mechanisms: **chrome-devtools MCP preferred**
(attached to the shared, already-authed QA Chrome via `shield browser`), **playwright
only as fallback** — and playwright "may launch without the shared profile," i.e. it
hits the SSO/Google login wall. But streams keep reaching for playwright anyway
("isolated mode hits the OAuth wall", on more than one stream), turning a should-be-
authed QA into a manual-login escalation. Likely root cause: chrome-devtools MCP isn't
reliably available in the stream session, so they silently fall through to option 2.
Fix: make chrome-devtools MCP reliably present in every stream session (register it in
the stream's `.mcp.json` / sync-skills-style, like the flat-skills fix), so the
preferred authed path actually works and playwright stays a true last resort. Sharpen
the skill wording so a fall-through is loud (say *why* it fell through), not silent.

## 2026-07-31 · Corrupt state.json bricks shield clean (and shield status)
`shield clean` reads a stream's `.claude/shield/state.json` via `jq` up front (mode, pr_number,
branch). If that JSON is malformed, jq errors and it bails **without
removing anything** — the worktree/branch/tab get stranded and can't be closed through
the normal path. Hit 2026-07-31 on `tiptap-ai-server-toolkit-experiment`: state.json
had a parse error (~line 52), so clean choked and left the worktree; had to remove it
by hand (`git worktree remove --force` + `git branch -D` + `shield mux kill --tab`). Same
corruption also makes `shield status` print the stream with no stage (jq errors mid-table).
Fix: harden `shield clean` (and status's per-stream read) to tolerate an unparseable
state.json — fall back to sane defaults (mode=worktree, derive branch from git) and
still remove the worktree/branch/tab, or at least fail with a clear "corrupt state,
re-run with --force-nostate" path instead of a raw jq error. Bonus: a `state.json`
write that's atomic (write-temp-then-rename) would stop the corruption happening when a
coordinator is killed mid-write.
