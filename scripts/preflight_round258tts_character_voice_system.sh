#!/usr/bin/env bash
# preflight_round258tts_character_voice_system.sh
# Round 258TTS-CHARACTER-VOICE-SYSTEM + Round 258B-TTS-EMOTION-AUDIT:
#   캐릭터 보이스 아이덴티티 + 감정 운율 + 팀원 교체 버그 수정 + 감정 표현 감사 검증
# 검사 38개 — 예상: 38/38 PASS
set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MYTEAM="$REPO_ROOT/MyTeam"
SCRIPTS="$REPO_ROOT/scripts"

PASS=0
FAIL=0
TOTAL=38

pass() { PASS=$((PASS + 1)); echo "  ✅ PASS [$PASS/$TOTAL] $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ❌ FAIL [$FAIL/$TOTAL] $1"; }

echo "=================================================="
echo " Round 258TTS-CHARACTER-VOICE-SYSTEM + 258B-TTS-EMOTION-AUDIT Preflight"
echo " $(date)"
echo "=================================================="

# 1. CharacterVoiceProfile.swift 존재
echo ""
echo "[1] CharacterVoiceProfile.swift 존재 확인"
if [ -f "$MYTEAM/CharacterVoiceProfile.swift" ]; then
  pass "CharacterVoiceProfile.swift 존재"
else
  fail "CharacterVoiceProfile.swift 없음"
fi

# 2. CharacterVoiceProfileCatalog에 11개 profiles 정의
echo ""
echo "[2] CharacterVoiceProfileCatalog 11개 profiles 확인"
PROFILE_COUNT=$(grep -c "CharacterVoiceProfile(" "$MYTEAM/CharacterVoiceProfile.swift" 2>/dev/null || echo 0)
if [ "$PROFILE_COUNT" -ge 11 ]; then
  pass "CharacterVoiceProfileCatalog에 $PROFILE_COUNT개 profiles 정의"
else
  fail "CharacterVoiceProfileCatalog에 $PROFILE_COUNT개 profiles — 11개 필요"
fi

# 3. M1~M5/F1~F5 preset 커버리지 확인
echo ""
echo "[3] M1~M5/F1~F5 preset 커버리지 확인"
PRESET_FAIL=0
for P in M1 M2 M3 M4 M5 F1 F2 F3 F4 F5; do
  if ! grep -q "\"$P\"" "$MYTEAM/CharacterVoiceProfile.swift" 2>/dev/null; then
    PRESET_FAIL=$((PRESET_FAIL + 1))
    echo "    ⚠️  preset $P 없음"
  fi
done
if [ "$PRESET_FAIL" -eq 0 ]; then
  pass "M1~M5/F1~F5 preset 모두 커버"
else
  fail "누락 preset: $PRESET_FAIL개"
fi

# 4. SupertonicVoicePresetPolicy.pitch(for:) 존재
echo ""
echo "[4] SupertonicVoicePresetPolicy.pitch(for:) 존재 확인"
if grep -q "static func pitch" "$MYTEAM/SupertonicVoicePresetPolicy.swift" 2>/dev/null; then
  pass "SupertonicVoicePresetPolicy.pitch(for:) 존재"
else
  fail "SupertonicVoicePresetPolicy.pitch(for:) 없음"
fi

# 5. SupertonicVoicePresetPolicy.rate(for:) 존재
echo ""
echo "[5] SupertonicVoicePresetPolicy.rate(for:) 존재 확인"
if grep -q "static func rate" "$MYTEAM/SupertonicVoicePresetPolicy.swift" 2>/dev/null; then
  pass "SupertonicVoicePresetPolicy.rate(for:) 존재"
else
  fail "SupertonicVoicePresetPolicy.rate(for:) 없음"
fi

# 6. AudioPlaybackService.playFloatSamples pitch/rate 파라미터 존재
echo ""
echo "[6] AudioPlaybackService.playFloatSamples pitch/rate 파라미터 확인"
if grep -q "pitch: Float" "$MYTEAM/AudioPlaybackService.swift" 2>/dev/null && \
   grep -q "rate: Float" "$MYTEAM/AudioPlaybackService.swift" 2>/dev/null; then
  pass "playFloatSamples pitch/rate 파라미터 존재"
else
  fail "playFloatSamples pitch 또는 rate 파라미터 없음"
fi

