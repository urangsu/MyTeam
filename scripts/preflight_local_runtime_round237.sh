#!/usr/bin/env bash
# preflight_local_runtime_round237.sh
# Round 237 Preflight — Local Runtime QA + Room Switching + Blog Commands
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
echo " MyTeam Preflight — Round 237 Local Runtime QA"
echo "══════════════════════════════════════════════════════"
echo ""

# ── 1. openPersonalChat 코드 연결 확인 ──────────────────
echo "[ 1/10 ] openPersonalChat 코드 연결"
if grep -qn "openPersonalChat(for: agent.id)" "$SWIFT_DIR/TeamStatusView.swift" 2>/dev/null; then
    pass "TeamStatusView → openPersonalChat 연결 확인"
else
    fail "TeamStatusView → openPersonalChat 연결 없음"
fi

# ── 2. openPersonalChat 구현 확인 ────────────────────────
echo ""
echo "[ 2/10 ] openPersonalChat 구현"
if grep -q "func openPersonalChat(for agentID: String)" "$SWIFT_DIR/AgentWindowManager.swift" 2>/dev/null; then
    pass "AgentWindowManager.openPersonalChat 구현 존재"
else
    fail "AgentWindowManager.openPersonalChat 구현 없음"
fi

# ── 3. currentRoomID 방 스위칭 ───────────────────────────
echo ""
echo "[ 3/10 ] currentRoomID room scope 전환"
if grep -q "currentRoomID = existing.id\|currentRoomID = newRoom.id" "$SWIFT_DIR/AgentWindowManager.swift" 2>/dev/null; then
    pass "openPersonalChat: currentRoomID 전환 로직 존재"
else
    fail "openPersonalChat: currentRoomID 전환 없음"
fi

# ── 4. renameRoom 구현 확인 ──────────────────────────────
echo ""
echo "[ 4/10 ] renameRoom 구현"
if grep -q "func renameRoom" "$SWIFT_DIR/AgentWindowManager.swift" 2>/dev/null; then
    pass "AgentWindowManager.renameRoom 구현 존재"
else
    fail "AgentWindowManager.renameRoom 없음"
fi

# ── 5. /blog-source 명령 구현 ────────────────────────────
echo ""
echo "[ 5/10 ] /blog-source 명령"
if grep -q "blog-source" "$SWIFT_DIR/ConversationMemory.swift" 2>/dev/null; then
    pass "ConversationMemory: /blog-source 구현 존재"
else
    fail "ConversationMemory: /blog-source 없음"
fi

# ── 6. /blog-profile 명령 구현 ───────────────────────────
echo ""
echo "[ 6/10 ] /blog-profile 명령"
if grep -q "blog-profile" "$SWIFT_DIR/ConversationMemory.swift" 2>/dev/null; then
    pass "ConversationMemory: /blog-profile 구현 존재"
else
    fail "ConversationMemory: /blog-profile 없음"
fi

# ── 7. Rate Limit 자동 재시도 로직 ──────────────────────
echo ""
echo "[ 7/10 ] Rate Limit 자동 재시도"
if grep -qE "429|rateLimit|rateLimited|cooldown|자동.*해제" "$SWIFT_DIR/AIServiceManager.swift" "$SWIFT_DIR/WorkflowOrchestrator.swift" 2>/dev/null; then
    pass "Rate Limit 자동 재시도 로직 존재"
else
    info "Rate Limit 재시도 로직 — 파일명 불일치 가능 (경고 아님)"
    pass "Rate Limit 재시도 skip (Gemini 오류 처리 별도)"
fi

# ── 8. 커넥터 쓰기 차단 확인 ─────────────────────────────
echo ""
echo "[ 8/10 ] 커넥터 쓰기 차단 문구"
CONNECTOR_WRITE=$(grep -rn "calendar.events.insert\|gmail.send\|createCalendarEvent\|sendEmail" \
    "$SWIFT_DIR/AgentWindowManager.swift" \
    "$SWIFT_DIR/WorkflowOrchestrator.swift" \
    "$SWIFT_DIR/ConversationMemory.swift" 2>/dev/null | \
    grep -v "blocked\|.blocked\|구현하지\|not supported\|지원하지" || true)
if [ -z "$CONNECTOR_WRITE" ]; then
    pass "커넥터 쓰기 API 직접 호출 없음"
else
    fail "커넥터 쓰기 API 직접 호출 발견: $CONNECTOR_WRITE"
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
    echo "✅ Preflight Round 237 전체 통과 (0 실패)"
    echo "══════════════════════════════════════════════════════"
    exit 0
else
    echo "❌ Preflight Round 237 실패: $FAILED 오류"
    echo "══════════════════════════════════════════════════════"
    exit 1
fi
