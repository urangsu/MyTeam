#!/usr/bin/env bash
# preflight_nav_connector_round239.sh
# Round 239 Preflight — Personal Chat Navigation + Connector UX Cleanup
#
# 실패(exit 1): 필수 조건 미충족, 금지 문구 검출, 빌드 실패

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
echo " MyTeam Preflight — Round 239 Nav + Connector UX"
echo "══════════════════════════════════════════════════════"
echo ""

# ── 1. openPersonalChat didSelectAgentForChat 알림 ──────
echo "[ 1/9 ] openPersonalChat → didSelectAgentForChat 알림"
if grep -q "didSelectAgentForChat" "$SWIFT_DIR/AgentWindowManager.swift" 2>/dev/null; then
    pass "AgentWindowManager.openPersonalChat: didSelectAgentForChat 알림 포함"
else
    fail "AgentWindowManager.openPersonalChat: didSelectAgentForChat 알림 없음"
fi

# ── 2. 알림 양쪽 분기 (기존방 + 신규방) ─────────────────
echo ""
echo "[ 2/9 ] didSelectAgentForChat 두 분기 모두 알림"
COUNT=$(grep -c "didSelectAgentForChat" "$SWIFT_DIR/AgentWindowManager.swift" 2>/dev/null || true)
if [ "$COUNT" -ge 2 ]; then
    pass "openPersonalChat: 두 분기(기존방/신규방) 모두 알림 ($COUNT곳)"
else
    fail "openPersonalChat: 알림 분기 부족 ($COUNT곳, 2 이상 필요)"
fi

# ── 3. 커넥터 내부 개발 문구 제거 ──────────────────────
echo ""
echo "[ 3/9 ] 커넥터 내부 개발 문구 제거"
LEAKS=$(grep -n "IMAP 기반\|metadata 먼저\|본문 읽기는 추후\|Desktop OAuth.*연동 예정\|공식 API 제약 검토" \
    "$SWIFT_DIR/AssistantConnectorCatalog.swift" 2>/dev/null || true)
if [ -z "$LEAKS" ]; then
    pass "AssistantConnectorCatalog: 내부 개발 문구 없음"
else
    fail "AssistantConnectorCatalog: 개발 문구 발견: $LEAKS"
fi

# ── 4. 커넥터 notes 사용자 문구 존재 ───────────────────
echo ""
echo "[ 4/9 ] 커넥터 notes 사용자 향 문구"
if grep -q "연동 준비 중입니다\|자동으로 가져옵니다\|새 메일 수와 발신자" \
    "$SWIFT_DIR/AssistantConnectorCatalog.swift" 2>/dev/null; then
    pass "AssistantConnectorCatalog: 사용자 향 notes 문구 존재"
else
    fail "AssistantConnectorCatalog: 사용자 향 notes 문구 없음"
fi

# ── 5. DailyBriefingCardView Gmail 개발 문구 제거 ──────
echo ""
echo "[ 5/9 ] DailyBriefingCardView Gmail 내부 문구 제거"
GMAIL_LEAK=$(grep -n "메일 본문 요약/발송/삭제\|준비 중입니다\." \
    "$SWIFT_DIR/DailyBriefingCardView.swift" 2>/dev/null || true)
if [ -z "$GMAIL_LEAK" ]; then
    pass "DailyBriefingCardView: Gmail 개발 문구 없음"
else
    fail "DailyBriefingCardView: Gmail 개발 문구 발견: $GMAIL_LEAK"
fi

# ── 6. DailyBriefingCardView Gmail 사용자 문구 존재 ────
echo ""
echo "[ 6/9 ] DailyBriefingCardView Gmail 사용자 문구"
if grep -q "Gmail 연결 후" "$SWIFT_DIR/DailyBriefingCardView.swift" 2>/dev/null; then
    pass "DailyBriefingCardView: Gmail 사용자 안내 문구 존재"
else
    fail "DailyBriefingCardView: Gmail 사용자 안내 문구 없음"
fi

# ── 7. schedulePopupCard 데드 코드 제거 ────────────────
echo ""
echo "[ 7/9 ] schedulePopupCard 데드 코드 제거"
if grep -q "private var schedulePopupCard: some View" "$SWIFT_DIR/TeamStatusView.swift" 2>/dev/null; then
    fail "TeamStatusView: schedulePopupCard 데드 코드 여전히 존재"
else
    pass "TeamStatusView: schedulePopupCard 제거됨"
fi

# ── 8. chatHistory isSystem 필터 (Round 238 회귀 없음) ─
echo ""
echo "[ 8/9 ] chatHistory isSystem 필터 유지"
COUNT=$(grep -c "!\\\$0.isSystem" "$SWIFT_DIR/AgentChatView.swift" 2>/dev/null || true)
if [ "$COUNT" -ge 2 ]; then
    pass "AgentChatView.chatHistory: isSystem 필터 유지 ($COUNT곳)"
else
    fail "AgentChatView.chatHistory: isSystem 필터 회귀 ($COUNT곳)"
fi

# ── 9. Debug + Release 빌드 ─────────────────────────────
echo ""
echo "[ 9/9 ] Debug + Release 빌드"

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
    echo "✅ Preflight Round 239 전체 통과 (0 실패)"
    echo "══════════════════════════════════════════════════════"
    exit 0
else
    echo "❌ Preflight Round 239 실패: $FAILED 오류"
    echo "══════════════════════════════════════════════════════"
    exit 1
fi
