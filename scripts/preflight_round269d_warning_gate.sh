#!/usr/bin/env bash
# preflight_round269d_warning_gate.sh
# Round 269D: Warning Zero Gate
# Supertonic3ONNXRunner와 번들 모델의 현재 Release 계약을 정적으로 검증한다.
# Production 파일 구조 계약을 정적으로 검증한다.
# 12개 검사

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/MyTeam"
PASS=0
FAIL=0

ok()   { echo "  ✅ PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL+1)); }
fhas() { grep -qF "$1" "$2" 2>/dev/null; }
fnot() { ! grep -qF "$1" "$2" 2>/dev/null; }

echo "=== Round 269D WARNING-ZERO-GATE Preflight ==="
echo

# 1. AgentWindowManager addChatLog(roomID:)에 @discardableResult
#    → MainActor.run { addChatLog(...) }의 unused result 경고 근본 해결
fhas '@discardableResult' "$SRC/AgentWindowManager.swift" \
  && ok "AgentWindowManager @discardableResult 존재 (MainActor.run 경고 방지)" \
  || fail "@discardableResult 없음"

# 2. AIService에 httpBody = try? 없음 (Round 265 silent failure 수정)
if grep -qE 'httpBody\s*=\s*try\?' "$SRC/AIService.swift" 2>/dev/null; then
    fail "AIService httpBody = try? silent failure 잔존"
else
    ok "AIService httpBody = try? 없음"
fi

# 3. continuation.finish(throwing:) guard 패턴 — AIService
fhas 'continuation.finish(throwing:' "$SRC/AIService.swift" \
  && ok "AIService continuation.finish(throwing:) guard 패턴 존재" \
  || fail "continuation.finish(throwing:) 없음"

# 4. Supertonic3ONNXRunner는 실제 제품 actor로 유지
fhas 'actor Supertonic3ONNXRunner' "$SRC/Supertonic3ONNXRunner.swift" \
  && ok "Supertonic3ONNXRunner 제품 actor 존재" \
  || fail "Supertonic3ONNXRunner 제품 actor 없음"

# 5. S3Config Swift 6 주석 존재 (pre-existing warning 설명)
fhas 'Swift 6 future error' "$SRC/Supertonic3ONNXRunner.swift" \
  && ok "S3Config Swift 6 forward-compat 주석 존재" \
  || fail "S3Config Swift 6 주석 없음"

# 6. S3Config에 불필요한 nonisolated(unsafe) 없음
fnot 'nonisolated(unsafe) static let sampleRate' "$SRC/Supertonic3ONNXRunner.swift" \
  && ok "S3Config nonisolated(unsafe) 제거됨 (컴파일러 권고 반영)" \
  || fail "S3Config nonisolated(unsafe) 잔존"

# 7. fallbackTTSAvailable = false (TTSProductPolicy)
fhas 'fallbackTTSAvailable: Bool       = false' "$SRC/TTSProductPolicy.swift" \
  && ok "TTSProductPolicy.fallbackTTSAvailable = false" \
  || fail "fallbackTTSAvailable != false"

# 8. autoSpeakDefaultEnabled = false (TTSProductPolicy)
fhas 'autoSpeakDefaultEnabled: Bool    = false' "$SRC/TTSProductPolicy.swift" \
  && ok "TTSProductPolicy.autoSpeakDefaultEnabled = false" \
  || fail "autoSpeakDefaultEnabled != false"

# 9. no Apple TTS (비주석)
if grep -vE '^\s*//' "$SRC/SpeechManager.swift" 2>/dev/null | grep -qF 'AVSpeechSynthesizer'; then
    fail "AVSpeechSynthesizer 비주석 라인 잔존"
else
    ok "Apple TTS 없음"
fi

# 10. App Store Release에 필요한 Supertonic3 모델 번들과 무결성
if python3 "$ROOT/scripts/validate_supertonic3_bundle.py" --require-bundle >/dev/null; then
    ok "Supertonic3 번들 모델 및 무결성 검증"
else
    fail "Supertonic3 번들 모델 또는 무결성 불일치"
fi

# 11. .log git untracked
if git -C "$ROOT" ls-files '*.log' 2>/dev/null | grep -q '\.log'; then
    fail ".log 파일 git track됨"
else
    ok ".log git untracked (정상)"
fi

# 12. LLMModelRegistry 정적 blockedIDs 없음 (269A 완료 확인)
fnot 'static let blockedIDs' "$SRC/LLMModelRegistry.swift" \
  && ok "LLMModelRegistry 정적 blockedIDs 없음" \
  || fail "정적 blockedIDs 잔존"

echo
echo "=== 결과: PASS=$PASS FAIL=$FAIL / 12 ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
