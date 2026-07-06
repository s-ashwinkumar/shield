# Phase 1 · Plan 3 — Dependency sharing on stream creation

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development or superpowers:executing-plans. Steps use `- [ ]`.

**Goal:** When a stream's worktree is created, make its per-service dependencies available in **seconds** by sharing mainline's already-installed deps (via symlink), with a **scoped reinstall** only when the branch's lockfile diverges — replacing today's "nothing, then manual symlink-or-copy roulette" (`rstream` sets up no deps).

**Architecture:** A `rdev_share_deps <worktree_dir>` lib helper symlinks each service's heavy dep dir from mainline into the worktree (all-Linux, resolved in-container, so symlinks are valid). Before symlinking, it compares the worktree's lockfile to mainline's; if they differ, it does a scoped real install *in the worktree* for that service instead of symlinking. Called by `rstream` right after worktree creation.

**Tech Stack:** bash, git (worktree + lockfile diff), the rhythms services' native installers (`npm ci`, `bundle install`, `poetry install`) run **inside the dev container** via the existing `docker exec` helper (deps must be Linux, matching mainline).

## Global Constraints

- Sharing is **symlink-based, mainline → worktree**, and only valid because both live inside the container mount (Linux ↔ Linux). Never symlink host-installed (darwin) deps.
- Only symlink a dep dir that **exists in mainline**; otherwise skip (nothing to share).
- Never mutate mainline's dep dirs. Symlinks are one-way (worktree → mainline). A divergent worktree gets its **own real** dep dir (breaks the symlink for that service only).
- Idempotent: re-running on a worktree that already has correct deps is a no-op.
- Container-centric model: worktrees live at `$WORKTREE_DIR/<name>` inside `~/code/rhythms`.

## Dep inventory (verified 2026-07-06)
| Service | Shared dir | Size | Lockfile | Installer (in container) |
|---|---|---|---|---|
| webui | `webui/node_modules` | 1.6G | `webui/package-lock.json` | `npm ci` |
| (root) | `node_modules` | 3.8M | `package-lock.json` | `npm ci` |
| railsapi | `railsapi/.cache/bundle` (`BUNDLE_PATH`) | 707M | `railsapi/Gemfile.lock` | `bundle install` |
| mlai | `mlai/.venv` | 1.4G | `mlai/poetry.lock` | `poetry install` |

## File Structure
```
bin/_rdev_lib.sh   # MODIFY — add rdev_share_deps() + rdev_docker_exec() helpers
bin/rstream        # MODIFY — call rdev_share_deps "$WORK_DIR" after worktree setup
tests/rdev-deps.test.sh  # NEW — unit tests for divergence detection (pure, no docker)
```

---

## SPIKE RESULTS (2026-07-06 — run against fullstack-fullstack-1)

- **Node (`node_modules` symlink): ✓** vitest ran in-container, 15 passed.
- **Ruby (`BUNDLE_PATH`/`.cache/bundle` symlink): ✓** `bundle check` → "dependencies are satisfied".
- **Python (poetry): `.venv` symlink is IGNORED** — poetry uses `POETRY_CACHE_DIR` (`$WORKDIR/.cache/pypoetry/virtualenvs`), so it made a *fresh* venv. → mlai's share target is **`mlai/.cache/pypoetry`**, not `.venv`. (Symlinking that dir should share; verify.)
- **TWO prerequisites discovered (blockers, not optional):**
  1. **`mise trust`** — a fresh worktree's `mise.toml` files are untrusted; mise refuses to run until trusted (`mise trust <dir>` per service, in-container).
  2. **Git worktree path mismatch (the big one).** `git worktree add` on the host writes `.git` → `gitdir: /Users/ashwin/code/rhythms/.git/worktrees/<n>` (host path). In-container the repo is at `/workspaces/rhythms`, so git fails: *"fatal: not a git repository."* **This is the real root of the silent wrong-code testing.** Fix: container must alias the host path → mount, e.g. `ln -s /workspaces/rhythms /Users/ashwin/code/rhythms` (belongs in devcontainer setup / postCreate — **infra, Plan 5 territory**). With the alias applied, the full spike passed (git + bundle + vitest all ✓).

