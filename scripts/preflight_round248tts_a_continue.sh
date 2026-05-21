#!/bin/bash
# Round 248TTS-A-CONTINUE: Supertonic3 Runtime Boundary Pipeline Preflight
# Policy: No ONNX execution, no dummy audio, no model auto-download

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MYTEAM="$REPO_ROOT/MyTeam"
PASS=0
FAIL=0

check() {
    local desc="$1"
    local result="$2"
    if [ "$result" = "pass" ]; then
        echo "  ✓ $desc"
        PASS=$((PASS+1))
    else
        echo "  ✗ $desc"
        FAIL=$((FAIL+1))
    fi
}

echo "=== Round 248TTS-A-CONTINUE Preflight ==="

# 1. ONNXRuntimeAdapter.swift exists (protocol boundary)
[ -f "$MYTEAM/ONNXRuntimeAdapter.swift" ] && check "ONNXRuntimeAdapter.swift exists" "pass" || check "ONNXRuntimeAdapter.swift exists" "fail"

# 2. ONNXRuntimeAdapterProtocol defined
grep -q "protocol ONNXRuntimeAdapterProtocol" "$MYTEAM/ONNXRuntimeAdapter.swift" && check "ONNXRuntimeAdapterProtocol protocol defined" "pass" || check "ONNXRuntimeAdapterProtocol protocol defined" "fail"

# 3. ONNXRuntimeUnavailableAdapter exists (Cloud stub)
grep -q "ONNXRuntimeUnavailableAdapter" "$MYTEAM/ONNXRuntimeAdapter.swift" && check "ONNXRuntimeUnavailableAdapter Cloud stub exists" "pass" || check "ONNXRuntimeUnavailableAdapter Cloud stub exists" "fail"

# 4. Supertonic3ModelManifest.swift exists
[ -f "$MYTEAM/Supertonic3ModelManifest.swift" ] && check "Supertonic3ModelManifest.swift exists" "pass" || check "Supertonic3ModelManifest.swift exists" "fail"

# 5. candidateFilenames array defined (manifest-based discovery)
grep -q "candidateFilenames" "$MYTEAM/Supertonic3ModelManifest.swift" && check "candidateFilenames in manifest" "pass" || check "candidateFilenames in manifest" "fail"

# 6. Supertonic3InferencePipeline.swift exists
[ -f "$MYTEAM/Supertonic3InferencePipeline.swift" ] && check "Supertonic3InferencePipeline.swift exists" "pass" || check "Supertonic3InferencePipeline.swift exists" "fail"

# 7. Pipeline throws missingRuntime (Cloud boundary)
grep -q "missingRuntime" "$MYTEAM/Supertonic3InferencePipeline.swift" && check "Pipeline throws missingRuntime" "pass" || check "Pipeline throws missingRuntime" "fail"

# 8. No dummy WAV / fake audio data in pipeline
if grep -q "dummy\|fakeAudio\|Data(count\|[0-9]* bytes" "$MYTEAM/Supertonic3InferencePipeline.swift" 2>/dev/null; then
    check "No dummy audio in pipeline" "fail"
else
    check "No dummy audio in pipeline" "pass"
fi

# 9. Supertonic3TTSProbe.swift exists with Readiness enum
[ -f "$MYTEAM/Supertonic3TTSProbe.swift" ] && grep -q "Supertonic3Readiness" "$MYTEAM/Supertonic3TTSProbe.swift" && check "Supertonic3Readiness enum in probe" "pass" || check "Supertonic3Readiness enum in probe" "fail"

# 10. redactedDirectory used in TTSLabView (not full path)
grep -q "redactedDirectory" "$MYTEAM/TTSLabView.swift" && check "TTSLabView uses redactedDirectory" "pass" || check "TTSLabView uses redactedDirectory" "fail"

# 11. No Apple TTS in actual code (import or construction — not in comments/strings)
if grep -rn "AVSpeechSynthesizer\|NSSpeechSynthesizer" "$MYTEAM/" 2>/dev/null \
    | grep -v "^\s*//" | grep -v "^.*\".*AVSpeech.*\"" | grep -v ".xcodeproj" \
    | grep -v "// Apple TTS" | grep -qv "Text\("; then
    check "No Apple TTS (AVSpeechSynthesizer)" "fail"
else
    check "No Apple TTS (AVSpeechSynthesizer)" "pass"
fi

# 12. No model auto-download code
if grep -rq "URLSession.*download.*supertonic\|supertonic.*download.*URLSession" "$MYTEAM/" 2>/dev/null; then
    check "No auto-download code" "fail"
else
    check "No auto-download code" "pass"
fi

# 13. KSkillAssistRuntime.swift registered in pbxproj
grep -q "KSkillAssistRuntime" "$REPO_ROOT/MyTeam/MyTeam.xcodeproj/project.pbxproj" && check "KSkillAssistRuntime.swift in pbxproj" "pass" || check "KSkillAssistRuntime.swift in pbxproj" "fail"

# 14. Supertonic3TensorTypes.swift exists
[ -f "$MYTEAM/Supertonic3TensorTypes.swift" ] && check "Supertonic3TensorTypes.swift exists" "pass" || check "Supertonic3TensorTypes.swift exists" "fail"

# 15. ONNXRuntimeAvailability enum defined
grep -q "ONNXRuntimeAvailability" "$MYTEAM/ONNXRuntimeAdapter.swift" && check "ONNXRuntimeAvailability enum defined" "pass" || check "ONNXRuntimeAvailability enum defined" "fail"

# 16. Qwen3 default disabled
grep -q "enableExperimentalQwenTTS" "$MYTEAM/TTSLabView.swift" && check "Qwen3 dev-lab-only flag exists" "pass" || check "Qwen3 dev-lab-only flag exists" "fail"

# 17. No large model files in repo (stubs < 10KB are allowed)
LARGE_ONNX=$(find "$REPO_ROOT" -name "*.onnx" -size +10k 2>/dev/null)
if [ -n "$LARGE_ONNX" ]; then
    check "No large .onnx model files in repo (>10KB)" "fail"
else
    check "No large .onnx model files in repo (>10KB)" "pass"
fi

echo ""
echo "=== Result: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
