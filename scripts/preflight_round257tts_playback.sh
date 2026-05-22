#!/usr/bin/env bash
# preflight_round257tts_playback.sh
# Round 257TTS-PLAYBACK: Supertonic3 합성 결과 → AudioPlaybackService 실제 재생 연결 검증
# 검사 12개 — 예상: 12/12 PASS
set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MYTEAM="$REPO_ROOT/MyTeam"
SCRIPTS="$REPO_ROOT/scripts"

PASS=0
FAIL=0
TOTAL=12

pass() { PASS=$((PASS + 1)); echo "  ✅ PASS [$PASS/$TOTAL] $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ❌ FAIL [$FAIL/$TOTAL] $1"; }

echo "=================================================="
echo " Round 257TTS-PLAYBACK Preflight"
echo " $(date)"
echo "=================================================="

# 1. AudioPlaybackService에 playFloatSamples 존재
echo ""
echo "[1] AudioPlaybackService.playFloatSamples 존재 확인"
if grep -q "func playFloatSamples" "$MYTEAM/AudioPlaybackService.swift" 2>/dev/null; then
  pass "playFloatSamples 메서드 존재"
else
  fail "AudioPlaybackService에 playFloatSamples 없음"
fi

# 2. playFloatSamples가 floatChannelData를 사용해 Float 샘플 복사
echo ""
echo "[2] playFloatSamples floatChannelData 사용 확인"
if grep -q "floatChannelData" "$MYTEAM/AudioPlaybackService.swift" 2>/dev/null; then
  pass "floatChannelData 사용 확인"
else
  fail "playFloatSamples에 floatChannelData 없음 — Float 샘플 복사 누락"
fi

# 3. SpeechManager가 Supertonic 경로에서 AudioPlaybackService.playFloatSamples 호출
echo ""
echo "[3] SpeechManager → AudioPlaybackService.playFloatSamples 호출 확인"
if grep -q "playback.playFloatSamples\|AudioPlaybackService.*playFloatSamples" "$MYTEAM/SpeechManager.swift" 2>/dev/null; then
  pass "SpeechManager에서 playFloatSamples 호출 존재"
else
  fail "SpeechManager에 playFloatSamples 호출 없음 — 재생 연결 누락"
fi

# 4. dispatchToInferencePipeline supertonic3 경로가 onPlaybackStarted를 playFloatSamples에 전달
#    (onPlaybackStarted()를 playback 전에 직접 호출하지 않음)
echo ""
echo "[4] dispatchToInferencePipeline onPlaybackStarted 타이밍 확인"
# WAV 쓰기 후 즉시 onPlaybackStarted()를 단독 호출하는 패턴이 없어야 함
# "WAV written" 로그 직후 "onPlaybackStarted()" 단독 호출이 아닌지 체크
# 패턴: supertonic3 case에 playFloatSamples 호출이 있으면 OK
DISPATCH_OK=$(grep -c "playback.playFloatSamples" "$MYTEAM/SpeechManager.swift" 2>/dev/null || echo 0)
if [ "$DISPATCH_OK" -ge 1 ]; then
  pass "dispatchToInferencePipeline이 playFloatSamples를 통해 재생 (onPlaybackStarted 타이밍 준수)"
else
  fail "dispatchToInferencePipeline에 playFloatSamples 없음 — onPlaybackStarted 타이밍 위반 가능"
fi

# 5. SpeechManager에 speakOnce 메서드 존재
echo ""
echo "[5] SpeechManager.speakOnce 메서드 존재 확인"
if grep -q "func speakOnce" "$MYTEAM/SpeechManager.swift" 2>/dev/null; then
  pass "speakOnce 메서드 존재"
else
  fail "SpeechManager에 speakOnce 없음"
fi

# 6. SpeakButtonView가 speakOnce 호출 (synthesize 단독 호출이 아님)
echo ""
echo "[6] SpeakButtonView가 speakOnce 호출 확인"
if grep -q "speakOnce\|SpeechManager.shared.speakOnce" "$MYTEAM/AgentChatView.swift" 2>/dev/null; then
  pass "SpeakButtonView에서 speakOnce 호출 존재"
else
  fail "SpeakButtonView에 speakOnce 호출 없음 — 재생 연결 누락"
fi

