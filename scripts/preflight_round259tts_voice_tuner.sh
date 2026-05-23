#!/usr/bin/env bash
# preflight_round259tts_voice_tuner.sh
# Round 259TTS-VOICE-TUNER: 임시 P/R/S 튜닝 컨트롤 + pitch 재조정 + AC 모드 분리 검증
# 검사 22개 — 예상: 22/22 PASS
set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MYTEAM="$REPO_ROOT/MyTeam"
SCRIPTS="$REPO_ROOT/scripts"

PASS=0
FAIL=0
TOTAL=22

pass() { PASS=$((PASS + 1)); echo "  ✅ PASS [$PASS/$TOTAL] $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ❌ FAIL [$FAIL/$TOTAL] $1"; }

echo "=================================================="
echo " Round 259TTS-VOICE-TUNER Preflight"
echo " $(date)"
echo "=================================================="

# 1. VoiceTuningState.swift 존재
echo ""
echo "[1] VoiceTuningState.swift 존재 확인"
if [ -f "$MYTEAM/VoiceTuningState.swift" ]; then
  pass "VoiceTuningState.swift 존재"
else
  fail "VoiceTuningState.swift 없음"
fi

# 2. VoiceTuningValues에 pitch/rate/speed 필드 존재
echo ""
echo "[2] VoiceTuningValues pitch/rate/speed 필드 확인"
if grep -q "var pitch" "$MYTEAM/VoiceTuningState.swift" 2>/dev/null && \
   grep -q "var rate"  "$MYTEAM/VoiceTuningState.swift" 2>/dev/null && \
   grep -q "var speed" "$MYTEAM/VoiceTuningState.swift" 2>/dev/null; then
  pass "VoiceTuningValues pitch/rate/speed 필드 존재"
else
  fail "VoiceTuningValues에 pitch/rate/speed 필드 누락"
fi

# 3. TTSLabView에 tuningPitch/tuningRate/tuningSpeed 상태 변수 존재
echo ""
echo "[3] TTSLabView tuningPitch/tuningRate/tuningSpeed 상태 변수 확인"
if grep -q "tuningPitch" "$MYTEAM/TTSLabView.swift" 2>/dev/null && \
   grep -q "tuningRate"  "$MYTEAM/TTSLabView.swift" 2>/dev/null && \
   grep -q "tuningSpeed" "$MYTEAM/TTSLabView.swift" 2>/dev/null; then
  pass "TTSLabView tuningPitch/tuningRate/tuningSpeed 존재"
else
  fail "TTSLabView에 튜닝 상태 변수 누락"
fi

# 4. TTSLabView에 useTuningOverride 상태 변수 존재
echo ""
echo "[4] TTSLabView useTuningOverride 확인"
if grep -q "useTuningOverride" "$MYTEAM/TTSLabView.swift" 2>/dev/null; then
  pass "TTSLabView useTuningOverride 존재"
else
  fail "TTSLabView useTuningOverride 없음"
fi

# 5. TTSLabView에 "임시 P/R/S 튜닝" 섹션 존재
echo ""
echo "[5] TTSLabView '임시 P/R/S 튜닝' 섹션 확인"
if grep -q "임시 P/R/S 튜닝" "$MYTEAM/TTSLabView.swift" 2>/dev/null; then
  pass "TTSLabView에 '임시 P/R/S 튜닝' 섹션 존재"
else
  fail "TTSLabView에 '임시 P/R/S 튜닝' 섹션 없음"
fi

# 6. TTSLabView pitch ±100 초과 경고 표시
echo ""
echo "[6] TTSLabView pitch 경고 표시 확인"
if grep -q "pitchArtifactThreshold\|Pitch.*100.*비프음\|비프음.*100\|Pitch ±100" "$MYTEAM/TTSLabView.swift" 2>/dev/null; then
  pass "TTSLabView에 pitch artifact 경고 존재"
else
  fail "TTSLabView에 pitch artifact 경고 없음"
fi

# 7. SpeechManager에 previewWithTuning 함수 존재
echo ""
echo "[7] SpeechManager.previewWithTuning 존재 확인"
if grep -q "func previewWithTuning" "$MYTEAM/SpeechManager.swift" 2>/dev/null; then
  pass "SpeechManager.previewWithTuning 존재"
else
  fail "SpeechManager.previewWithTuning 없음"
fi

# 8. previewWithTuning이 speed를 Supertonic3ONNXRunner에 전달
echo ""
echo "[8] previewWithTuning → synthesize(speed:) 전달 확인"
if grep -A 20 "func previewWithTuning" "$MYTEAM/SpeechManager.swift" 2>/dev/null | grep -q "speed: speed"; then
  pass "previewWithTuning에서 speed를 synthesize에 전달"
