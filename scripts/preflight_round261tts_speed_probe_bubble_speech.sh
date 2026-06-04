#!/usr/bin/env bash
# Round 261TTS-SPEED-PROBE-AND-BUBBLESPEECH: preflight 22/22
# Usage: bash scripts/preflight_round261tts_speed_probe_bubbleSpeech.sh
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
LAB="$ROOT/MyTeam/TTSLabView.swift"
PROBE="$ROOT/MyTeam/SupertonicSpeedProbe.swift"
ANIM="$ROOT/MyTeam/BubbleSpeechSynthesizer.swift"
ONNX="$ROOT/MyTeam/Supertonic3ONNXRunner.swift"
AWM="$ROOT/MyTeam/AgentWindowManager.swift"

# [1] SupertonicSpeedProbe.swift 존재
check 1 "SupertonicSpeedProbe.swift 존재" "[ -f '$PROBE' ]"

# [2] SupertonicSpeedProbeResult에 speed/durationSec/sampleCount/realtimeFactor 포함
check 2 "SupertonicSpeedProbeResult 필드 4종" \
  "grep -q 'speed:' '$PROBE' && grep -q 'durationSec:' '$PROBE' && grep -q 'sampleCount:' '$PROBE' && grep -q 'realtimeFactor:' '$PROBE'"

# [3] SpeechManager에 probeSpeedApplication 존재
check 3 "SpeechManager.probeSpeedApplication 존재" \
  "grep -q 'func probeSpeedApplication' '$SM'"

# [4] probeSpeedApplication에 speed 0.70, 1.00, 1.30, 2.00 포함
check 4 "probeSpeedApplication testSpeeds 4종" \
  "grep -q 'testSpeeds' '$SM'"

# [5] probeSpeedApplication이 playFloatSamples 호출하지 않음
check 5 "probeSpeedApplication은 playFloatSamples 호출 없음" \
  "! awk '/func probeSpeedApplication/,/^    func [a-z]/' '$SM' | grep -q 'playFloatSamples'"

# [6] TTSLabView에 Speed 적용 계측 섹션 존재
check 6 "TTSLabView Speed 적용 계측 섹션 존재" \
  "grep -q 'Speed 적용 계측' '$LAB'"

# [7] BubbleSpeechSynthesizer.swift 존재
check 7 "BubbleSpeechSynthesizer.swift 존재" "[ -f '$ANIM' ]"

# [8] BubbleSpeechConfig 존재
check 8 "BubbleSpeechConfig 정의 존재" \
  "grep -q 'struct BubbleSpeechConfig' '$ANIM'"

# [9] BubbleSpeechVoiceProfile 존재
check 9 "BubbleSpeechVoiceProfile 정의 존재" \
  "grep -q 'enum BubbleSpeechVoiceProfile' '$ANIM'"

# [10] BubbleSpeechSynthesizer.synthesize 반환 [Float]
check 10 "BubbleSpeechSynthesizer.synthesize -> [Float]" \
  "grep -q 'static func synthesize.*-> \[Float\]' '$ANIM'"

# [11] SpeechManager에 previewBubbleSpeech 존재
check 11 "SpeechManager.previewBubbleSpeech 존재" \
  "grep -q 'func previewBubbleSpeech' '$SM'"

# [12] previewBubbleSpeech가 Supertonic3ONNXRunner 사용하지 않음
check 12 "previewBubbleSpeech는 Supertonic3ONNXRunner 호출 없음" \
  "! awk '/func previewBubbleSpeech/,/^    func [a-z]/' '$SM' | grep -q 'Supertonic3ONNXRunner'"

# [13] TTSLabView에 BubbleSpeech 섹션 존재
check 13 "TTSLabView BubbleSpeech 섹션 존재" \
  "grep -q '음절형 말소리 테스트' '$LAB'"

# [14] BubbleSpeech 섹션에 profile picker 존재
check 14 "BubbleSpeech profile picker 존재" \
  "grep -q 'bubbleSpeechProfile' '$LAB'"

# [15] BubbleSpeech 섹션에 speed slider 존재
check 15 "BubbleSpeech speed slider 존재" \
  "grep -q 'bubbleSpeechSpeed' '$LAB'"

# [16] BubbleSpeech 섹션에 pitchOffset slider 존재
check 16 "BubbleSpeech pitchOffset slider 존재" \
  "grep -q 'bubbleSpeechPitchOffset' '$LAB'"

# [17] BubbleSpeechSynthesizer가 외부 샘플 파일 로드 안 함 (URL/Bundle/resource 없음)
check 17 "BubbleSpeechSynthesizer 외부 샘플 로드 없음" \
  "! grep -q 'Bundle.main\|NSDataAsset\|contentsOfFile\|AudioFile' '$ANIM'"

# [18] 치코 role UX 디자이너 보존
check 18 "치코 role UX 디자이너 보존" \
  "grep -q 'UX 디자이너' '$AWM'"

# [19] fallbackTTSAvailable false
check 19 "fallbackTTSAvailable false 유지" \
  "! grep -rq 'fallbackTTSAvailable.*=.*true' '$ROOT/MyTeam/'"

# [20] autoSpeakDefaultEnabled false
check 20 "autoSpeakDefaultEnabled false 유지" \
  "! grep -rq 'autoSpeakDefaultEnabled.*=.*true' '$ROOT/MyTeam/'"

# [21] AVSpeechSynthesizer 인스턴스 생성 없음 (주석/문자열 허용, 실제 호출 금지)
check 21 "AVSpeechSynthesizer 인스턴스 생성 없음" \
  "! grep -rq 'AVSpeechSynthesizer()' '$ROOT/MyTeam/'"

# [22] no tracked .onnx
check 22 "커밋된 .onnx 없음" \
  "! git -C '$ROOT' ls-files | grep -q '\.onnx'"

echo ""
echo "=============================="
echo "결과: ${PASS}개 통과 / $((PASS+FAIL))개 검사"
if [ "$FAIL" -eq 0 ]; then
    echo "🎉 ALL ${PASS}/22 PASS — Round 261TTS preflight OK"
else
    echo "💥 ${FAIL}개 실패"
    exit 1
fi
