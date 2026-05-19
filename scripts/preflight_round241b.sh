#!/usr/bin/env bash
# preflight_round241b.sh
# Round 241B Preflight — Personal Conversation Map + GoalGate Pivot + BYOK Fix

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$REPO_ROOT/MyTeam/MyTeam.xcodeproj"
SCHEME="MyTeam"
SWIFT_DIR="$REPO_ROOT/MyTeam"

FAILED=0

pass()  { echo "✅ $1"; }
fail()  { echo "❌ $1"; FAILED=$((FAILED + 1)); }

echo ""
echo "══════════════════════════════════════════════════════"
echo " MyTeam Preflight — Round 241B Personal Conv Map + GoalGate"
echo "══════════════════════════════════════════════════════"
echo ""

# ── 1. selectedPersonalConversationIDByAgentID 존재 ─────
echo "[ 1/12 ] selectedPersonalConversationIDByAgentID 추가 여부"
if grep -q 'var selectedPersonalConversationIDByAgentID' "$SWIFT_DIR/AgentWindowManager.swift" 2>/dev/null; then
    pass "AgentWindowManager: selectedPersonalConversationIDByAgentID 존재"
else
    fail "AgentWindowManager: selectedPersonalConversationIDByAgentID 없음"
fi

# ── 2. openPersonalConversation 함수 존재 ───────────────
echo ""
echo "[ 2/12 ] openPersonalConversation 함수 존재"
if grep -q 'func openPersonalConversation' "$SWIFT_DIR/AgentWindowManager.swift" 2>/dev/null; then
    pass "AgentWindowManager: openPersonalConversation 존재"
else
    fail "AgentWindowManager: openPersonalConversation 없음"
fi

# ── 3. personalConversation(for:) 함수 존재 ────────────
echo ""
echo "[ 3/12 ] personalConversation(for:) 함수 존재"
if grep -q 'func personalConversation(for' "$SWIFT_DIR/AgentWindowManager.swift" 2>/dev/null; then
    pass "AgentWindowManager: personalConversation(for:) 존재"
else
    fail "AgentWindowManager: personalConversation(for:) 없음"
fi

# ── 4. openPersonalConversation이 selectedTeamWorkroomID 변경하지 않음 ──
echo ""
echo "[ 4/12 ] openPersonalConversation — selectedTeamWorkroomID 불변"
SECTION=$(awk '/func openPersonalConversation/,/^    func [a-zA-Z]/' "$SWIFT_DIR/AgentWindowManager.swift" 2>/dev/null || true)
if echo "$SECTION" | grep -q 'selectedTeamWorkroomID ='; then
    fail "AgentWindowManager.openPersonalConversation: selectedTeamWorkroomID를 변경하고 있음"
else
    pass "AgentWindowManager.openPersonalConversation: selectedTeamWorkroomID 불변"
fi

# ── 5. openPersonalConversation이 room.agentIDs mutation 없음 ──
echo ""
echo "[ 5/12 ] openPersonalConversation — room.agentIDs mutation 없음"
if echo "$SECTION" | grep -q '\.agentIDs\s*='; then
    fail "AgentWindowManager.openPersonalConversation: room.agentIDs를 변경하고 있음"
else
    pass "AgentWindowManager.openPersonalConversation: agentIDs mutation 없음"
fi

# ── 6. TeamStatusView selectedTeamWorkroomID 사용 ────────
echo ""
echo "[ 6/12 ] TeamStatusView selectedTeamWorkroomID 사용"
if grep -q 'selectedTeamWorkroomID' "$SWIFT_DIR/TeamStatusView.swift" 2>/dev/null; then
    pass "TeamStatusView: selectedTeamWorkroomID 참조 존재"
else
    fail "TeamStatusView: selectedTeamWorkroomID 없음"
fi

# ── 7. AgentChatView 개인 대화 사이드바 preview 제거 ─────
echo ""
echo "[ 7/12 ] AgentChatView 개인 대화 사이드바 preview 제거 (Round 241A 유지)"
if grep -q 'Round 241A.*message preview 금지\|개인 대화 사이드바 message preview 금지' "$SWIFT_DIR/AgentChatView.swift" 2>/dev/null; then
    pass "AgentChatView: 개인 대화 사이드바 preview 제거"
else
    fail "AgentChatView: 개인 대화 사이드바 preview 잔존"
fi

# ── 8. AgentQuickSwitchBar ScrollView(.horizontal) 존재 ─
echo ""
echo "[ 8/12 ] AgentQuickSwitchBar ScrollView(.horizontal) 존재"
if grep -q 'ScrollView(.horizontal\|ScrollView(\.horizontal' "$SWIFT_DIR/AgentQuickSwitchBar.swift" 2>/dev/null; then
    pass "AgentQuickSwitchBar: ScrollView(.horizontal) 존재"
else
    fail "AgentQuickSwitchBar: ScrollView(.horizontal) 없음"
fi

# ── 9. BYOK 버튼 {} .disabled(true) 패턴 없음 ──────────
echo ""
echo "[ 9/12 ] BYOK 버튼 no-op 패턴 제거"
if grep -q '{} *$' "$SWIFT_DIR/BYOKProviderCenterView.swift" 2>/dev/null && \
   grep -A1 '{} *$' "$SWIFT_DIR/BYOKProviderCenterView.swift" 2>/dev/null | grep -q '\.disabled(true)'; then
    fail "BYOKProviderCenterView: 버튼 {} .disabled(true) 패턴 잔존"
else
    pass "BYOKProviderCenterView: no-op 버튼 패턴 제거"
fi

# ── 10. GoalGate directChat pivot 존재 ──────────────────
echo ""
echo "[ 10/12 ] GoalGate directChat pivot"
if grep -q 'kind: .directChat' "$SWIFT_DIR/GoalGate.swift" 2>/dev/null; then
    pass "GoalGate: directChat pivot 적용"
else
    fail "GoalGate: directChat pivot 없음 (blocked 하드블록 상태)"
fi

# ── 11. docs/SupertonicAssessment.md 존재 ───────────────
echo ""
echo "[ 11/12 ] docs/SupertonicAssessment.md 존재"
if [ -f "$REPO_ROOT/docs/SupertonicAssessment.md" ]; then
    pass "docs/SupertonicAssessment.md 존재"
else
    fail "docs/SupertonicAssessment.md 없음"
fi

# ── 12. Debug + Release 빌드 ─────────────────────────────
echo ""
echo "[ 12/12 ] Debug + Release 빌드"
DEBUG_RESULT=$(xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    build \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | tail -3)

RELEASE_RESULT=$(xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    build \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | tail -3)

if echo "$DEBUG_RESULT" | grep -q "BUILD SUCCEEDED"; then
    pass "Debug BUILD SUCCEEDED"
else
    fail "Debug BUILD FAILED"
fi

if echo "$RELEASE_RESULT" | grep -q "BUILD SUCCEEDED"; then
    pass "Release BUILD SUCCEEDED"
else
    fail "Release BUILD FAILED"
fi

# ── 결과 요약 ─────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════"
if [ "$FAILED" -eq 0 ]; then
    echo "✅ Preflight Round 241B 전체 통과 (0 실패)"
    echo "══════════════════════════════════════════════════════"
    exit 0
else
    echo "❌ Preflight Round 241B 실패: $FAILED 오류"
    echo "══════════════════════════════════════════════════════"
    exit 1
fi
