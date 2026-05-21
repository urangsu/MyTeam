#!/usr/bin/env bash
# preflight_round266a_cloud_verify.sh
# Round 266A-CLOUD-VERIFY: AssistOnly Governance Cloud Static Verification
# Cloud static checked — Mac build pending — Manual QA pending — Submission not ready

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

PASS=0
FAIL=0
RESULTS=()

check() {
    local id="$1"
    local desc="$2"
    local result="$3"   # "pass" or "fail"
    local note="${4:-}"
    if [ "$result" = "pass" ]; then
        RESULTS+=("✅ CHECK $id: $desc${note:+ — $note}")
        PASS=$((PASS + 1))
    else
        RESULTS+=("❌ FAIL  $id: $desc${note:+ — $note}")
        FAIL=$((FAIL + 1))
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# CHECK 1: assistOnlySkillIDs property exists in SkillAvailabilityResolver
# ─────────────────────────────────────────────────────────────────────────────
if grep -q "assistOnlySkillIDs" MyTeam/SkillAvailabilityResolver.swift 2>/dev/null; then
    check 1 "assistOnlySkillIDs exists in SkillAvailabilityResolver" "pass"
else
    check 1 "assistOnlySkillIDs exists in SkillAvailabilityResolver" "fail" "Missing property"
fi

# ─────────────────────────────────────────────────────────────────────────────
# CHECK 2: accounting-tax assistOnly override exists
# ─────────────────────────────────────────────────────────────────────────────
if grep -q '"korean.accounting-tax"' MyTeam/SkillAvailabilityResolver.swift 2>/dev/null && \
   grep -q "return .assistOnly" MyTeam/SkillAvailabilityResolver.swift 2>/dev/null; then
    check 2 "accounting-tax assistOnly override in SkillAvailabilityResolver" "pass"
else
    check 2 "accounting-tax assistOnly override in SkillAvailabilityResolver" "fail" "Missing case or return"
fi

# ─────────────────────────────────────────────────────────────────────────────
# CHECK 3: accounting-tax disclaimer required text exists
# ─────────────────────────────────────────────────────────────────────────────
if grep -q "세무·회계 판단은 실제 증빙과 계약 구조에 따라 달라질 수 있으므로 전문가 확인이 필요합니다" \
       MyTeam/AccountingTaxSummaryCardView.swift 2>/dev/null; then
    check 3 "accounting-tax disclaimer text present in AccountingTaxSummaryCardView" "pass"
else
    check 3 "accounting-tax disclaimer text present in AccountingTaxSummaryCardView" "fail" "Exact disclaimer string missing"
fi

# ─────────────────────────────────────────────────────────────────────────────
# CHECK 4: accounting-tax disclaimer is always visible (not in DisclosureGroup)
# ─────────────────────────────────────────────────────────────────────────────
# Policy: the code comment "Always visible" must exist adjacent to disclaimer
# (added in Round 266A governance hardening, enforces non-collapsible constraint)
ALWAYS_VISIBLE=$(grep -n "Always visible\|non-collapsible" MyTeam/AccountingTaxSummaryCardView.swift 2>/dev/null || true)
if [ -n "$ALWAYS_VISIBLE" ]; then
    check 4 "accounting-tax disclaimer marked non-collapsible (Always visible comment present)" "pass"
else
    check 4 "accounting-tax disclaimer marked non-collapsible (Always visible comment present)" "fail" \
        "Missing 'Always visible' policy comment near disclaimer"
fi

# ─────────────────────────────────────────────────────────────────────────────
# CHECK 5: KSkillAssistRuntime user-facing section headers — Korean terms only
# ─────────────────────────────────────────────────────────────────────────────
HEADERS_OK=true
for header in "준비 체크리스트" "필요한 입력" "다음에 할 일" "직접 진행이 필요한 작업"; do
    if ! grep -q "$header" MyTeam/KSkillAssistRuntime.swift 2>/dev/null; then
        HEADERS_OK=false
        break
    fi
done
if [ "$HEADERS_OK" = "true" ]; then
    check 5 "KSkillAssistRuntime formatMarkdown uses Korean UX section headers" "pass"
else
    check 5 "KSkillAssistRuntime formatMarkdown uses Korean UX section headers" "fail" "One or more Korean section headers missing"
fi

# ─────────────────────────────────────────────────────────────────────────────
# CHECK 6: hardBlockedActions internal term NOT exposed in user-facing strings
#          (must not appear in Korean-facing quoted strings; struct field names OK)
# ─────────────────────────────────────────────────────────────────────────────
# The internal term 'hardBlockedActions' should only appear as Swift identifiers, not as user-facing strings
HARD_BLOCKED_USER_FACING=$(grep -n '".*hardBlockedActions.*"' MyTeam/KSkillAssistRuntime.swift 2>/dev/null) || HARD_BLOCKED_USER_FACING=""
if [ -z "$HARD_BLOCKED_USER_FACING" ]; then
    check 6 "hardBlockedActions not exposed in user-facing quoted strings" "pass"
else
    check 6 "hardBlockedActions not exposed in user-facing quoted strings" "fail" "Found: $HARD_BLOCKED_USER_FACING"
fi

# ─────────────────────────────────────────────────────────────────────────────
# CHECK 7: ToolScope does NOT have .assistOnly (it's a FeatureAvailability case)
# ─────────────────────────────────────────────────────────────────────────────
TOOLSCOPE_ASSISTONLY=$(grep -n "ToolScope.*assistOnly\|\.assistOnly.*ToolScope" \
    MyTeam/BuiltInKoreanSkills.swift MyTeam/ToolContractValidator.swift 2>/dev/null \
    | grep -v "^#\|^//" || true)
if [ -z "$TOOLSCOPE_ASSISTONLY" ]; then
    check 7 "No invalid ToolScope.assistOnly references in skill files" "pass"
else
    check 7 "No invalid ToolScope.assistOnly references in skill files" "fail" "Found: $TOOLSCOPE_ASSISTONLY"
fi

# ─────────────────────────────────────────────────────────────────────────────
# CHECK 8: RouterBurnInSuite has 10 governance burn-in cases
# ─────────────────────────────────────────────────────────────────────────────
KSKILL_CASES=$(grep -c '"맞춤법 검사해줘\|개인정보 처리방침 만들어줘\|세금 계산 도와줘\|매입세액 계산\|DART 공시 확인해줘\|KTX 예매 도와줘\|삼성전자 지금 사도\|장학금 신청 준비\|법령 찾아줘\|네이버 뉴스 요약해줘"' \
    MyTeam/RouterBurnInSuite.swift 2>/dev/null) || KSKILL_CASES=0
if [ "$KSKILL_CASES" -ge 10 ]; then
    check 8 "RouterBurnInSuite has 10 governance K-skill burn-in cases ($KSKILL_CASES found)" "pass"
else
    check 8 "RouterBurnInSuite has 10 governance K-skill burn-in cases" "fail" "Found $KSKILL_CASES (need 10)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# CHECK 9: Dedicated skill cards 4 routes exist in SkillResultRendererView
# ─────────────────────────────────────────────────────────────────────────────
CARDS_OK=true
for card in "SpellCheckResultCardView" "PrivacyTermsArtifactCardView" "DiagnosticsResultCardView" "AccountingTaxSummaryCardView"; do
    if ! grep -q "$card" MyTeam/SkillResultRendererView.swift 2>/dev/null; then
        CARDS_OK=false
        break
    fi
done
if [ "$CARDS_OK" = "true" ]; then
    check 9 "All 4 dedicated skill card routes present in SkillResultRendererView" "pass"
else
    check 9 "All 4 dedicated skill card routes present in SkillResultRendererView" "fail" "One or more dedicated cards missing"
fi

# ─────────────────────────────────────────────────────────────────────────────
# CHECK 10: Supertonic3 NOT set as default TTS provider (must be UserDefaults-gated)
# ─────────────────────────────────────────────────────────────────────────────
# isEnabled must read from UserDefaults, not be hardcoded true
if grep -q "UserDefaults.standard.bool" MyTeam/Supertonic3TTSConfig.swift 2>/dev/null && \
   ! grep -q "isEnabled.*=.*true\b" MyTeam/Supertonic3TTSConfig.swift 2>/dev/null; then
    check 10 "Supertonic3 isEnabled reads UserDefaults (not hardcoded true)" "pass"
else
    check 10 "Supertonic3 isEnabled reads UserDefaults (not hardcoded true)" "fail" "Possible hardcoded enabled state"
fi

# ─────────────────────────────────────────────────────────────────────────────
# CHECK 11: TTSLabView isolation — Supertonic3 referenced only in lab/diagnostic context
# ─────────────────────────────────────────────────────────────────────────────
# Supertonic3 should appear in: TTSLabView, Supertonic3* files, DiagnosticsResultCardView, RuntimeDiagnosticsService
SUPERTONIC3_OUTSIDE_LAB=$(grep -Rln "Supertonic3" MyTeam/ 2>/dev/null | grep -v \
    "Supertonic3\|TTSLabView\|RuntimeDiagnosticsService\|DiagnosticsResultCardView\|TTSRoutingPolicy\|ToolContractValidator\|ONNXRuntime\|TTSProviderModels\|SpeechManager\|project\.pbxproj\|\.md" || true)
if [ -z "$SUPERTONIC3_OUTSIDE_LAB" ]; then
    check 11 "Supertonic3 isolated to lab/diagnostic/routing files only" "pass"
else
    check 11 "Supertonic3 isolated to lab/diagnostic/routing files only" "fail" \
        "Found in unexpected files: $SUPERTONIC3_OUTSIDE_LAB"
fi

# ─────────────────────────────────────────────────────────────────────────────
# CHECK 12: No StoreKit/OAuth/Gmail/Calendar write changes in this round's commits
# ─────────────────────────────────────────────────────────────────────────────
RESTRICTED_CHANGES=$(git diff HEAD~2 -- \
    "MyTeam/StoreKit*" \
    "MyTeam/*OAuth*" \
    "MyTeam/*Gmail*" \
    "MyTeam/*CalendarWrite*" \
    2>/dev/null | grep "^+" | grep -v "^+++" | head -5 || true)
if [ -z "$RESTRICTED_CHANGES" ]; then
    check 12 "No StoreKit/OAuth/Gmail/CalendarWrite changes in Round 266A commits" "pass"
else
    check 12 "No StoreKit/OAuth/Gmail/CalendarWrite changes in Round 266A commits" "fail" \
        "Unexpected changes detected"
fi

# ─────────────────────────────────────────────────────────────────────────────
# CHECK 13: 4 policy docs exist
# ─────────────────────────────────────────────────────────────────────────────
DOCS_OK=true
for doc in "docs/KSkillAssistPolicy.md" "docs/SkillResultRenderingPolicy.md" \
           "docs/AccountingTaxSkillPolicy.md" "docs/TTSProviderPolicy.md"; do
    if [ ! -f "$doc" ]; then
        DOCS_OK=false
        break
    fi
done
if [ "$DOCS_OK" = "true" ]; then
    check 13 "All 4 policy docs present" "pass"
else
    check 13 "All 4 policy docs present" "fail" "One or more policy docs missing"
fi

# ─────────────────────────────────────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo " Round 266A-CLOUD-VERIFY — AssistOnly Governance Static Check"
echo "============================================================"
for r in "${RESULTS[@]}"; do
    echo "  $r"
done
echo ""
echo "  PASSED: $PASS / $((PASS + FAIL))"
echo ""
echo "  Cloud status:     Cloud static checked"
echo "  Mac build:        Mac build pending"
echo "  Manual QA:        Manual QA pending"
echo "  Submission:       Submission not ready"
echo "============================================================"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
