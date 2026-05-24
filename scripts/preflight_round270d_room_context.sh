#!/usr/bin/env bash
# preflight_round270d_room_context.sh
# Round 270D: Room-Scoped Context Builder Gate
# 8개 정적 검사
# 2026-05-24

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

ok()   { echo "  ✅ PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL+1)); }

RCFILE="$ROOT/MyTeam/RoomContextBuilder.swift"
WO="$ROOT/MyTeam/WorkflowOrchestrator.swift"

echo "=== Round 270D ROOM-CONTEXT Preflight ==="
echo

# 1. RoomContextBuilder.swift 존재
if [ -f "$RCFILE" ]; then
    ok "RoomContextBuilder.swift 존재"
else
    fail "RoomContextBuilder.swift 없음"
fi

# 2. RoomContext struct 존재
if grep -q 'struct RoomContext' "$RCFILE" 2>/dev/null; then
    ok "RoomContext struct 존재"
else
    fail "RoomContext struct 없음"
fi

# 3. RoomContextBuilder.build(manager:roomID:maxMessages:) 존재
if grep -q 'static func build(' "$RCFILE" 2>/dev/null; then
    ok "RoomContextBuilder.build() 존재"
else
    fail "RoomContextBuilder.build() 없음"
fi

# 4. RoomContext.systemPromptContext 존재
if grep -q 'systemPromptContext' "$RCFILE" 2>/dev/null; then
    ok "RoomContext.systemPromptContext 존재"
else
    fail "RoomContext.systemPromptContext 없음"
fi

# 5. WorkflowOrchestrator에서 chatHistory: [] 단독 호출 없음
BARE_EMPTY=$(grep -c 'chatHistory: \[\]' "$WO" 2>/dev/null || true)
if [ "$BARE_EMPTY" -eq 0 ]; then
    ok "WorkflowOrchestrator chatHistory: [] 단독 사용 없음 (모두 교체됨)"
else
    fail "WorkflowOrchestrator chatHistory: [] ${BARE_EMPTY}곳 잔존"
fi

# 6. RoomContextBuilder.build가 WorkflowOrchestrator에서 호출됨
if grep -q 'RoomContextBuilder.build' "$WO" 2>/dev/null; then
    COUNT=$(grep -c 'RoomContextBuilder.build' "$WO")
    ok "RoomContextBuilder.build WorkflowOrchestrator에서 호출 (${COUNT}곳)"
else
    fail "RoomContextBuilder.build WorkflowOrchestrator에서 미호출"
fi

# 7. contextualChatHistory 사용 확인
if grep -q 'contextualChatHistory' "$WO" 2>/dev/null; then
    ok "contextualChatHistory WorkflowOrchestrator에서 사용"
else
    fail "contextualChatHistory WorkflowOrchestrator에서 미사용"
fi

# 8. pbxproj에 RoomContextBuilder 등록
PBXPROJ="$ROOT/MyTeam/MyTeam.xcodeproj/project.pbxproj"
if grep -q 'RoomContextBuilder.swift' "$PBXPROJ" 2>/dev/null; then
    ok "RoomContextBuilder.swift pbxproj 등록됨"
else
    fail "RoomContextBuilder.swift pbxproj 미등록"
fi

echo
echo "=== 결과: PASS=$PASS FAIL=$FAIL / 8 ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
