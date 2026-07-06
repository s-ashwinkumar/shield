# Phase 1 · Plan 2 — `rdev-mux` substrate adapter + port stream lifecycle onto Herdr

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce a thin, backend-agnostic multiplexer adapter (`bin/rdev-mux`) that rdev scripts call instead of raw `tmux`, targeting Herdr today; then port `_rdev_lib.sh`'s session helpers and `rstream`'s window/pane/launch block to use it — so a stream spawns as a Herdr **tab** (in the default workspace) with a coordinator agent pane + shell pane, tracked in the blocked/working/done sidebar.

**Architecture:** `rdev-mux` is a single bash CLI. Every verb dispatches through `_mux_run`, which either execs the real backend command (Herdr) or, when `RDEV_MUX_BACKEND=echo`, prints the command it *would* run. That echo backend makes every verb unit-testable without a live server and gives a free `--dry-run`. rdev keeps `git worktree add` + its symlink/agent setup unchanged; only the tmux calls move behind `rdev-mux`. A future `tmux` backend can be added without touching callers.

**Tech Stack:** bash, Herdr ≥ 0.7 CLI (`herdr workspace|agent|pane|worktree|status`), plain-bash test harness (no bats dependency).

## Global Constraints

- **Do not touch `rwatch`** (explicit user decision) and do not change the pipeline stage logic.
- rdev scripts must call **`rdev-mux`**, never `herdr` directly (substrate-agnostic rule).
- Adapter output stays **terse / single-line** (AXI ergonomics rule).
- Backend selected by `RDEV_MUX_BACKEND` env: `herdr` (default) or `echo` (tests/dry-run). Unknown value → error.
- Herdr concepts: tmux *session* → Herdr persistent session (one default workspace, unmanaged); tmux *window per stream* → Herdr **tab per stream**; the 2 panes (coordinator + shell) → panes within that tab. **We do NOT use the workspace concept yet** — tabs live in the default workspace.
- The old iTerm+tmux stack stays untouched; this is additive (`rstream` gains a code path, guarded so the legacy path still works if `RDEV_MUX_BACKEND=tmux-legacy`… out of scope, just don't delete the tmux code — comment it out or branch on backend).
- Preserve existing behavior: worktree at `$WORKTREE_DIR/$NAME`, symlink `docs/plans`, copy agents into `.claude/agents/`, init state, launch coordinator with the same initial prompt.

## File Structure

```
bin/rdev-mux            # NEW — the adapter CLI (backend dispatch + verbs)
bin/_rdev_lib.sh        # MODIFY — session helpers call rdev-mux
bin/rstream             # MODIFY — window/pane/launch block (≈ lines 255-293) → rdev-mux
tests/rdev-mux.test.sh  # NEW — plain-bash tests using RDEV_MUX_BACKEND=echo
```

Responsibility split: `rdev-mux` owns *all* multiplexer command construction. `_rdev_lib.sh`/`rstream` own rdev domain logic (worktree, state, agents, prompts) and call `rdev-mux` verbs.

---

### Task 1: `rdev-mux` skeleton — arg parse, backend dispatch, echo backend

**Files:**
- Create: `bin/rdev-mux`
- Create: `tests/rdev-mux.test.sh`

**Interfaces:**
- Produces: `rdev-mux <verb> [flags]`; `_mux_run <cmd...>` helper; `RDEV_MUX_BACKEND` handling. Later tasks add verbs that call `_mux_run herdr <args...>`.

- [ ] **Step 1: Write the failing test harness + first test**

`tests/rdev-mux.test.sh`:
```bash
#!/usr/bin/env bash
# Plain-bash test harness for rdev-mux (no bats needed).
set -uo pipefail
MUX="$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin" && pwd)/rdev-mux"
PASS=0; FAIL=0
assert_eq() { # assert_eq <desc> <expected> <actual>
  if [[ "$2" == "$3" ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1));
    printf 'FAIL: %s\n  expected: %q\n  actual:   %q\n' "$1" "$2" "$3"; fi
}
assert_contains() { # assert_contains <desc> <needle> <haystack>
  if [[ "$3" == *"$2"* ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1));
    printf 'FAIL: %s\n  needle: %q\n  in:     %q\n' "$1" "$2" "$3"; fi
}

# --- Task 1 ---
out="$(RDEV_MUX_BACKEND=echo "$MUX" _selftest 2>&1)"
assert_eq "echo backend passes args through" "herdr a b c" "$out"
out="$(RDEV_MUX_BACKEND=bogus "$MUX" _selftest 2>&1)"; rc=$?
assert_contains "unknown backend errors" "unknown RDEV_MUX_BACKEND" "$out"

echo "----"; echo "PASS=$PASS FAIL=$FAIL"; [[ $FAIL -eq 0 ]]
```

- [ ] **Step 2: Run it, expect failure**

Run: `bash tests/rdev-mux.test.sh`
Expected: FAIL (rdev-mux doesn't exist / not executable).

- [ ] **Step 3: Write `bin/rdev-mux` skeleton**

`bin/rdev-mux`:
```bash
#!/usr/bin/env bash
# rdev-mux -- substrate adapter. rdev scripts call this instead of tmux/herdr.
set -euo pipefail

RDEV_MUX_BACKEND="${RDEV_MUX_BACKEND:-herdr}"

# _mux_run <backend-cmd> [args...]
# echo backend: print the command (dry-run / test). herdr backend: exec it.
_mux_run() {
  case "$RDEV_MUX_BACKEND" in
    echo) printf '%s' "$*" ;;
    herdr) command herdr "${@:2}" ;;   # $1 is the literal 'herdr' label; drop it
    *) echo "rdev-mux: unknown RDEV_MUX_BACKEND '$RDEV_MUX_BACKEND'" >&2; return 2 ;;
  esac
}

verb="${1:-}"; shift || true
case "$verb" in
  _selftest) _mux_run herdr a b c ;;
  *) echo "rdev-mux: unknown verb '$verb'" >&2; exit 2 ;;
esac
```

- [ ] **Step 4: Make executable, run test, expect pass**

Run: `chmod +x bin/rdev-mux && bash tests/rdev-mux.test.sh`
Expected: `PASS=2 FAIL=0`.

- [ ] **Step 5: Commit**

```bash
git add bin/rdev-mux tests/rdev-mux.test.sh && git commit -m "feat(rdev-mux): adapter skeleton with echo/herdr backend dispatch"
```

---

### Task 2: Core verbs — `space-new`, `agent-start`, `pane-split`, `list`, `send`, `state`, `kill`

**Files:**
- Modify: `bin/rdev-mux`
- Modify: `tests/rdev-mux.test.sh`

**Interfaces:**
- Produces (exact CLIs callers rely on):
  - `rdev-mux tab-new --name NAME --cwd DIR` → herdr `tab create --cwd DIR --label NAME --no-focus` (in the default workspace)
  - `rdev-mux agent-start --name NAME --cwd DIR [--tab TAB] -- <argv...>` → herdr `agent start NAME --cwd DIR [--tab TAB] --no-focus -- <argv...>`
  - `rdev-mux pane-split --cwd DIR [--dir right|down] [--ratio R]` → herdr `pane split --direction DIR --ratio R --cwd DIR --no-focus`
  - `rdev-mux list` → herdr `agent list`
  - `rdev-mux send --target T --text TXT` → herdr `agent send T TXT`
  - `rdev-mux state --target T` → herdr `agent get T`
  - `rdev-mux kill --tab TAB` → herdr `tab close TAB`

- [ ] **Step 1: Write failing tests for each verb's command construction**

Append to `tests/rdev-mux.test.sh` before the summary line:
```bash
# --- Task 2 ---
B() { RDEV_MUX_BACKEND=echo "$MUX" "$@"; }
assert_eq "tab-new" "tab create --cwd /w/x --label USENG-1 --no-focus" \
  "$(B tab-new --name USENG-1 --cwd /w/x)"
assert_eq "agent-start passes argv after --" \
  "agent start USENG-1 --cwd /w/x --tab t9 --no-focus -- claude --agent coordinator" \
  "$(B agent-start --name USENG-1 --cwd /w/x --tab t9 -- claude --agent coordinator)"
assert_eq "pane-split defaults" "pane split --direction right --ratio 0.3 --cwd /w/x --no-focus" \
  "$(B pane-split --cwd /w/x)"
assert_eq "list" "agent list" "$(B list)"
assert_eq "send" "agent send tgt hello world" "$(B send --target tgt --text 'hello world')"
assert_eq "state" "agent get tgt" "$(B state --target tgt)"
assert_eq "kill" "tab close t9" "$(B kill --tab t9)"
```
*(Note: echo backend drops the leading `herdr` label — assertions match the args only. Adjust `_mux_run` echo to also drop the label: `echo) shift; printf '%s' "$*" ;;`.)*

- [ ] **Step 2: Run, expect failures**

Run: `bash tests/rdev-mux.test.sh`
Expected: the Task 2 assertions FAIL (verbs not implemented).

- [ ] **Step 3: Implement the verbs**

In `bin/rdev-mux`, first fix the echo backend to drop the label, then add verbs. Replace the `_mux_run` echo line and the `case`:
```bash
_mux_run() {
  case "$RDEV_MUX_BACKEND" in
    echo) shift; printf '%s' "$*" ;;
    herdr) shift; command herdr "$@" ;;
    *) echo "rdev-mux: unknown RDEV_MUX_BACKEND '$RDEV_MUX_BACKEND'" >&2; return 2 ;;
  esac
}

# flag parser: sets vars name/cwd/tab/target/text/dir/ratio; leaves argv after `--` in REST
_parse() {
  REST=(); name=""; cwd=""; tab=""; target=""; text=""; dir="right"; ratio="0.3"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name) name="$2"; shift 2 ;;
      --cwd) cwd="$2"; shift 2 ;;
      --tab) tab="$2"; shift 2 ;;
      --target) target="$2"; shift 2 ;;
      --text) text="$2"; shift 2 ;;
      --dir) dir="$2"; shift 2 ;;
      --ratio) ratio="$2"; shift 2 ;;
      --) shift; REST=("$@"); break ;;
      *) echo "rdev-mux: bad flag '$1'" >&2; return 2 ;;
    esac
  done
}

verb="${1:-}"; shift || true
case "$verb" in
  _selftest) _mux_run herdr a b c ;;
  tab-new)     _parse "$@"; _mux_run herdr tab create --cwd "$cwd" --label "$name" --no-focus ;;
  agent-start) _parse "$@"
               args=(agent start "$name" --cwd "$cwd")
               [[ -n "$tab" ]] && args+=(--tab "$tab")
               args+=(--no-focus -- "${REST[@]}")
               _mux_run herdr "${args[@]}" ;;
  pane-split)  _parse "$@"; _mux_run herdr pane split --direction "$dir" --ratio "$ratio" --cwd "$cwd" --no-focus ;;
  list)        _mux_run herdr agent list ;;
  send)        _parse "$@"; _mux_run herdr agent send "$target" "$text" ;;
  state)       _parse "$@"; _mux_run herdr agent get "$target" ;;
  kill)        _parse "$@"; _mux_run herdr tab close "$tab" ;;
  *) echo "rdev-mux: unknown verb '$verb'" >&2; exit 2 ;;
esac
```

- [ ] **Step 4: Run tests, expect pass**

Run: `bash tests/rdev-mux.test.sh`
Expected: `FAIL=0` (all Task 1 + Task 2 assertions pass).

- [ ] **Step 5: Commit**

```bash
git add bin/rdev-mux tests/rdev-mux.test.sh && git commit -m "feat(rdev-mux): core verbs mapping to herdr workspace/agent/pane"
```

---

### Task 3: Port `_rdev_lib.sh` session helpers to Herdr via rdev-mux

**Files:**
- Modify: `bin/_rdev_lib.sh` (functions `rdev_ensure_session` ~line 58, `rdev_maybe_attach` ~line 75; leave `rdev_resolve_session` reading the config value but stop shelling to tmux)

**Interfaces:**
- Consumes: `rdev-mux` (Task 2), Herdr `status`/session model.
- Produces: `rdev_ensure_session` guarantees a Herdr server/session exists; `rdev_maybe_attach` attaches the client. Callers (`rstream`, `rdev`, etc.) keep the same function names.

- [ ] **Step 1: Write a failing test for session-ensure behavior**

Add to `tests/rdev-mux.test.sh`:
```bash
# --- Task 3 ---
out="$(RDEV_MUX_BACKEND=echo "$MUX" server-ensure 2>&1)"
assert_eq "server-ensure checks status" "status server" "$out"
```

- [ ] **Step 2: Run, expect fail**

Run: `bash tests/rdev-mux.test.sh`
Expected: FAIL (no `server-ensure` verb).

- [ ] **Step 3: Add `server-ensure` verb to `bin/rdev-mux`**

Add to the `case`:
```bash
  server-ensure) _mux_run herdr status server ;;
```

- [ ] **Step 4: Port the lib functions**

In `bin/_rdev_lib.sh`, replace the tmux bodies of `rdev_ensure_session` and `rdev_maybe_attach`:
```bash
rdev_ensure_session() {
  # Herdr server is the persistent session. Ensure it's up.
  if ! rdev-mux server-ensure >/dev/null 2>&1; then
    echo "Herdr server not running. Start it with: herdr" >&2
    return 1
  fi
}

rdev_maybe_attach() {
  # Attaching to Herdr is interactive (`herdr`); leave it to the caller's shell.
  # No-op under Herdr; kept for API compatibility.
  :
}
```
*(Leave `rdev_resolve_session` as-is if other code reads `$TMUX_SESSION`; it's harmless. Note in a comment that session naming is now Herdr's.)*

- [ ] **Step 5: Run tests + shellcheck the lib**

Run: `bash tests/rdev-mux.test.sh && bash -n bin/_rdev_lib.sh && echo OK`
Expected: `FAIL=0` and `OK`.

- [ ] **Step 6: Commit**

```bash
git add bin/rdev-mux bin/_rdev_lib.sh tests/rdev-mux.test.sh && git commit -m "feat: port session helpers to herdr via rdev-mux"
```

---

### Task 4: Port `rstream`'s window/pane/launch block to rdev-mux

**Files:**
- Modify: `bin/rstream` (the block at ~lines 255-293: `tmux new-window` / `split-window` / `set-option` / `send-keys`)

**Interfaces:**
- Consumes: `rdev-mux tab-new`, `pane-split`, `agent-start`; `$WORK_DIR`, `$NAME`, `$TICKET`, `$PERM_FLAG` (existing rstream vars).
- Produces: a stream launched as a Herdr **tab** (label = `$NAME`) in the default workspace, containing the coordinator agent pane + a shell pane, with the same initial coordinator prompt.

- [ ] **Step 1: Replace the tmux launch block**

In `bin/rstream`, comment out the existing `tmux new-window … send-keys … Enter` block (keep it for reference/legacy) and add:
```bash
# --- Create Herdr tab + launch coordinator (via rdev-mux) ---
TAB_ID="$(rdev-mux tab-new --name "$NAME" --cwd "$WORK_DIR")"
# Coordinator agent pane (Herdr tracks its blocked/working/done state)
rdev-mux agent-start --name "$NAME" --cwd "$WORK_DIR" --tab "$TAB_ID" -- \
  claude --agent coordinator $PERM_FLAG \
  "Start. Read state, fetch ticket $TICKET from Linear, present summary, and begin planning."
# Companion shell pane (30% split)
rdev-mux pane-split --cwd "$WORK_DIR" --dir right --ratio 0.3
echo "  Tab: $NAME ($TAB_ID)"
```
*(Note: `tab-new` returns the raw `herdr tab create` stdout. If herdr prints more than a bare id, add `--json` handling; confirm real output format in Step 3.)*

- [ ] **Step 2: Dry-run the whole path with the echo backend**

Run: `RDEV_MUX_BACKEND=echo bin/rstream USENG-DRYRUN --base main 2>&1 | grep -E 'tab create|agent start|pane split'`
Expected: prints the three constructed herdr commands with `--cwd` pointing at the worktree, `--label USENG-DRYRUN`, and the coordinator argv intact. (Worktree/git steps may run for real — use a throwaway ticket name or add an early `--dry-run` guard if needed.)

- [ ] **Step 3: Confirm real `herdr tab create` output shape**

Run: `herdr tab create --cwd /tmp --label mux-probe --no-focus; herdr tab list`
Expected: note whether the create prints a bare tab id or a sentence. If not a bare id, update `tab-new` to parse it (e.g. `--json` + `jq -r .id`) and re-run tests. Clean up: `herdr tab close <id>`.

- [ ] **Step 4: End-to-end smoke test (real backend)**

Manual: launch `herdr`, then from a shell run `rstream USENG-SMOKE` (a disposable branch). 
Expected: a new Herdr tab `USENG-SMOKE` appears with a coordinator pane (Claude starts, sidebar shows 🟡 working) and a shell pane. Kill after: `rdev-mux kill --tab <id>` and remove the test worktree/branch.

- [ ] **Step 5: Commit**

```bash
git add bin/rstream && git commit -m "feat(rstream): launch streams as herdr workspaces via rdev-mux"
```

---

## As-built corrections (2026-07-06, verified against real Herdr 0.7.1)

- **Streams are tabs inside ONE project workspace** (not tabs in the default workspace, and not workspaces-per-stream). Sidebar fleet unit = workspace; tabs nest under it. So:
  - `rdev [name]` (ported from tmux bootstrap) find-or-creates the **`rhythms` workspace** (label from `RDEV_WORKSPACE`, default `rhythms`) and focuses it.
  - `rstream <ticket>` ensures that workspace, then creates a **tab** in it (coordinator agent pane + shell pane). Herdr auto-tiles the agent pane beside the tab's root shell pane → the 2-pane split, no explicit `pane-split` needed.
- **New adapter verb `space-ensure --name --cwd`** — find-or-create a workspace by label, returns `workspace_id`. `tab-new`/`tab-find` gained `--workspace` (tabs are created in / scoped to that workspace).
- **Herdr output is JSON by default** (no `--json` flag): `tab create`→`.result.tab.tab_id`, `workspace create`→`.result.workspace.workspace_id`, `*list`→`.result.{tabs,workspaces}[]`. Parsing via `jq` on the herdr path; echo backend passes the command string through for tests.
- `_rdev_lib.sh`: added `RDEV_WORKSPACE` default; `rdev_ensure_session`/`rdev_maybe_attach` ported. `bin/rdev` rewritten for the workspace bootstrap (devcontainer/services auto-start deferred to Plan 5).
- Sidebar shows each git workspace's **root branch** beneath its name (e.g. `rdev` → `main`); per-stream worktree branches live with their tabs.
- Adapter tests: **13/13 green**. `rdev-mux` symlinked into `~/.local/bin` (matches other rdev commands).

## Self-Review

**Spec coverage (§5 substrate adapter):** `rdev-mux` created as the thin, backend-agnostic wrapper (Tasks 1-2); session helpers ported (Task 3); `rstream` launches via it (Task 4). Herdr owns tab/pane/agent lifecycle; rdev keeps worktree/state/agent-copy logic. Streams map to **tabs** (workspace concept unused for now). ✓ `rwatch` untouched. ✓ Old tmux code commented, not deleted (legacy path preserved). ✓

**Placeholder scan:** no TBD/TODO. One genuine unknown flagged with a concrete resolution step: `herdr workspace create` output shape (Task 4 Step 3) — resolved empirically before relying on `$WS_ID`, with a fallback (`--json`+`jq`). Not a placeholder; it's a verify-then-adjust step.

**Type consistency:** verb names and flags are identical across `rdev-mux` definition (Task 2), the tests, and the `rstream` callsites (`tab-new`/`agent-start`/`pane-split`/`kill --tab`). `_mux_run` echo-drops the leading `herdr` label consistently (fixed in Task 2 Step 3, matching the Task 2 assertions).

**Deferred to later plans:** dep-sharing on stream creation (Plan 3), test/lint runner + `.cursorindexingignore` (Plan 4), lease/promote (Plan 5). Worktree creation via `herdr worktree create` (vs current `git worktree add`) intentionally NOT changed here — revisit once the adapter is proven.
