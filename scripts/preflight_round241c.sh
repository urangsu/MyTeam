#!/usr/bin/env bash
# preflight_round241c.sh
# Round 241C Preflight — Team Composer Routing + Unread Badge + Overlay/Chrome Repair

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
echo " MyTeam Preflight — Round 241C Surface Routing & Chrome"
echo "══════════════════════════════════════════════════════"
echo ""

# ── 1. selectedTeamWorkroomID 존재 (241A 유지) ──────────
echo "[ 1/12 ] selectedTeamWorkroomID 존재"
if grep -q 'var selectedTeamWorkroomID: UUID?' "$SWIFT_DIR/AgentWindowManager.swift" 2>/dev/null; then
    pass "AgentWindowManager: selectedTeamWorkroomID 존재"
else
    fail "AgentWindowManager: selectedTeamWorkroomID 없음"
fi

# ── 2. selectedPersonalConversationIDByAgentID 존재 (241B 유지) ──
echo ""
echo "[ 2/12 ] selectedPersonalConversationIDByAgentID 존재"
if grep -q 'var selectedPersonalConversationIDByAgentID' "$SWIFT_DIR/AgentWindowManager.swift" 2>/dev/null; then
    pass "AgentWindowManager: selectedPersonalConversationIDByAgentID 존재"
else
    fail "AgentWindowManager: selectedPersonalConversationIDByAgentID 없음"
fi

# ── 3. TeamTableView sendTeamInput에서 currentRoomID 없음 ──
echo ""
echo "[ 3/12 ] TeamTableView.sendTeamInput — currentRoomID 사용 없음"
SEND_SECTION=$(grep -A 35 'func sendTeamInput' "$SWIFT_DIR/TeamTableView.swift" 2>/dev/null || true)
if echo "$SEND_SECTION" | grep -q 'manager\.currentRoomID'; then
    fail "TeamTableView.sendTeamInput: manager.currentRoomID를 사용 중 (선택된 개인 대화방으로 메시지 전송될 수 있음)"
else
    pass "TeamTableView.sendTeamInput: currentRoomID 사용 없음"
fi

# ── 4. TeamTableView sendTeamInput에서 selectedTeamWorkroomID 사용 ──
echo ""
echo "[ 4/12 ] TeamTableView.sendTeamInput — selectedTeamWorkroomID 사용"
if echo "$SEND_SECTION" | grep -q 'selectedTeamWorkroomID'; then
    pass "TeamTableView.sendTeamInput: selectedTeamWorkroomID 사용"
else
    fail "TeamTableView.sendTeamInput: selectedTeamWorkroomID 없음"
fi

# ── 5. TeamTableView sendTeamInput에서 activePersonalAgentID 없음 ──
echo ""
echo "[ 5/12 ] TeamTableView.sendTeamInput — activePersonalAgentID 참조 없음"
if echo "$SEND_SECTION" | grep -q 'activePersonalAgentID'; then
    fail "TeamTableView.sendTeamInput: activePersonalAgentID를 참조 중 (팀 composer 오염)"
else
    pass "TeamTableView.sendTeamInput: activePersonalAgentID 참조 없음"
fi

# ── 6. unreadCount helper 존재 ──────────────────────────
echo ""
echo "[ 6/12 ] unreadCount(for:) helper 존재"
if grep -q 'func unreadCount(for roomID' "$SWIFT_DIR/AgentWindowManager.swift" 2>/dev/null; then
    pass "AgentWindowManager: unreadCount(for:) 존재"
else
    fail "AgentWindowManager: unreadCount(for:) 없음"
fi

# ── 7. unreadCount가 room.messages.count 직접 반환하지 않음 ──
echo ""
echo "[ 7/12 ] unreadCount — messages.count 직접 반환 없음"
UNREAD_SECTION=$(grep -A 12 'func unreadCount' "$SWIFT_DIR/AgentWindowManager.swift" 2>/dev/null || true)
if echo "$UNREAD_SECTION" | grep -q 'return.*messages\.count\b'; then
    fail "AgentWindowManager.unreadCount: messages.count를 직접 반환 중 (필터 없음)"
else
    pass "AgentWindowManager.unreadCount: messages.count 직접 반환 없음"
fi

# ── 8. unreadCount가 isSystem 필터 포함 ─────────────────
echo ""
echo "[ 8/12 ] unreadCount — isSystem 필터 포함"
if echo "$UNREAD_SECTION" | grep -q 'isSystem'; then
    pass "AgentWindowManager.unreadCount: isSystem 필터 포함"
else
    fail "AgentWindowManager.unreadCount: isSystem 필터 없음 (system 메시지가 badge에 포함될 수 있음)"
fi

# ── 9. AgentChatView 개인 대화 사이드바 preview 없음 (241A 유지) ──
echo ""
echo "[ 9/12 ] AgentChatView 개인 대화 사이드바 preview 없음"
if grep -q 'Round 241A.*message preview 금지\|개인 대화 사이드바 message preview 금지' "$SWIFT_DIR/AgentChatView.swift" 2>/dev/null; then
    pass "AgentChatView: 개인 대화 사이드바 preview 제거"
else
    fail "AgentChatView: 개인 대화 사이드바 preview 잔존"
fi

# ── 10. Agent menu — contextMenu 또는 Menu 사용 ─────────
echo ""
echo "[ 10/12 ] Agent menu — contextMenu / SwiftUI Menu 사용"
if grep -q '\.contextMenu\b\|SwiftUI\.Menu\b' "$SWIFT_DIR/TeamTableView.swift" 2>/dev/null; then
    pass "TeamTableView: contextMenu 또는 SwiftUI Menu 사용"
else
    fail "TeamTableView: contextMenu / SwiftUI Menu 없음 (clipped overlay 상태일 수 있음)"
fi

# ── 11. footerView — 별도 detached RoundedRectangle 없음 ──
echo ""
echo "[ 11/12 ] footerView — detached RoundedRectangle background 없음"
FOOTER_SECTION=$(awk '/private var footerView/,/^    (private )?var [a-zA-Z]/' "$SWIFT_DIR/TeamStatusView.swift" 2>/dev/null || true)
if echo "$FOOTER_SECTION" | grep -q 'RoundedRectangle.*fill\|\.background.*RoundedRectangle'; then
    fail "TeamStatusView.footerView: detached RoundedRectangle background 존재"
else
    pass "TeamStatusView.footerView: detached RoundedRectangle 없음 (패널 chrome 통합)"
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
    echo "✅ Preflight Round 241C 전체 통과 (0 실패)"
    echo "══════════════════════════════════════════════════════"
    exit 0
else
    echo "❌ Preflight Round 241C 실패: $FAILED 오류"
    echo "══════════════════════════════════════════════════════"
    exit 1
fi
