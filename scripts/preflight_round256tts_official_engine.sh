#!/usr/bin/env bash
# preflight_round256tts_official_engine.sh
# Round 256TTS-OFFICIAL-ENGINE: Supertonic3 공식 엔진 승격 검증
# 검사 18개 — 예상: 18/18 PASS
set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MYTEAM="$REPO_ROOT/MyTeam"
SCRIPTS="$REPO_ROOT/scripts"

PASS=0
FAIL=0
TOTAL=18

pass() { PASS=$((PASS + 1)); echo "  ✅ PASS [$PASS/$TOTAL] $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ❌ FAIL [$FAIL/$TOTAL] $1"; }

echo "=================================================="
echo " Round 256TTS-OFFICIAL-ENGINE Preflight"
echo " $(date)"
echo "=================================================="

# 1. TTSProductPolicy.swift 존재
echo ""
echo "[1] TTSProductPolicy.swift 존재 확인"
if [ -f "$MYTEAM/TTSProductPolicy.swift" ]; then
  pass "TTSProductPolicy.swift 존재"
else
  fail "TTSProductPolicy.swift 없음"
fi

# 2. TTSProductPolicy.officialEngineEnabled = true
echo ""
echo "[2] officialEngineEnabled = true 확인"
if grep -q "officialEngineEnabled.*=.*true" "$MYTEAM/TTSProductPolicy.swift" 2>/dev/null; then
  pass "officialEngineEnabled = true"
else
  fail "officialEngineEnabled가 true가 아님"
fi

# 3. officialEngine = .supertonic3
echo ""
echo "[3] officialEngine = .supertonic3 확인"
if grep -q "officialEngine.*:.*TTSProviderKind.*=.*\.supertonic3" "$MYTEAM/TTSProductPolicy.swift" 2>/dev/null; then
  pass "officialEngine = .supertonic3"
else
  fail "officialEngine이 .supertonic3가 아님"
fi

# 4. autoSpeakDefaultEnabled = false (모든 메시지 자동 재생 기본 OFF)
echo ""
echo "[4] autoSpeakDefaultEnabled = false 확인"
if grep -q "autoSpeakDefaultEnabled.*=.*false" "$MYTEAM/TTSProductPolicy.swift" 2>/dev/null; then
  pass "autoSpeakDefaultEnabled = false"
else
  fail "autoSpeakDefaultEnabled가 false가 아님 — 자동 재생 기본 ON 금지"
fi

# 5. fallbackTTSAvailable = false
echo ""
echo "[5] fallbackTTSAvailable = false 확인"
if grep -q "fallbackTTSAvailable.*=.*false" "$MYTEAM/TTSProductPolicy.swift" 2>/dev/null; then
  pass "fallbackTTSAvailable = false"
else
  fail "fallbackTTSAvailable가 false가 아님 — 폴백 TTS 금지"
fi

# 6. SupertonicVoicePresetPolicy.swift 존재
echo ""
echo "[6] SupertonicVoicePresetPolicy.swift 존재 확인"
if [ -f "$MYTEAM/SupertonicVoicePresetPolicy.swift" ]; then
  pass "SupertonicVoicePresetPolicy.swift 존재"
else
  fail "SupertonicVoicePresetPolicy.swift 없음"
fi

# 7. 11개 에이전트 ID → 프리셋 매핑 존재 (agent_1 ~ agent_11)
echo ""
echo "[7] agent_1 ~ agent_11 매핑 확인"
AGENT_COUNT=$(grep -c '"agent_[0-9]' "$MYTEAM/SupertonicVoicePresetPolicy.swift" 2>/dev/null || echo 0)
if [ "$AGENT_COUNT" -ge 11 ]; then
  pass "11개 에이전트 매핑 존재 ($AGENT_COUNT개 확인)"
else
  fail "에이전트 매핑 부족 — 최소 11개 필요, 현재 $AGENT_COUNT개"
fi