# 7. SpeechManager이 pitch/rate를 playFloatSamples에 전달
echo ""
echo "[7] SpeechManager → playFloatSamples pitch/rate 전달 확인"
PITCH_PASS=$(grep -c "pitch: pitch" "$MYTEAM/SpeechManager.swift" 2>/dev/null || echo 0)
RATE_PASS=$(grep -c "rate: rate" "$MYTEAM/SpeechManager.swift" 2>/dev/null || echo 0)
if [ "$PITCH_PASS" -ge 1 ] && [ "$RATE_PASS" -ge 1 ]; then
  pass "SpeechManager이 pitch/rate를 playFloatSamples에 전달"
else
  fail "SpeechManager: pitch=$PITCH_PASS건, rate=$RATE_PASS건 전달 — 둘 다 필요"
fi

# 8. SupertonicProsodyTextProcessor.swift 존재
echo ""
echo "[8] SupertonicProsodyTextProcessor.swift 존재 확인"
if [ -f "$MYTEAM/SupertonicProsodyTextProcessor.swift" ]; then
  pass "SupertonicProsodyTextProcessor.swift 존재"
else
  fail "SupertonicProsodyTextProcessor.swift 없음"
fi

# 9. SpeechManager에서 SupertonicProsodyTextProcessor.preprocess 호출
echo ""
echo "[9] SpeechManager → SupertonicProsodyTextProcessor.preprocess 호출 확인"
PREPROCESS_COUNT=$(grep -c "SupertonicProsodyTextProcessor.preprocess" "$MYTEAM/SpeechManager.swift" 2>/dev/null || echo 0)
if [ "$PREPROCESS_COUNT" -ge 2 ]; then
  pass "SpeechManager에서 SupertonicProsodyTextProcessor.preprocess $PREPROCESS_COUNT건 호출"
else
  fail "SpeechManager에 SupertonicProsodyTextProcessor.preprocess $PREPROCESS_COUNT건 — 2건 이상 필요 (dispatch + speakOnce)"
fi

# 10. TTSLabView에 캐릭터 목소리 매핑 섹션 존재
echo ""
echo "[10] TTSLabView 캐릭터 목소리 매핑 섹션 존재 확인"
if grep -q "캐릭터 목소리 매핑" "$MYTEAM/TTSLabView.swift" 2>/dev/null; then
  pass "TTSLabView 캐릭터 목소리 매핑 섹션 존재"
else
  fail "TTSLabView에 캐릭터 목소리 매핑 섹션 없음"
fi

# 11. TTSLabView에 샘플 말하기 액션 존재 (speakOnce 호출)
echo ""
echo "[11] TTSLabView 샘플 말하기 액션(speakOnce) 확인"
if grep -q "speakOnce\|speakVoiceDirectorSample" "$MYTEAM/TTSLabView.swift" 2>/dev/null; then
  pass "TTSLabView에 speakOnce/speakVoiceDirectorSample 호출 존재"
else
  fail "TTSLabView에 speakOnce 샘플 말하기 없음"
fi

# 12. AgentWindowManager.replaceTeamAgent(at:with:) 존재
echo ""
echo "[12] AgentWindowManager.replaceTeamAgent(at:with:) 존재 확인"
if grep -q "func replaceTeamAgent" "$MYTEAM/AgentWindowManager.swift" 2>/dev/null; then
  pass "replaceTeamAgent(at:with:) 존재"
else
  fail "AgentWindowManager에 replaceTeamAgent 없음"
fi

# 13. replaceTeamAgent 내부에 swapAgent 호출 존재
echo ""
echo "[13] replaceTeamAgent → swapAgent 호출 확인"
# Extract replaceTeamAgent function body and check for swapAgent call
if grep -A 10 "func replaceTeamAgent" "$MYTEAM/AgentWindowManager.swift" 2>/dev/null | grep -q "swapAgent"; then
  pass "replaceTeamAgent 내부에 swapAgent 호출 존재"
else
  fail "replaceTeamAgent에 swapAgent 호출 없음"
fi

# 14. TeamTableView에 슬롯 서브메뉴 존재
echo ""
echo "[14] TeamTableView 슬롯 서브메뉴 확인"
if grep -q "showSwapWindow(replaceIndex:" "$MYTEAM/TeamTableView.swift" 2>/dev/null; then
  pass "TeamTableView에 슬롯 인덱스 전달 showSwapWindow(replaceIndex:) 존재"
else
  fail "TeamTableView에 showSwapWindow(replaceIndex:) 없음"
