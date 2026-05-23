#!/usr/bin/env bash
# preflight_round269a_model_truth_gate.sh
# Round 269A: Model Truth Gate — KnownBrokenModel, Release discovery, unified routing
# 18개 검사

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/MyTeam"
PASS=0
FAIL=0

ok()   { echo "  ✅ PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL+1)); }
fhas() { grep -qF "$1" "$2" 2>/dev/null; }
fnot() { ! grep -qF "$1" "$2" 2>/dev/null; }

echo "=== Round 269A MODEL-TRUTH-GATE Preflight ==="
echo

# 1. LLMModelRegistry에 KnownBrokenModel 구조체
fhas 'struct KnownBrokenModel' "$SRC/LLMModelRegistry.swift" \
  && ok "KnownBrokenModel 구조체 존재" || fail "KnownBrokenModel 없음"

# 2. 정적 blockedIDs 배열 제거됨
fnot 'static let blockedIDs' "$SRC/LLMModelRegistry.swift" \
  && ok "정적 blockedIDs 없음" || fail "정적 blockedIDs 잔존"

# 3. isKnownBroken() 존재
fhas 'func isKnownBroken' "$SRC/LLMModelRegistry.swift" \
  && ok "isKnownBroken() 존재" || fail "isKnownBroken() 없음"

# 4. knownBrokenModels 목록 존재
fhas 'knownBrokenModels' "$SRC/LLMModelRegistry.swift" \
  && ok "knownBrokenModels 목록 존재" || fail "knownBrokenModels 없음"

# 5. AIModelPolicy.dynamicModelDiscoveryAllowed 항상 true
fhas 'return true' "$SRC/AIModelPolicy.swift" \
  && ok "dynamicModelDiscoveryAllowed 항상 true" || fail "dynamicModelDiscoveryAllowed = true 없음"

# 6. dynamicModelDiscovery에 #if DEBUG 없음
if grep -A5 'dynamicModelDiscoveryAllowed' "$SRC/AIModelPolicy.swift" | grep -q '#if DEBUG'; then
    fail "dynamicModelDiscoveryAllowed에 #if DEBUG 잔존"
else
    ok "dynamicModelDiscoveryAllowed에 #if DEBUG 없음"
fi

# 7. resolvedModelID가 isKnownBroken 사용
fhas 'isKnownBroken' "$SRC/AIModelPolicy.swift" \
  && ok "resolvedModelID → isKnownBroken 사용" || fail "resolvedModelID → isKnownBroken 없음"

# 8. AIService에 isKnownBroken 필터
fhas 'isKnownBroken' "$SRC/AIService.swift" \
  && ok "AIService → isKnownBroken 사용" || fail "AIService → isKnownBroken 없음"

# 9. AIService에 레거시 isBlocked 없음
fnot 'LLMModelRegistry.isBlocked' "$SRC/AIService.swift" \
  && ok "AIService LLMModelRegistry.isBlocked 레거시 제거됨" || fail "AIService LLMModelRegistry.isBlocked 잔존"

# 10. AIModelPolicy에 레거시 isBlocked 없음
fnot 'LLMModelRegistry.isBlocked' "$SRC/AIModelPolicy.swift" \
  && ok "AIModelPolicy LLMModelRegistry.isBlocked 레거시 제거됨" || fail "AIModelPolicy LLMModelRegistry.isBlocked 잔존"

# 11. LLMResponseMetadata 구조체 존재 (269B)
fhas 'struct LLMResponseMetadata' "$SRC/AIService.swift" \
  && ok "LLMResponseMetadata 구조체 존재" || fail "LLMResponseMetadata 없음"

# 12. getResponseWithMetadata 함수 존재 (269B)
fhas 'getResponseWithMetadata' "$SRC/AIService.swift" \
  && ok "getResponseWithMetadata 존재" || fail "getResponseWithMetadata 없음"

# 13. getResponse가 실제 provider.displayName 반환
fhas 'provider.displayName' "$SRC/AIService.swift" \
  && ok "getResponse → 실제 provider.displayName 반환" || fail "getResponse → 실제 provider 없음"

# 14. getResponseStream에 requiresToolUse 파라미터 (269B)
fhas 'requiresToolUse: Bool = false' "$SRC/AIService.swift" \
  && ok "getResponseStream requiresToolUse 파라미터 존재" || fail "getResponseStream requiresToolUse 없음"

# 15. quickSummary가 providerCandidates 사용
fhas 'providerCandidates' "$SRC/AIService.swift" \
  && ok "quickSummary providerCandidates 통합 라우팅" || fail "providerCandidates 없음"

# 16. generatePrivacyTerms가 candidates 루프 사용
fhas 'for provider in candidates' "$SRC/AIService.swift" \
  && ok "generatePrivacyTerms candidates 루프 통합" || fail "candidates 루프 없음"

# 17. AVSpeechSynthesizer 비주석 라인 없음
if grep -vE '^\s*//' "$SRC/SpeechManager.swift" 2>/dev/null | grep -qF 'AVSpeechSynthesizer'; then
    fail "AVSpeechSynthesizer 비주석 라인 잔존"
else
    ok "AVSpeechSynthesizer 없음 (주석만 허용)"
fi

# 18. AIService LLMModelRegistry 참조 유지
fhas 'LLMModelRegistry' "$SRC/AIService.swift" \
  && ok "AIService LLMModelRegistry 참조 유지" || fail "AIService LLMModelRegistry 참조 없음"

echo
echo "=== 결과: PASS=$PASS FAIL=$FAIL / 18 ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
