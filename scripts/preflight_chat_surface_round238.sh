#!/usr/bin/env bash
# preflight_chat_surface_round238.sh
# Round 238 Preflight — Chat Surface Visibility + System Log Filtering
#
# 실패(exit 1): 필수 조건 미충족, 금지 패턴 검출, 빌드 실패
# 경고(exit 0): 없음

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$REPO_ROOT/MyTeam/MyTeam.xcodeproj"
SCHEME="MyTeam"
SWIFT_DIR="$REPO_ROOT/MyTeam"

FAILED=0

pass()  { echo "✅ $1"; }
fail()  { echo "❌ $1"; FAILED=$((FAILED + 1)); }
info()  { echo "ℹ️  $1"; }

echo ""
echo "══════════════════════════════════════════════════════"
echo " MyTeam Preflight — Round 238 Chat Surface"
echo "══════════════════════════════════════════════════════"
echo ""

# ── 1. isSystem 필터 — AgentChatView.chatHistory ─────────
echo "[ 1/10 ] chatHistory isSystem 필터"
if grep -q "!\\\$0.isSystem" "$SWIFT_DIR/AgentChatView.swift" 2>/dev/null; then
    pass "AgentChatView.chatHistory: isSystem 필터 존재"
else
    fail "AgentChatView.chatHistory: isSystem 필터 없음"
fi

# ── 2. 개인 대화창 isSystem 필터 (양쪽 분기) ────────────
echo ""
echo "[ 2/10 ] chatHistory 두 분기 모두 isSystem 필터"
COUNT=$(grep -c "!\\\$0.isSystem" "$SWIFT_DIR/AgentChatView.swift" 2>/dev/null || true)
if [ "$COUNT" -ge 2 ]; then
    pass "chatHistory: isSystem 필터 양쪽 분기 적용 ($COUNT곳)"
else
    fail "chatHistory: isSystem 필터 한쪽만 적용 ($COUNT곳)"
fi

# ── 3. WorkroomHomeView isBeginnerMode 조건 제거 ─────────
echo ""
echo "[ 3/10 ] WorkroomHomeView 조건 — isBeginnerMode 제거"
if grep -q "isBeginnerMode || manager.teamChatLogs.isEmpty" "$SWIFT_DIR/TeamStatusView.swift" 2>/dev/null; then
    fail "TeamStatusView: isBeginnerMode || 여전히 존재"
else
    pass "TeamStatusView: isBeginnerMode || 조건 제거됨"
fi

# ── 4. WorkroomHomeView teamChatLogs.isEmpty 단독 조건 ───
echo ""
echo "[ 4/10 ] WorkroomHomeView teamChatLogs.isEmpty 단독 조건"
if grep -q "teamChatLogs.isEmpty" "$SWIFT_DIR/TeamStatusView.swift" 2>/dev/null; then
    pass "TeamStatusView: teamChatLogs.isEmpty 조건 존재"
else
    fail "TeamStatusView: teamChatLogs.isEmpty 조건 없음"
fi

# ── 5. 개인 대화창 빈 상태 힌트 ──────────────────────────
echo ""
echo "[ 5/10 ] 개인 대화창 빈 상태 단순 힌트"
if grep -q "isPersonalChat" "$SWIFT_DIR/AgentChatView.swift" 2>/dev/null && \
   grep -q "바로 말을 걸 수 있어요" "$SWIFT_DIR/AgentChatView.swift" 2>/dev/null; then
    pass "AgentChatView: 개인창 단순 힌트 존재"
else
    fail "AgentChatView: 개인창 단순 힌트 없음"
fi

# ── 6. 푸터 컴팩트 스타일 ─────────────────────────────────
echo ""
echo "[ 6/10 ] footerView 컴팩트 스타일"
if grep -q "cornerRadius.*18\|RoundedRectangle.*18" "$SWIFT_DIR/TeamStatusView.swift" 2>/dev/null; then
    pass "TeamStatusView.footerView: 컴팩트 RoundedRectangle 존재"
else
    fail "TeamStatusView.footerView: 컴팩트 배경 없음"
fi

# ── 7. 푸터 과도한 패딩 제거 ─────────────────────────────
echo ""
echo "[ 7/10 ] footerView 과도한 padding(.vertical, 14) 제거"
# 14는 footerView 영역에 없어야 함
FOOTER_SECTION=$(awk '/MARK: - 하위 뷰/,/private func handleFile/' "$SWIFT_DIR/TeamStatusView.swift" 2>/dev/null || true)
if echo "$FOOTER_SECTION" | grep -q "padding(.vertical, 14)"; then
    fail "TeamStatusView.footerView: padding(.vertical, 14) 여전히 존재"
else
    pass "TeamStatusView.footerView: 과도한 패딩 제거됨"
fi

# ── 8. teamChatLogs 시스템 메시지 필터 확인 ─────────────
echo ""
echo "[ 8/10 ] teamChatLogs isSystem 필터"
if grep -q "\.filter.*!.*isSystem\|filter.*isSystem.*false" "$SWIFT_DIR/AgentWindowManager.swift" 2>/dev/null; then
    pass "AgentWindowManager.teamChatLogs: isSystem 필터 존재"
else
    fail "AgentWindowManager.teamChatLogs: isSystem 필터 없음"
fi

# ── 9. QA 문서 존재 확인 ─────────────────────────────────
echo ""
echo "[ 9/10 ] QA 문서"
if [ -f "$REPO_ROOT/docs/qa/LocalRuntimeQA_Round237.md" ]; then
    pass "LocalRuntimeQA_Round237.md 존재"
else
    fail "LocalRuntimeQA_Round237.md 없음"
fi

# ── 10. Debug + Release 빌드 ─────────────────────────────
echo ""
echo "[ 10/10 ] Debug + Release 빌드"

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
    echo "✅ Preflight Round 238 전체 통과 (0 실패)"
    echo "══════════════════════════════════════════════════════"
    exit 0
else
    echo "❌ Preflight Round 238 실패: $FAILED 오류"
    echo "══════════════════════════════════════════════════════"
    exit 1
fi