fi

# 15. showSwapWindow() 인덱스 미전달 단독 호출 없음
echo ""
echo "[15] showSwapWindow() 인덱스 미전달 단독 호출 없음 확인"
# showSwapWindow() without replaceIndex: should not exist
BARE_SWAP=$(grep -n "showSwapWindow()" "$MYTEAM/TeamTableView.swift" 2>/dev/null | wc -l | tr -d ' ')
if [ "$BARE_SWAP" -eq 0 ]; then
  pass "showSwapWindow() 단독 호출 없음 — 슬롯 0 고정 버그 수정됨"
else
  fail "TeamTableView에 showSwapWindow() 단독 호출 $BARE_SWAP건 — 버그 미수정"
fi

# 16. openPersonalChat이 activeAgents를 수정하지 않음 (안전성 확인)
echo ""
echo "[16] openPersonalChat activeAgents 수정 없음 확인"
PERSONAL_CHAT_MODIFY=0
if grep -A 20 "func openPersonalChat" "$MYTEAM/AgentWindowManager.swift" 2>/dev/null | grep -q "activeAgents\["; then
  PERSONAL_CHAT_MODIFY=1
fi
if [ "$PERSONAL_CHAT_MODIFY" -eq 0 ]; then
  pass "openPersonalChat이 activeAgents 슬롯을 직접 수정하지 않음"
else
  fail "openPersonalChat이 activeAgents를 수정함 — 의도치 않은 슬롯 변경 가능"
fi

# 17. AgentQuickSwitchBar가 activeAgents를 수정하지 않음
echo ""
echo "[17] AgentQuickSwitchBar activeAgents 직접 수정 없음 확인"
if [ -f "$MYTEAM/AgentQuickSwitchBar.swift" ]; then
  QUICK_MODIFY=0
  if grep -q "activeAgents\[" "$MYTEAM/AgentQuickSwitchBar.swift" 2>/dev/null; then
    QUICK_MODIFY=1
  fi
  if [ "$QUICK_MODIFY" -eq 0 ]; then
    pass "AgentQuickSwitchBar가 activeAgents를 직접 수정하지 않음"
  else
    fail "AgentQuickSwitchBar가 activeAgents를 직접 수정 — 슬롯 안전성 확인 필요"
  fi
else
  pass "AgentQuickSwitchBar.swift 없음 — 스킵"
fi

# 18. 치코 역할 "UX 디자이너" 포함 확인 (Round 258TTS: 역할 변경)
echo ""
echo "[18] 치코 역할 'UX 디자이너' 포함 확인"
if grep -q "UX 디자이너" "$MYTEAM/AgentWindowManager.swift" 2>/dev/null; then
  pass "치코 role에 'UX 디자이너' 포함"
else
  fail "치코 role에 'UX 디자이너' 없음 — 역할 변경 미적용"
fi

# 19. no AVSpeechSynthesizer
echo ""
echo "[19] AVSpeechSynthesizer 실제 사용 없음 확인"
APPLE_TTS=$(grep -rn "AVSpeechSynthesizer" "$MYTEAM/" --include="*.swift" 2>/dev/null \
  | grep -v '//.*AVSpeechSynthesizer' \
  | grep -v '".*AVSpeechSynthesizer' \
  | wc -l | tr -d ' ')
if [ "$APPLE_TTS" -eq 0 ]; then
  pass "AVSpeechSynthesizer 실제 사용 없음"
else
  fail "AVSpeechSynthesizer 실제 사용 $APPLE_TTS건 — Apple TTS 절대 금지"
fi

# 20. fallbackTTSAvailable = false
echo ""
echo "[20] fallbackTTSAvailable = false 확인"
if grep -q "fallbackTTSAvailable.*=.*false" "$MYTEAM/TTSProductPolicy.swift" 2>/dev/null; then
  pass "fallbackTTSAvailable = false"
else
  fail "fallbackTTSAvailable가 false가 아님"
fi

# 21. autoSpeakDefaultEnabled = false
echo ""
echo "[21] autoSpeakDefaultEnabled = false 확인"
if grep -q "autoSpeakDefaultEnabled.*=.*false" "$MYTEAM/TTSProductPolicy.swift" 2>/dev/null; then
  pass "autoSpeakDefaultEnabled = false"
else
  fail "autoSpeakDefaultEnabled가 false가 아님"
fi

