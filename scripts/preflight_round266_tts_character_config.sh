#!/usr/bin/env bash
# preflight_round266_tts_character_config.sh
# Round 266: TTS agentID propagation fix + TTS-CharConfig log
# 16개 검사

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/MyTeam"
PASS=0
FAIL=0

ok()   { echo "  ✅ PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL+1)); }
fhas() { grep -qF "$1" "$2" 2>/dev/null; }
fnot() { ! grep -qF "$1" "$2" 2>/dev/null; }

echo "=== Round 266 TTS-CHARACTER-CONFIG Preflight ==="
echo

# 1. SpeechManager에 agentID 파라미터 존재
fhas 'agentID' "$SRC/SpeechManager.swift" \
  && ok "SpeechManager에 agentID 파라미터 존재" \
  || fail "SpeechManager에 agentID 파라미터 없음"

# 2. dispatchToInferencePipeline에 agentID 전달
fhas 'agentID: agentID' "$SRC/SpeechManager.swift" \
  && ok "dispatchToInferencePipeline에 agentID: agentID 전달 존재" \
  || fail "dispatchToInferencePipeline에 agentID: agentID 전달 없음"

# 3. TTS-CharConfig 로그 존재
fhas 'TTS-CharConfig' "$SRC/SpeechManager.swift" \
  && ok "TTS-CharConfig 로그 존재" \
  || fail "TTS-CharConfig 로그 없음"

# 4. Supertonic3ONNXRunner.synthesize에 preset 파라미터 전달
fhas 'preset:' "$SRC/SpeechManager.swift" \
  && ok "synthesize에 preset: 파라미터 전달 존재" \
  || fail "synthesize에 preset: 파라미터 없음"

# 5. SpeechManager에 SupertonicVoicePresetPolicy 참조
fhas 'SupertonicVoicePresetPolicy' "$SRC/SpeechManager.swift" \
  && ok "SpeechManager에 SupertonicVoicePresetPolicy 참조 존재" \
  || fail "SpeechManager에 SupertonicVoicePresetPolicy 참조 없음"

# 6. Supertonic3ONNXRunner.swift 존재
[ -f "$SRC/Supertonic3ONNXRunner.swift" ] \
  && ok "Supertonic3ONNXRunner.swift 존재" \
  || fail "Supertonic3ONNXRunner.swift 없음"

# 7. S3Config nonisolated(unsafe) — Swift 6 actor-isolation 대응
fhas 'nonisolated(unsafe)' "$SRC/Supertonic3ONNXRunner.swift" \
  && ok "S3Config nonisolated(unsafe) 적용됨" \
  || fail "S3Config nonisolated(unsafe) 없음"

# 8. sampleRate nonisolated(unsafe)
fhas 'nonisolated(unsafe) static let sampleRate' "$SRC/Supertonic3ONNXRunner.swift" \
  && ok "sampleRate nonisolated(unsafe) 확인" \
  || fail "sampleRate nonisolated(unsafe) 없음"

# 9. totalStepDefault nonisolated(unsafe)
fhas 'nonisolated(unsafe) static let totalStepDefault' "$SRC/Supertonic3ONNXRunner.swift" \
  && ok "totalStepDefault nonisolated(unsafe) 확인" \
  || fail "totalStepDefault nonisolated(unsafe) 없음"

# 10. no Apple TTS (AVSpeechSynthesizer) — 주석은 허용, 실제 사용 금지
if grep -vE '^\s*//' "$SRC/SpeechManager.swift" 2>/dev/null | grep -qF 'AVSpeechSynthesizer'; then
    fail "SpeechManager에 AVSpeechSynthesizer 실제 사용 존재 (Apple TTS 금지)"
else
    ok "SpeechManager에 AVSpeechSynthesizer 실제 사용 없음"
fi

# 11. fallbackTTSAvailable = false (TTSProductPolicy에 있음)
if [ -f "$SRC/TTSProductPolicy.swift" ]; then
    fhas 'fallbackTTSAvailable' "$SRC/TTSProductPolicy.swift" \
      && ok "TTSProductPolicy.fallbackTTSAvailable 존재" \
      || fail "TTSProductPolicy.fallbackTTSAvailable 없음"
else
    fhas 'fallbackTTSAvailable' "$SRC/SpeechManager.swift" \
      && ok "fallbackTTSAvailable 존재 (SpeechManager)" \
      || fail "fallbackTTSAvailable 없음"
fi

# 12. autoSpeakDefaultEnabled = false 또는 false 반환
if grep -qE 'autoSpeakDefaultEnabled.*=.*false|return false.*autospeak' "$SRC/SpeechManager.swift" 2>/dev/null; then
    ok "autoSpeakDefaultEnabled = false 확인"
else
    # 대안: 변수가 없거나 false 반환
    fnot 'autoSpeakDefaultEnabled.*=.*true' "$SRC/SpeechManager.swift" \
      && ok "autoSpeakDefaultEnabled = true 없음 (기본 false)" \
      || fail "autoSpeakDefaultEnabled = true 존재"
fi

# 13. SupertonicVoicePresetPolicy.swift 존재
[ -f "$SRC/SupertonicVoicePresetPolicy.swift" ] \
  && ok "SupertonicVoicePresetPolicy.swift 존재" \
  || fail "SupertonicVoicePresetPolicy.swift 없음"

# 14. AudioPlaybackService.swift 존재
[ -f "$SRC/AudioPlaybackService.swift" ] \
  && ok "AudioPlaybackService.swift 존재" \
  || fail "AudioPlaybackService.swift 없음"

# 15. AudioPlaybackService.playFloatSamples 존재
fhas 'playFloatSamples' "$SRC/AudioPlaybackService.swift" \
  && ok "AudioPlaybackService.playFloatSamples 존재" \
  || fail "AudioPlaybackService.playFloatSamples 없음"

# 16. no Qwen3TTS 복구
fnot 'Qwen3TTS' "$SRC/SpeechManager.swift" \
  && ok "SpeechManager에 Qwen3TTS 없음 (복구 금지)" \
  || fail "SpeechManager에 Qwen3TTS 존재 (복구 금지 위반)"

echo
echo "=== 결과: PASS=$PASS FAIL=$FAIL / 16 ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