# 8. SpeechManager.swift에 Supertonic3ONNXRunner.shared.synthesize 호출 존재
echo ""
echo "[8] SpeechManager에 Supertonic3ONNXRunner.shared.synthesize 호출 확인"
if grep -q "Supertonic3ONNXRunner.shared.synthesize" "$MYTEAM/SpeechManager.swift" 2>/dev/null; then
  pass "Supertonic3ONNXRunner.shared.synthesize 호출 존재"
else
  fail "SpeechManager에 Supertonic3ONNXRunner.shared.synthesize 호출 없음"
fi

# 9. SpeechManager.synthesize(text:agentID:) public API 존재
echo ""
echo "[9] SpeechManager.synthesize(text:agentID:) 공개 API 확인"
if grep -q "func synthesize(text:.*agentID:" "$MYTEAM/SpeechManager.swift" 2>/dev/null; then
  pass "SpeechManager.synthesize(text:agentID:) 존재"
else
  fail "SpeechManager.synthesize(text:agentID:) 없음"
fi

# 10. AgentChatView에 SpeakButtonView 존재 (말하기 버튼)
echo ""
echo "[10] AgentChatView에 SpeakButtonView 존재 확인"
if grep -q "SpeakButtonView" "$MYTEAM/AgentChatView.swift" 2>/dev/null; then
  pass "SpeakButtonView 존재"
else
  fail "AgentChatView에 SpeakButtonView 없음"
fi

# 11. Apple TTS (AVSpeechSynthesizer) 실제 사용 코드 없음
# 에러 메시지 문자열("...")에 포함된 것은 제외하고, 실제 import/class/let/var 사용만 검사
echo ""
echo "[11] AVSpeechSynthesizer 실제 사용 코드 없음 확인"
APPLE_TTS_COUNT=$(grep -rn "AVSpeechSynthesizer" "$MYTEAM/" --include="*.swift" 2>/dev/null \
  | grep -v '//.*AVSpeechSynthesizer' \
  | grep -v '".*AVSpeechSynthesizer' \
  | wc -l | tr -d ' ')
if [ "$APPLE_TTS_COUNT" -eq 0 ]; then
  pass "AVSpeechSynthesizer 실제 사용 없음"
else
  fail "AVSpeechSynthesizer 실제 사용 코드 $APPLE_TTS_COUNT건 — Apple TTS 절대 금지"
  grep -rn "AVSpeechSynthesizer" "$MYTEAM/" --include="*.swift" | grep -v '^\s*//' | grep -v '".*AVSpeechSynthesizer.*"'
fi

# 12. 앱 launch 자동 init 없음 (MyTeamApp, AppDelegate에서 ONNXRunner.shared 직접 호출 없음)
echo ""
echo "[12] 앱 launch 자동 init 없음 확인"
LAUNCH_INIT_COUNT=0
for LAUNCH_FILE in "$MYTEAM/MyTeamApp.swift" "$MYTEAM/AppDelegate.swift"; do
  if [ -f "$LAUNCH_FILE" ]; then
    CNT=$(grep -n "Supertonic3ONNXRunner.shared" "$LAUNCH_FILE" 2>/dev/null | wc -l | tr -d ' ')
    LAUNCH_INIT_COUNT=$((LAUNCH_INIT_COUNT + CNT))
  fi
done
if [ "$LAUNCH_INIT_COUNT" -eq 0 ]; then
  pass "앱 launch 자동 init 없음"
else
  fail "앱 launch 파일에 Supertonic3ONNXRunner.shared 참조 $LAUNCH_INIT_COUNT건 — auto-init 금지"
fi

# 13. ONNX 모델 파일 git-tracked 없음
echo ""
echo "[13] ONNX 모델 파일 git tracked 없음 확인"
TRACKED_ONNX=$(git -C "$REPO_ROOT" ls-files --error-unmatch "*.onnx" 2>/dev/null | wc -l | tr -d ' ')
if [ "$TRACKED_ONNX" -eq 0 ]; then
  pass "git-tracked .onnx 파일 없음"
