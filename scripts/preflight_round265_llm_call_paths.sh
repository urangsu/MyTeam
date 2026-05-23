#!/usr/bin/env bash
# preflight_round265_llm_call_paths.sh
# Round 265 + Round 269A/B: LLM 호출 경로 통합 검사
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

echo "=== Round 265 + 269A/B LLM-CALL-PATHS Preflight ==="
echo

# 1. AIService에 gpt-5.5 하드코딩 없음
fnot '"gpt-5.5"' "$SRC/AIService.swift" \
  && ok "AIService에 gpt-5.5 하드코딩 없음" \
  || fail "AIService에 gpt-5.5 하드코딩 존재"

# 2. AIService에 gpt-5.1 하드코딩 없음
fnot '"gpt-5.1"' "$SRC/AIService.swift" \
  && ok "AIService에 gpt-5.1 하드코딩 없음" \
  || fail "AIService에 gpt-5.1 하드코딩 존재"

# 3. AIService에 gpt-5.2 하드코딩 없음
fnot '"gpt-5.2"' "$SRC/AIService.swift" \
  && ok "AIService에 gpt-5.2 하드코딩 없음" \
  || fail "AIService에 gpt-5.2 하드코딩 존재"

# 4. AIService에 gemini-1.5-flash 하드코딩 없음
fnot '"gemini-1.5-flash"' "$SRC/AIService.swift" \
  && ok "AIService에 gemini-1.5-flash 하드코딩 없음" \
  || fail "AIService에 gemini-1.5-flash 하드코딩 존재"

# 5. AIService에 gemini-1.5-pro 하드코딩 없음
fnot '"gemini-1.5-pro"' "$SRC/AIService.swift" \
  && ok "AIService에 gemini-1.5-pro 하드코딩 없음" \
  || fail "AIService에 gemini-1.5-pro 하드코딩 존재"

# 6. 269A: AIService에 isKnownBroken 필터 존재 (isBlocked 대체)
fhas 'LLMModelRegistry.isKnownBroken' "$SRC/AIService.swift" \
  && ok "AIService에 LLMModelRegistry.isKnownBroken 필터 존재" \
  || fail "AIService에 LLMModelRegistry.isKnownBroken 필터 없음"

# 7. AIService Gemini primary — LLMModelRegistry.Gemini.primary 사용
fhas 'LLMModelRegistry.Gemini.primary' "$SRC/AIService.swift" \
  && ok "AIService Gemini에 LLMModelRegistry.Gemini.primary 사용" \
  || fail "AIService Gemini에 LLMModelRegistry.Gemini.primary 없음"

# 8. AIService Claude fallback — LLMModelRegistry.Claude 참조
fhas 'LLMModelRegistry.Claude' "$SRC/AIService.swift" \
  && ok "AIService에 LLMModelRegistry.Claude 참조 존재" \
  || fail "AIService에 LLMModelRegistry.Claude 참조 없음"

# 9. AIService httpBody 직접 대입에 try? 없음
if grep -qE 'httpBody\s*=\s*try\?' "$SRC/AIService.swift" 2>/dev/null; then
    fail "AIService httpBody = try? JSONSerialization silent failure 존재"
else
    ok "AIService httpBody 직접 대입 try? 없음"
fi

# 10. SpeechManager에 gpt-5.x 하드코딩 없음
fnot '"gpt-5' "$SRC/SpeechManager.swift" \
  && ok "SpeechManager에 gpt-5.x 하드코딩 없음" \
  || fail "SpeechManager에 gpt-5.x 하드코딩 존재"

# 11. WorkflowOrchestrator에 gpt-5.x 하드코딩 없음
if [ -f "$SRC/WorkflowOrchestrator.swift" ]; then
    fnot '"gpt-5' "$SRC/WorkflowOrchestrator.swift" \
      && ok "WorkflowOrchestrator에 gpt-5.x 하드코딩 없음" \
      || fail "WorkflowOrchestrator에 gpt-5.x 하드코딩 존재"
else
    ok "WorkflowOrchestrator.swift 없음 (검사 스킵)"
fi

# 12. TeamOrchestrator에 gpt-5.x 하드코딩 없음
if [ -f "$SRC/TeamOrchestrator.swift" ]; then
    fnot '"gpt-5' "$SRC/TeamOrchestrator.swift" \
      && ok "TeamOrchestrator에 gpt-5.x 하드코딩 없음" \
      || fail "TeamOrchestrator에 gpt-5.x 하드코딩 존재"
else
    ok "TeamOrchestrator.swift 없음 (검사 스킵)"
fi

# 13. LLMModelRegistry OpenRouter.fallback = openai/gpt-4.1
fhas 'openai/gpt-4.1' "$SRC/LLMModelRegistry.swift" \
  && ok "OpenRouter.fallback = openai/gpt-4.1" \
  || fail "OpenRouter.fallback 없음"

# 14. 269A: LLMModelRegistry에 정적 blockedIDs 없음 (KnownBrokenModel 기반)
fnot 'static let blockedIDs' "$SRC/LLMModelRegistry.swift" \
  && ok "LLMModelRegistry 정적 blockedIDs 없음 (269A 완료)" \
  || fail "LLMModelRegistry에 정적 blockedIDs 잔존"

# 15. 269A: AIModelPolicy.dynamicModelDiscoveryAllowed가 Debug/Release 모두 true
fhas 'return true' "$SRC/AIModelPolicy.swift" \
  && ok "AIModelPolicy.dynamicModelDiscoveryAllowed = true (항상)" \
  || fail "AIModelPolicy.dynamicModelDiscoveryAllowed true 없음"

# 16. 269B: LLMResponseMetadata 구조체 존재
fhas 'LLMResponseMetadata' "$SRC/AIService.swift" \
  && ok "LLMResponseMetadata 존재 (269B)" \
  || fail "LLMResponseMetadata 없음"

# 17. AIModelPolicy.modelFamily가 LLMModelRegistry.defaultModelFamilyLabel 사용
fhas 'LLMModelRegistry.defaultModelFamilyLabel' "$SRC/AIModelPolicy.swift" \
  && ok "AIModelPolicy.modelFamily가 LLMModelRegistry.defaultModelFamilyLabel 사용" \
  || fail "AIModelPolicy.modelFamily가 하드코딩"

# 18. LLMModelRegistry.swift가 pbxproj에 FILEREF로 등록됨
fhas 'LLMR264REL001FILEREF0000G1' "$SRC/MyTeam.xcodeproj/project.pbxproj" \
  && ok "pbxproj FILEREF LLMR264REL001 등록 확인" \
  || fail "pbxproj FILEREF LLMR264REL001 없음"

echo
echo "=== 결과: PASS=$PASS FAIL=$FAIL / 18 ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
