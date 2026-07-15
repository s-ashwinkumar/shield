#!/usr/bin/env bash
# rdev shared library -- sourced by all rdev scripts

set -euo pipefail

RDEV_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rdev"
RDEV_CONFIG="$RDEV_CONFIG_DIR/config"

# --- Config ---

rdev_load_config() {
  if [[ ! -f "$RDEV_CONFIG" ]]; then
    echo "Error: rdev config not found at $RDEV_CONFIG"
    echo "Run 'install' from the rdev repo to set up."
    exit 1
  fi
  # shellcheck source=/dev/null
  source "$RDEV_CONFIG"

  # Expand tildes
  RHYTHMS_DIR="${RHYTHMS_DIR/#\~/$HOME}"
  WORKTREE_DIR="${WORKTREE_DIR/#\~/$HOME}"

  # Validate required
  if [[ -z "${RHYTHMS_DIR:-}" ]]; then
    echo "Error: RHYTHMS_DIR not set in config"
    exit 1
  fi
  if [[ ! -d "$RHYTHMS_DIR" ]]; then
    echo "Error: RHYTHMS_DIR ($RHYTHMS_DIR) does not exist"
    exit 1
  fi

  WORKTREE_DIR="${WORKTREE_DIR:-${RHYTHMS_DIR}/.claude/worktrees}"
  TMUX_SESSION="${TMUX_SESSION:-rdev}"
  # Herdr workspace that holds all stream tabs (analog of the tmux session).
  RDEV_WORKSPACE="${RDEV_WORKSPACE:-rhythms}"
  NOTIFY="${NOTIFY:-true}"
  DEVCONTAINER="${DEVCONTAINER:-fullstack}"
  MAX_REVIEW_LOOPS="${MAX_REVIEW_LOOPS:-3}"

  # Resolve rdev repo root (where agents/ and skills/ live)
  RDEV_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
}

# --- Session ---

# Resolve tmux session: --session flag > current session > config default
# Call after parsing args that set SESSION_FLAG
rdev_resolve_session() {
  if [[ -n "${SESSION_FLAG:-}" ]]; then
    TMUX_SESSION="$SESSION_FLAG"
  elif [[ -n "${TMUX:-}" ]]; then
    # Inside tmux -- use current session
    TMUX_SESSION="$(tmux display-message -p '#S')"
  fi
  # Otherwise TMUX_SESSION stays as config default (rdev)
}

rdev_ensure_session() {
  # Under Herdr, the persistent server IS the session. Ensure it's up.
  # (Backend is abstracted by rdev-mux; herdr's server auto-starts on `herdr`.)
  if ! rdev-mux server-ensure >/dev/null 2>&1; then
    echo "Herdr server not running. Start it with: herdr" >&2
    return 1
  fi
}

# Call at the end of a script to attach if we created a new session.
# Attaching to Herdr is interactive (`herdr`); left to the caller's shell.
# Kept as a no-op for API compatibility with existing callers.
rdev_maybe_attach() {
  :
}

# --- Herdr stream helpers ---

# Echo the Herdr tab id for a stream (in the project workspace), or empty.
rdev_stream_tab() {
  local ws
  ws="$(rdev-mux space-find --name "$RDEV_WORKSPACE")"
  [[ -z "$ws" ]] && return 0
  rdev-mux tab-find --name "$1" --workspace "$ws"
}

# Run a command in a stream tab's coordinator (first/left) pane.
rdev_coord_run() {
  local pane
  pane="$(rdev-mux pane-first --tab "$1")"
  [[ -z "$pane" ]] && return 1
  rdev-mux pane-run --pane "$pane" --text "$2"
}

# Send a message to the LIVE coordinator in a stream tab's first pane, then submit
# it (Enter) — types into the running claude, like typing in the pane yourself.
rdev_coord_msg() {
  local pane
  pane="$(rdev-mux pane-first --tab "$1")"
  [[ -z "$pane" ]] && return 1
  rdev-mux send-text --pane "$pane" --text "$2"
  rdev-mux send-enter --pane "$pane"
}

# --- Herdr worktree / container helpers (container-centric testing) ---

# The dev container that mounts the repo at /workspaces/rhythms.
rdev_container() { echo "${DEVCONTAINER}-${DEVCONTAINER}-1"; }

