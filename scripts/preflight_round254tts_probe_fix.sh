#!/usr/bin/env bash
# preflight_round254tts_probe_fix.sh
# Round 254TTS-PROBE-FIX: Supertonic Probe runtime status 수정 검증
# 기대: 13/13 PASSED

set -uo pipefail

REPO_ROOT="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"
MYTEAM="$REPO_ROOT/MyTeam"

PASS=0; FAIL=0

check() {
    local desc="$1" result="$2"
    if [ "$result" = "pass" ]; then
        echo "  ✅ $desc"; PASS=$((PASS+1))
    else
        echo "  ❌ $desc"; FAIL=$((FAIL+1))
    fi
}

echo ""
echo "═══════════════════════════════════════════════════════"
echo " preflight_round254tts_probe_fix.sh"
echo "═══════════════════════════════════════════════════════"
echo ""

# 1. Supertonic3ONNXRuntimeProbe.swift exists
[ -f "$MYTEAM/Supertonic3ONNXRuntimeProbe.swift" ] \
    && check "Supertonic3ONNXRuntimeProbe.swift exists" "pass" \
    || check "Supertonic3ONNXRuntimeProbe.swift exists" "fail"

# 2. imports OnnxRuntimeBindings
grep -q "import OnnxRuntimeBindings" "$MYTEAM/Supertonic3ONNXRuntimeProbe.swift" 2>/dev/null \
    && check "Supertonic3ONNXRuntimeProbe imports OnnxRuntimeBindings" "pass" \
    || check "Supertonic3ONNXRuntimeProbe imports OnnxRuntimeBindings" "fail"

# 3. creates ORTEnv
grep -q "ORTEnv" "$MYTEAM/Supertonic3ONNXRuntimeProbe.swift" 2>/dev/null \
    && check "Supertonic3ONNXRuntimeProbe uses ORTEnv" "pass" \
    || check "Supertonic3ONNXRuntimeProbe uses ORTEnv" "fail"

# 4. Supertonic3TTSProbe no longer contains hardcoded runtimeAvailable: false
grep -q "runtimeAvailable: false" "$MYTEAM/Supertonic3TTSProbe.swift" 2>/dev/null \
    && check "No hardcoded runtimeAvailable: false in probe (FAIL — still present)" "fail" \
    || check "No hardcoded runtimeAvailable: false in probe" "pass"

# 5. Old stale runtime note removed
grep -q "248TTS에서 onnxruntime-swift-package-manager SPM 추가 예정" "$MYTEAM/Supertonic3TTSProbe.swift" 2>/dev/null \
    && check "Old stale runtime note removed (FAIL — still present)" "fail" \
    || check "Old stale runtime note removed" "pass"

# 6. Probe references Supertonic3ONNXRuntimeProbe
grep -q "Supertonic3ONNXRuntimeProbe" "$MYTEAM/Supertonic3TTSProbe.swift" 2>/dev/null \
    && check "Supertonic3TTSProbe references Supertonic3ONNXRuntimeProbe" "pass" \
    || check "Supertonic3TTSProbe references Supertonic3ONNXRuntimeProbe" "fail"

# 7. ProbeRunResult includes noticeAccepted field
grep -q "noticeAccepted" "$MYTEAM/Supertonic3TTSProbe.swift" 2>/dev/null \
    && check "Supertonic3ProbeRunResult has noticeAccepted field" "pass" \
    || check "Supertonic3ProbeRunResult has noticeAccepted field" "fail"

# 8. canSynthesize includes noticeAccepted
grep -A5 "canSynthesize" "$MYTEAM/Supertonic3TTSProbe.swift" 2>/dev/null | grep -q "noticeAccepted" \
    && check "canSynthesize includes noticeAccepted" "pass" \
    || check "canSynthesize includes noticeAccepted" "fail"

# 9. TTSLabView still gates synthesis button by noticeAccepted
grep -q "!noticeAccepted" "$MYTEAM/TTSLabView.swift" 2>/dev/null \
    && check "TTSLabView synthesis button gated by noticeAccepted" "pass" \
    || check "TTSLabView synthesis button gated by noticeAccepted" "fail"

# 10. SpeechManager does not reference Supertonic3ONNXRunner (no production wiring)
SPEECH_REF=$(grep -n "Supertonic3ONNXRunner" "$MYTEAM/SpeechManager.swift" 2>/dev/null | wc -l | tr -d ' ')
[ "$SPEECH_REF" -eq 0 ] \
    && check "SpeechManager does not reference Supertonic3ONNXRunner" "pass" \
    || check "SpeechManager does not reference Supertonic3ONNXRunner ($SPEECH_REF hits)" "fail"

# 11. MyTeamApp does not auto-init Supertonic
AUTO_INIT=$(grep -rn "Supertonic3ONNXRunner.shared\|Supertonic3TTSProvider.shared" \
    "$MYTEAM/MyTeamApp.swift" "$MYTEAM/AppDelegate.swift" 2>/dev/null | wc -l | tr -d ' ')
[ "$AUTO_INIT" -eq 0 ] \
    && check "No Supertonic auto-init on launch" "pass" \
    || check "No Supertonic auto-init on launch ($AUTO_INIT hits)" "fail"

# 12. No tracked .onnx files
ONNX_TRACKED=$(git -C "$REPO_ROOT" ls-files | grep "\.onnx$" | wc -l | tr -d ' ')
[ "$ONNX_TRACKED" -eq 0 ] \
    && check "No tracked .onnx files" "pass" \
    || check "No tracked .onnx files ($ONNX_TRACKED found)" "fail"

# 13. No bundled .onnx in app resources
ONNX_BUNDLED=$(find "$MYTEAM/Resources" -name "*.onnx" 2>/dev/null | wc -l | tr -d ' ')
[ "$ONNX_BUNDLED" -eq 0 ] \
    && check "No .onnx in app bundle resources" "pass" \
    || check "No .onnx in app bundle resources ($ONNX_BUNDLED found)" "fail"

echo ""
echo "───────────────────────────────────────────────────────"
echo " RESULT: $PASS PASSED / $FAIL FAILED"
echo "───────────────────────────────────────────────────────"
echo ""
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
