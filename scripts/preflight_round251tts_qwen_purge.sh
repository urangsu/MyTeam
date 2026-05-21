#!/usr/bin/env bash
# preflight_round251tts_qwen_purge.sh
# Round 251TTS-QWEN-PURGE: Qwen3 완전 제거 + Supertonic-only 정책 검증
# 기대: 14/14 PASSED

set -uo pipefail

REPO_ROOT="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"
MYTEAM="$REPO_ROOT/MyTeam"
DOCS="$REPO_ROOT/docs"
SCRIPTS="$REPO_ROOT/scripts"

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
echo " preflight_round251tts_qwen_purge.sh"
echo "═══════════════════════════════════════════════════"
echo ""

# 1. No Qwen/qwen string in MyTeam Swift code (excluding comments with "removed"/"purge")
QWEN_SWIFT=$(grep -rn "Qwen\|qwen\|QWEN" "$MYTEAM"/*.swift 2>/dev/null | grep -v "//.*[Rr]emoved\|//.*[Pp]urge\|//.*제거\|//.*단독\|//.*후보" | wc -l | tr -d ' ')
[ "$QWEN_SWIFT" -eq 0 ] && check "No Qwen/qwen in Swift code" "pass" || check "No Qwen/qwen in Swift code ($QWEN_SWIFT hits)" "fail"

# 2. No Qwen in active policy docs (TTSProviderPolicy, Supertonic3PoCPolicy)
QWEN_DOCS=$(grep -n "Qwen\|qwen" "$DOCS/TTSProviderPolicy.md" "$DOCS/Supertonic3PoCPolicy.md" 2>/dev/null | wc -l | tr -d ' ')
[ "$QWEN_DOCS" -eq 0 ] && check "No Qwen in active policy docs" "pass" || check "No Qwen in active policy docs ($QWEN_DOCS hits)" "fail"

# 3. No Qwen provider enum/case in TTSProviderModels
grep -iq "qwen" "$MYTEAM/TTSProviderModels.swift" 2>/dev/null \
    && check "No Qwen in TTSProviderModels" "fail" \
    || check "No Qwen in TTSProviderModels" "pass"

# 4. Supertonic is the only TTSProviderKind case (check enum block only)
if grep -A5 "enum TTSProviderKind" "$MYTEAM/TTSProviderModels.swift" 2>/dev/null | grep -q "case supertonic3" \
    && ! grep -A5 "enum TTSProviderKind" "$MYTEAM/TTSProviderModels.swift" 2>/dev/null | grep -q "case qwen\|case apple"; then
    check "Supertonic3 is the only TTSProviderKind case" "pass"
else
    check "Supertonic3 is the only TTSProviderKind case" "fail"
fi

# 5. licenseVerified default false
grep -q "licenseVerified.*false\|licenseVerified: Bool.*=.*false" "$MYTEAM/TTSProviderModels.swift" 2>/dev/null \
    && check "licenseVerified default false" "pass" \
    || check "licenseVerified default false" "fail"

# 6. canShipAsProductFeature is false
grep -A3 "canShipAsProductFeature" "$MYTEAM/TTSProviderModels.swift" 2>/dev/null | grep -q "false" \
    && check "canShipAsProductFeature is false" "pass" \
    || check "canShipAsProductFeature is false" "fail"

# 7. No tracked .onnx files
ONNX_TRACKED=$(git -C "$REPO_ROOT" ls-files | grep "\.onnx$" | wc -l | tr -d ' ')
[ "$ONNX_TRACKED" -eq 0 ] \
    && check "No tracked .onnx files" "pass" \
    || check "No tracked .onnx files ($ONNX_TRACKED found)" "fail"

# 8. No bundled ONNX in app resources
ONNX_BUNDLED=$(find "$MYTEAM/Resources" -name "*.onnx" 2>/dev/null | wc -l | tr -d ' ')
[ "$ONNX_BUNDLED" -eq 0 ] \
    && check "No ONNX in app bundle resources" "pass" \
    || check "No ONNX in app bundle resources ($ONNX_BUNDLED found)" "fail"

# 9. No Supertonic auto-init on launch
AUTO_INIT=$(grep -rn "Supertonic3ONNXRunner.shared\|Supertonic3TTSProvider.shared" \
    "$MYTEAM/MyTeamApp.swift" "$MYTEAM/AppDelegate.swift" 2>/dev/null | wc -l | tr -d ' ')
[ "$AUTO_INIT" -eq 0 ] \
    && check "No Supertonic auto-init on launch" "pass" \
    || check "No Supertonic auto-init on launch ($AUTO_INIT hits)" "fail"

# 10. TTSLab-only exposure (Supertonic not in main chat UI)
PROD_EXPOSURE=$(grep -rn "Supertonic3\|supertonic3" \
    "$MYTEAM/AgentWindowView.swift" "$MYTEAM/ChatView.swift" \
    "$MYTEAM/WorkroomView.swift" 2>/dev/null | wc -l | tr -d ' ')
[ "$PROD_EXPOSURE" -eq 0 ] \
    && check "Supertonic TTSLab-only (not in main UI)" "pass" \
    || check "Supertonic TTSLab-only (not in main UI — $PROD_EXPOSURE hits)" "fail"

# 11. No System TTS user-facing fallback (AVSpeechSynthesizer absent — real code only, not comments/strings)
AVS=$(grep -rn "AVSpeechSynthesizer\|AVSpeechUtterance\|NSSpeechSynthesizer" \
    "$MYTEAM"/*.swift 2>/dev/null | \
    grep -v "//.*AVSpeech\|//.*NSSpeech" | \
    grep -v '".*AVSpeech.*"' | \
    wc -l | tr -d ' ')
[ "$AVS" -eq 0 ] \
    && check "No AVSpeechSynthesizer (System TTS absent)" "pass" \
    || check "No AVSpeechSynthesizer ($AVS hits)" "fail"

# 12. No commercial-ready claim in Supertonic code/docs
COMM=$(grep -rn "commercial.ready\|商業利用可\|App Store.approved" \
    "$MYTEAM"/Supertonic3*.swift "$DOCS"/*.md 2>/dev/null | wc -l | tr -d ' ')
[ "$COMM" -eq 0 ] \
    && check "No commercial-ready claim" "pass" \
    || check "No commercial-ready claim ($COMM hits)" "fail"

# 13. No Qwen3TTSService.swift file
[ ! -f "$MYTEAM/Qwen3TTSService.swift" ] \
    && check "Qwen3TTSService.swift deleted" "pass" \
    || check "Qwen3TTSService.swift still exists" "fail"

# 14. TTSProviderPolicy.md mentions Supertonic-only
grep -q "Supertonic.*후보\|only.*candidate\|단독 후보" "$DOCS/TTSProviderPolicy.md" 2>/dev/null \
    && check "TTSProviderPolicy.md states Supertonic-only" "pass" \
    || check "TTSProviderPolicy.md states Supertonic-only" "fail"

echo ""
echo "───────────────────────────────────────────────────"
echo " RESULT: $PASS PASSED / $FAIL FAILED"
echo "───────────────────────────────────────────────────"

# Final Qwen grep (활성 코드/정책 파일만; TASK.md·DEVLOG.md는 역사적 개발 로그 → 제외)
echo ""
echo "Final Qwen grep (활성 파일 0건 이어야 함):"
QWEN_FINAL=$(grep -R "Qwen\|qwen\|QWEN" \
    --include="*.swift" --include="*.sh" --include="*.md" \
    "$MYTEAM" "$DOCS" "$SCRIPTS" 2>/dev/null | \
    grep -v "Binary\|SupertonicAssessment\|AppStorePackaging\|PrivacyNutrition\|voices-audit\|POLICY.md\|round247\|round248\|round251tts_qwen_purge\|graphify" | \
    wc -l | tr -d ' ')
if [ "$QWEN_FINAL" -eq 0 ]; then
    echo "  ✅ Qwen 참조 0건"
else
    echo "  ❌ Qwen 참조 ${QWEN_FINAL}건 남음:"
    grep -R "Qwen\|qwen\|QWEN" \
        --include="*.swift" --include="*.sh" --include="*.md" \
        "$MYTEAM" "$DOCS" "$SCRIPTS" 2>/dev/null | \
        grep -v "Binary\|SupertonicAssessment\|AppStorePackaging\|PrivacyNutrition\|voices-audit\|POLICY.md\|round247\|round248\|round251tts_qwen_purge\|graphify" | \
        head -20
fi

echo ""
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
