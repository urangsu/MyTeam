#!/usr/bin/env bash
# Round 261A-265Z: Remaining Skill Cards + Accounting Tax Skill
# Preflight validation — 12 checks.
# Usage: bash scripts/preflight_round261a_265z.sh

set -euo pipefail
cd "$(dirname "$0")/.."

PASS=0
FAIL=0

check() {
    local desc="$1"
    local result="$2"
    if [ "$result" = "1" ]; then
        echo "  PASS: $desc"
        PASS=$((PASS+1))
    else
        echo "  FAIL: $desc"
        FAIL=$((FAIL+1))
    fi
}

echo "=== Round 261A-265Z Preflight ==="

# Check 1: SpellCheckResultCardView.swift exists
check "SpellCheckResultCardView.swift created" \
    "$([ -f MyTeam/SpellCheckResultCardView.swift ] && echo 1 || echo 0)"

# Check 2: PrivacyTermsArtifactCardView.swift exists
check "PrivacyTermsArtifactCardView.swift created" \
    "$([ -f MyTeam/PrivacyTermsArtifactCardView.swift ] && echo 1 || echo 0)"

# Check 3: DiagnosticsResultCardView.swift exists
check "DiagnosticsResultCardView.swift created" \
    "$([ -f MyTeam/DiagnosticsResultCardView.swift ] && echo 1 || echo 0)"

# Check 4: AccountingTaxSummaryCardView.swift exists
check "AccountingTaxSummaryCardView.swift created" \
    "$([ -f MyTeam/AccountingTaxSummaryCardView.swift ] && echo 1 || echo 0)"

# Check 5: SkillResultRendererView dispatches all 4 new skill IDs
DISPATCH_COUNT=$(grep -c '"korean.spell-check"\|"korean.privacy-terms"\|"runtime.diagnostics"\|"korean.accounting-tax"' MyTeam/SkillResultRendererView.swift 2>/dev/null || true)
check "SkillResultRendererView dispatches 4 new skills (found: ${DISPATCH_COUNT:-0})" \
    "$([ "${DISPATCH_COUNT:-0}" -ge 4 ] && echo 1 || echo 0)"

# Check 6: AccountingTaxSummaryCardView has always-visible disclaimer
check "AccountingTaxSummaryCardView has non-collapsible disclaimer" \
    "$(grep -q 'disclaimer\|면책 조항\|참고용이며\|세무사' MyTeam/AccountingTaxSummaryCardView.swift && echo 1 || echo 0)"

# Check 7: AccountingTaxSummaryCardView disclaimer NOT inside DisclosureGroup
check "Disclaimer not in DisclosureGroup (always visible)" \
    "$(! grep -q 'DisclosureGroup' MyTeam/AccountingTaxSummaryCardView.swift && echo 1 || echo 0)"

# Check 8: BuiltInKoreanSkills has accounting-tax skill
check "BuiltInKoreanSkills has korean.accounting-tax skill" \
    "$(grep -q 'korean.accounting-tax' MyTeam/BuiltInKoreanSkills.swift && echo 1 || echo 0)"

# Check 9: BuiltInKoreanSkills.all includes accountingTaxSkill
check "BuiltInKoreanSkills.all array includes accountingTaxSkill" \
    "$(grep -q 'accountingTaxSkill' MyTeam/BuiltInKoreanSkills.swift && echo 1 || echo 0)"

# Check 10: New card files registered in pbxproj
CARD_REG=$(grep -c 'SpellCheckResultCardView\|PrivacyTermsArtifactCardView\|DiagnosticsResultCardView\|AccountingTaxSummaryCardView' MyTeam/MyTeam.xcodeproj/project.pbxproj 2>/dev/null || true)
check "4 new card files registered in pbxproj (found: ${CARD_REG:-0} refs)" \
    "$([ "${CARD_REG:-0}" -ge 8 ] && echo 1 || echo 0)"

# Check 11: SpellCheckResultCardView uses orange accent (design consistency)
check "SpellCheckResultCardView uses orange accent color" \
    "$(grep -q '\.orange' MyTeam/SpellCheckResultCardView.swift && echo 1 || echo 0)"

# Check 12: Prior round artifacts still intact (regression guard)
check "SkillResultRendererView still has KSkillAssistRuntime dispatch (regression guard)" \
    "$(grep -q 'isAssistSkillID' MyTeam/SkillResultRendererView.swift && echo 1 || echo 0)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && echo "ALL PASS" && exit 0 || exit 1
