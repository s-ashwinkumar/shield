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
  if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    return 0
  fi

  echo "Creating tmux session '$TMUX_SESSION'..."
  tmux new-session -d -s "$TMUX_SESSION" -c "$RHYTHMS_DIR"

  if [[ -z "${TMUX:-}" ]]; then
    RDEV_ATTACH_AFTER=true
  fi
}

# Call at the end of a script to attach if we created a new session.
# Attaching to Herdr is interactive (`herdr`); left to the caller's shell.
# Kept as a no-op for API compatibility with existing callers.
rdev_maybe_attach() {
  if [[ "${RDEV_ATTACH_AFTER:-false}" == "true" ]]; then
    exec tmux attach-session -t "$TMUX_SESSION"
  fi
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