# Container path for a host worktree dir under $WORKTREE_DIR.
rdev_container_path() { echo "/workspaces/rhythms/.claude/worktrees/$(basename "$1")"; }

# Run a command inside the dev container at a container path.
rdev_docker_exec() {  # rdev_docker_exec <container-cwd> <cmd...>
  local cwd="$1"; shift
  docker exec "$(rdev_container)" bash -lc "cd '$cwd' && $*"
}

# Make a host-created worktree usable in-container: (1) alias the host repo path
# to the mount so git's worktree gitdir pointer resolves, (2) trust mise configs.
# Idempotent. Safe: never touches the mount path itself.
rdev_container_prep() {  # rdev_container_prep <host_worktree_dir>
  local cpath; cpath="$(rdev_container_path "$1")"
  local c; c="$(rdev_container)"
  docker exec "$c" bash -lc "host='$RHYTHMS_DIR'
    [ \"\$host\" = /workspaces/rhythms ] && exit 0
    if [ ! -L \"\$host\" ]; then
      rm -rf \"\$host\" 2>/dev/null || true
      mkdir -p \"\$(dirname \"\$host\")\"
      ln -s /workspaces/rhythms \"\$host\"
    fi" 2>/dev/null || true
  docker exec "$c" bash -lc \
    "for d in '$cpath' '$cpath'/webui '$cpath'/railsapi '$cpath'/mlai '$cpath'/mcpservers; do mise trust \"\$d\" >/dev/null 2>&1 || true; done" 2>/dev/null || true
}

# True (0) if the worktree's copy of <rel_lockfile> differs from mainline's.
rdev_lock_diverged() {  # rdev_lock_diverged <worktree_dir> <rel_lockfile>
  local wt="$1" rel="$2"
  [[ -f "$RHYTHMS_DIR/$rel" && -f "$wt/$rel" ]] || return 1
  ! diff -q "$RHYTHMS_DIR/$rel" "$wt/$rel" >/dev/null 2>&1
}

# Share mainline deps into a worktree by symlink (all-Linux, in-container) when the
# lockfile matches; reinstall in the worktree when it diverges. mlai's poetry venv
# is special-cased below — it can NEVER be symlink-shared.
rdev_share_deps() {  # rdev_share_deps <host_worktree_dir>
  local wt="$1" cpath; cpath="$(rdev_container_path "$wt")"
  # dep dir : lockfile : service subdir : install cmd
  local specs=(
    "webui/node_modules:webui/package-lock.json:webui:npm ci"
    "node_modules:package-lock.json:.:npm ci"
    "railsapi/.cache/bundle:railsapi/Gemfile.lock:railsapi:bundle install"
  )
  local spec dep lock svc inst
  for spec in "${specs[@]}"; do
    IFS=: read -r dep lock svc inst <<<"$spec"
    [[ -e "$RHYTHMS_DIR/$dep" ]] || { echo "  skip $dep (not in mainline)"; continue; }
    if rdev_lock_diverged "$wt" "$lock"; then
      # worktree's lock differs from mainline -> it needs its OWN deps. Drop any
      # stale mainline symlink first (else the divergent worktree runs main's deps).
      [[ -L "$wt/$dep" ]] && rm -f "$wt/$dep"
      if [[ -e "$wt/$dep" ]]; then
        echo "  $dep: own install present (lock diverged)"
      else
        echo "  $dep: lock diverged -> '$inst' in worktree"
        rdev_docker_exec "$cpath/$svc" "mise x -- $inst" || echo "  WARN: $inst failed for $svc"
      fi
    elif [[ -e "$wt/$dep" ]]; then
      echo "  keep $dep (present, lock matches)"
    else
      mkdir -p "$(dirname "$wt/$dep")"
      ln -s "$RHYTHMS_DIR/$dep" "$wt/$dep"
      echo "  $dep: symlinked from mainline"
    fi
  done

  # mlai: NEVER symlink the poetry cache/venv. poetry's virtualenvs.path is
  # $POETRY_CACHE_DIR/virtualenvs (= mlai/.cache/pypoetry/virtualenvs) with
  # in-project OFF, so a symlinked .cache/pypoetry points the worktree's venv path
  # at mainline's EXISTING venv -> poetry dies recreating it ([Errno 17] File
  # exists) -> mlai exits -> hivemind tears down the whole app. Give the worktree
  # its own cache + venv instead (its own poetry install).
  if [[ -d "$RHYTHMS_DIR/mlai" ]]; then
    if [[ -L "$wt/mlai/.cache/pypoetry" ]]; then
      rm -f "$wt/mlai/.cache/pypoetry"
      echo "  mlai/.cache/pypoetry: removed shared symlink (poetry venv can't be shared)"
    fi
    # --no-root: mlai runs from src/ via PYTHONPATH, so the root "rhythms" package
    # is NOT installed (plain `poetry install` dies with "No file/folder found for
    # package rhythms", leaving an incomplete venv — then each mlai sub-process
    # races to create it at boot and hits [Errno 17]). Marker file records that
    # the venv is complete, so we don't reuse a half-built one.
    if [[ -f "$wt/mlai/.cache/pypoetry/.rdev-venv-ready" ]]; then
      echo "  mlai: own poetry venv present"
    else
      echo "  mlai: building own poetry venv (poetry install --no-root)..."
      if rdev_docker_exec "$cpath/mlai" "mise x -- poetry install --no-root"; then
        touch "$wt/mlai/.cache/pypoetry/.rdev-venv-ready"
      else
        echo "  WARN: mlai poetry install failed"
      fi
    fi
  fi
}

# --- Per-worktree DB isolation ---

# Deterministic per-stream DB-name suffix (postgres-safe): "_<sanitized-lowercase>".
# railsapi test db = habits_rob_test<suffix><TEST_ENV_NUMBER>; keeps parallel
# integration test runs from different worktrees off each other's data.
rdev_db_suffix() {  # rdev_db_suffix <name>
  local s
  s="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '_' | sed 's/_*$//')"
  printf '_%s' "$s"
}

# Create + migrate a worktree's isolated mlai dev DB (parity with rails, whose
# parallel:setup auto-creates its test DB). No-op on mainline (unset suffix).
# Idempotent. Runs the in-container script under `mise x` so POSTGRES_* come from
# the worktree's own .dev.env. See bin/_rdev_mlai_setup.sh for the why.
rdev_mlai_setup() {  # rdev_mlai_setup <host_worktree_dir>
  local wt="$1" cpath here
  cpath="$(rdev_container_path "$wt")"
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  docker exec -i "$(rdev_container)" bash -lc "cd '$cpath/mlai' && exec mise x -- bash -s" \
    < "$here/_rdev_mlai_setup.sh"
}

# --- Live server (promote) helpers — agent-friendly, no pane, no user ---

# (Re)start the live app in-container, pointed at a container WORKSPACE_ROOT.
# Stops the current dev (pkill -f hivemind), then starts `dev` backgrounded so it
# survives the docker-exec session; logs to <workspace>/dev.log. Documented flow:
# start with `dev`/`devd`, watch `tail -f dev.log`, stop with `pkill -f hivemind`.
rdev_serve() {  # rdev_serve <container-workspace-path>
  local c; c="$(rdev_container)"
  # 1. Stop the current server; WAIT for the hivemind procs (port holders) to
  #    actually exit before restarting, else the new dev hits ports-in-use.
  docker exec "$c" bash -lc \
    'pkill -f hivemind 2>/dev/null || true; for i in $(seq 1 20); do pgrep -f hivemind >/dev/null || break; sleep 0.5; done'
  # 2. Start DETACHED (docker exec -d): a plain `&` background job is reaped when
  #    the exec session ends, so nohup/disown are not enough — -d is.
  # 3. Select the code with WORKSPACE_ROOT, NOT cwd: dev.Procfile runs
  #    `mise x -C $WORKSPACE_ROOT/<svc>`, and dev's Procfile path is fixed to
  #    mainline, so cd does nothing — the env var is what repoints the app.
  docker exec -d "$c" bash -lc "cd '$1' && WORKSPACE_ROOT='$1' exec dev > '$1/dev.log' 2>&1"
  echo "  live server → WORKSPACE_ROOT=$1 (detached; watch: docker exec $c tail -f $1/dev.log)"
}

# --- Notifications ---

rdev_notify() {
  local title="${1:-rdev}"
  local message="${2:-Done}"
  if [[ "$NOTIFY" == "true" ]] && command -v terminal-notifier &>/dev/null; then
    terminal-notifier -title "$title" -message "$message" -sound default -group rdev 2>/dev/null || true
  fi
}

# --- State management ---

# Resolve work directory for a stream: prefers worktree if it exists, falls back to local
rdev_resolve_work_dir() {
  local name="$1"
  # Check worktree first — if it exists, it takes priority
  if [[ -f "$WORKTREE_DIR/$name/.claude/rdev/state.json" ]]; then
    echo "$WORKTREE_DIR/$name"
    return
  fi
  # Check local mode (state in main repo's .claude/rdev/)
  if [[ -f "$RHYTHMS_DIR/.claude/rdev/state.json" ]]; then
    local ticket stream_name
    ticket=$(jq -r '.ticket // ""' "$RHYTHMS_DIR/.claude/rdev/state.json")
    stream_name=$(jq -r '.name // ""' "$RHYTHMS_DIR/.claude/rdev/state.json")
    if [[ "$ticket" == "$name" || "$stream_name" == "$name" ]]; then
      echo "$RHYTHMS_DIR"
      return
    fi
  fi
  # Fall back to worktree path (may not exist yet)
  echo "$WORKTREE_DIR/$name"
}

rdev_state_file() {
  local name="$1"
  local work_dir
  work_dir="$(rdev_resolve_work_dir "$name")"
  echo "$work_dir/.claude/rdev/state.json"
}

rdev_read_state() {
  local name="$1"
  local state_file
  state_file="$(rdev_state_file "$name")"
  if [[ -f "$state_file" ]]; then
    cat "$state_file"
  else
    echo '{}'
  fi
}

rdev_get_stage() {
  local name="$1"
  rdev_read_state "$name" | jq -r '.stage // "unknown"'
}

rdev_get_stage_from() {
  local state_file="$1"
  if [[ -f "$state_file" ]]; then
    jq -r '.stage // "unknown"' "$state_file"
  else
    echo "unknown"
  fi
}

rdev_update_state() {
  local name="$1"
  local key="$2"
  local value="$3"
  local state_file
  state_file="$(rdev_state_file "$name")"
  local tmp
  tmp=$(jq --arg k "$key" --arg v "$value" '.[$k] = $v' "$state_file")
  echo "$tmp" > "$state_file"
}

# rdev_signal_attention <name> <type> <summary>
# Raise a coordinator-flagged attention signal on the stream's state file.
# rfleet's scan picks up the changed .attention.ts and emits one item.
# This is the ONLY way a plan_gate should be raised — on a genuinely
# ready-for-approval plan, never on mere entry into the plan stage.
rdev_signal_attention() {
  local name="$1" type="$2" summary="$3"
  local state_file
  state_file="$(rdev_state_file "$name")"
  [[ -f "$state_file" ]] || { echo "rdev_signal_attention: no state file for '$name'" >&2; return 1; }
  local now; now=$(date +%s)
  local tmp
  tmp=$(jq --arg t "$type" --arg s "$summary" --argjson ts "$now" \
          '.attention = {type:$t, summary:$s, ts:$ts}' "$state_file") || return 1
  echo "$tmp" > "$state_file"
}

rdev_init_state() {
  local name="$1"
  local ticket="$2"
  local state_dir="$WORKTREE_DIR/$name/.claude/rdev"
  mkdir -p "$state_dir"
  cat > "$state_dir/state.json" <<EOF
{
  "stage": "plan",
  "ticket": "$ticket",
  "mode": "worktree",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "review_loops_done": 0,
  "max_review_loops": $MAX_REVIEW_LOOPS,
  "promoted": false
}
EOF
}

rdev_init_state_at() {
  local work_dir="$1"
  local name="$2"
  local ticket="$3"
  local is_local="${4:-false}"
  local is_design="${5:-false}"
  local is_god="${6:-false}"
  local mode="worktree"
  [[ "$is_local" == "true" ]] && mode="local"
  local state_dir="$work_dir/.claude/rdev"
  mkdir -p "$state_dir"
  cat > "$state_dir/state.json" <<EOF
{
  "stage": "plan",
  "name": "$name",
  "ticket": "$ticket",
  "mode": "$mode",
  "design": $is_design,
  "god_mode": $is_god,
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "review_loops_done": 0,
  "max_review_loops": $MAX_REVIEW_LOOPS,
  "promoted": false
}
EOF
}

# --- Worktree helpers ---

rdev_worktree_branch() {
  local worktree_path="$1"
  git -C "$worktree_path" rev-parse --abbrev-ref HEAD 2>/dev/null
}
