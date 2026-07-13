#!/usr/bin/env bash
# Smoke test for rfleet against fixture state dirs (no herdr, no config).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RFLEET="$SCRIPT_DIR/../bin/rfleet"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
FIX="$TMP/streams"; ATT="$TMP/attention"
mkdir -p "$FIX/USENG-1/.claude/rdev" "$FIX/USENG-2/.claude/rdev"

run_rfleet() {
  RFLEET_ONCE=1 RFLEET_SHADOW=1 RFLEET_NO_PANES=1 \
  RFLEET_SCAN_DIR="$FIX" RFLEET_HOME="$ATT" "$RFLEET" >/dev/null
}

fail() { echo "FAIL: $1"; exit 1; }
count() { ls "$ATT/$1" 2>/dev/null | grep -c '\.json$' || true; }

# 1) plan stage → plan_gate item
echo '{"stage":"plan","ticket":"USENG-1"}' > "$FIX/USENG-1/.claude/rdev/state.json"
echo '{"stage":"build","ticket":"USENG-2"}' > "$FIX/USENG-2/.claude/rdev/state.json"
run_rfleet
[[ $(count pending) -eq 1 ]] || fail "expected 1 pending item, got $(count pending)"
ls "$ATT/pending" | grep -q "USENG-1--plan_gate" || fail "expected plan_gate for USENG-1"

# 2) re-scan → no duplicates
run_rfleet
[[ $(count pending) -eq 1 ]] || fail "dedupe broken: $(count pending) items"

# 3) stage moves past plan → plan_gate auto-cancelled; done → done_followups
echo '{"stage":"done","ticket":"USENG-1","demo_required":true,"dev1_ready":false}' \
  > "$FIX/USENG-1/.claude/rdev/state.json"
run_rfleet
ls "$ATT/pending" | grep -q "USENG-1--plan_gate" && fail "plan_gate not cancelled"
ls "$ATT/done"    | grep -q "USENG-1--plan_gate" || fail "cancelled item not in done/"
ls "$ATT/pending" | grep -q "USENG-1--done_followups" || fail "expected done_followups"
grep -q "Supercut demo needed" "$ATT/pending/"USENG-1--done_followups--*.json \
  || fail "done_followups missing demo note"

# 4) coordinator attention flag → typed item; clearing it → cancelled
jq '.attention={"type":"qa_escalation","summary":"3 QA rounds still failing","ts":"t1"}' \
  <<< '{"stage":"qa","ticket":"USENG-2"}' > "$FIX/USENG-2/.claude/rdev/state.json"
run_rfleet
ls "$ATT/pending" | grep -q "USENG-2--qa_escalation" || fail "expected qa_escalation"
echo '{"stage":"qa","ticket":"USENG-2"}' > "$FIX/USENG-2/.claude/rdev/state.json"
run_rfleet
ls "$ATT/pending" | grep -q "USENG-2--qa_escalation" && fail "flagged item not cancelled"

# 5) dead-man (non-shadow): old unacked item fires escalated_raw
f=$(ls "$ATT/pending/"USENG-1--done_followups--*.json)
jq '.created_at = (.created_at - 3600)' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
RFLEET_ONCE=1 RFLEET_NO_PANES=1 RFLEET_DEADMAN_MIN=10 \
  RFLEET_SCAN_DIR="$FIX" RFLEET_HOME="$ATT" "$RFLEET" >/dev/null 2>&1
[[ $(jq -r '.escalated_raw' "$f") == "true" ]] || fail "dead-man did not fire"

# 6) heartbeat exists
[[ -f "$ATT/heartbeat" ]] || fail "no heartbeat"

echo "PASS: all rfleet smoke tests"