**Consequence:** dep-sharing (Tasks 2–3) is validated, but it is **gated on the git-path alias prerequisite**, which is a devcontainer-setup change bigger than Plan 3. Sequence: land the container path-alias (Plan 5 / devcontainer) → then Tasks 2–3 here. Also add `mise trust` + POETRY_CACHE_DIR (not .venv) to `rdev_share_deps`.

---

### Task 1 (SPIKE): verify symlink-sharing actually works per language in-container — DONE (see SPIKE RESULTS above)

**Files:** none (investigation; record findings in the plan).

- [ ] **Step 1: node_modules symlink** — in a scratch worktree, `ln -s <main>/webui/node_modules <wt>/webui/node_modules`, then `docker exec … cd <wt>/webui && npm run test:unit`. Expect: passes using shared modules.
- [ ] **Step 2: bundle symlink** — `ln -s <main>/railsapi/.cache/bundle <wt>/railsapi/.cache/bundle`, then `docker exec … cd <wt>/railsapi && bundle check`. Expect: "The Gemfile's dependencies are satisfied."
- [ ] **Step 3: poetry .venv symlink (RISKY)** — `ln -s <main>/mlai/.venv <wt>/mlai/.venv`, then `docker exec … cd <wt>/mlai && poetry run python -c 'print(1)'`. Venv scripts hardcode absolute paths → this may fail or warn. **Record the result.** If it fails, the fallback for mlai is a shared `POETRY_VIRTUALENVS_PATH` (out-of-project shared venv keyed by hash) or per-worktree `poetry install --sync` (slow first time). Decide mlai's strategy from this spike.
- [ ] **Step 4: Record** the working mechanism per service in this plan before building Task 2.

---

### Task 2: `rdev_share_deps` + `rdev_docker_exec` helpers (with divergence fallback)

**Files:** Modify `bin/_rdev_lib.sh`; create `tests/rdev-deps.test.sh`.

**Interfaces:**
- Produces: `rdev_share_deps <worktree_dir>` — for each service, symlink its dep dir from mainline unless the lockfile diverges (then scoped install). `rdev_lock_diverged <wt> <rel_lockfile>` → returns 0 (true) if the worktree's lockfile differs from mainline's.

- [ ] **Step 1: Write failing test for divergence detection**

`tests/rdev-deps.test.sh`:
```bash
#!/usr/bin/env bash
set -uo pipefail
LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin" && pwd)/_rdev_lib.sh"
# Stub config so the lib loads without a real rdev config.
export RDEV_CONFIG=/dev/null
RHYTHMS_DIR=$(mktemp -d); export RHYTHMS_DIR
source "$LIB" 2>/dev/null || true   # we only need the pure functions
P=0; F=0
ok(){ [[ "$2" == "$3" ]] && P=$((P+1)) || { F=$((F+1)); echo "FAIL $1: exp=$2 got=$3"; }; }

# same lockfile -> not diverged (rc 1); different -> diverged (rc 0)
main="$RHYTHMS_DIR"; wt=$(mktemp -d)
mkdir -p "$main/webui" "$wt/webui"
echo "A" > "$main/webui/package-lock.json"; echo "A" > "$wt/webui/package-lock.json"
rdev_lock_diverged "$wt" "webui/package-lock.json"; ok "same" 1 $?
echo "B" > "$wt/webui/package-lock.json"
rdev_lock_diverged "$wt" "webui/package-lock.json"; ok "diff" 0 $?
echo "P=$P F=$F"; [[ $F -eq 0 ]]
```

- [ ] **Step 2: Run, expect fail** — `bash tests/rdev-deps.test.sh` → FAIL (function undefined).

- [ ] **Step 3: Implement helpers in `_rdev_lib.sh`**

