#!/usr/bin/env bash
# preflight_round264_model_registry.sh
# Round 264-MODEL-REGISTRY: LLMModelRegistry + AIModelPolicy registry wrapper
# 22개 검사

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/MyTeam"
PASS=0
FAIL=0

ok()   { echo "  ✅ PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL+1)); }
fhas() { grep -qF "$1" "$2" 2>/dev/null; }
fnot() { ! grep -qF "$1" "$2" 2>/dev/null; }

echo "=== Round 264 MODEL-REGISTRY Preflight ==="
echo

# 1. LLMModelRegistry.swift 존재
[ -f "$SRC/LLMModelRegistry.swift" ] && ok "LLMModelRegistry.swift 존재" || fail "LLMModelRegistry.swift 없음"

# 2. pbxproj에 등록
fhas "LLMModelRegistry.swift" "$SRC/MyTeam.xcodeproj/project.pbxproj" \
  && ok "pbxproj에 LLMModelRegistry.swift 등록됨" \
  || fail "pbxproj에 LLMModelRegistry.swift 미등록"

# 3. OpenAI primary = gpt-4.1
fhas 'static let primary:  String = "gpt-4.1"' "$SRC/LLMModelRegistry.swift" \
  && ok "OpenAI.primary = gpt-4.1" \
  || fail "OpenAI.primary != gpt-4.1"

# 4. OpenAI fallback = gpt-4o
fhas 'static let fallback: String = "gpt-4o"' "$SRC/LLMModelRegistry.swift" \
  && ok "OpenAI.fallback = gpt-4o" \
  || fail "OpenAI.fallback 없음"

# 5. Claude primary = claude-sonnet-4-5-20250514
fhas 'claude-sonnet-4-5-20250514' "$SRC/LLMModelRegistry.swift" \
  && ok "Claude.primary = claude-sonnet-4-5-20250514" \
  || fail "Claude.primary 없음"

# 6. Gemini primary = gemini-2.5-flash
fhas '"gemini-2.5-flash"' "$SRC/LLMModelRegistry.swift" \
  && ok "Gemini.primary = gemini-2.5-flash" \
  || fail "Gemini.primary 없음"

# 7. OpenRouter primary = anthropic/claude-sonnet-4-5
fhas 'anthropic/claude-sonnet-4-5' "$SRC/LLMModelRegistry.swift" \
  && ok "OpenRouter.primary = anthropic/claude-sonnet-4-5" \
  || fail "OpenRouter.primary 없음"

# 8. blockedIDs 정의 — gpt-5.5 포함
fhas '"gpt-5.5"' "$SRC/LLMModelRegistry.swift" \
  && ok "blockedIDs에 gpt-5.5 포함" \
  || fail "blockedIDs에 gpt-5.5 없음"

# 9. blockedIDs — claude-opus-4-7 포함
fhas '"claude-opus-4-7"' "$SRC/LLMModelRegistry.swift" \
  && ok "blockedIDs에 claude-opus-4-7 포함" \
  || fail "blockedIDs에 claude-opus-4-7 없음"

# 10. blockedIDs — gemini-2.0-flash 포함
fhas '"gemini-2.0-flash"' "$SRC/LLMModelRegistry.swift" \
  && ok "blockedIDs에 gemini-2.0-flash 포함" \
  || fail "blockedIDs에 gemini-2.0-flash 없음"

# 11. isBlocked() 함수 존재
fhas 'func isBlocked' "$SRC/LLMModelRegistry.swift" \
  && ok "isBlocked() 존재" \
  || fail "isBlocked() 없음"

# 12. allBlockedIDs 집합 존재
fhas 'allBlockedIDs' "$SRC/LLMModelRegistry.swift" \
  && ok "allBlockedIDs 존재" \
  || fail "allBlockedIDs 없음"

# 13. AIModelPolicy.swift에 LLMModelRegistry 참조
fhas 'LLMModelRegistry' "$SRC/AIModelPolicy.swift" \
  && ok "AIModelPolicy가 LLMModelRegistry 참조" \
  || fail "AIModelPolicy에 LLMModelRegistry 참조 없음"

# 14. AIModelPolicy.defaultModel이 LLMModelRegistry 사용
fhas 'LLMModelRegistry.OpenAI.primary' "$SRC/AIModelPolicy.swift" \
  && ok "AIModelPolicy.defaultModel이 LLMModelRegistry.OpenAI.primary 사용" \
  || fail "AIModelPolicy.defaultModel에 LLMModelRegistry.OpenAI.primary 없음"

# 15. AIModelPolicy.pinnedModelID가 Gemini primary를 LLMModelRegistry에서 가져옴
fhas 'LLMModelRegistry.Gemini.primary' "$SRC/AIModelPolicy.swift" \
  && ok "pinnedModelID에 LLMModelRegistry.Gemini.primary 사용" \
  || fail "pinnedModelID에 LLMModelRegistry.Gemini.primary 없음"

# 16. AIModelPolicy.pinnedModelID가 Claude primary를 LLMModelRegistry에서 가져옴
fhas 'LLMModelRegistry.Claude.primary' "$SRC/AIModelPolicy.swift" \
  && ok "pinnedModelID에 LLMModelRegistry.Claude.primary 사용" \
  || fail "pinnedModelID에 LLMModelRegistry.Claude.primary 없음"

# 17. resolvedModelID가 isBlocked 사용
fhas 'LLMModelRegistry.isBlocked' "$SRC/AIModelPolicy.swift" \
  && ok "resolvedModelID에 isBlocked 사용" \
  || fail "resolvedModelID에 isBlocked 없음"

# 18. AIService.swift에 LLMModelRegistry 참조
fhas 'LLMModelRegistry' "$SRC/AIService.swift" \
  && ok "AIService.swift가 LLMModelRegistry 참조" \
  || fail "AIService.swift에 LLMModelRegistry 참조 없음"

# 19. AIService에 gemini-2.0-flash 하드코딩 없음
fnot '"gemini-2.0-flash"' "$SRC/AIService.swift" \
  && ok "AIService에 gemini-2.0-flash 하드코딩 없음" \
  || fail "AIService에 gemini-2.0-flash 하드코딩 존재"

# 20. AIService에 claude-opus-4-7 하드코딩 없음
fnot '"claude-opus-4-7"' "$SRC/AIService.swift" \
  && ok "AIService에 claude-opus-4-7 하드코딩 없음" \
  || fail "AIService에 claude-opus-4-7 하드코딩 존재"

# 21. AIModelPolicy에 gpt-5.5 하드코딩 없음
fnot '"gpt-5.5"' "$SRC/AIModelPolicy.swift" \
  && ok "AIModelPolicy에 gpt-5.5 하드코딩 없음" \
  || fail "AIModelPolicy에 gpt-5.5 하드코딩 존재"

# 22. defaultModelFamilyLabel 존재
fhas 'defaultModelFamilyLabel' "$SRC/LLMModelRegistry.swift" \
  && ok "defaultModelFamilyLabel 존재" \
  || fail "defaultModelFamilyLabel 없음"

echo
echo "=== 결과: PASS=$PASS FAIL=$FAIL / 22 ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
