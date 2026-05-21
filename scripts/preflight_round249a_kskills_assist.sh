#!/bin/bash
# Round 249A-KSKILLS-ASSIST: K-Skills Assist Runtime Preflight
# Policy: No fake API calls, no auto booking/payment, honest checklist responses

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MYTEAM="$REPO_ROOT/MyTeam"
PASS=0
FAIL=0

check() {
    local desc="$1"
    local result="$2"
    if [ "$result" = "pass" ]; then
        echo "  ✓ $desc"
        PASS=$((PASS+1))
    else
        echo "  ✗ $desc"
        FAIL=$((FAIL+1))
    fi
}

echo "=== Round 249A-KSKILLS-ASSIST Preflight ==="

# 1. KSkillAssistRuntime.swift exists
[ -f "$MYTEAM/KSkillAssistRuntime.swift" ] && check "KSkillAssistRuntime.swift exists" "pass" || check "KSkillAssistRuntime.swift exists" "fail"

# 2. KSkillAssistIntent enum covers all 11 intents
INTENT_COUNT=$(grep -c "^    case " "$MYTEAM/KSkillAssistRuntime.swift" 2>/dev/null || echo "0")
[ "$INTENT_COUNT" -ge 11 ] && check "KSkillAssistIntent has 11+ intents ($INTENT_COUNT found)" "pass" || check "KSkillAssistIntent has 11+ intents ($INTENT_COUNT found)" "fail"

# 3. hardBlockedActions field in KSkillAssistResponse
grep -q "hardBlockedActions" "$MYTEAM/KSkillAssistRuntime.swift" && check "hardBlockedActions field exists" "pass" || check "hardBlockedActions field exists" "fail"

# 4. requiredUserInputs field in KSkillAssistResponse
grep -q "requiredUserInputs" "$MYTEAM/KSkillAssistRuntime.swift" && check "requiredUserInputs field exists" "pass" || check "requiredUserInputs field exists" "fail"

# 5. KTX auto-booking blocked
grep -q "자동 좌석 예매 확정\|자동 예매" "$MYTEAM/KSkillAssistRuntime.swift" && check "KTX auto-booking in hardBlockedActions" "pass" || check "KTX auto-booking in hardBlockedActions" "fail"

# 6. Stock fake quote blocked
grep -q "매수/매도 확정\|수익 보장" "$MYTEAM/KSkillAssistRuntime.swift" && check "Stock fake quote in hardBlockedActions" "pass" || check "Stock fake quote in hardBlockedActions" "fail"

# 7. DART fake lookup blocked
grep -q "DART.*조회한 척\|직접 조회한 척" "$MYTEAM/KSkillAssistRuntime.swift" && check "DART fake lookup in hardBlockedActions" "pass" || check "DART fake lookup in hardBlockedActions" "fail"

# 8. SkillAvailabilityResolver has ktx/stock/map entries
grep -q "korean.ktx-booking" "$MYTEAM/SkillAvailabilityResolver.swift" && check "SkillAvailabilityResolver has ktx-booking" "pass" || check "SkillAvailabilityResolver has ktx-booking" "fail"

# 9. WorkflowOrchestrator wires KSkillAssistRuntime
grep -q "KSkillAssistRuntime.detectIntent\|KSkillAssistRuntime\.detectIntent" "$MYTEAM/WorkflowOrchestrator.swift" && check "WorkflowOrchestrator wires KSkillAssistRuntime" "pass" || check "WorkflowOrchestrator wires KSkillAssistRuntime" "fail"

# 10. No fake stock/map/dart API calls
if grep -q "URLSession.*dart\|dart.*URLSession\|URLSession.*naver\|naver.*URLSession" "$MYTEAM/KSkillAssistRuntime.swift" 2>/dev/null; then
    check "No fake API calls in KSkillAssistRuntime" "fail"
else
    check "No fake API calls in KSkillAssistRuntime" "pass"
fi

# 11. formatMarkdown function exists
grep -q "func formatMarkdown" "$MYTEAM/KSkillAssistRuntime.swift" && check "formatMarkdown function exists" "pass" || check "formatMarkdown function exists" "fail"

# 12. KSkillAssistRuntime in pbxproj
grep -q "KSkillAssistRuntime" "$REPO_ROOT/MyTeam/MyTeam.xcodeproj/project.pbxproj" && check "KSkillAssistRuntime.swift in pbxproj" "pass" || check "KSkillAssistRuntime.swift in pbxproj" "fail"

echo ""
echo "=== Result: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
