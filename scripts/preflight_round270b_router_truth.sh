#!/usr/bin/env bash
# preflight_round270b_router_truth.sh
# Round 270B: LLM Router Truth Gate
# 12개 정적 검사 — xcodebuild 실행 없이 소스 코드 패턴 확인
# 2026-05-24

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

ok()   { echo "  ✅ PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL+1)); }

AI="$ROOT/MyTeam/AIService.swift"
ACV="$ROOT/MyTeam/AgentChatView.swift"

echo "=== Round 270B ROUTER-TRUTH Preflight ==="
echo

# 1. providerCandidates 함수 존재
if grep -q 'func providerCandidates' "$AI"; then
    ok "providerCandidates 함수 존재"
else
    fail "providerCandidates 함수 없음"
fi

# 2. toolCapable 배열 정의 존재
if grep -q 'toolCapable' "$AI"; then
    ok "toolCapable 배열 존재"
else
    fail "toolCapable 배열 없음"
fi

# 3. requiresToolUse && !toolCapable.contains(preferred) 분기에서 toolCapable이 preferred보다 먼저
# toolCapable + [preferred] 패턴이 있어야 함 (이전 버그는 [preferred] + toolCapable)
if grep -A5 'requiresToolUse && !toolCapable.contains' "$AI" | grep -q 'toolCapable + \[preferred\]'; then
    ok "tool-capable provider가 preferred보다 먼저 (순서 버그 수정됨)"
else
    fail "tool-capable provider 순서 버그 미수정 (toolCapable + [preferred] 패턴 없음)"
fi

# 4. 스트림 경로에 dynamicModelDiscoveryAllowed 사용
COUNT_DYNAMIC=$(grep -c 'dynamicModelDiscoveryAllowed' "$AI" || true)
if [ "$COUNT_DYNAMIC" -ge 3 ]; then
    ok "dynamicModelDiscoveryAllowed 스트림 경로에 사용 (${COUNT_DYNAMIC}곳)"
else
    fail "dynamicModelDiscoveryAllowed 스트림 경로 참조 부족 (${COUNT_DYNAMIC}곳, 최소 3 필요)"
fi

# 5. 스트림 경로에서 modelOverrideAllowed 단독 사용 없음
# (quickSummary/generatePrivacyTerms의 'if AIModelPolicy.modelOverrideAllowed,' 콤마 형식은 허용)
STREAM_OVERRIDE=$(grep -c 'if AIModelPolicy\.modelOverrideAllowed {' "$AI" 2>/dev/null || true)
if [ "$STREAM_OVERRIDE" -eq 0 ]; then
    ok "스트림 경로에서 modelOverrideAllowed 단독 사용 없음"
else
    fail "스트림 경로에서 modelOverrideAllowed 단독 사용 ${STREAM_OVERRIDE}곳 잔존"
fi

# 6. ResolvedLLMCall struct 존재
if grep -q 'struct ResolvedLLMCall' "$AI"; then
    ok "ResolvedLLMCall struct 존재"
else
    fail "ResolvedLLMCall struct 없음"
fi

# 7. ResolvedLLMCall.ModelSource enum 존재
if grep -q 'enum ModelSource' "$AI"; then
    ok "ResolvedLLMCall.ModelSource enum 존재"
else
    fail "ResolvedLLMCall.ModelSource enum 없음"
fi

# 8. ModelSource cases: cached, discovered, floor
if grep -q 'case cached' "$AI" && grep -q 'case discovered' "$AI" && grep -q 'case floor' "$AI"; then
    ok "ModelSource cases (cached/discovered/floor) 존재"
else
    fail "ModelSource cases 일부 누락"
fi

# 9. getResponseWithMetadata에서 pinnedModelID 단독 반환 없음 (실제 캐시 사용)
# cachedGeminiModelId 또는 cachedClaudeModelId 또는 cachedOpenAIModelId 사용 확인
if grep -q 'cachedGeminiModelId\|cachedClaudeModelId\|cachedOpenAIModelId' "$AI"; then
    ok "getResponseWithMetadata가 캐시된 실제 modelID 사용"
else
    fail "getResponseWithMetadata가 캐시 modelID 미사용 (pinnedModelID만 반환)"
fi

# 10. LLMResponseMetadata 유지 (269B backward compat)
if grep -q 'struct LLMResponseMetadata' "$AI"; then
    ok "LLMResponseMetadata struct 유지 (backward compat)"
else
    fail "LLMResponseMetadata struct 없음"
fi

# 11. ToolNeedClassifier 존재
if grep -q 'ToolNeedClassifier' "$ACV"; then
    ok "ToolNeedClassifier 존재 (AgentChatView)"
else
    fail "ToolNeedClassifier 없음"
fi

# 12. getResponseStream에 requiresToolUse 파라미터 전달 (AgentChatView)
COUNT_TOOL_USE=$(grep -c 'requiresToolUse: ToolNeedClassifier' "$ACV" || true)
if [ "$COUNT_TOOL_USE" -ge 2 ]; then
    ok "requiresToolUse 전달 (${COUNT_TOOL_USE}곳)"
else
    fail "requiresToolUse 전달 부족 (${COUNT_TOOL_USE}곳, 최소 2 필요)"
fi

echo
echo "=== 결과: PASS=$PASS FAIL=$FAIL / 12 ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