else
  fail "previewWithTuning에서 speed 전달 없음"
fi

# 9. previewWithTuning이 pitch/rate를 playFloatSamples에 전달
echo ""
echo "[9] previewWithTuning → playFloatSamples(pitch:rate:) 전달 확인"
if grep -A 30 "func previewWithTuning" "$MYTEAM/SpeechManager.swift" 2>/dev/null | grep -q "pitch: pitch" && \
   grep -A 30 "func previewWithTuning" "$MYTEAM/SpeechManager.swift" 2>/dev/null | grep -q "rate: rate"; then
  pass "previewWithTuning에서 pitch/rate를 playFloatSamples에 전달"
else
  fail "previewWithTuning에서 pitch/rate 전달 누락"
fi

# 10. TTSLabView 원본 preset 테스트에서 previewWithTuning 사용 가능
echo ""
echo "[10] TTSLabView 원본 preset 테스트 → previewWithTuning 분기 확인"
if grep -q "previewWithTuning" "$MYTEAM/TTSLabView.swift" 2>/dev/null; then
  pass "TTSLabView에서 previewWithTuning 호출"
else
  fail "TTSLabView에서 previewWithTuning 호출 없음"
fi

# 11. TTSLabView 캐릭터 테스트에서 tuning 분기 존재
echo ""
echo "[11] TTSLabView 캐릭터 테스트 → useTuningOverride 분기 확인"
if grep -c "useTuningOverride" "$MYTEAM/TTSLabView.swift" 2>/dev/null | grep -qv "^0$"; then
  pass "TTSLabView에 useTuningOverride 분기 존재 (다중)"
else
  fail "TTSLabView에 useTuningOverride 분기 없음"
fi

# 12. TTSLabView 감정 테스트에서 tuning 분기 존재
echo ""
echo "[12] TTSLabView 감정 표현 테스트 → tuning override 분기 확인"
# emotionPreviewSection computed property 안에서 previewWithTuning 호출 확인
if grep -A 80 "emotionPreviewSection: some View" "$MYTEAM/TTSLabView.swift" 2>/dev/null | grep -q "previewWithTuning"; then
  pass "감정 표현 테스트에서 previewWithTuning 호출 분기 존재"
else
  fail "감정 표현 테스트에서 previewWithTuning 분기 없음"
fi