# 22. no tracked .onnx files
echo ""
echo "[22] tracked .onnx 파일 없음 확인"
ONNX_TRACKED=$(git -C "$REPO_ROOT" ls-files "*.onnx" 2>/dev/null | wc -l | tr -d ' ')
if [ "$ONNX_TRACKED" -eq 0 ]; then
  pass ".onnx 파일 git 추적 없음"
else
  fail ".onnx 파일 $ONNX_TRACKED건 git 추적 중 — ONNX 파일 commit 금지"
fi

# ============================================================
# Round 258B-TTS-EMOTION-AUDIT: 감정 표현 감사 추가 검사 (23~38)
# ============================================================

# 23. 치코 status "UX와 온보딩을 도와주는 중" 확인
echo ""
echo "[23] 치코 status 'UX와 온보딩을 도와주는 중' 확인"
if grep -q "UX와 온보딩을 도와주는 중" "$MYTEAM/AgentWindowManager.swift" 2>/dev/null; then
  pass "치코 status 'UX와 온보딩을 도와주는 중' 존재"
else
  fail "치코 status 'UX와 온보딩을 도와주는 중' 없음"
fi

# 24. SupertonicVoicePresetPolicy.emotionStyle(for:) 존재
echo ""
echo "[24] SupertonicVoicePresetPolicy.emotionStyle(for:) 존재 확인"
if grep -q "static func emotionStyle" "$MYTEAM/SupertonicVoicePresetPolicy.swift" 2>/dev/null; then
  pass "emotionStyle(for:) 존재"
else
  fail "emotionStyle(for:) 없음"
fi

# 25. pitch(for:emotion:) emotion-aware API 존재
echo ""
echo "[25] pitch(for:emotion:) emotion-aware API 존재 확인"
if grep -q "func pitch.*emotion.*SupertonicEmotionStyle" "$MYTEAM/SupertonicVoicePresetPolicy.swift" 2>/dev/null; then
  pass "pitch(for:emotion:) emotion-aware API 존재"
else
  fail "pitch(for:emotion:) emotion-aware API 없음"
fi

# 26. rate(for:emotion:) emotion-aware API 존재
echo ""
echo "[26] rate(for:emotion:) emotion-aware API 존재 확인"
if grep -q "func rate.*emotion.*SupertonicEmotionStyle" "$MYTEAM/SupertonicVoicePresetPolicy.swift" 2>/dev/null; then
  pass "rate(for:emotion:) emotion-aware API 존재"
else
  fail "rate(for:emotion:) emotion-aware API 없음"
fi

# 27. speed(for:emotion:) emotion-aware API 존재
echo ""
echo "[27] speed(for:emotion:) emotion-aware API 존재 확인"
if grep -q "func speed.*emotion.*SupertonicEmotionStyle" "$MYTEAM/SupertonicVoicePresetPolicy.swift" 2>/dev/null; then
  pass "speed(for:emotion:) emotion-aware API 존재"
else
  fail "speed(for:emotion:) emotion-aware API 없음"
fi

# 28. SpeechManager에서 emotionStyle(for:) 호출
echo ""
echo "[28] SpeechManager → emotionStyle(for:) 호출 확인"
if grep -q "emotionStyle(for:" "$MYTEAM/SpeechManager.swift" 2>/dev/null; then
  pass "SpeechManager에서 emotionStyle(for:) 호출"
else
  fail "SpeechManager에서 emotionStyle(for:) 호출 없음"
fi

# 29. SpeechManager에 previewPreset 함수 존재
echo ""
echo "[29] SpeechManager.previewPreset 함수 존재 확인"
if grep -q "func previewPreset" "$MYTEAM/SpeechManager.swift" 2>/dev/null; then
  pass "SpeechManager.previewPreset 존재"
else
  fail "SpeechManager.previewPreset 없음"
fi

# 30. previewPreset이 pitch=0, rate=1 사용 확인
echo ""
echo "[30] previewPreset pitch=0, rate=1 사용 확인"
PRESET_PITCH0=0
PRESET_RATE1=0
if grep -A 30 "func previewPreset" "$MYTEAM/SpeechManager.swift" 2>/dev/null | grep -q "pitch:.*0"; then
  PRESET_PITCH0=1
fi
if grep -A 30 "func previewPreset" "$MYTEAM/SpeechManager.swift" 2>/dev/null | grep -q "rate:.*1"; then
  PRESET_RATE1=1