else
  fail "git-tracked .onnx 파일 $TRACKED_ONNX개 발견 — ONNX 모델 커밋 금지"
fi

# 14. TTSRoutingPolicy에 isSupertonic3Available 존재
echo ""
echo "[14] TTSRoutingPolicy.isSupertonic3Available 존재 확인"
if grep -q "isSupertonic3Available" "$MYTEAM/TTSRoutingPolicy.swift" 2>/dev/null; then
  pass "TTSRoutingPolicy.isSupertonic3Available 존재"
else
  fail "TTSRoutingPolicy.isSupertonic3Available 없음"
fi

# 15. ToolContractValidator에 Round 256TTS validators 존재
echo ""
echo "[15] ToolContractValidator에 256TTS validators 존재 확인"
V256_COUNT=$(grep -c "validateSupertonicOfficialEnginePolicy\|validateNoFallbackTTSAfterOfficialEngine\|validateNoAutoSpeakDefaultPolicy\|validateSupertonicCharacterVoicePresetPolicy\|validateNoAppleTTSAfterOfficialEngine\|validateNoLaunchAutoInitAfterOfficialEngine" "$MYTEAM/ToolContractValidator.swift" 2>/dev/null || echo 0)
if [ "$V256_COUNT" -ge 12 ]; then
  pass "ToolContractValidator 256TTS validators 존재 ($V256_COUNT개 참조)"
else
  fail "256TTS validators 부족 — 호출부+구현부 최소 12개 필요, 현재 $V256_COUNT개"
fi

# 16. RuntimeDiagnosticsSnapshot에 256TTS 필드 존재
echo ""
echo "[16] RuntimeDiagnosticsSnapshot 256TTS 필드 확인"
DIAG_COUNT=$(grep -c "ttsOfficialEngine\|ttsAutoSpeakDefault\|ttsFallbackAvailableAfterOfficial\|supertonicKoreanQuality\|supertonicLocalRuntime\|supertonicReleaseIntegration\|supertonicBundlePolicy" "$MYTEAM/RuntimeDiagnosticsService.swift" 2>/dev/null || echo 0)
if [ "$DIAG_COUNT" -ge 7 ]; then
  pass "RuntimeDiagnosticsSnapshot 256TTS 필드 존재 ($DIAG_COUNT개)"
else
  fail "RuntimeDiagnosticsSnapshot 256TTS 필드 부족 — 최소 7개 필요, 현재 $DIAG_COUNT개"
fi

# 17. TTSLabView에 officialEngineStatusSection 존재
echo ""
echo "[17] TTSLabView officialEngineStatusSection 확인"
if grep -q "officialEngineStatusSection\|Official Engine\|officialEngine" "$MYTEAM/TTSLabView.swift" 2>/dev/null; then
  pass "TTSLabView에 공식 엔진 상태 섹션 존재"
else
  fail "TTSLabView에 공식 엔진 상태 섹션 없음"
fi

# 18. 이전 preflight 통과 전제 (preflight_round254tts_probe_fix.sh가 존재)
echo ""
echo "[18] 이전 라운드 preflight 파일 존재 확인 (round254tts_probe_fix)"
if [ -f "$SCRIPTS/preflight_round254tts_probe_fix.sh" ]; then
  pass "preflight_round254tts_probe_fix.sh 존재 (이전 라운드 전제 확인)"
else
  fail "preflight_round254tts_probe_fix.sh 없음 — 이전 라운드 preflight 누락"
fi

echo ""
echo "=================================================="
echo " 결과: PASS=$PASS / FAIL=$FAIL / TOTAL=$TOTAL"
if [ "$FAIL" -eq 0 ]; then
  echo " 🎉 ALL PASS — Round 256TTS-OFFICIAL-ENGINE preflight 통과"
else
  echo " ⚠️  FAIL $FAIL건 — 수정 후 재실행 필요"
fi
echo "=================================================="

[ "$FAIL" -eq 0 ]
