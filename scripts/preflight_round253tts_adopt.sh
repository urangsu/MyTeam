#!/usr/bin/env bash
# preflight_round253tts_adopt.sh
# Round 253TTS: Supertonic adoption gate policy checks
# Expected: all checks PASS before release exposure work continues.

set -uo pipefail

REPO_ROOT="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"
MYTEAM="$REPO_ROOT/MyTeam"
DOCS="$REPO_ROOT/docs"

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
echo "═══════════════════════════════════════════════════"
echo " preflight_round253tts_adopt.sh"
echo "═══════════════════════════════════════════════════"
echo ""

# 1. Supertonic-only policy exists
grep -q "Supertonic.*only TTS candidate\|Supertonic.*유일한 TTS 후보\|Supertonic.*단독 후보" "$DOCS/TTSProviderPolicy.md" "$MYTEAM/TTSProviderModels.swift" 2>/dev/null \
    && check "Supertonic-only policy present" "pass" \
    || check "Supertonic-only policy present" "fail"

# 2. No default user-facing TTS yet
grep -q "userFacingTTSEnabled: Bool[[:space:]]*=[[:space:]]*false" "$MYTEAM/TTSProviderModels.swift" 2>/dev/null \
    && check "userFacingTTSEnabled remains false" "pass" \
    || check "userFacingTTSEnabled remains false" "fail"

# 3. License gate is now allowed for planning
grep -q "licenseVerified: Bool[[:space:]]*=[[:space:]]*true" "$MYTEAM/TTSProviderModels.swift" 2>/dev/null \
    && check "licenseVerified true for planning" "pass" \
    || check "licenseVerified true for planning" "fail"

# 4. Commercial use allowed flag exists
grep -q "commercialUseAllowed: Bool[[:space:]]*=[[:space:]]*true" "$MYTEAM/TTSProviderModels.swift" 2>/dev/null \
    && check "commercialUseAllowed true" "pass" \
    || check "commercialUseAllowed true" "fail"

# 5. Remaining release gates are locked
grep -q "koreanQualityAccepted: Bool[[:space:]]*=[[:space:]]*false" "$MYTEAM/TTSProviderModels.swift" 2>/dev/null \
    && grep -q "localRuntimeVerified: Bool[[:space:]]*=[[:space:]]*false" "$MYTEAM/TTSProviderModels.swift" 2>/dev/null \
    && grep -q "releaseIntegrationApproved: Bool[[:space:]]*=[[:space:]]*false" "$MYTEAM/TTSProviderModels.swift" 2>/dev/null \
    && check "quality/runtime/release gates remain locked" "pass" \
    || check "quality/runtime/release gates remain locked" "fail"

# 6. No fallback TTS
grep -q "fallbackTTSAvailable: Bool[[:space:]]*=[[:space:]]*false" "$MYTEAM/TTSProviderModels.swift" 2>/dev/null \
    && check "fallback TTS remains disabled" "pass" \
    || check "fallback TTS remains disabled" "fail"

# 7. No Supertonic launch auto-init
grep -q "supertonicAutoInitOnLaunch: Bool[[:space:]]*=[[:space:]]*false" "$MYTEAM/TTSProviderModels.swift" 2>/dev/null \
    && check "Supertonic launch auto-init disabled" "pass" \
    || check "Supertonic launch auto-init disabled" "fail"

# 8. Use restriction policy doc exists
[ -f "$DOCS/SupertonicUseRestrictions.md" ] \
    && check "SupertonicUseRestrictions.md exists" "pass" \
    || check "SupertonicUseRestrictions.md exists" "fail"

# 9. Commercial license review doc exists and says OpenRAIL-M
grep -q "OpenRAIL-M" "$DOCS/SupertonicCommercialLicenseReview.md" 2>/dev/null \
    && check "Commercial license review documents OpenRAIL-M" "pass" \
    || check "Commercial license review documents OpenRAIL-M" "fail"

# 10. No tracked ONNX files
ONNX_TRACKED=$(git -C "$REPO_ROOT" ls-files | grep "\.onnx$" | wc -l | tr -d ' ')
[ "$ONNX_TRACKED" -eq 0 ] \
    && check "No tracked .onnx files" "pass" \
    || check "No tracked .onnx files ($ONNX_TRACKED found)" "fail"

# 11. No bundled ONNX resources
ONNX_BUNDLED=$(find "$MYTEAM/Resources" -name "*.onnx" 2>/dev/null | wc -l | tr -d ' ')
[ "$ONNX_BUNDLED" -eq 0 ] \
    && check "No ONNX in app bundle resources" "pass" \
    || check "No ONNX in app bundle resources ($ONNX_BUNDLED found)" "fail"

# 12. Product readiness not claimable
if grep -q "canShipAsProductFeature" "$MYTEAM/TTSProviderModels.swift" 2>/dev/null \
   && grep -q "userFacingTTSEnabled.*false" "$MYTEAM/TTSProviderModels.swift" 2>/dev/null; then
    check "canShipAsProductFeature remains blocked by release gates" "pass"
else
    check "canShipAsProductFeature remains blocked by release gates" "fail"
fi

echo ""
echo "───────────────────────────────────────────────────"
echo " RESULT: $PASS PASSED / $FAIL FAILED"
echo "───────────────────────────────────────────────────"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