# 13. CharacterVoiceProfile 치코/핀/몽몽 basePitch <= 100
echo ""
echo "[13] 치코/핀/몽몽 basePitch <= 100 확인 (artifact 감소)"
PITCH_OK=1
for NAME in "chiko_f2" "pin_f4" "mongmong_f3b"; do
  # Extract basePitch value for each profile
  PITCH_VAL=$(grep -A 8 "\"$NAME\"" "$MYTEAM/CharacterVoiceProfile.swift" 2>/dev/null | grep "basePitch:" | grep -oE '[-]?[0-9]+' | head -1)
  if [ -n "$PITCH_VAL" ]; then
    ABS_PITCH=${PITCH_VAL#-}
    if [ "$ABS_PITCH" -gt 100 ] 2>/dev/null; then
      PITCH_OK=0
      echo "    ⚠️  $NAME basePitch=$PITCH_VAL > 100"
    fi
  fi
done
if [ "$PITCH_OK" -eq 1 ]; then
  pass "치코/핀/몽몽 basePitch 모두 ±100 이하"
else
  fail "일부 캐릭터 basePitch > 100 — 재조정 필요"
fi

# 14. 모코/올리버 basePitch 안정 범위 확인 (±60 이하)
echo ""
echo "[14] 모코/올리버 basePitch 안정 범위 (±60 이하) 확인"
STABLE_OK=1
for NAME in "moco_f3" "oliver_m5"; do
  PITCH_VAL=$(grep -A 8 "\"$NAME\"" "$MYTEAM/CharacterVoiceProfile.swift" 2>/dev/null | grep "basePitch:" | grep -oE '[-]?[0-9]+' | head -1)
  if [ -n "$PITCH_VAL" ]; then
    ABS_PITCH=${PITCH_VAL#-}
    if [ "$ABS_PITCH" -gt 60 ] 2>/dev/null; then
      STABLE_OK=0
      echo "    ⚠️  $NAME basePitch=$PITCH_VAL > 60"
    fi
  fi
done
if [ "$STABLE_OK" -eq 1 ]; then
  pass "모코/올리버 basePitch ±60 이하 (안정 범위)"
else
  fail "모코/올리버 basePitch 범위 초과"
fi

# 15. SupertonicVoicePresetPolicy.animalCrossingTuning 존재
echo ""
echo "[15] SupertonicVoicePresetPolicy.animalCrossingTuning 존재 확인"
if grep -q "func animalCrossingTuning" "$MYTEAM/SupertonicVoicePresetPolicy.swift" 2>/dev/null; then
  pass "animalCrossingTuning(for:) 존재"
else
  fail "animalCrossingTuning(for:) 없음"
fi

# 16. Animal Crossing이 단순 animalCrossingBoost 누적 방식이 아님
echo ""
echo "[16] Animal Crossing — boost 누적 방식 아닌 별도 target 방식 확인"
# The animalCrossing case should call animalCrossingTuning, not use animalCrossingPitchBoost
if grep -A 5 "case .animalCrossing" "$MYTEAM/SupertonicVoicePresetPolicy.swift" 2>/dev/null | grep -q "animalCrossingTuning"; then
  pass "Animal Crossing이 animalCrossingTuning() 별도 target 사용"
else
  fail "Animal Crossing이 여전히 boost 누적 방식"
fi

# 17. 치코 role "UX 디자이너 & 온보딩 도우미" 유지
echo ""
echo "[17] 치코 role 'UX 디자이너 & 온보딩 도우미' 유지 확인"
if grep -q "UX 디자이너 & 온보딩 도우미" "$MYTEAM/AgentWindowManager.swift" 2>/dev/null; then
  pass "치코 role 'UX 디자이너 & 온보딩 도우미' 유지"
else
  fail "치코 role 변경됨 — 수정 금지"
fi

# 18. fallbackTTSAvailable = false
echo ""
echo "[18] fallbackTTSAvailable = false 확인"
if grep -q "fallbackTTSAvailable.*=.*false" "$MYTEAM/TTSProductPolicy.swift" 2>/dev/null; then
  pass "fallbackTTSAvailable = false"
else
  fail "fallbackTTSAvailable가 false가 아님"
fi

# 19. autoSpeakDefaultEnabled = false
echo ""
echo "[19] autoSpeakDefaultEnabled = false 확인"
if grep -q "autoSpeakDefaultEnabled.*=.*false" "$MYTEAM/TTSProductPolicy.swift" 2>/dev/null; then
  pass "autoSpeakDefaultEnabled = false"
else
  fail "autoSpeakDefaultEnabled가 false가 아님"
fi

# 20. no AVSpeechSynthesizer
echo ""
echo "[20] AVSpeechSynthesizer 실제 사용 없음 확인"
APPLE_TTS=$(grep -rn "AVSpeechSynthesizer" "$MYTEAM/" --include="*.swift" 2>/dev/null \
  | grep -v '//.*AVSpeechSynthesizer' \
  | grep -v '".*AVSpeechSynthesizer' \
  | wc -l | tr -d ' ')
if [ "$APPLE_TTS" -eq 0 ]; then
  pass "AVSpeechSynthesizer 실제 사용 없음"
else
  fail "AVSpeechSynthesizer 실제 사용 $APPLE_TTS건 — Apple TTS 절대 금지"
fi

# 21. no tracked .onnx
echo ""
echo "[21] tracked .onnx 파일 없음 확인"
ONNX_TRACKED=$(git -C "$REPO_ROOT" ls-files "*.onnx" 2>/dev/null | wc -l | tr -d ' ')
if [ "$ONNX_TRACKED" -eq 0 ]; then
  pass ".onnx 파일 git 추적 없음"
else
  fail ".onnx 파일 $ONNX_TRACKED건 git 추적 중 — 금지"
fi

# 22. 이전 preflight (258TTS/258B) 여전히 통과
echo ""
echo "[22] preflight_round258tts_character_voice_system.sh 통과 확인"
if bash "$SCRIPTS/preflight_round258tts_character_voice_system.sh" > /dev/null 2>&1; then
  pass "preflight_round258tts_character_voice_system.sh 38/38 PASS"
else
  fail "preflight_round258tts_character_voice_system.sh 실패 — 회귀"
fi

echo ""
echo "=================================================="
echo " 결과: PASS=$PASS / FAIL=$FAIL / TOTAL=$TOTAL"
if [ "$FAIL" -eq 0 ]; then
  echo " 🎉 ALL PASS — Round 259TTS-VOICE-TUNER preflight 통과"
else
  echo " ⚠️  FAIL $FAIL건 — 수정 후 재실행 필요"
fi
echo "=================================================="

[ "$FAIL" -eq 0 ]
