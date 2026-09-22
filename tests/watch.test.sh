#!/usr/bin/env bash
# Smoke test for shield watch against fixture state dirs (no herdr, no config).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WATCH="$SCRIPT_DIR/../libexec/shield-watch"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
FIX="$TMP/streams"; ATT="$TMP/attention"
mkdir -p "$FIX/ENG-1/.claude/shield" "$FIX/ENG-2/.claude/shield"

run_watch() {
  SHIELD_WATCH_ONCE=1 SHIELD_WATCH_SHADOW=1 SHIELD_WATCH_NO_PANES=1 \
  SHIELD_WATCH_SCAN_DIR="$FIX" SHIELD_WATCH_HOME="$ATT" "$WATCH" >/dev/null
}

fail() { echo "FAIL: $1"; exit 1; }
count() { ls "$ATT/$1" 2>/dev/null | grep -c '\.json$' || true; }

# 1) coordinator raises the plan gate (shield gate → state.attention) → plan_gate item
echo '{"stage":"plan","ticket":"ENG-1","attention":{"type":"plan_gate","summary":"Plan ready for approval","ts":1}}' \
  > "$FIX/ENG-1/.claude/shield/state.json"
echo '{"stage":"build","ticket":"ENG-2"}' > "$FIX/ENG-2/.claude/shield/state.json"
run_watch
[[ $(count pending) -eq 1 ]] || fail "expected 1 pending item, got $(count pending)"
ls "$ATT/pending" | grep -q "ENG-1--plan_gate" || fail "expected plan_gate for ENG-1"

# 2) re-scan → no duplicates
run_watch
[[ $(count pending) -eq 1 ]] || fail "dedupe broken: $(count pending) items"

# 3) stage moves past plan → plan_gate auto-cancelled; done → done_followups
echo '{"stage":"done","ticket":"ENG-1","demo_required":true}' \
  > "$FIX/ENG-1/.claude/shield/state.json"
run_watch
ls "$ATT/pending" | grep -q "ENG-1--plan_gate" && fail "plan_gate not cancelled"
ls "$ATT/done"    | grep -q "ENG-1--plan_gate" || fail "cancelled item not in done/"
ls "$ATT/pending" | grep -q "ENG-1--done_followups" || fail "expected done_followups"
grep -q "demo needed" "$ATT/pending/"ENG-1--done_followups--*.json \
  || fail "done_followups missing demo note"

# 4) coordinator attention flag → typed item; clearing it → cancelled
jq '.attention={"type":"qa_escalation","summary":"3 QA rounds still failing","ts":"t1"}' \
  <<< '{"stage":"qa","ticket":"ENG-2"}' > "$FIX/ENG-2/.claude/shield/state.json"
run_watch
ls "$ATT/pending" | grep -q "ENG-2--qa_escalation" || fail "expected qa_escalation"
echo '{"stage":"qa","ticket":"ENG-2"}' > "$FIX/ENG-2/.claude/shield/state.json"
run_watch
ls "$ATT/pending" | grep -q "ENG-2--qa_escalation" && fail "flagged item not cancelled"

# 5) dead-man (non-shadow): old unacked item fires escalated_raw
f=$(ls "$ATT/pending/"ENG-1--done_followups--*.json)
jq '.created_at = (.created_at - 3600)' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
SHIELD_WATCH_ONCE=1 SHIELD_WATCH_NO_PANES=1 SHIELD_WATCH_DEADMAN_MIN=10 \
  SHIELD_WATCH_SCAN_DIR="$FIX" SHIELD_WATCH_HOME="$ATT" "$WATCH" >/dev/null 2>&1
[[ $(jq -r '.escalated_raw' "$f") == "true" ]] || fail "dead-man did not fire"

# 6) heartbeat exists
[[ -f "$ATT/heartbeat" ]] || fail "no heartbeat"

echo "PASS: all shield watch smoke tests"
