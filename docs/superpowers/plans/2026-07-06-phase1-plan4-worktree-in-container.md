# Phase 1 · Plan 4 — Worktree-in-container correctness (+ dep-share) — kills silent wrong-code testing

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development or superpowers:executing-plans. Steps use `- [ ]`.

**Goal:** Make `docker exec` into a stream's worktree actually work — git-valid, mise-trusted, deps present — so unit/integration tests and lint run against the **worktree's** code instead of falling back to main (today's silent wrong-code bug). Wire the prep + dep-share into stream creation, and stop Cursor from indexing all worktrees.

**Architecture:** rdev applies the fixes **idempotently via `docker exec`** on stream creation (NOT by editing rhythms' devcontainer config — keeps the new stack non-invasive and parallel to the tmux one). Three prep steps per worktree: (1) container path-alias so git's host-path pointer resolves in-container, (2) `mise trust` the worktree configs, (3) share mainline deps by symlink (scoped reinstall on lockfile divergence). All verified by the Plan 3 spike.

**Tech Stack:** bash, `docker exec` into `${DEVCONTAINER}-${DEVCONTAINER}-1` (`fullstack-fullstack-1`), git worktrees, mise, `npm ci`/`bundle install`/`poetry install`.

## Global Constraints
- **Non-invasive:** do NOT modify rhythms' `.devcontainer/`. rdev ensures container state via `docker exec` (idempotent; re-applied per stream — survives container recreation implicitly because rstream re-runs it).
- Container-centric: worktrees at `$WORKTREE_DIR/<name>` (inside the mount); the container sees them at `/workspaces/rhythms/.claude/worktrees/<name>`.
- The host repo path is `$RHYTHMS_DIR` (`/Users/ashwin/code/rhythms`); the container mount is `/workspaces/rhythms`. The alias bridges them.
- All in-container installs are Linux (match mainline); sharing is symlink-from-mainline.
- Only touch worktree-mode streams (local mode already runs on main).

## Spike-verified facts (Plan 3, 2026-07-06)
- Git fails in-container for a host-created worktree until `/Users/ashwin/code/rhythms → /workspaces/rhythms` symlink exists in the container. With it: `git rev-parse` ✓.
- Fresh worktree `mise.toml` is untrusted → `mise trust` per service dir needed.
- Symlinked `node_modules` → vitest 15 passed; symlinked `BUNDLE_PATH` → `bundle check` satisfied.
- Poetry ignores a `.venv` symlink; it uses `POETRY_CACHE_DIR` (`<svc>/.cache/pypoetry`) → share **that** dir for mlai.

## File Structure
```
bin/_rdev_lib.sh   # MODIFY — add rdev_docker_exec, rdev_container_prep, rdev_share_deps, rdev_lock_diverged
bin/rstream        # MODIFY — after worktree setup: rdev_container_prep + rdev_share_deps
tests/rdev-deps.test.sh   # NEW — unit test for lock-divergence (pure)
<rhythms>/.cursorindexingignore  # NEW — exclude .claude/worktrees from Cursor indexing
```

---

### Task 1: `rdev_docker_exec` + `rdev_container_prep` (git alias + mise trust)

**Files:** Modify `bin/_rdev_lib.sh`.

**Interfaces:** `rdev_docker_exec <container-cwd> <cmd...>`; `rdev_container_prep <worktree_dir>` — ensures the host-path alias exists in the container and trusts the worktree's mise configs. Idempotent.

- [ ] **Step 1: Implement**
```bash
RDEV_CONTAINER="${DEVCONTAINER}-${DEVCONTAINER}-1"   # e.g. fullstack-fullstack-1

rdev_docker_exec() {  # rdev_docker_exec <container-cwd> <cmd...>
  local cwd="$1"; shift
  docker exec "$RDEV_CONTAINER" bash -lc "cd '$cwd' && $*"
}

# container path for a host worktree dir under $WORKTREE_DIR
rdev_container_path() {  # rdev_container_path <host_worktree_dir>
  echo "/workspaces/rhythms/.claude/worktrees/$(basename "$1")"
}

# Ensure git works in-container for host-created worktrees, and trust mise.
rdev_container_prep() {  # rdev_container_prep <host_worktree_dir>
  local cpath; cpath="$(rdev_container_path "$1")"
  # 1. host-path alias -> mount (fixes git worktree gitdir path mismatch)
  docker exec "$RDEV_CONTAINER" bash -lc \
    '[ -L /Users/ashwin/code/rhythms ] || { rm -rf /Users/ashwin/code/rhythms 2>/dev/null; mkdir -p /Users/ashwin/code; ln -s /workspaces/rhythms /Users/ashwin/code/rhythms; }'
  # 2. trust the worktree's mise configs
  docker exec "$RDEV_CONTAINER" bash -lc \
    "for d in '$cpath' '$cpath'/webui '$cpath'/railsapi '$cpath'/mlai '$cpath'/mcpservers; do mise trust \"\$d\" >/dev/null 2>&1; done"
}
```
*(The alias host path is hard-coded to `$RHYTHMS_DIR`'s value; if `$RHYTHMS_DIR` differs, derive it: `host="${RHYTHMS_DIR}"` and alias `$host → /workspaces/rhythms`. Use the literal from config, not a guess.)*

- [ ] **Step 2: Verify (live)** — on an existing worktree: `rdev_container_prep <wt>` then `rdev_docker_exec "$(rdev_container_path <wt>)" "git rev-parse --abbrev-ref HEAD"` → prints the branch (not "not a git repository").
- [ ] **Step 3:** `bash -n bin/_rdev_lib.sh`.

---

### Task 2: `rdev_share_deps` + divergence detection

**Files:** Modify `bin/_rdev_lib.sh`; create `tests/rdev-deps.test.sh`.

**Interfaces:** `rdev_lock_diverged <wt> <rel_lockfile>` (pure); `rdev_share_deps <worktree_dir>` (symlink from mainline, scoped reinstall on divergence).

- [ ] **Step 1: Failing test** (pure divergence check) — `tests/rdev-deps.test.sh`:
```bash
#!/usr/bin/env bash
set -uo pipefail
export RDEV_CONFIG=/dev/null; RHYTHMS_DIR=$(mktemp -d); export RHYTHMS_DIR
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin" && pwd)/_rdev_lib.sh" 2>/dev/null || true
P=0;F=0; ok(){ [[ "$2" == "$3" ]] && P=$((P+1)) || { F=$((F+1)); echo "FAIL $1 exp=$2 got=$3"; }; }
mkdir -p "$RHYTHMS_DIR/webui"; wt=$(mktemp -d); mkdir -p "$wt/webui"
echo A >"$RHYTHMS_DIR/webui/package-lock.json"; echo A >"$wt/webui/package-lock.json"
rdev_lock_diverged "$wt" webui/package-lock.json; ok same 1 $?
echo B >"$wt/webui/package-lock.json"; rdev_lock_diverged "$wt" webui/package-lock.json; ok diff 0 $?
echo "P=$P F=$F"; [[ $F -eq 0 ]]
```
- [ ] **Step 2: Run → fail.**
- [ ] **Step 3: Implement in `_rdev_lib.sh`**
```bash
rdev_lock_diverged() {  # true(0) if worktree lockfile differs from mainline
  local wt="$1" rel="$2"
  [[ -f "$RHYTHMS_DIR/$rel" && -f "$wt/$rel" ]] || return 1
  ! diff -q "$RHYTHMS_DIR/$rel" "$wt/$rel" >/dev/null 2>&1
}

rdev_share_deps() {  # rdev_share_deps <host_worktree_dir>
  local wt="$1" cpath; cpath="$(rdev_container_path "$wt")"
  # dep_dir : lockfile : service-subdir : installer
  local specs=(
    "webui/node_modules:webui/package-lock.json:webui:npm ci"
    "node_modules:package-lock.json:.:npm ci"
    "railsapi/.cache/bundle:railsapi/Gemfile.lock:railsapi:bundle install"
    "mlai/.cache/pypoetry:mlai/poetry.lock:mlai:poetry install"
  )
  local spec dep lock svc inst
  for spec in "${specs[@]}"; do
    IFS=: read -r dep lock svc inst <<<"$spec"
    [[ -e "$RHYTHMS_DIR/$dep" ]] || { echo "  skip $dep (not in mainline)"; continue; }
    [[ -e "$wt/$dep" ]] && { echo "  keep $dep (present)"; continue; }
    if rdev_lock_diverged "$wt" "$lock"; then
      echo "  $dep: lockfile diverged -> '$inst' in worktree"
      rdev_docker_exec "$cpath/$svc" "mise x -- $inst"
    else
      mkdir -p "$(dirname "$wt/$dep")"; ln -s "$RHYTHMS_DIR/$dep" "$wt/$dep"
      echo "  $dep: symlinked from mainline"
    fi
  done
}
```
- [ ] **Step 4: Run test → pass; `bash -n`.**

---

### Task 3: wire prep + dep-share into `rstream`

**Files:** Modify `bin/rstream` (worktree-mode setup, after the `.claude`/agents/plans symlinks, before the tab launch).

- [ ] **Step 1:** Add:
```bash
    echo "Preparing container (git alias + mise trust)..."
    rdev_container_prep "$WORK_DIR"
    echo "Sharing dependencies..."
    rdev_share_deps "$WORK_DIR"
```
- [ ] **Step 2:** `bash -n bin/rstream`.
- [ ] **Step 3 (live smoke):** `rstream <fresh-ticket>` → then `rdev_docker_exec "$(rdev_container_path <wt>)/webui" "mise x -- npm run test:unit"` runs against the worktree and passes in seconds (symlinked deps). Confirm git works in-container.

---

### Task 4: stop Cursor indexing all worktrees

**Files:** Create `<rhythms>/.cursorindexingignore` (tracked via `git add -f` if `.claude` is gitignored — confirm).

- [ ] **Step 1:** Create `$RHYTHMS_DIR/.cursorindexingignore` containing:
```
.claude/worktrees/
```
- [ ] **Step 2:** Reload Cursor; confirm indexing no longer walks worktrees (responsive with many present). Note: `.cursorindexingignore` excludes from indexing but keeps files openable.

---

## Self-Review
**Spec coverage:** kills silent wrong-code testing (Task 1 git alias — the verified root cause); dep-sharing §7 (Task 2, with spike-corrected mlai target); Cursor indexing §6 (Task 4); wired into stream creation (Task 3). ✓
**Placeholders:** none — commands are spike-verified. The one hard-coded value (`/Users/ashwin/code/rhythms`) is called out to derive from `$RHYTHMS_DIR`.
**Non-invasive:** no rhythms devcontainer edits; rdev applies via docker exec. ✓
**Dependency on Plan 5:** none — this is independent of the lease/promote work. Plan 5 (rlocal + rpromote/runpromote port) remains the final piece and can reuse `rdev_docker_exec`/`rdev_container_prep`.
