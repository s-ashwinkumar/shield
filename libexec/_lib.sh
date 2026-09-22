#!/usr/bin/env bash
# shield shared library -- sourced by every libexec/shield-* command.
#
# Two config layers:
#   global   ~/.config/shield/config   (SHIELD_CONFIG overrides) — user-wide defaults
#   project  <repo>/.shield/config     — optional, per repo (deps, container, ports, ...)
# The project is the git repo you are in (worktrees resolve to their main repo),
# or SHIELD_PROJECT (set by `shield -C <path|name>`), or DEFAULT_PROJECT.
# Streams are registered in ~/.shield/streams/<name> so any command can find a
# stream's worktree (and therefore its project) from anywhere.

set -euo pipefail

SHIELD_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
SHIELD_LIBEXEC="$SHIELD_ROOT/libexec"
SHIELD_CONFIG="${SHIELD_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/shield/config}"
SHIELD_HOME="${SHIELD_HOME:-$HOME/.shield}"
SHIELD_STREAMS="$SHIELD_HOME/streams"
# Per-worktree state dir, relative to the work dir.
SHIELD_STATE_REL=".claude/shield"

# The substrate adapter (Herdr), always called by absolute path.
mux() { "$SHIELD_LIBEXEC/shield-mux" "$@"; }

shield_die() { echo "Error: $*" >&2; exit 1; }

# --- Global config ---

shield_load_config() {
  if [[ -f "$SHIELD_CONFIG" ]]; then
    # shellcheck source=/dev/null
    source "$SHIELD_CONFIG"
  fi
  PROJECTS_ROOT="${PROJECTS_ROOT:-}"; PROJECTS_ROOT="${PROJECTS_ROOT/#\~/$HOME}"
  DEFAULT_PROJECT="${DEFAULT_PROJECT:-}"; DEFAULT_PROJECT="${DEFAULT_PROJECT/#\~/$HOME}"
  NOTIFY="${NOTIFY:-true}"
  MAX_REVIEW_LOOPS="${MAX_REVIEW_LOOPS:-3}"
  SHIELD_RUNNER="${SHIELD_RUNNER:-claude}"
  SHIELD_TERMINAL_APP="${SHIELD_TERMINAL_APP:-}"
  # Herdr workspace that holds the coulson tab (streams live in per-project workspaces).
  SHIELD_WORKSPACE="${SHIELD_WORKSPACE:-shield}"
}

# --- Project resolution ---

# Echo the main repo root for any path inside a repo or one of its worktrees.
shield_project_root() {  # shield_project_root <dir>
  local common
  common="$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 1
  if [[ "$(basename "$common")" == ".git" ]]; then
    dirname "$common"
  else
    git -C "$1" rev-parse --show-toplevel 2>/dev/null
  fi
}

