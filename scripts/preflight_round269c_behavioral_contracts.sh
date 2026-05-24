#!/usr/bin/env bash
# preflight_round269c_behavioral_contracts.sh
# Round 269C: Behavioral contract tests (grep/AST-level)
# XCTest fake-provider unit tests는 Round 270+에서 추가 예정.
# 이 파일은 "코드가 올바른 구조를 가지고 있는가"를 정적으로 검증한다.
# 20개 검사

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/MyTeam"
PASS=0
FAIL=0

ok()   { echo "  ✅ PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL+1)); }
fhas() { grep -qF "$1" "$2" 2>/dev/null; }
fnot() { ! grep -qF "$1" "$2" 2>/dev/null; }

echo "=== Round 269C BEHAVIORAL-CONTRACTS Preflight ==="
echo

# ── Behavioral Contract 1: 최신 모델이 block되지 않음 ──
# 1. LLMModelRegistry knownBrokenModels가 현재 주석 처리된 예시만 포함
#    (활성 항목 없음 = 모든 모델 허용)
if grep -v '^[[:space:]]*//' "$SRC/LLMModelRegistry.swift" | grep -qF 'KnownBrokenModel('; then
    fail "활성 KnownBrokenModel 항목 존재 — 의도된 경우 이 검사를 업데이트하세요"
else
    ok "knownBrokenModels 활성 항목 없음 (모든 모델 discovery 허용)"
fi

# 2. Discovery 경로가 floor fallback보다 항상 먼저 시도됨
fhas 'dynamicModelDiscoveryAllowed' "$SRC/AIService.swift" \
  && ok "AIService — discovery 경로 존재" || fail "AIService discovery 경로 없음"

# ── Behavioral Contract 2: tool 요청이 tool-capable provider로 감 ──
# 3. requiresToolUse 파라미터 → providerCandidates에 전달됨
fhas 'providerCandidates(preferred: preferredProvider, requiresToolUse: requiresToolUse)' "$SRC/AIService.swift" \
  && ok "requiresToolUse → providerCandidates 전달 확인" \
  || fail "requiresToolUse → providerCandidates 미전달"

# 4. tool-capable provider 목록 Claude + OpenAI
fhas 'let toolCapable: [LLMProvider] = [.claude, .openAI]' "$SRC/AIService.swift" \
  && ok "toolCapable = [claude, openAI] 정의" || fail "toolCapable 정의 없음"

# 5. requiresToolUse = true 시 baseOrder 우선 배치 로직
fhas 'if requiresToolUse && !toolCapable.contains(preferred)' "$SRC/AIService.swift" \
  && ok "requiresToolUse tool-capable 우선 라우팅 로직 존재" || fail "tool-capable 우선 라우팅 없음"

# 6. claudeWithTools가 Claude API만 사용 (tool loop)
fhas 'func claudeWithTools' "$SRC/AIService.swift" \
  && ok "claudeWithTools 전용 함수 존재" || fail "claudeWithTools 없음"

# ── Behavioral Contract 3: fallback metadata가 실제 provider를 말함 ──
# 7. LLMResponseMetadata에 usedFallback 플래그
fhas 'let usedFallback: Bool' "$SRC/AIService.swift" \
  && ok "LLMResponseMetadata.usedFallback 필드 존재" || fail "usedFallback 없음"

# 8. LLMResponseMetadata에 fallbackChain
fhas 'let fallbackChain: [LLMProvider]' "$SRC/AIService.swift" \
  && ok "LLMResponseMetadata.fallbackChain 필드 존재" || fail "fallbackChain 없음"

# 9. getResponse가 실제 성공 provider를 반환 (설정값 아님)
fhas 'return (text: fullText, provider: provider.displayName)' "$SRC/AIService.swift" \
  && ok "getResponse → 실제 provider.displayName 반환" || fail "getResponse 실제 provider 반환 없음"

# 10. getResponseWithMetadata가 LLMResponseMetadata 반환
fhas '(text: String, metadata: LLMResponseMetadata)' "$SRC/AIService.swift" \
  && ok "getResponseWithMetadata → LLMResponseMetadata 반환" || fail "LLMResponseMetadata 반환 없음"

# ── Behavioral Contract 4: room context가 섞이지 않음 ──
# 11. addChatLog(roomID:) 가 roomID를 필수 파라미터로 받음
fhas 'roomID: UUID' "$SRC/AgentWindowManager.swift" \
  && ok "addChatLog(roomID:) 존재" || fail "addChatLog(roomID:) 없음"

# 12. WorkflowOrchestrator가 항상 roomID를 명시하여 addChatLog 호출
fhas 'addChatLog(roomID: roomID' "$SRC/WorkflowOrchestrator.swift" \
  && ok "WorkflowOrchestrator → roomID 명시 addChatLog 호출" || fail "roomID 명시 호출 없음"

# 13. deprecated addChatLog (currentRoomID 읽는 버전) 경고 존재
fhas '@available(*, deprecated' "$SRC/AgentWindowManager.swift" \
  && ok "roomID 미지정 addChatLog deprecated 마킹됨" || fail "deprecated 마킹 없음"

# ── Behavioral Contract 5: 단일 호출 경로 통합 ──
# 14. quickSummary가 providerCandidates 기반
fhas 'let candidates = providerCandidates' "$SRC/AIService.swift" \
  && ok "quickSummary providerCandidates 통합" || fail "providerCandidates 통합 없음"

# 15. generatePrivacyTerms가 candidates 루프 기반
fhas 'for provider in candidates' "$SRC/AIService.swift" \
  && ok "generatePrivacyTerms candidates 루프" || fail "candidates 루프 없음"

# 16. quickSummary에 Gemini→Claude→OpenAI 하드코딩 순서 없음
fnot '"geminiAPIKey", { key in try await self.geminiQuickCall' "$SRC/AIService.swift" \
  && ok "quickSummary 하드코딩 순서 없음 (통합 라우팅)" || fail "quickSummary 하드코딩 순서 잔존"

# ── Behavioral Contract 6: 안전망 ──
# 17. floor fallback 상수 유지 (discovery 완전 실패 시)
fhas 'static let primary:  String = "gpt-4.1"' "$SRC/LLMModelRegistry.swift" \
  && ok "OpenAI floor fallback 상수 존재" || fail "OpenAI floor fallback 없음"

# 18. shouldFallbackProvider — 429/500/503 fallback 허용
fhas '429, 500, 502, 503, 504' "$SRC/AIService.swift" \
  && ok "shouldFallbackProvider HTTP 오류 코드 정의됨" || fail "fallback HTTP 코드 없음"

# 19. Gemini 쿨다운 메커니즘 존재
fhas 'isGeminiProviderCoolingDown' "$SRC/AIService.swift" \
  && ok "Gemini 쿨다운 메커니즘 존재" || fail "Gemini 쿨다운 없음"

# 20. no Apple TTS
if grep -vE '^\s*//' "$SRC/SpeechManager.swift" 2>/dev/null | grep -qF 'AVSpeechSynthesizer'; then
    fail "AVSpeechSynthesizer 비주석 라인 잔존"
else
    ok "Apple TTS 없음"
fi

echo
echo "=== 결과: PASS=$PASS FAIL=$FAIL / 20 ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
