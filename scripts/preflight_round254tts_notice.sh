#!/usr/bin/env bash
# preflight_round254tts_notice.sh
# Round 254TTS-NOTICE: Supertonic License Notice + Use Restriction UX Gate
# Cloud static checked — Mac build pending — Submission not ready

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

PASS=0
FAIL=0
RESULTS=()

check() {
    local id="$1"
    local desc="$2"
    local result="$3"
    local note="${4:-}"
    if [ "$result" = "pass" ]; then
        RESULTS+=("✅ CHECK $id: $desc${note:+ — $note}")
        PASS=$((PASS + 1))
    else
        RESULTS+=("❌ FAIL  $id: $desc${note:+ — $note}")
        FAIL=$((FAIL + 1))
    fi
}

# CHECK 1: SupertonicTTSNoticePolicy.swift exists
if [ -f "MyTeam/SupertonicTTSNoticePolicy.swift" ]; then
    check 1 "SupertonicTTSNoticePolicy.swift exists" "pass"
else
    check 1 "SupertonicTTSNoticePolicy.swift exists" "fail" "File missing"
fi

# CHECK 2: SupertonicNoticeCardView.swift exists
if [ -f "MyTeam/SupertonicNoticeCardView.swift" ]; then
    check 2 "SupertonicNoticeCardView.swift exists" "pass"
else
    check 2 "SupertonicNoticeCardView.swift exists" "fail" "File missing"
fi

# CHECK 3: TTSLabView uses SupertonicNoticeCardView
if grep -q "SupertonicNoticeCardView" MyTeam/TTSLabView.swift 2>/dev/null; then
    check 3 "TTSLabView uses SupertonicNoticeCardView" "pass"
else
    check 3 "TTSLabView uses SupertonicNoticeCardView" "fail" "SupertonicNoticeCardView not referenced in TTSLabView"
fi

# CHECK 4: TTSLabView has noticeAccepted state
if grep -q "noticeAccepted" MyTeam/TTSLabView.swift 2>/dev/null; then
    check 4 "TTSLabView has noticeAccepted state" "pass"
else
    check 4 "TTSLabView has noticeAccepted state" "fail" "noticeAccepted @State variable missing"
fi

# CHECK 5: ONNX synth button disabled when !noticeAccepted
if grep -q "!noticeAccepted" MyTeam/TTSLabView.swift 2>/dev/null; then
    check 5 "ONNX synth button disabled when !noticeAccepted" "pass"
else
    check 5 "ONNX synth button disabled when !noticeAccepted" "fail" "noticeAccepted not in disabled condition"
fi

# CHECK 6: UserDefaults keys defined in policy
KEYS_OK=true
for key in "supertonic.licenseNoticeAccepted" "supertonic.useRestrictionsAccepted" "supertonic.noticeVersionAccepted"; do
    if ! grep -q "$key" MyTeam/SupertonicTTSNoticePolicy.swift 2>/dev/null; then
        KEYS_OK=false
        break
    fi
done
if [ "$KEYS_OK" = "true" ]; then
    check 6 "UserDefaults keys defined in SupertonicTTSNoticePolicy" "pass"
else
    check 6 "UserDefaults keys defined in SupertonicTTSNoticePolicy" "fail" "One or more UserDefaults keys missing"
fi

# CHECK 7: License notice text exists
if grep -q "licenseNoticeText" MyTeam/SupertonicTTSNoticePolicy.swift 2>/dev/null; then
    check 7 "License notice text defined" "pass"
else
    check 7 "License notice text defined" "fail" "licenseNoticeText missing"
fi

# CHECK 8: Use restriction text exists
if grep -q "useRestrictionsText" MyTeam/SupertonicTTSNoticePolicy.swift 2>/dev/null; then
    check 8 "Use restrictions text defined" "pass"
else
    check 8 "Use restrictions text defined" "fail" "useRestrictionsText missing"
fi

# CHECK 9: TTSProductPolicy licenseVerified true
if grep -q "licenseVerified.*=.*true" MyTeam/TTSProviderModels.swift 2>/dev/null; then
    check 9 "TTSProductPolicy.licenseVerified is true" "pass"
else
    check 9 "TTSProductPolicy.licenseVerified is true" "fail" "licenseVerified not set to true"
fi