fi
if [ "$PRESET_PITCH0" -eq 1 ] && [ "$PRESET_RATE1" -eq 1 ]; then
  pass "previewPreset pitch=0, rate=1 확인"
else
  fail "previewPreset pitch=0($PRESET_PITCH0) 또는 rate=1($PRESET_RATE1) 미확인"
fi

# 31. SpeechManager에 previewCharacterEmotion 함수 존재
echo ""
echo "[31] SpeechManager.previewCharacterEmotion 함수 존재 확인"
if grep -q "func previewCharacterEmotion" "$MYTEAM/SpeechManager.swift" 2>/dev/null; then
  pass "SpeechManager.previewCharacterEmotion 존재"
else
  fail "SpeechManager.previewCharacterEmotion 없음"
fi

# 32. TTSLabView에 "원본 Preset 테스트" 섹션 존재
echo ""
echo "[32] TTSLabView '원본 Preset 테스트' 섹션 확인"
if grep -q "원본 Preset 테스트" "$MYTEAM/TTSLabView.swift" 2>/dev/null; then
  pass "TTSLabView에 '원본 Preset 테스트' 섹션 존재"
else
  fail "TTSLabView에 '원본 Preset 테스트' 섹션 없음"
fi

# 33. TTSLabView에 "감정 표현 테스트" 섹션 존재
echo ""
echo "[33] TTSLabView '감정 표현 테스트' 섹션 확인"
if grep -q "감정 표현 테스트" "$MYTEAM/TTSLabView.swift" 2>/dev/null; then
  pass "TTSLabView에 '감정 표현 테스트' 섹션 존재"
else
  fail "TTSLabView에 '감정 표현 테스트' 섹션 없음"
fi

# 34. TTSLabView에서 previewPreset 호출
echo ""
echo "[34] TTSLabView → previewPreset 호출 확인"
if grep -q "previewPreset" "$MYTEAM/TTSLabView.swift" 2>/dev/null; then
  pass "TTSLabView에서 previewPreset 호출"
else
  fail "TTSLabView에서 previewPreset 호출 없음"
fi

# 35. AgentSwapView에서 replaceTeamAgent 사용
echo ""
echo "[35] AgentSwapView → replaceTeamAgent 사용 확인"
if grep -q "replaceTeamAgent" "$MYTEAM/AgentSwapView.swift" 2>/dev/null; then
  pass "AgentSwapView에서 replaceTeamAgent 사용"
else
  fail "AgentSwapView에서 replaceTeamAgent 사용 없음"
fi

# 36. swapAgent 내부에서 syncSelectedTeamWorkroomAgents 호출
echo ""
echo "[36] swapAgent → syncSelectedTeamWorkroomAgents 호출 확인"
if grep -A 30 "func swapAgent" "$MYTEAM/AgentWindowManager.swift" 2>/dev/null | grep -q "syncSelectedTeamWorkroomAgents"; then
  pass "swapAgent에서 syncSelectedTeamWorkroomAgents 호출"
else
  fail "swapAgent에서 syncSelectedTeamWorkroomAgents 호출 없음"
fi

# 37. CharacterVoiceProfile에 emotionSpeedBoost 필드 존재
echo ""
echo "[37] CharacterVoiceProfile.emotionSpeedBoost 필드 확인"
if grep -q "emotionSpeedBoost" "$MYTEAM/CharacterVoiceProfile.swift" 2>/dev/null; then
  pass "CharacterVoiceProfile에 emotionSpeedBoost 필드 존재"
else
  fail "CharacterVoiceProfile에 emotionSpeedBoost 필드 없음"
fi

# 38. reports/round258b_tts_emotion_audit.md 존재
echo ""
echo "[38] reports/round258b_tts_emotion_audit.md 존재 확인"
if [ -f "$REPO_ROOT/reports/round258b_tts_emotion_audit.md" ]; then
  pass "reports/round258b_tts_emotion_audit.md 존재"
else
  fail "reports/round258b_tts_emotion_audit.md 없음"
fi

echo ""
echo "=================================================="
echo " 결과: PASS=$PASS / FAIL=$FAIL / TOTAL=$TOTAL"
if [ "$FAIL" -eq 0 ]; then
  echo " 🎉 ALL PASS — Round 258TTS+258B preflight 통과"
else
  echo " ⚠️  FAIL $FAIL건 — 수정 후 재실행 필요"
fi
echo "=================================================="

[ "$FAIL" -eq 0 ]
