#!/usr/bin/env bash
# Unit tests for libexec/_lib.sh (no herdr, no docker, no real config).
set -uo pipefail
LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../libexec" && pwd)/_lib.sh"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
TMP="$(cd "$TMP" && pwd -P)"   # macOS: /var -> /private/var, match git's paths
export SHIELD_CONFIG="$TMP/none" SHIELD_HOME="$TMP/home"
source "$LIB"
set +e   # the lib enables `set -e`; our assertions rely on non-zero returns
shield_load_config
P=0; F=0
ok(){ [[ "$2" == "$3" ]] && P=$((P+1)) || { F=$((F+1)); echo "FAIL $1: exp=[$2] got=[$3]"; }; }

# --- a repo with a worktree ---
REPO="$TMP/code/app"; mkdir -p "$REPO"
git -C "$REPO" init -q -b trunk && git -C "$REPO" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
git -C "$REPO" worktree add -q "$TMP/wt1" -b stream/X

ok "project_root from repo"     "$REPO" "$(shield_project_root "$REPO")"
ok "project_root from worktree" "$REPO" "$(shield_project_root "$TMP/wt1")"
shield_project_root "$TMP" >/dev/null 2>&1; ok "project_root outside git fails" 1 $?

# --- defaults with no .shield/config ---
shield_use_project "$REPO"
ok "default workspace"    "app"                      "$WORKSPACE"
ok "default worktree dir" "$REPO/.claude/worktrees"  "$WORKTREE_DIR"
ok "base branch fallback" "main"                     "$BASE_BRANCH"
ok "default tracker"      "auto"                     "$TRACKER"
ok "no deps"              "0"                        "${#DEPS[@]}"

# --- per-repo config ---
mkdir -p "$REPO/.shield"
cat > "$REPO/.shield/config" <<'CFG'
WORKSPACE=apps
BASE_BRANCH=trunk
WORKTREE_DIR=../wts
DEPS=("node_modules:package-lock.json:.:touch installed")
SERVICES=(web:3000)
PREVIEW_URL="https://app-pr-{pr}.example.com"
CFG
shield_use_project "$REPO"
ok "config workspace"      "apps"          "$WORKSPACE"
ok "config base"           "trunk"         "$BASE_BRANCH"
ok "relative worktree dir" "$REPO/../wts"  "$WORKTREE_DIR"
ok "config deps"           "1"             "${#DEPS[@]}"
ok "config preview"        "https://app-pr-{pr}.example.com" "$PREVIEW_URL"
rm "$REPO/.shield/config"; shield_use_project "$REPO"
ok "reset between projects" "0" "${#DEPS[@]}"
ok "reset preview"          ""  "$PREVIEW_URL"

# --- resolve_project: SHIELD_PROJECT by name under PROJECTS_ROOT, and by cwd ---
PROJECTS_ROOT="$TMP/code"
( SHIELD_PROJECT=app; shield_resolve_project; echo "$PROJECT_DIR" ) > "$TMP/o" 2>&1
ok "resolve by name" "$REPO" "$(cat "$TMP/o")"
( cd "$TMP/wt1" && shield_resolve_project && echo "$PROJECT_DIR" ) > "$TMP/o" 2>&1
ok "resolve by cwd (worktree)" "$REPO" "$(cat "$TMP/o")"
( cd "$TMP" && shield_resolve_project ) >/dev/null 2>&1
ok "resolve outside git dies" 1 $?

# --- stream registry ---
shield_register_stream ENG-1 "$TMP/wt1"
ok "registered" "$TMP/wt1" "$(shield_stream_dir ENG-1)"
( shield_register_stream ENG-1 "$TMP/elsewhere" ) >/dev/null 2>&1
ok "collision refused" 1 $?
shield_register_stream GONE "$TMP/missing"
ok "names skip missing dirs" "ENG-1" "$(shield_stream_names | tr '\n' ' ' | sed 's/ $//')"
( cd "$TMP" && shield_resolve_stream ENG-1 && echo "$PROJECT_DIR|$WORK_DIR" ) > "$TMP/o" 2>&1
ok "resolve_stream from anywhere" "$REPO|$TMP/wt1" "$(cat "$TMP/o")"
shield_unregister_stream ENG-1
ok "unregistered" "" "$(shield_stream_dir ENG-1)"

# --- git excludes: idempotent, one block ---
shield_use_project "$REPO"
shield_git_exclude; shield_git_exclude
EX="$REPO/.git/info/exclude"
ok "one exclude block" "1" "$(grep -c '^# >>> shield >>>$' "$EX")"
grep -qx '/.claude/' "$EX"; ok "untracked .claude excluded whole" 0 $?
mkdir -p "$TMP/wt1/.claude/shield"; echo '{}' > "$TMP/wt1/.claude/shield/state.json"
ok "state invisible to git status" "" "$(git -C "$TMP/wt1" status --porcelain)"

# --- dependency sharing (host) ---
echo A > "$REPO/package-lock.json"; mkdir -p "$REPO/node_modules"
DEPS=("node_modules:package-lock.json:.:touch installed")
echo A > "$TMP/wt1/package-lock.json"
shield_share_deps "$TMP/wt1" >/dev/null
[[ -L "$TMP/wt1/node_modules" ]]; ok "lock match -> symlink" 0 $?
echo B > "$TMP/wt1/package-lock.json"
shield_share_deps "$TMP/wt1" >/dev/null
[[ ! -e "$TMP/wt1/node_modules" && -f "$TMP/wt1/installed" ]]; ok "lock diverged -> own install" 0 $?
shield_lock_diverged "$TMP/wt1" "nope.lock"; ok "missing lock -> not diverged" 1 $?

# --- container path mapping ---
CONTAINER=c1 CONTAINER_WORKDIR=/workspaces/app
ok "exec path in container" "/workspaces/app/.claude/worktrees/X" "$(shield_exec_path "$REPO/.claude/worktrees/X")"
shield_exec_path "$TMP/wt1" >/dev/null 2>&1; ok "outside project not mappable" 1 $?
CONTAINER=""
ok "exec path on host" "$TMP/wt1" "$(shield_exec_path "$TMP/wt1")"

# --- state init carries project facts ---
PREVIEW_URL="https://x-{pr}.dev"; MAX_REVIEW_LOOPS=2
shield_init_state_at "$TMP/wt1" ENG-9 ENG-9 worktree false false
ok "state project" "$REPO" "$(jq -r .project "$TMP/wt1/.claude/shield/state.json")"
ok "state preview" "https://x-{pr}.dev" "$(jq -r .preview_url_pattern "$TMP/wt1/.claude/shield/state.json")"
ok "state loops"   "2" "$(jq -r .max_review_loops "$TMP/wt1/.claude/shield/state.json")"

echo "P=$P F=$F"; [[ $F -eq 0 ]]
