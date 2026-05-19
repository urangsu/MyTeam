#!/usr/bin/env bash
# preflight_ux_round240.sh
# Round 240 Preflight — Runtime UX P0 Fixes

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
echo " MyTeam Preflight — Round 240 Runtime UX"
echo "══════════════════════════════════════════════════════"
echo ""

# ── 1. 사이드바 미리보기 isSystem 필터 ──────────────────
echo "[ 1/10 ] 사이드바 미리보기 isSystem 필터"
if grep -q 'messages.last(where: { !\$0.isSystem })' "$SWIFT_DIR/AgentChatView.swift" 2>/dev/null; then
    pass "AgentChatView: 사이드바 미리보기 isSystem 필터 존재"
else
    fail "AgentChatView: 사이드바 미리보기 isSystem 필터 없음"
fi

# ── 2. 메시지 카운트 isSystem 필터 ──────────────────────
echo ""
echo "[ 2/10 ] 메시지 카운트 isSystem 필터"
if grep -q 'messages.filter({ !\$0.isSystem }).count' "$SWIFT_DIR/AgentChatView.swift" 2>/dev/null; then
    pass "AgentChatView: 메시지 카운트 isSystem 필터 존재"
else
    fail "AgentChatView: 메시지 카운트 isSystem 필터 없음"
fi

# ── 3. 초상화 크기 28px ─────────────────────────────────
echo ""
echo "[ 3/10 ] AgentQuickSwitchBar 초상화 28px"
if grep -q "width: 28, height: 28" "$SWIFT_DIR/AgentQuickSwitchBar.swift" 2>/dev/null; then
    pass "AgentQuickSwitchBar: 초상화 28px"
else
    fail "AgentQuickSwitchBar: 초상화 28px 아님"
fi

# ── 4. 초상화 spacing 6 ─────────────────────────────────
echo ""
echo "[ 4/10 ] AgentQuickSwitchBar spacing 6"
if grep -q "HStack(spacing: 6)" "$SWIFT_DIR/AgentQuickSwitchBar.swift" 2>/dev/null; then
    pass "AgentQuickSwitchBar: spacing 6"
else
    fail "AgentQuickSwitchBar: spacing 6 아님"
fi

# ── 5. Artifact 카드 ScrollView 내부 ────────────────────
echo ""
echo "[ 5/10 ] Artifact 카드 ScrollView 내부 배치"
# Artifact 섹션이 .padding(12) (ScrollView 내부 VStack 패딩) 앞에 나와야 함
ARTIFACT_LINE=$(grep -n "Artifact 카드.*ScrollView 내부" "$SWIFT_DIR/TeamStatusView.swift" 2>/dev/null | head -1 | cut -d: -f1)
PADDING_LINE=$(grep -n '\.padding(12)' "$SWIFT_DIR/TeamStatusView.swift" 2>/dev/null | head -1 | cut -d: -f1)
if [ -n "$ARTIFACT_LINE" ] && [ -n "$PADDING_LINE" ] && [ "$ARTIFACT_LINE" -lt "$PADDING_LINE" ]; then
    pass "TeamStatusView: Artifact 카드가 ScrollView 내부에 위치"
else
    fail "TeamStatusView: Artifact 카드가 ScrollView 외부에 위치"
fi

# ── 6. footerView RoundedRectangle 배경 제거 ────────────
echo ""
echo "[ 6/10 ] footerView 배경 제거 (패널 통합)"
FOOTER_SECTION=$(awk '/MARK: - 하위 뷰.*컨트롤 바/,/^    private func/' "$SWIFT_DIR/TeamStatusView.swift" 2>/dev/null || true)
if echo "$FOOTER_SECTION" | grep -q "RoundedRectangle"; then
    fail "TeamStatusView.footerView: RoundedRectangle 배경 여전히 존재"
else
    pass "TeamStatusView.footerView: RoundedRectangle 배경 제거됨"
fi

# ── 7. footerView Divider 경계선 존재 ───────────────────
echo ""
echo "[ 7/10 ] footerView Divider 경계선"
if echo "$FOOTER_SECTION" | grep -q "Divider()"; then
    pass "TeamStatusView.footerView: Divider 경계선 존재"
else
    fail "TeamStatusView.footerView: Divider 경계선 없음"
fi

# ── 8. statusPanel 높이 550 ─────────────────────────────
echo ""
echo "[ 8/10 ] statusPanel 초기 높이"
if grep -q "height: CGFloat = 550" "$SWIFT_DIR/AgentWindowManager.swift" 2>/dev/null; then
    pass "AgentWindowManager: statusPanel 높이 550"
else
    fail "AgentWindowManager: statusPanel 높이 550 아님"
fi

# ── 9. statusPanel contentMinSize ───────────────────────
echo ""
echo "[ 9/10 ] statusPanel contentMinSize"
if grep -q "contentMinSize = NSSize(width: 300, height: 400)" "$SWIFT_DIR/AgentWindowManager.swift" 2>/dev/null; then
    pass "AgentWindowManager: contentMinSize 설정됨"
else
    fail "AgentWindowManager: contentMinSize 미설정"
fi

# ── 10. Debug + Release 빌드 ────────────────────────────
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
    echo "✅ Preflight Round 240 전체 통과 (0 실패)"
    echo "══════════════════════════════════════════════════════"
    exit 0
else
    echo "❌ Preflight Round 240 실패: $FAILED 오류"
    echo "══════════════════════════════════════════════════════"
    exit 1
fi
