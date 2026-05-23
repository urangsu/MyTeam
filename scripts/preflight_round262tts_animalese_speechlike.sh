#!/usr/bin/env bash
# Round 262TTS-ANIMALESE-SPEECHLIKE-ENGINE: preflight 23/23
# Usage: bash scripts/preflight_round262tts_animalese_speechlike.sh
set -euo pipefail

PASS=0
FAIL=0

check() {
    local id="$1" desc="$2"; shift 2
    if eval "$@" &>/dev/null; then
        echo "✅ [$id] $desc"
        PASS=$((PASS+1))
    else
        echo "❌ [$id] $desc"
        FAIL=$((FAIL+1))
    fi
}

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MYTEAM="$ROOT/MyTeam"
ANIM="$MYTEAM/AnimaleseSynthesizer.swift"
KSD="$MYTEAM/KoreanSyllableDecomposer.swift"
SNAP="$MYTEAM/AudioFeatureSnapshot.swift"
LAB="$MYTEAM/TTSLabView.swift"
SM="$MYTEAM/SpeechManager.swift"
AWM="$MYTEAM/AgentWindowManager.swift"
POLICY="$MYTEAM/TTSProductPolicy.swift"

check 1 "KoreanSyllableDecomposer.swift exists" "[ -f '$KSD' ]"
check 2 "KoreanSyllableDecomposer uses Hangul base 0xAC00" \
  "grep -q '0xAC00' '$KSD' && grep -q 'medialCount = 21' '$KSD' && grep -q 'finalCount = 28' '$KSD'"
check 3 "AnimaleseSynthesizer no longer contains majorScale" \
  "! grep -q 'majorScale' '$ANIM'"
check 4 "AnimaleseSyllableFrame exists" "grep -q 'struct AnimaleseSyllableFrame' '$ANIM'"
check 5 "AnimaleseVowelColor exists" "grep -q 'enum AnimaleseVowelColor' '$ANIM'"
check 6 "AnimaleseTransientKind exists" "grep -q 'enum AnimaleseTransientKind' '$ANIM'"
check 7 "AnimaleseTailKind exists" "grep -q 'enum AnimaleseTailKind' '$ANIM'"
check 8 "generateSyllable exists" "grep -q 'static func generateSyllable' '$ANIM'"
check 9 "speechFrequency exists" "grep -q 'static func speechFrequency' '$ANIM'"
check 10 "AnimaleseSynthesizer handles phrase pause" \
  "grep -q 'AnimaleseToken' '$ANIM' && grep -q 'shortPause' '$ANIM' && grep -q 'mediumPause' '$ANIM' && grep -q 'longPause' '$ANIM'"
check 11 "Animalese profiles distinguish speech/effect" \
  "grep -q 'profileKindLabel' '$ANIM' && grep -q 'effect' '$ANIM' && grep -q 'speech' '$ANIM'"
check 12 "AudioFeatureSnapshot.swift exists" "[ -f '$SNAP' ]"
check 13 "AudioFeatureAnalyzer has zeroCrossingRate" "grep -q 'zeroCrossingRate' '$SNAP'"
check 14 "AudioFeatureAnalyzer has estimatedClickCount" "grep -q 'estimatedClickCount' '$SNAP'"
check 15 "TTSLabView shows 음절형 말소리" "grep -q '음절형 말소리' '$LAB'"
check 16 "SpeechManager.previewAnimalese still exists" "grep -q 'func previewAnimalese' '$SM'"
check 17 "previewAnimalese does not call Supertonic3ONNXRunner" \
  "! awk '/func previewAnimalese/,/^    func [a-z]/' '$SM' | grep -q 'Supertonic3ONNXRunner'"
check 18 "No Nintendo/Animal Crossing sample assets" \
  "! find '$MYTEAM/Resources' -type f 2>/dev/null | grep -Ei 'nintendo|animal.?crossing|youtube|acnh'"
check 19 "Chiko role remains UX 디자이너 & 온보딩 도우미" \
  "grep -q '치코' '$AWM' && grep -q 'UX 디자이너 & 온보딩 도우미' '$AWM'"
check 20 "fallbackTTSAvailable false" \
  "grep -q 'fallbackTTSAvailable.*=.*false' '$POLICY'"
check 21 "autoSpeakDefaultEnabled false" \
  "grep -q 'autoSpeakDefaultEnabled.*=.*false' '$POLICY'"
check 22 "No AVSpeechSynthesizer active constructor" \
  "! grep -rq 'AVSpeechSynthesizer()' '$MYTEAM'"
check 23 "No tracked .onnx" \
  "! git -C '$ROOT' ls-files | grep -q '\\.onnx$'"

echo ""
echo "=============================="
echo "결과: ${PASS}개 통과 / $((PASS+FAIL))개 검사"
if [ "$FAIL" -eq 0 ]; then
    echo "🎉 ALL ${PASS}/23 PASS — Round 262TTS preflight OK"
else
    echo "💥 ${FAIL}개 실패"
    exit 1
fi