# CHECK 10: TTSProductPolicy userFacingTTSEnabled false
if grep -q "userFacingTTSEnabled.*=.*false" MyTeam/TTSProviderModels.swift 2>/dev/null; then
    check 10 "TTSProductPolicy.userFacingTTSEnabled is false" "pass"
else
    check 10 "TTSProductPolicy.userFacingTTSEnabled is false" "fail" "userFacingTTSEnabled not false — Release TTS must remain locked"
fi

# CHECK 11: TTSProductPolicy fallbackTTSAvailable false
if grep -q "fallbackTTSAvailable.*=.*false" MyTeam/TTSProviderModels.swift 2>/dev/null; then
    check 11 "TTSProductPolicy.fallbackTTSAvailable is false" "pass"
else
    check 11 "TTSProductPolicy.fallbackTTSAvailable is false" "fail" "fallbackTTSAvailable not false — no fallback TTS allowed"
fi

# CHECK 12: No Supertonic auto-init on launch (checks for actual init/start calls, not comments or prints)
AUTOINIT=$(grep -Rn "Supertonic3.*\.init\|Supertonic3.*start\|Supertonic3.*load\|Supertonic3.*enable\b" \
    MyTeam/MyTeamApp.swift MyTeam/AppDelegate.swift 2>/dev/null \
    | grep -v "^#\|^\s*//" || true)
if [ -z "$AUTOINIT" ]; then
    check 12 "No Supertonic auto-init call in app launch entry points" "pass"
else
    check 12 "No Supertonic auto-init call in app launch entry points" "fail" "Found: $AUTOINIT"
fi

# CHECK 13: No Supertonic3ONNXRunner connection in SpeechManager
if ! grep -q "Supertonic3ONNXRunner\|Supertonic3ONNXSpike" MyTeam/SpeechManager.swift 2>/dev/null; then
    check 13 "SpeechManager does not reference Supertonic3ONNXRunner" "pass"
else
    check 13 "SpeechManager does not reference Supertonic3ONNXRunner" "fail" "ONNX runner must not be wired to SpeechManager"
fi

# CHECK 14: No tracked .onnx files
TRACKED_ONNX=$(git ls-files "*.onnx" 2>/dev/null || true)
if [ -z "$TRACKED_ONNX" ]; then
    check 14 "No tracked .onnx files in git" "pass"
else
    check 14 "No tracked .onnx files in git" "fail" "Tracked: $TRACKED_ONNX"
fi

# CHECK 15: No bundled .onnx files (not in source dirs that would be copied to bundle)
BUNDLED_ONNX=$(find MyTeam -name "*.onnx" 2>/dev/null || true)
if [ -z "$BUNDLED_ONNX" ]; then
    check 15 "No .onnx files in source tree" "pass"
else
    check 15 "No .onnx files in source tree" "fail" "Found: $BUNDLED_ONNX"
fi

# CHECK 16: docs/SupertonicUseRestrictions.md exists
if [ -f "docs/SupertonicUseRestrictions.md" ]; then
    check 16 "docs/SupertonicUseRestrictions.md exists" "pass"
else
    check 16 "docs/SupertonicUseRestrictions.md exists" "fail" "File missing"
fi

# CHECK 17: docs/SupertonicCommercialLicenseReview.md exists
if [ -f "docs/SupertonicCommercialLicenseReview.md" ]; then
    check 17 "docs/SupertonicCommercialLicenseReview.md exists" "pass"
else
    check 17 "docs/SupertonicCommercialLicenseReview.md exists" "fail" "File missing"
fi

# CHECK 18: scripts/preflight_round253tts_adopt.sh exists
if [ -f "scripts/preflight_round253tts_adopt.sh" ]; then
    check 18 "scripts/preflight_round253tts_adopt.sh exists" "pass"
else
    check 18 "scripts/preflight_round253tts_adopt.sh exists" "fail" "File missing"
fi

# ─────────────────────────────────────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo " Round 254TTS-NOTICE — Supertonic License Notice Gate Check"
echo "============================================================"
for r in "${RESULTS[@]}"; do
    echo "  $r"
done
echo ""
echo "  PASSED: $PASS / $((PASS + FAIL))"
echo ""
echo "  Cloud status:     Cloud static checked"
echo "  Mac build:        Mac build pending"
echo "  Release TTS:      Locked"
echo "  Submission:       Submission not ready"
echo "============================================================"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