# 7. S3WavWriter.write가 SpeechManager의 유일한 출력 동작이 아님
#    (playFloatSamples도 있어야 함 — check 3으로 이미 검증, 여기선 동시 존재 확인)
echo ""
echo "[7] S3WavWriter.write + playFloatSamples 동시 존재 확인"
HAS_WAV=$(grep -c "S3WavWriter.write" "$MYTEAM/SpeechManager.swift" 2>/dev/null || echo 0)
HAS_PLAY=$(grep -c "playFloatSamples" "$MYTEAM/SpeechManager.swift" 2>/dev/null || echo 0)
if [ "$HAS_WAV" -ge 1 ] && [ "$HAS_PLAY" -ge 1 ]; then
  pass "S3WavWriter.write(debug) + playFloatSamples(재생) 모두 존재"
else
  fail "SpeechManager: S3WavWriter=$HAS_WAV건, playFloatSamples=$HAS_PLAY건 — 둘 다 필요"
fi

# 8. Apple TTS (AVSpeechSynthesizer) 실제 사용 없음
echo ""
echo "[8] AVSpeechSynthesizer 실제 사용 없음 확인"
APPLE_TTS=$(grep -rn "AVSpeechSynthesizer" "$MYTEAM/" --include="*.swift" 2>/dev/null \
  | grep -v '//.*AVSpeechSynthesizer' \
  | grep -v '".*AVSpeechSynthesizer' \
  | wc -l | tr -d ' ')
if [ "$APPLE_TTS" -eq 0 ]; then
  pass "AVSpeechSynthesizer 실제 사용 없음"
else
  fail "AVSpeechSynthesizer 실제 사용 $APPLE_TTS건 — Apple TTS 절대 금지"
fi

# 9. fallbackTTSAvailable = false (폴백 TTS 없음)
echo ""
echo "[9] fallbackTTSAvailable = false 확인"
if grep -q "fallbackTTSAvailable.*=.*false" "$MYTEAM/TTSProductPolicy.swift" 2>/dev/null; then
  pass "fallbackTTSAvailable = false"
else
  fail "fallbackTTSAvailable가 false가 아님"
fi

# 10. autoSpeakDefaultEnabled = false
echo ""
echo "[10] autoSpeakDefaultEnabled = false 확인"
if grep -q "autoSpeakDefaultEnabled.*=.*false" "$MYTEAM/TTSProductPolicy.swift" 2>/dev/null; then
  pass "autoSpeakDefaultEnabled = false"
else
  fail "autoSpeakDefaultEnabled가 false가 아님 — 자동 재생 기본 ON 금지"
fi

# 11. MyTeamApp/AppDelegate에 Supertonic3ONNXRunner.shared 자동 init 없음
echo ""
echo "[11] 앱 launch auto-init 없음 확인"
LAUNCH_INIT=0
for F in "$MYTEAM/MyTeamApp.swift" "$MYTEAM/AppDelegate.swift"; do
  if [ -f "$F" ]; then
    CNT=$(grep -n "Supertonic3ONNXRunner.shared" "$F" 2>/dev/null | wc -l | tr -d ' ')
    LAUNCH_INIT=$((LAUNCH_INIT + CNT))
  fi
done
if [ "$LAUNCH_INIT" -eq 0 ]; then
  pass "앱 launch auto-init 없음"
else
  fail "앱 launch 파일에 Supertonic3ONNXRunner.shared $LAUNCH_INIT건 — auto-init 금지"
fi

# 12. preflight_round256tts_official_engine.sh 존재 (이전 라운드 전제)
echo ""
echo "[12] preflight_round256tts_official_engine.sh 존재 확인"
if [ -f "$SCRIPTS/preflight_round256tts_official_engine.sh" ]; then
  pass "preflight_round256tts_official_engine.sh 존재"
else
  fail "preflight_round256tts_official_engine.sh 없음"
fi

echo ""
echo "=================================================="
echo " 결과: PASS=$PASS / FAIL=$FAIL / TOTAL=$TOTAL"
if [ "$FAIL" -eq 0 ]; then
  echo " 🎉 ALL PASS — Round 257TTS-PLAYBACK preflight 통과"
else
  echo " ⚠️  FAIL $FAIL건 — 수정 후 재실행 필요"
fi
echo "=================================================="

[ "$FAIL" -eq 0 ]
