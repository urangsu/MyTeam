#!/usr/bin/env bash
# Round 260B-TTS-OFFICIAL-SPEED-RANGE: preflight 18/18
# Usage: bash scripts/preflight_round260btts_official_speed_range.sh
set -euo pipefail
PASS=0; FAIL=0

check() {
    local id="$1" desc="$2"; shift 2
    if eval "$@" &>/dev/null; then
        echo "✅ [$id] $desc"; PASS=$((PASS+1))
    else
        echo "❌ [$id] $desc"; FAIL=$((FAIL+1))
    fi
}

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SM="$ROOT/MyTeam/SpeechManager.swift"
ONNX="$ROOT/MyTeam/Supertonic3ONNXRunner.swift"
VTS="$ROOT/MyTeam/VoiceTuningState.swift"
TAG="$ROOT/MyTeam/SupertonicExpressionTagPolicy.swift"
PROC="$ROOT/MyTeam/SupertonicProsodyTextProcessor.swift"
LAB="$ROOT/MyTeam/TTSLabView.swift"
PBXPROJ="$ROOT/MyTeam/MyTeam.xcodeproj/project.pbxproj"

# [1] SupertonicExpressionTagPolicy.swift 존재
check 1 "SupertonicExpressionTagPolicy.swift 존재" "[ -f '$TAG' ]"

# [2] <laugh>, <breath>, <sigh> tag 정의
check 2 "expression tag 3종 정의 (laugh/breath/sigh)" \
  "grep -q '<laugh>' '$TAG' && grep -q '<breath>' '$TAG' && grep -q '<sigh>' '$TAG'"

# [3] SupertonicExpressionTagPolicy.apply(emotion:to:) 존재
check 3 "SupertonicExpressionTagPolicy.apply(emotion:to:) 존재" \
  "grep -q 'apply(emotion:' '$TAG'"

# [4] isFormalOrNumeric 가드 존재
check 4 "isFormalOrNumeric formal/numeric guard 존재" \
  "grep -q 'isFormalOrNumeric' '$TAG'"

# [5] VoiceTuningDefaults.speedRange == 0.70...2.00
check 5 "speedRange 0.70...2.00 (공식 범위)" \
  "grep -q '0.70...2.00' '$VTS'"

# [6] recommendedSpeedRange / experimentalSpeedRange / extremeSpeedRange 존재
check 6 "speedZone 3종 상수 존재" \
  "grep -q 'recommendedSpeedRange' '$VTS' && grep -q 'experimentalSpeedRange' '$VTS' && grep -q 'extremeSpeedRange' '$VTS'"

# [7] speedWarningLow / speedWarningHigh / speedExtremeHigh 존재
check 7 "speedWarning 임계값 3종 존재" \
  "grep -q 'speedWarningLow' '$VTS' && grep -q 'speedWarningHigh' '$VTS' && grep -q 'speedExtremeHigh' '$VTS'"

# [8] Supertonic3ONNXRunner safeSpeed 0.70~2.00
check 8 "Supertonic3ONNXRunner safeSpeed clamp 0.70~2.00" \
  "grep -q 'min(2.00, max(0.70' '$ONNX'"

# [9] preprocess useExpressionTags 파라미터 존재
check 9 "SupertonicProsodyTextProcessor.preprocess useExpressionTags 파라미터" \
  "grep -q 'useExpressionTags' '$PROC'"

# [10] previewWithTuning useExpressionTags 파라미터 존재
check 10 "SpeechManager.previewWithTuning useExpressionTags 파라미터" \
  "grep -q 'useExpressionTags' '$SM'"

# [11] expressionTagsSection in TTSLabView
check 11 "TTSLabView expressionTagsSection 존재" \
  "grep -q 'expressionTagsSection' '$LAB'"

# [12] A/B 테스트 버튼 "없음" 존재
check 12 "TTSLabView expression tags 없음 버튼 존재" \
  "grep -q '없음' '$LAB'"

# [13] S slider 경고 3종 — 0.80 미만
check 13 "TTSLabView S<0.80 발음 경고 존재" \
  "grep -q 'speedWarningLow' '$LAB'"

# [14] S slider 경고 — 1.30 초과
check 14 "TTSLabView S>1.30 효과음 경고 존재" \
  "grep -q 'speedWarningHigh' '$LAB'"

# [15] S slider 경고 — 1.60 초과 (🚨)
check 15 "TTSLabView S>1.60 극단 경고 존재" \
  "grep -q 'speedExtremeHigh' '$LAB'"

# [16] BubbleSpeech tuning speed-first 1.35~1.60
check 16 "BubbleSpeech tuning speed-first 1.35~1.60" \
  "grep -q '1.35' '$ROOT/MyTeam/SupertonicVoicePresetPolicy.swift' && grep -q '1.60' '$ROOT/MyTeam/SupertonicVoicePresetPolicy.swift'"

# [17] pbxproj에 SupertonicExpressionTagPolicy 등록
check 17 "pbxproj에 SupertonicExpressionTagPolicy.swift 등록" \
  "grep -q 'SupertonicExpressionTagPolicy' '$PBXPROJ'"

# [18] 치코 role 수정 금지 확인
check 18 "치코 role UX 디자이너 보존" \
  "grep -q 'UX 디자이너' '$ROOT/MyTeam/AgentWindowManager.swift'"

echo ""
echo "=============================="
echo "결과: ${PASS}개 통과 / $((PASS+FAIL))개 검사"
if [ "$FAIL" -eq 0 ]; then
    echo "🎉 ALL ${PASS}/18 PASS — Round 260B preflight OK"
else
    echo "💥 ${FAIL}개 실패"
    exit 1
fi
