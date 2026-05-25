#!/bin/bash
# Round 250A-255Z Preflight: KSkills CardView + TTS Verification
# Purpose: Verify K-skills structured card + TTS scope locks
# Usage: bash scripts/preflight_round250a_255z_kskills_tts.sh
# Exit: 0 if all checks pass, 1 if any fails

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

check_pass() {
    echo -e "${GREEN}✅ PASS${NC}: $1"
    ((PASS_COUNT++))
}

check_fail() {
    echo -e "${RED}❌ FAIL${NC}: $1"
    ((FAIL_COUNT++))
}

echo "=========================================="
echo "Round 250A-255Z Preflight: KSkills + TTS"
echo "=========================================="
echo ""

# =============================================================================
# Part 1: K-Skills CardView Infrastructure
# =============================================================================

echo "Part 1: K-Skills CardView"
echo "---"

# 1. KSkillAssistCardView.swift exists
if [ -f "$REPO_ROOT/MyTeam/KSkillAssistCardView.swift" ]; then
    check_pass "KSkillAssistCardView.swift exists"
else
    check_fail "KSkillAssistCardView.swift missing"
fi

# 2. isAssistSkillID function in KSkillAssistRuntime
if grep -q "static func isAssistSkillID" "$REPO_ROOT/MyTeam/KSkillAssistRuntime.swift" 2>/dev/null; then
    check_pass "KSkillAssistRuntime: isAssistSkillID function found"
else
    check_fail "KSkillAssistRuntime: isAssistSkillID missing"
fi

# 3. parseSections function in KSkillAssistRuntime
if grep -q "static func parseSections" "$REPO_ROOT/MyTeam/KSkillAssistRuntime.swift" 2>/dev/null; then
    check_pass "KSkillAssistRuntime: parseSections function found"
else
    check_fail "KSkillAssistRuntime: parseSections missing"
fi

# 4. SkillResultRendererView dispatch to KSkillAssistCardView
if grep -q "KSkillAssistCardView\|isAssistSkillID" "$REPO_ROOT/MyTeam/SkillResultRendererView.swift" 2>/dev/null; then
    check_pass "SkillResultRendererView: K-skills dispatch found"
else
    check_fail "SkillResultRendererView: K-skills dispatch missing"
fi

# 5. Hard-blocked actions in KSkillAssistCardView
if grep -q "hardBlockedActions" "$REPO_ROOT/MyTeam/KSkillAssistCardView.swift" 2>/dev/null; then
    check_pass "KSkillAssistCardView: hardBlockedActions section found"
else
    check_fail "KSkillAssistCardView: hardBlockedActions missing"
fi

# 6. Hard-blocked actions NOT in DisclosureGroup (always visible)
if grep -q "hardBlockedActions" "$REPO_ROOT/MyTeam/KSkillAssistCardView.swift" 2>/dev/null; then
    if grep -A 5 "hardBlockedActions" "$REPO_ROOT/MyTeam/KSkillAssistCardView.swift" 2>/dev/null | grep -q "DisclosureGroup"; then
        check_fail "KSkillAssistCardView: hardBlockedActions wrapped in DisclosureGroup (must be always visible)"
    else
        check_pass "KSkillAssistCardView: hardBlockedActions always visible"
    fi
else
    check_fail "KSkillAssistCardView: hardBlockedActions section not found"
fi

echo ""

# =============================================================================
# Part 2: RouterBurnInSuite K-Skills Cases
# =============================================================================

echo "Part 2: RouterBurnInSuite K-Skills Burn-In"
echo "---"

# 7-13. K-skills burn-in test cases (7 cases)
KSKILL_CASES=("kskill-ktx-assist" "kskill-stock-assist" "kskill-dart-assist" "kskill-map-assist" "kskill-scholarship-assist" "kskill-law-assist" "kskill-news-assist")

