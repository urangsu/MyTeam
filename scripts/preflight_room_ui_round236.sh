#!/usr/bin/env bash
# preflight_room_ui_round236.sh
# Round 236 Preflight — Room Purpose Inference + Blog Profile + Rename
#
# 실패(exit 1): 필수 API 없음, 금지 문구 검출, 빌드 실패
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
echo " MyTeam Preflight — Round 236 Room Purpose + Blog"
echo "══════════════════════════════════════════════════════"
echo ""

# ── 1. renameRoom 존재 확인 ───────────────────────────────
echo "[ 1/12 ] renameRoom 존재 확인"
if grep -q "func renameRoom" "$SWIFT_DIR/AgentWindowManager.swift" 2>/dev/null; then
    pass "AgentWindowManager.renameRoom 존재"
else
    fail "AgentWindowManager.renameRoom 없음"
fi

# ── 2. openPersonalChat / openAgentChat 확인 ─────────────
echo ""
echo "[ 2/12 ] openPersonalChat / openAgentChat 확인"
if grep -qE "func openPersonalChat|func openAgentChat" "$SWIFT_DIR/AgentWindowManager.swift" 2>/dev/null; then
    pass "openPersonalChat/openAgentChat 함수 존재"
else
    fail "openPersonalChat/openAgentChat 없음"
fi

# ── 3. BlogStyleProfile 존재 확인 ────────────────────────
echo ""
echo "[ 3/12 ] BlogStyleProfile 존재 확인"
if grep -q "BlogStyleProfile" "$SWIFT_DIR/ChatModels.swift" 2>/dev/null; then
    pass "ChatModels.BlogStyleProfile 존재"
else
    fail "ChatModels.BlogStyleProfile 없음"
fi

# ── 4. RoomProfile / RoomPurpose 존재 확인 ───────────────
echo ""
echo "[ 4/12 ] RoomProfile / RoomPurpose 존재 확인"
if grep -q "RoomProfile" "$SWIFT_DIR/ChatModels.swift" 2>/dev/null; then
    pass "ChatModels.RoomProfile 존재"
else
    fail "ChatModels.RoomProfile 없음"
fi

# ── 5. /blog-source 명령 존재 확인 ───────────────────────
echo ""
echo "[ 5/12 ] /blog-source 명령 확인"
if grep -q "blog-source" "$SWIFT_DIR/ConversationMemory.swift" 2>/dev/null; then
    pass "ConversationMemory: /blog-source 명령 존재"
else
    fail "ConversationMemory: /blog-source 없음"
fi

# ── 6. /blog-profile 명령 존재 확인 ──────────────────────
echo ""
echo "[ 6/12 ] /blog-profile 명령 확인"
if grep -q "blog-profile" "$SWIFT_DIR/ConversationMemory.swift" 2>/dev/null; then
    pass "ConversationMemory: /blog-profile 명령 존재"
else
    fail "ConversationMemory: /blog-profile 없음"
fi

# ── 7. room purpose inference 존재 확인 ──────────────────
echo ""
echo "[ 7/12 ] room purpose inference 확인"
if grep -q "inferredRoomProfile\|RoomPurpose\|blogWriting" "$SWIFT_DIR/AgentWindowManager.swift" 2>/dev/null; then
    pass "AgentWindowManager: room purpose inference 존재"
else
    fail "AgentWindowManager: room purpose inference 없음"
fi

# ── 8. 금지: 블로그 전용 방 강제 생성 ─────────────────────
echo ""
echo "[ 8/12 ] 블로그 전용 방 강제 생성 금지 확인"
BLOG_FORCE=$(grep -n "createBlogRoom\|\"블로그 전용\"\|forceBlog\|mandatoryBlog" "$SWIFT_DIR/AgentWindowManager.swift" "$SWIFT_DIR/TeamStatusView.swift" 2>/dev/null || true)
if [ -n "$BLOG_FORCE" ]; then
    fail "블로그 전용 방 강제 생성 패턴 발견: $BLOG_FORCE"
else
    pass "블로그 전용 방 강제 생성 없음"
fi

# ── 9. 금지 기술 UX 문구 검색 ────────────────────────────
echo ""
echo "[ 9/12 ] 금지 기술 UX 문구 검색"

TECH_PATTERNS=(
    '"미구현"'
    '"stub"'
    '"hash mismatch"'
    '"IMAP 기반"'
    '"read-only 검토"'
    '"rate limit"'
    '"쿨다운"'
)

UI_FILES=(
    "$SWIFT_DIR/ArtifactCardView.swift"
    "$SWIFT_DIR/DailyBriefingCardView.swift"
    "$SWIFT_DIR/TeamStatusView.swift"
    "$SWIFT_DIR/WorkroomHomeView.swift"
    "$SWIFT_DIR/BeginnerTaskCardView.swift"
)

tech_fail=0
for pattern in "${TECH_PATTERNS[@]}"; do
    for file in "${UI_FILES[@]}"; do
        [ -f "$file" ] || continue
        if grep -qF "$pattern" "$file" 2>/dev/null; then
            fail "기술 UX 문구 발견 '$pattern' in $(basename $file)"
            tech_fail=$((tech_fail + 1))
        fi
    done
done

if [ "$tech_fail" -eq 0 ]; then
    pass "기술 UX 금지 문구 없음"
fi

# ── 10. 문서 확인 ─────────────────────────────────────────
echo ""
echo "[ 10/12 ] 인벤토리/커넥터 문서 확인"

if [ -f "$REPO_ROOT/docs/ProductImplementationInventory.md" ]; then
    pass "ProductImplementationInventory.md 존재"
else
    fail "ProductImplementationInventory.md 없음"
fi

if [ -f "$REPO_ROOT/docs/connectors/ConnectorReadinessPlan.md" ]; then
    pass "connectors/ConnectorReadinessPlan.md 존재"
else
    fail "connectors/ConnectorReadinessPlan.md 없음"
fi

# ── 11. Debug 빌드 ────────────────────────────────────────
echo ""
echo "[ 11/12 ] Debug 빌드"

if xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    build \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | tail -5 | grep -q "BUILD SUCCEEDED"; then
    pass "Debug BUILD SUCCEEDED"
else
    fail "Debug BUILD FAILED"
fi

# ── 12. Release 빌드 ──────────────────────────────────────
echo ""
echo "[ 12/12 ] Release 빌드"

if xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    build \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | tail -5 | grep -q "BUILD SUCCEEDED"; then
    pass "Release BUILD SUCCEEDED"
else
    fail "Release BUILD FAILED"
fi

# ── 결과 요약 ─────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════"
if [ "$FAILED" -eq 0 ]; then
    echo "✅ Preflight Round 236 전체 통과 (0 실패)"
    echo "══════════════════════════════════════════════════════"
    exit 0
else
    echo "❌ Preflight Round 236 실패: $FAILED 오류"
    echo "══════════════════════════════════════════════════════"
    exit 1
fi
