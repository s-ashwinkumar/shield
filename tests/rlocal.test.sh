#!/usr/bin/env bash
# rlocal lease tests (RDEV_LEASE_FILE bypasses config; no docker/herdr needed).
set -uo pipefail
BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin" && pwd)/rlocal"
export RDEV_LEASE_FILE="$(mktemp -d)/lease.json"
P=0; F=0
ok(){ [[ "$2" == "$3" ]] && P=$((P+1)) || { F=$((F+1)); echo "FAIL $1: exp=[$2] got=[$3]"; }; }

ok "free status"      "local server: FREE" "$("$BIN" status)"
ok "holder empty"     ""                   "$("$BIN" holder)"

"$BIN" claim USENG-1 --worktree /w/1 >/dev/null 2>&1; ok "claim rc" 0 $?
ok "holder after claim" "USENG-1" "$("$BIN" holder)"

"$BIN" claim USENG-2 --worktree /w/2 >/dev/null 2>&1; ok "other claim blocked" 1 $?
"$BIN" claim USENG-1 --worktree /w/1 >/dev/null 2>&1; ok "self reclaim ok" 0 $?

"$BIN" release USENG-2 >/dev/null 2>&1; ok "wrong-name release blocked" 1 $?
"$BIN" release USENG-1 >/dev/null 2>&1; ok "release rc" 0 $?
ok "holder after release" "" "$("$BIN" holder)"

# an ancient lease: without --ttl it stays claimed (blocked); with --ttl it's stale
echo '{"holder":"ghost","worktree":"/w/g","claimed_at":1,"pid":999999,"user":"x"}' > "$RDEV_LEASE_FILE"
"$BIN" claim USENG-4 --worktree /w/4 >/dev/null 2>&1; ok "no-ttl: ancient lease still blocks" 1 $?
"$BIN" claim USENG-3 --worktree /w/3 --ttl 5 >/dev/null 2>&1; ok "ttl: stale takeover rc" 0 $?
ok "holder after takeover" "USENG-3" "$("$BIN" holder)"

echo "P=$P F=$F"; [[ $F -eq 0 ]]
