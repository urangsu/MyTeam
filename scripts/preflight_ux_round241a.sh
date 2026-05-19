#!/usr/bin/env bash
# preflight_ux_round241a.sh
# Round 241A Preflight — Hard Separation of Team Workroom and Personal Agent Conversation

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
echo " MyTeam Preflight — Round 241A Team/Personal Separation"
echo "══════════════════════════════════════════════════════"
echo ""

# ── 1. selectedTeamWorkroomID 존재 ──────────────────────
echo "[ 1/12 ] selectedTeamWorkroomID 추가 여부"
if grep -q 'var selectedTeamWorkroomID: UUID?' "$SWIFT_DIR/AgentWindowManager.swift" 2>/dev/null; then
    pass "AgentWindowManager: selectedTeamWorkroomID 존재"
else
    fail "AgentWindowManager: selectedTeamWorkroomID 없음"
fi

# ── 2. activePersonalAgentID 존재 ───────────────────────
echo ""
echo "[ 2/12 ] activePersonalAgentID 추가 여부"
if grep -q 'var activePersonalAgentID: String?' "$SWIFT_DIR/AgentWindowManager.swift" 2>/dev/null; then
    pass "AgentWindowManager: activePersonalAgentID 존재"
else
    fail "AgentWindowManager: activePersonalAgentID 없음"
fi

# ── 3. selectTeamWorkroom 헬퍼 ──────────────────────────
echo ""
echo "[ 3/12 ] selectTeamWorkroom 헬퍼"
if grep -q 'func selectTeamWorkroom' "$SWIFT_DIR/AgentWindowManager.swift" 2>/dev/null; then
    pass "AgentWindowManager: selectTeamWorkroom 존재"
else
    fail "AgentWindowManager: selectTeamWorkroom 없음"
fi

# ── 4. openPersonalChat이 selectedTeamWorkroomID 변경하지 않음 ──
echo ""
echo "[ 4/12 ] openPersonalChat — selectedTeamWorkroomID 불변"
PERSONAL_CHAT_SECTION=$(awk '/func openPersonalChat/,/^    func [a-zA-Z]/' "$SWIFT_DIR/AgentWindowManager.swift" 2>/dev/null || true)
if echo "$PERSONAL_CHAT_SECTION" | grep -q 'selectedTeamWorkroomID ='; then
    fail "AgentWindowManager.openPersonalChat: selectedTeamWorkroomID를 변경하고 있음"
else
    pass "AgentWindowManager.openPersonalChat: selectedTeamWorkroomID 불변"
fi

# ── 5. teamChatLogs가 selectedTeamWorkroomID 기준 ───────
echo ""
echo "[ 5/12 ] teamChatLogs selectedTeamWorkroomID 기준"
if grep -q 'selectedTeamWorkroomID' "$SWIFT_DIR/AgentWindowManager.swift" 2>/dev/null && \
   grep -A2 'var teamChatLogs' "$SWIFT_DIR/AgentWindowManager.swift" | grep -q 'selectedTeamWorkroomID'; then
    pass "AgentWindowManager: teamChatLogs가 selectedTeamWorkroomID 기준"
else
    fail "AgentWindowManager: teamChatLogs가 currentRoomID 기준 (오염 위험)"
fi

# ── 6. TeamStatusView.sendTeamMessage selectedTeamWorkroomID ──
echo ""
echo "[ 6/12 ] TeamStatusView.sendTeamMessage selectedTeamWorkroomID 기준"
# roomIDAtSend 캡처가 selectedTeamWorkroomID를 사용하는지 확인 (currentRoomID 금지)
if grep -A5 'func sendTeamMessage' "$SWIFT_DIR/TeamStatusView.swift" 2>/dev/null | grep -q 'selectedTeamWorkroomID'; then
    pass "TeamStatusView.sendTeamMessage: selectedTeamWorkroomID 기준"
else
    fail "TeamStatusView.sendTeamMessage: currentRoomID 사용 중 (오염 위험)"
fi

# ── 7. TeamStatusView.chatroomSidebar selectTeamWorkroom ──
echo ""
echo "[ 7/12 ] TeamStatusView.chatroomSidebar selectTeamWorkroom 사용"
if grep -q 'manager\.selectTeamWorkroom' "$SWIFT_DIR/TeamStatusView.swift" 2>/dev/null; then
    pass "TeamStatusView: 방 탭에서 selectTeamWorkroom 호출"
else
    fail "TeamStatusView: 방 탭에서 currentRoomID 직접 변경 중"
fi

# ── 8. TeamStatusView 방 선택 isSelected selectedTeamWorkroomID ──
echo ""
echo "[ 8/12 ] TeamStatusView 방 선택 isSelected selectedTeamWorkroomID"
if grep -q 'selectedTeamWorkroomID == room.id' "$SWIFT_DIR/TeamStatusView.swift" 2>/dev/null; then
    pass "TeamStatusView: isSelected가 selectedTeamWorkroomID 기준"
else
    fail "TeamStatusView: isSelected가 currentRoomID 기준 (개인 대화 시 하이라이트 오류)"
fi

# ── 9. 개인 대화 사이드바 preview 제거 ──────────────────
echo ""
echo "[ 9/12 ] AgentChatView 개인 대화 사이드바 message preview 제거"
if grep -q 'Round 241A.*message preview 금지\|개인 대화 사이드바 message preview 금지' "$SWIFT_DIR/AgentChatView.swift" 2>/dev/null; then
    pass "AgentChatView: 개인 대화 사이드바 preview 제거"
else
    fail "AgentChatView: 개인 대화 사이드바 preview 잔존"
fi

# ── 10. RoomIdentitySeparationPolicy 문서 ───────────────
echo ""
echo "[ 10/12 ] docs/RoomIdentitySeparationPolicy.md 존재"
if [ -f "$REPO_ROOT/docs/RoomIdentitySeparationPolicy.md" ]; then
    pass "docs/RoomIdentitySeparationPolicy.md 존재"
else
    fail "docs/RoomIdentitySeparationPolicy.md 없음"
fi

# ── 11. Debug 빌드 ───────────────────────────────────────
echo ""
echo "[ 11/12 ] Debug 빌드"
DEBUG_RESULT=$(xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
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

# ── 12. Release 빌드 ─────────────────────────────────────
echo ""
echo "[ 12/12 ] Release 빌드"
RELEASE_RESULT=$(xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    build \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | tail -3)

if echo "$RELEASE_RESULT" | grep -q "BUILD SUCCEEDED"; then
    pass "Release BUILD SUCCEEDED"
else
    fail "Release BUILD FAILED"
fi

# ── 결과 요약 ─────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════"
if [ "$FAILED" -eq 0 ]; then
    echo "✅ Preflight Round 241A 전체 통과 (0 실패)"
    echo "══════════════════════════════════════════════════════"
    exit 0
else
    echo "❌ Preflight Round 241A 실패: $FAILED 오류"
    echo "══════════════════════════════════════════════════════"
    exit 1
fi
