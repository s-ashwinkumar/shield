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

# --- Task 2 ---
B() { RDEV_MUX_BACKEND=echo "$MUX" "$@"; }
assert_eq "tab-new" "herdr tab create --cwd /w/x --label USENG-1 --no-focus" \
  "$(B tab-new --name USENG-1 --cwd /w/x)"
assert_eq "agent-start passes argv after --" \
  "herdr agent start USENG-1 --cwd /w/x --tab t9 --no-focus -- claude --agent coordinator" \
  "$(B agent-start --name USENG-1 --cwd /w/x --tab t9 -- claude --agent coordinator)"
assert_eq "pane-split defaults" "herdr pane split --direction right --ratio 0.3 --cwd /w/x --no-focus" \
  "$(B pane-split --cwd /w/x)"
assert_eq "list" "herdr agent list" "$(B list)"
assert_eq "stream-list" "herdr tab list" "$(B stream-list --workspace wB)"
assert_eq "send" "herdr agent send tgt hello world" "$(B send --target tgt --text 'hello world')"
assert_eq "state" "herdr agent get tgt" "$(B state --target tgt)"
assert_eq "kill" "herdr tab close t9" "$(B kill --tab t9)"

# --- Task 3 ---
assert_eq "server-ensure checks status" "herdr status server" "$(B server-ensure)"
assert_eq "tab-find lists tabs" "herdr tab list" "$(B tab-find --name USENG-1)"
assert_eq "space-ensure (find path)" "herdr workspace list" "$(B space-ensure --name rhythms --cwd /r)"
assert_eq "space-find" "herdr workspace list" "$(B space-find --name rhythms)"
assert_eq "tab-new with workspace" \
  "herdr tab create --workspace wr --cwd /w/x --label USENG-1 --no-focus" \
  "$(B tab-new --name USENG-1 --cwd /w/x --workspace wr)"
assert_eq "pane-first" "herdr pane list" "$(B pane-first --tab wr:t1)"
assert_eq "pane-split targeting a pane, coordinator keeps 70%" \
  "herdr pane split p0 --direction right --ratio 0.7 --cwd /w/x --no-focus" \
  "$(B pane-split --pane p0 --dir right --ratio 0.7 --cwd /w/x)"
assert_eq "pane-run" "herdr pane run p0 claude --agent coordinator" \
  "$(B pane-run --pane p0 --text 'claude --agent coordinator')"
assert_eq "send-text" "herdr pane send-text p0 build it now" "$(B send-text --pane p0 --text 'build it now')"
assert_eq "send-enter" "herdr pane send-keys p0 Enter" "$(B send-enter --pane p0)"
assert_eq "send-key" "herdr pane send-keys p0 ctrl+c" "$(B send-key --pane p0 --key ctrl+c)"
assert_eq "pane-rename" "herdr pane rename p0 USENG-1" "$(B pane-rename --pane p0 --name USENG-1)"
assert_eq "tab-focus" "herdr tab focus wr:t1" "$(B tab-focus --tab wr:t1)"

echo "----"; echo "PASS=$PASS FAIL=$FAIL"; [[ $FAIL -eq 0 ]]
