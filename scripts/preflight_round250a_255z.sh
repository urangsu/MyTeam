#!/usr/bin/env bash
# Round 250A-255Z: AssistOnly UX + TTS Lab Stabilization Pack
# Preflight validation — 12 checks.
# Usage: bash scripts/preflight_round250a_255z.sh

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

echo "=== Round 250A-255Z Preflight ==="

# Check 1: KSkillAssistCardView.swift exists
check "KSkillAssistCardView.swift exists" \
    "$([ -f MyTeam/KSkillAssistCardView.swift ] && echo 1 || echo 0)"

# Check 2: isAssistSkillID function in KSkillAssistRuntime
check "isAssistSkillID() defined in KSkillAssistRuntime" \
    "$(grep -q 'isAssistSkillID' MyTeam/KSkillAssistRuntime.swift && echo 1 || echo 0)"

# Check 3: parseSections function in KSkillAssistRuntime
check "parseSections() defined in KSkillAssistRuntime" \
    "$(grep -q 'parseSections' MyTeam/KSkillAssistRuntime.swift && echo 1 || echo 0)"

# Check 4: SkillResultRendererView dispatches to KSkillAssistCardView
check "SkillResultRendererView dispatches via isAssistSkillID" \
    "$(grep -q 'isAssistSkillID' MyTeam/SkillResultRendererView.swift && echo 1 || echo 0)"

# Check 5: KSkillAssistCardView in SkillResultRendererView
check "KSkillAssistCardView used in SkillResultRendererView" \
    "$(grep -q 'KSkillAssistCardView' MyTeam/SkillResultRendererView.swift && echo 1 || echo 0)"

# Check 6: RouterBurnInSuite has kskill-ktx-assist case
check "RouterBurnInSuite has kskill-ktx-assist" \
    "$(grep -q 'kskill-ktx-assist' MyTeam/RouterBurnInSuite.swift && echo 1 || echo 0)"

# Check 7: RouterBurnInSuite has kskill-stock-assist case
check "RouterBurnInSuite has kskill-stock-assist" \
    "$(grep -q 'kskill-stock-assist' MyTeam/RouterBurnInSuite.swift && echo 1 || echo 0)"

# Check 8: RouterBurnInSuite has all 7 kskill burn-in cases
KSKILL_COUNT=$(grep -c 'kskill-' MyTeam/RouterBurnInSuite.swift 2>/dev/null || echo 0)
check "RouterBurnInSuite has 7 kskill burn-in cases (found: $KSKILL_COUNT)" \
    "$([ "$KSKILL_COUNT" -ge 7 ] && echo 1 || echo 0)"

# Check 9: KSkillAssistCardView renders hardBlockedActions (never in DisclosureGroup in code)
BLOCKED_HAS_SECTION=$(grep -c 'hardBlockedSection' MyTeam/KSkillAssistCardView.swift 2>/dev/null || true)
BLOCKED_HAS_DISCLOSURE=$(grep -v '^\s*//' MyTeam/KSkillAssistCardView.swift | grep -c 'DisclosureGroup' 2>/dev/null || true)
check "KSkillAssistCardView hardBlockedSection exists and not in DisclosureGroup (code)" \
    "$([ "${BLOCKED_HAS_SECTION:-0}" -ge 1 ] && [ "${BLOCKED_HAS_DISCLOSURE:-0}" -eq 0 ] && echo 1 || echo 0)"

# Check 10: No AVSpeechSynthesizer in non-comment code (excluding inline comments and policy strings)
AVEECH_HITS=$(grep -v '^\s*//' MyTeam/*.swift 2>/dev/null | grep -v '"[^"]*AVSpeech[^"]*"' | grep -v '//.*AVSpeechSynthesizer' | grep -c 'AVSpeechSynthesizer' 2>/dev/null || true)
check "No AVSpeechSynthesizer in active code (found: ${AVEECH_HITS:-0} hits)" \
    "$([ "${AVEECH_HITS:-0}" -eq 0 ] && echo 1 || echo 0)"

# Check 11: Supertonic3TTSConfig.isEnabled reads from UserDefaults (not hardcoded true)
check "Supertonic3TTSConfig.isEnabled reads UserDefaults (not hardcoded true)" \
    "$(grep -q 'UserDefaults' MyTeam/Supertonic3TTSConfig.swift && ! grep -q 'isEnabled.*= true' MyTeam/Supertonic3TTSConfig.swift && echo 1 || echo 0)"

# Check 12: TTSRoutingPolicy selectedProvider returns nil path
check "TTSRoutingPolicy has nil (silent) return path" \
    "$(grep -q 'return nil' MyTeam/TTSRoutingPolicy.swift && echo 1 || echo 0)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && echo "ALL PASS" && exit 0 || exit 1