```bash
# True (0) if the worktree's copy of <rel_lockfile> differs from mainline's.
rdev_lock_diverged() {
  local wt="$1" rel="$2"
  [[ -f "$RHYTHMS_DIR/$rel" ]] || return 1          # no mainline lock -> treat as not diverged
  [[ -f "$wt/$rel" ]] || return 1
  ! diff -q "$RHYTHMS_DIR/$rel" "$wt/$rel" >/dev/null 2>&1
}

# Run a command inside the dev container at a given container path.
rdev_docker_exec() {  # rdev_docker_exec <container-cwd> <cmd...>
  local cwd="$1"; shift
  docker exec "${DEVCONTAINER}-${DEVCONTAINER}-1" bash -lc "cd '$cwd' && $*"
}

# Share deps from mainline into a worktree (symlink; scoped reinstall on divergence).
# Uses container paths (/workspaces/rhythms/...) for installs.
rdev_share_deps() {
  local wt="$1" wt_name; wt_name="$(basename "$wt")"
  # dep_dir : lockfile : installer(container-relative service dir)
  local specs=(
    "webui/node_modules:webui/package-lock.json:webui:npm ci"
    "node_modules:package-lock.json:.:npm ci"
    "railsapi/.cache/bundle:railsapi/Gemfile.lock:railsapi:bundle install"
    # mlai handled per Task 1 spike outcome (symlink or shared venv path)
  )
  local spec dep lock svc inst
  for spec in "${specs[@]}"; do
    IFS=: read -r dep lock svc inst <<<"$spec"
    [[ -e "$RHYTHMS_DIR/$dep" ]] || { echo "  skip $dep (not in mainline)"; continue; }
    [[ -e "$wt/$dep" ]] && { echo "  keep $dep (already present)"; continue; }
    if rdev_lock_diverged "$wt" "$lock"; then
      echo "  $dep: lockfile diverged -> scoped '$inst' in worktree"
      rdev_docker_exec "/workspaces/rhythms/.claude/worktrees/$wt_name/$svc" "$inst"
    else
      mkdir -p "$(dirname "$wt/$dep")"
      ln -s "$RHYTHMS_DIR/$dep" "$wt/$dep"
      echo "  $dep: symlinked from mainline"
    fi
  done
}
```

- [ ] **Step 4: Run test, expect pass** — `bash tests/rdev-deps.test.sh` → `F=0`.
- [ ] **Step 5: shellcheck** — `bash -n bin/_rdev_lib.sh`.

---

### Task 3: call `rdev_share_deps` from `rstream` after worktree creation

**Files:** Modify `bin/rstream` (worktree-mode setup block, after `git worktree add` + symlinks, before the tab/coordinator launch).

- [ ] **Step 1:** After the worktree is created and `.local.env`/`docs/plans`/`.claude` symlinks are set (worktree mode only), add:
```bash
    # Share deps from mainline (symlink; scoped reinstall if a lockfile diverged)
    echo "Sharing dependencies..."
    rdev_share_deps "$WORK_DIR"
```
- [ ] **Step 2:** `bash -n bin/rstream`.
- [ ] **Step 3 (live smoke):** `rstream <fresh-ticket>` on a branch with unchanged lockfiles → confirm the worktree's `webui/node_modules`, `railsapi/.cache/bundle` are symlinks to mainline and `docker exec … npm run test:unit` passes in seconds. Then test a branch that adds a package → confirm scoped `npm ci` runs instead.

---

## Self-Review
**Spec coverage (§7):** shared BUNDLE_PATH (railsapi bundle symlink), node_modules symlink + scoped `npm ci` on divergence (Task 2), automated on stream creation (Task 3). mlai venv strategy resolved by the Task 1 spike (symlink vs shared-venv-path). ✓
**Placeholders:** the ONLY open item is mlai's mechanism, explicitly gated behind the Task 1 spike (venv symlinks are unreliable) — not hand-waved; the spike decides it before Task 2 includes mlai.
**Risk:** symlinking a poetry `.venv` (abs-path shebangs) is the known-risky bit → Task 1 Step 3 tests it first. Divergence detection is pure/unit-tested; installs run in-container (Linux) matching mainline.
