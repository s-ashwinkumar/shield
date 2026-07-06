#!/usr/bin/env bash
# Pure unit test for rdev_lock_diverged (no docker needed).
set -uo pipefail
export RDEV_CONFIG=/dev/null
RHYTHMS_DIR=$(mktemp -d); export RHYTHMS_DIR
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin" && pwd)/_rdev_lib.sh" 2>/dev/null || true
set +e   # the lib enables `set -e`; our assertions rely on non-zero returns
P=0; F=0
ok(){ [[ "$2" == "$3" ]] && P=$((P+1)) || { F=$((F+1)); echo "FAIL $1: exp=$2 got=$3"; }; }

mkdir -p "$RHYTHMS_DIR/webui"; wt=$(mktemp -d); mkdir -p "$wt/webui"
echo A > "$RHYTHMS_DIR/webui/package-lock.json"; echo A > "$wt/webui/package-lock.json"
rdev_lock_diverged "$wt" "webui/package-lock.json"; ok "same->not diverged" 1 $?
echo B > "$wt/webui/package-lock.json"
rdev_lock_diverged "$wt" "webui/package-lock.json"; ok "diff->diverged" 0 $?
rm -f "$wt/webui/package-lock.json"
rdev_lock_diverged "$wt" "webui/package-lock.json"; ok "missing->not diverged" 1 $?

echo "P=$P F=$F"; [[ $F -eq 0 ]]
