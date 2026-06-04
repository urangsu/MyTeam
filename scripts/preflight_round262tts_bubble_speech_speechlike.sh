#!/usr/bin/env bash
# Round 262TTS-BUBBLESPEECH-SPEECHLIKE-ENGINE: preflight 23/23
# Usage: bash scripts/preflight_round262tts_bubbleSpeech_speechlike.sh
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
BUBBLE="$MYTEAM/BubbleSpeechSynthesizer.swift"
KSD="$MYTEAM/KoreanSyllableDecomposer.swift"
SNAP="$MYTEAM/AudioFeatureSnapshot.swift"
LAB="$MYTEAM/TTSLabView.swift"
SM="$MYTEAM/SpeechManager.swift"
AWM="$MYTEAM/AgentWindowManager.swift"
POLICY="$MYTEAM/TTSProductPolicy.swift"

check 1 "KoreanSyllableDecomposer.swift exists" "[ -f '$KSD' ]"
check 2 "KoreanSyllableDecomposer uses Hangul base 0xAC00" \
  "grep -q '0xAC00' '$KSD' && grep -q 'medialCount = 21' '$KSD' && grep -q 'finalCount = 28' '$KSD'"
check 3 "BubbleSpeechSynthesizer no longer contains majorScale" \
  "! grep -q 'majorScale' '$BUBBLE'"
check 4 "BubbleSpeechSyllableFrame exists" "grep -q 'struct BubbleSpeechSyllableFrame' '$BUBBLE'"
check 5 "BubbleSpeechVowelColor exists" "grep -q 'enum BubbleSpeechVowelColor' '$BUBBLE'"
check 6 "BubbleSpeechTransientKind exists" "grep -q 'enum BubbleSpeechTransientKind' '$BUBBLE'"
check 7 "BubbleSpeechTailKind exists" "grep -q 'enum BubbleSpeechTailKind' '$BUBBLE'"
check 8 "generateSyllable exists" "grep -q 'static func generateSyllable' '$BUBBLE'"
check 9 "speechFrequency exists" "grep -q 'static func speechFrequency' '$BUBBLE'"
check 10 "BubbleSpeechSynthesizer handles phrase pause" \
  "grep -q 'BubbleSpeechToken' '$BUBBLE' && grep -q 'shortPause' '$BUBBLE' && grep -q 'mediumPause' '$BUBBLE' && grep -q 'longPause' '$BUBBLE'"
check 11 "BubbleSpeech profiles distinguish speech/effect" \
  "grep -q 'profileKindLabel' '$BUBBLE' && grep -q 'effect' '$BUBBLE' && grep -q 'speech' '$BUBBLE'"
check 12 "AudioFeatureSnapshot.swift exists" "[ -f '$SNAP' ]"
check 13 "AudioFeatureAnalyzer has zeroCrossingRate" "grep -q 'zeroCrossingRate' '$SNAP'"
check 14 "AudioFeatureAnalyzer has estimatedClickCount" "grep -q 'estimatedClickCount' '$SNAP'"
check 15 "TTSLabView shows 뽀글뽀글 말하기" "grep -q '뽀글뽀글 말하기' '$LAB'"
check 16 "SpeechManager.previewBubbleSpeech still exists" "grep -q 'func previewBubbleSpeech' '$SM'"
check 17 "previewBubbleSpeech uses Supertonic3 voice synthesis" \
  "awk '/func previewBubbleSpeech/,/^    func [a-z]/' '$SM' | grep -q 'Supertonic3ONNXRunner'"
check 18 "No third-party sample assets" \
  "! find '$MYTEAM/Resources' -type f 2>/dev/null | grep -Ei 'youtube|third.?party.?sample|external.?sample'"
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