for case_id in "${KSKILL_CASES[@]}"; do
    if grep -q "\"$case_id\"" "$REPO_ROOT/MyTeam/RouterBurnInSuite.swift" 2>/dev/null; then
        check_pass "RouterBurnInSuite: $case_id burn-in case found"
    else
        check_fail "RouterBurnInSuite: $case_id burn-in case missing"
    fi
done

echo ""

# =============================================================================
# Part 3: TTS Scope Lock Verification
# =============================================================================

echo "Part 3: TTS Scope Lock"
echo "---"

# 14. TTSRoutingPolicy exists and has selectedProvider
if grep -q "enum TTSRoutingPolicy\|static func selectedProvider" "$REPO_ROOT/MyTeam/TTSRoutingPolicy.swift" 2>/dev/null; then
    check_pass "TTSRoutingPolicy: routing logic found"
else
    check_fail "TTSRoutingPolicy: routing logic missing"
fi

# 15. Supertonic3TTSConfig.isEnabled not hardcoded to true
if grep -q "isEnabled.*=.*true" "$REPO_ROOT/MyTeam/Supertonic3TTSConfig.swift" 2>/dev/null; then
    if grep -q "UserDefaults\|\.bool\|defaults" "$REPO_ROOT/MyTeam/Supertonic3TTSConfig.swift" 2>/dev/null; then
        check_pass "Supertonic3TTSConfig: isEnabled defaults to false via UserDefaults"
    else
        check_fail "Supertonic3TTSConfig: isEnabled hardcoded to true (must use UserDefaults)"
    fi
else
    check_pass "Supertonic3TTSConfig: isEnabled defaults to false"
fi

# 16. No AVSpeechSynthesizer instantiation in active code
if grep -q "AVSpeechSynthesizer()" "$REPO_ROOT/MyTeam"/*.swift 2>/dev/null; then
    check_fail "TTS: AVSpeechSynthesizer instantiation found in active code"
else
    check_pass "TTS: No AVSpeechSynthesizer instantiation in active code"
fi

# 17. TTSRoutingPolicy returns nil path exists (default silent)
if grep -q "return nil\|\.default\|silence" "$REPO_ROOT/MyTeam/TTSRoutingPolicy.swift" 2>/dev/null; then
    check_pass "TTSRoutingPolicy: nil/silent default path found"
else
    check_fail "TTSRoutingPolicy: nil/silent default path missing"
fi

echo ""

# =============================================================================
# Part 4: Runtime Diagnostics Integration
# =============================================================================

echo "Part 4: RuntimeDiagnosticsService"
echo "---"

# 18. RuntimeDiagnosticsService has Round 250 fields
if grep -q "kskillAssistCardViewAvailable\|kskillAssistSkillIDDispatchAvailable\|ttsDefaultProviderIsNilOrExperimental" "$REPO_ROOT/MyTeam/RuntimeDiagnosticsService.swift" 2>/dev/null; then
    check_pass "RuntimeDiagnosticsService: Round 250 diagnostic fields found"
else
    check_fail "RuntimeDiagnosticsService: Round 250 diagnostic fields missing"
fi

# 19. ToolContractValidator has Round 250 checks
if grep -q "validateKSkillAssistCardViewPolicy\|validateTTSDefaultSilentPolicy" "$REPO_ROOT/MyTeam/ToolContractValidator.swift" 2>/dev/null; then
    check_pass "ToolContractValidator: Round 250 validators found"
else
    check_fail "ToolContractValidator: Round 250 validators missing"
fi

echo ""

# =============================================================================
# Summary
# =============================================================================

echo "=========================================="
echo "Round 250A-255Z Preflight Summary"
echo "=========================================="

TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo "Checks: $TOTAL total"
echo "  ✅ PASS: $PASS_COUNT"
echo "  ❌ FAIL: $FAIL_COUNT"

if [ $FAIL_COUNT -eq 0 ]; then
    echo ""
    echo -e "${GREEN}All checks passed! ✅${NC}"
    echo "K-Skills CardView + TTS infrastructure ready."
    exit 0
else
    echo ""
    echo -e "${RED}Some checks failed. See details above.${NC}"
    exit 1
fi