# Load <root>/.shield/config over fresh defaults. Safe to call repeatedly
# (e.g. rstatus iterating several projects): every project key is reset first.
shield_use_project() {  # shield_use_project <project_root>
  PROJECT_DIR="$1"
  WORKSPACE="" WORKTREE_DIR="" BASE_BRANCH="" CONTAINER="" CONTAINER_WORKDIR=""
  PREVIEW_URL="" TRACKER="" SETUP_HOOK=""
  DEPS=() SERVICES=() COPY_FILES=(.env .env.local .local.env)
  if [[ -f "$PROJECT_DIR/.shield/config" ]]; then
    # shellcheck source=/dev/null
    source "$PROJECT_DIR/.shield/config"
  fi
  WORKSPACE="${WORKSPACE:-$(basename "$PROJECT_DIR")}"
  WORKTREE_DIR="${WORKTREE_DIR:-$PROJECT_DIR/.claude/worktrees}"
  WORKTREE_DIR="${WORKTREE_DIR/#\~/$HOME}"
  [[ "$WORKTREE_DIR" == /* ]] || WORKTREE_DIR="$PROJECT_DIR/$WORKTREE_DIR"
  CONTAINER_WORKDIR="${CONTAINER_WORKDIR:-$PROJECT_DIR}"
  TRACKER="${TRACKER:-auto}"
  SETUP_HOOK="${SETUP_HOOK:-.shield/setup}"
  [[ "$SETUP_HOOK" == /* ]] || SETUP_HOOK="$PROJECT_DIR/$SETUP_HOOK"
  if [[ -z "$BASE_BRANCH" ]]; then
    BASE_BRANCH="$(git -C "$PROJECT_DIR" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)"
    BASE_BRANCH="${BASE_BRANCH#origin/}"
    BASE_BRANCH="${BASE_BRANCH:-main}"
  fi
}

# Pick the project: SHIELD_PROJECT (a path, or a name under PROJECTS_ROOT) >
# the repo containing $PWD > DEFAULT_PROJECT.
shield_resolve_project() {
  local want="${SHIELD_PROJECT:-}" root=""
  if [[ -n "$want" ]]; then
    want="${want/#\~/$HOME}"
    if [[ ! -d "$want" && -n "$PROJECTS_ROOT" && -d "$PROJECTS_ROOT/$want" ]]; then
      want="$PROJECTS_ROOT/$want"
    fi
    [[ -d "$want" ]] || shield_die "project '$SHIELD_PROJECT' not found (not a directory${PROJECTS_ROOT:+, nor under $PROJECTS_ROOT})"
    root="$(shield_project_root "$want")" || shield_die "'$want' is not inside a git repo"
  elif root="$(shield_project_root "$PWD")"; then
    :
  elif [[ -n "$DEFAULT_PROJECT" ]]; then
    root="$(shield_project_root "$DEFAULT_PROJECT")" || shield_die "DEFAULT_PROJECT ($DEFAULT_PROJECT) is not a git repo"
  else
    shield_die "not inside a git repo. cd into a project, or pass: shield -C <path|name> ..."
  fi
  shield_use_project "$root"
}

# --- Stream registry (~/.shield/streams/<name> holds the stream's work dir) ---

shield_stream_dir() {  # echo the registered work dir for <name>, or nothing
  local f="$SHIELD_STREAMS/$1"
  [[ -f "$f" ]] && cat "$f"
  return 0
}

shield_register_stream() {  # shield_register_stream <name> <work_dir>
  local name="$1" dir="$2" existing
  existing="$(shield_stream_dir "$name")"
  if [[ -n "$existing" && "$existing" != "$dir" && -d "$existing" ]]; then
    shield_die "stream '$name' already exists at $existing. Clean it up first, or pick another name."
  fi
  mkdir -p "$SHIELD_STREAMS"
  printf '%s\n' "$dir" > "$SHIELD_STREAMS/$name"
}

shield_unregister_stream() { rm -f "$SHIELD_STREAMS/$1"; }

# All registered stream names whose work dir still exists.
shield_stream_names() {
  local f
  for f in "$SHIELD_STREAMS"/*; do
    [[ -f "$f" ]] || continue
    [[ -d "$(cat "$f")" ]] && basename "$f"
  done
  return 0
}

# Resolve a stream by name: the registry first (sets its project), else the
# current project. Sets PROJECT_DIR (+ project config) and WORK_DIR.
shield_resolve_stream() {  # shield_resolve_stream <name>
  local dir root
  dir="$(shield_stream_dir "$1")"
  if [[ -n "$dir" && -d "$dir" ]] && root="$(shield_project_root "$dir")"; then
    shield_use_project "$root"
    WORK_DIR="$dir"
    return 0
  fi
  shield_resolve_project
  WORK_DIR="$(shield_resolve_work_dir "$1")"
}

# --- Herdr stream helpers ---

shield_ensure_session() {
  # Under Herdr, the persistent server IS the session. Ensure it's up.
  if ! mux server-ensure >/dev/null 2>&1; then
    echo "Herdr server not running. Start it with: herdr" >&2
    return 1
  fi
}

# Echo the Herdr tab id for a stream (in the project workspace), or empty.
shield_stream_tab() {
  local ws
  ws="$(mux space-find --name "$WORKSPACE")"
  [[ -z "$ws" ]] && return 0
  mux tab-find --name "$1" --workspace "$ws"
}

# Send a message to the LIVE coordinator in a stream tab's first pane, then submit
# it (Enter) — types into the running agent, like typing in the pane yourself.
shield_coord_msg() {
  local pane
  pane="$(mux pane-first --tab "$1")"
  [[ -z "$pane" ]] && return 1
  mux send-text --pane "$pane" --text "$2"
  mux send-enter --pane "$pane"
}

# --- Repo hygiene ---

# Keep shield's per-worktree files out of `git status` (which would otherwise
# make `shield clean` refuse with "uncommitted changes"). Writes a marked block
# to the repo's shared info/exclude — local only, never committed.
shield_git_exclude() {
  local common ex lines
  common="$(git -C "$PROJECT_DIR" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 0
  ex="$common/info/exclude"
  if [[ -z "$(git -C "$PROJECT_DIR" ls-files .claude 2>/dev/null | head -1)" ]]; then
    lines="/.claude/"
  else
    lines="/$SHIELD_STATE_REL/
/.claude/agents/coordinator.md
/.claude/agents/builder.md
/.claude/agents/reviewer.md
/.claude/agents/coulson.md
/.claude/settings.local.json
/.claude/worktrees/"
  fi
  if [[ -z "$(git -C "$PROJECT_DIR" ls-files docs/plans 2>/dev/null | head -1)" ]]; then
    lines="$lines
/docs/plans"
  fi
  mkdir -p "$(dirname "$ex")"; touch "$ex"
  if [[ "$(sed -n '/^# >>> shield >>>$/,/^# <<< shield <<<$/p' "$ex" | sed '1d;$d')" != "$lines" ]]; then
    sed -i '' '/^# >>> shield >>>$/,/^# <<< shield <<<$/d' "$ex"
    printf '# >>> shield >>>\n%s\n# <<< shield <<<\n' "$lines" >> "$ex"
  fi
}

# --- Container (optional: CONTAINER in .shield/config) ---

# Path of a host dir as seen by the command runner: itself on the host, or the
# mapped path inside CONTAINER (the project is mounted at CONTAINER_WORKDIR).
shield_exec_path() {  # shield_exec_path <host_dir>
  if [[ -z "$CONTAINER" ]]; then echo "$1"; return 0; fi
  case "$1" in
    "$PROJECT_DIR"|"$PROJECT_DIR"/*) echo "$CONTAINER_WORKDIR${1#"$PROJECT_DIR"}" ;;
    *) echo "shield: $1 is outside $PROJECT_DIR, so it isn't visible in container '$CONTAINER'" >&2; return 1 ;;
  esac
}

# Run a shell command in a host dir — in CONTAINER when set, else on the host.
shield_exec() {  # shield_exec <host_dir> <cmd...>
  local dir="$1" cpath; shift
  cpath="$(shield_exec_path "$dir")" || return 1
  if [[ -n "$CONTAINER" ]]; then
    docker exec "$CONTAINER" bash -lc "cd '$cpath' && $*"
  else
    (cd "$dir" && bash -lc "$*")
  fi
}

# Make a host-created worktree usable in-container: alias the host project path
# to the mount so git's worktree gitdir pointer (a host path) resolves. No-op
# without a container or when the mount path equals the host path.
shield_container_prep() {
  [[ -n "$CONTAINER" && "$CONTAINER_WORKDIR" != "$PROJECT_DIR" ]] || return 0
  docker exec "$CONTAINER" bash -lc "host='$PROJECT_DIR'
    if [ ! -e \"\$host\" ]; then
      mkdir -p \"\$(dirname \"\$host\")\"
      ln -s '$CONTAINER_WORKDIR' \"\$host\"
    fi" 2>/dev/null || true
}

# --- Dependencies ---

# True (0) if the worktree's copy of <rel_lockfile> differs from mainline's.
shield_lock_diverged() {  # shield_lock_diverged <worktree_dir> <rel_lockfile>
  local wt="$1" rel="$2"
  [[ -f "$PROJECT_DIR/$rel" && -f "$wt/$rel" ]] || return 1
  ! diff -q "$PROJECT_DIR/$rel" "$wt/$rel" >/dev/null 2>&1
}

# For each DEPS entry "dep_dir:lockfile:subdir:install cmd": symlink mainline's
# dep dir into the worktree when the lockfile matches; run the install in the
# worktree when it diverges.
shield_share_deps() {  # shield_share_deps <worktree_dir>
  local wt="$1" spec dep lock svc inst
  if (( ${#DEPS[@]} == 0 )); then
    echo "  no DEPS in .shield/config — nothing to share"
    return 0
  fi
  for spec in "${DEPS[@]}"; do
    IFS=: read -r dep lock svc inst <<<"$spec"
    [[ -e "$PROJECT_DIR/$dep" ]] || { echo "  skip $dep (not in mainline)"; continue; }
    if shield_lock_diverged "$wt" "$lock"; then
      # worktree's lock differs from mainline -> it needs its OWN deps. Drop any
      # stale mainline symlink first (else the divergent worktree runs main's deps).
      [[ -L "$wt/$dep" ]] && rm -f "$wt/$dep"
      if [[ -e "$wt/$dep" ]]; then
        echo "  $dep: own install present (lock diverged)"
      else
        echo "  $dep: lock diverged -> '$inst' in worktree"
        shield_exec "$wt/$svc" "$inst" || echo "  WARN: $inst failed for $svc"
      fi
    elif [[ -e "$wt/$dep" ]]; then
      echo "  keep $dep (present, lock matches)"
    else
      mkdir -p "$(dirname "$wt/$dep")"
      ln -s "$PROJECT_DIR/$dep" "$wt/$dep"
      echo "  $dep: symlinked from mainline"
    fi
  done
}

# Copy untracked env files (COPY_FILES) from mainline into a new worktree.
shield_copy_files() {  # shield_copy_files <worktree_dir>
  local f
  for f in ${COPY_FILES[@]+"${COPY_FILES[@]}"}; do
    if [[ -f "$PROJECT_DIR/$f" && ! -e "$1/$f" ]]; then
      mkdir -p "$(dirname "$1/$f")"
      cp "$PROJECT_DIR/$f" "$1/$f"
      echo "Copied $f"
    fi
  done
}

# Run the project's setup hook (SETUP_HOOK, default .shield/setup) for a worktree.
# Repo-specific prep (per-worktree DBs, tool trust, codegen, ...) belongs there.
shield_run_setup_hook() {  # shield_run_setup_hook <worktree_dir> <stream>
  [[ -x "$SETUP_HOOK" ]] || return 0
  echo "  running setup hook: $SETUP_HOOK"
  (cd "$1" && SHIELD_STREAM="$2" SHIELD_WORKTREE="$1" SHIELD_PROJECT_DIR="$PROJECT_DIR" \
     SHIELD_CONTAINER="$CONTAINER" SHIELD_EXEC_PATH="$(shield_exec_path "$1" 2>/dev/null || true)" \
     "$SETUP_HOOK") || echo "  WARN: setup hook failed"
}

# --- Notifications ---

shield_notify() {
  local title="${1:-shield}"
  local message="${2:-Done}"
  if [[ "$NOTIFY" == "true" ]] && command -v terminal-notifier &>/dev/null; then
    terminal-notifier -title "$title" -message "$message" -sound default -group shield 2>/dev/null || true
  fi
}

# --- State management ---

# Resolve work directory for a stream: registry, then worktree, then local mode.
shield_resolve_work_dir() {
  local name="$1" dir
  dir="$(shield_stream_dir "$name")"
  if [[ -n "$dir" && -f "$dir/$SHIELD_STATE_REL/state.json" ]]; then
    echo "$dir"
    return
  fi
  if [[ -f "$WORKTREE_DIR/$name/$SHIELD_STATE_REL/state.json" ]]; then
    echo "$WORKTREE_DIR/$name"
    return
  fi
  # Local mode (state in the main repo's .claude/shield/)
  local st="$PROJECT_DIR/$SHIELD_STATE_REL/state.json"
  if [[ -f "$st" ]]; then
    local ticket stream_name
    ticket=$(jq -r '.ticket // ""' "$st")
    stream_name=$(jq -r '.name // ""' "$st")
    if [[ "$ticket" == "$name" || "$stream_name" == "$name" ]]; then
      echo "$PROJECT_DIR"
      return
    fi
  fi
  # Fall back to worktree path (may not exist yet)
  echo "$WORKTREE_DIR/$name"
}

shield_state_file() {
  echo "$(shield_resolve_work_dir "$1")/$SHIELD_STATE_REL/state.json"
}

shield_read_state() {
  local state_file
  state_file="$(shield_state_file "$1")"
  if [[ -f "$state_file" ]]; then
    cat "$state_file"
  else
    echo '{}'
  fi
}

shield_get_stage() {
  shield_read_state "$1" | jq -r '.stage // "unknown"'
}

shield_get_stage_from() {
  if [[ -f "$1" ]]; then
    jq -r '.stage // "unknown"' "$1"
  else
    echo "unknown"
  fi
}

shield_update_state() {
  local state_file tmp
  state_file="$(shield_state_file "$1")"
  tmp=$(jq --arg k "$2" --arg v "$3" '.[$k] = $v' "$state_file")
  echo "$tmp" > "$state_file"
}

# shield_signal_attention <name> <type> <summary>
# Raise a coordinator-flagged attention signal on the stream's state file.
# The watcher's scan picks up the changed .attention.ts and emits one item.
# This is the ONLY way a plan_gate should be raised — on a genuinely
# ready-for-approval plan, never on mere entry into the plan stage.
shield_signal_attention() {
  local name="$1" type="$2" summary="$3"
  local state_file
  state_file="$(shield_state_file "$name")"
  [[ -f "$state_file" ]] || { echo "shield_signal_attention: no state file for '$name'" >&2; return 1; }
  local now; now=$(date +%s)
  local tmp
  tmp=$(jq --arg t "$type" --arg s "$summary" --argjson ts "$now" \
          '.attention = {type:$t, summary:$s, ts:$ts}' "$state_file") || return 1
  echo "$tmp" > "$state_file"
}

# Project facts the agents read from state.json (refreshed on every launch).
shield_state_project_meta() {  # shield_state_project_meta <state_file>
  local tmp
  tmp=$(jq --arg p "$PROJECT_DIR" --arg b "$BASE_BRANCH" --arg t "$TRACKER" --arg u "$PREVIEW_URL" \
    '.project = $p | .base_branch = $b | .tracker = $t
     | if $u == "" then del(.preview_url_pattern) else .preview_url_pattern = $u end' "$1") || return 1
  echo "$tmp" > "$1"
}

shield_init_state_at() {  # <work_dir> <name> <ticket> <mode> <design> <god> [stage]
  local state_dir="$1/$SHIELD_STATE_REL"
  mkdir -p "$state_dir"
  cat > "$state_dir/state.json" <<EOF
{
  "stage": "${7:-plan}",
  "name": "$2",
  "ticket": "$3",
  "mode": "$4",
  "design": $5,
  "god_mode": $6,
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "review_loops_done": 0,
  "max_review_loops": $MAX_REVIEW_LOOPS
}
EOF
  shield_state_project_meta "$state_dir/state.json"
}

# Copy shield's agents into a work dir's .claude/agents/ (they hold permission
# frontmatter the session needs). An agent file the repo tracks in git is the
# repo's own and is never overwritten.
shield_install_agents() {  # shield_install_agents <work_dir>
  local a rel
  mkdir -p "$1/.claude/agents"
  for a in "$SHIELD_ROOT"/agents/*.md; do
    rel=".claude/agents/$(basename "$a")"
    git -C "$PROJECT_DIR" ls-files --error-unmatch "$rel" >/dev/null 2>&1 && continue
    cp "$a" "$1/$rel"
  done
}

# Remove shield's agent copies from a work dir (tracked repo agents are kept).
shield_remove_agents() {  # shield_remove_agents <work_dir>
  local a rel
  for a in "$SHIELD_ROOT"/agents/*.md; do
    rel=".claude/agents/$(basename "$a")"
    git -C "$PROJECT_DIR" ls-files --error-unmatch "$rel" >/dev/null 2>&1 && continue
    rm -f "$1/$rel"
  done
}

# Copy the workflow playbook into a work dir (git-excluded via shield_git_exclude).
shield_install_playbook() {  # shield_install_playbook <work_dir>
  [[ -d "$SHIELD_ROOT/playbook" ]] || return 0
  mkdir -p "$1/$SHIELD_STATE_REL/playbook"
  cp -R "$SHIELD_ROOT"/playbook/* "$1/$SHIELD_STATE_REL/playbook/"
}
