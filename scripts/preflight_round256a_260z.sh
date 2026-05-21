#!/usr/bin/env bash
# Round 256A-260Z: Character Bridge + Build Hygiene + App Store Finalization
# Preflight validation — 12 checks.
# Usage: bash scripts/preflight_round256a_260z.sh

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

echo "=== Round 256A-260Z Preflight ==="

# Check 1: WorkroomCharacterEvent has 7 new events
NEW_EVENT_COUNT=$(grep -c 'case fileReadStarted\|case verificationWarning\|case verificationFailed\|case approvalWaiting\|case taskCompleted\|case errorRecoveryStarted\|case longIdleTriggered' MyTeam/WorkroomCharacterEvent.swift 2>/dev/null || true)
check "WorkroomCharacterEvent has 7 new event cases (found: ${NEW_EVENT_COUNT:-0})" \
    "$([ "${NEW_EVENT_COUNT:-0}" -ge 7 ] && echo 1 || echo 0)"

# Check 2: CharacterReactionMapping has all 12 event cases
MAPPING_COUNT=$(grep -c 'case .workroomOpened\|case .workflowStarted\|case .documentCreated\|case .artifactReuseRequested\|case .multiRoomSwitched\|case .fileReadStarted\|case .verificationWarning\|case .verificationFailed\|case .approvalWaiting\|case .taskCompleted\|case .errorRecoveryStarted\|case .longIdleTriggered' MyTeam/WorkroomCharacterEvent.swift 2>/dev/null || true)
check "CharacterReactionMapping handles all 12 events (found: ${MAPPING_COUNT:-0})" \
    "$([ "${MAPPING_COUNT:-0}" -ge 12 ] && echo 1 || echo 0)"

# Check 3: CharacterReactionEventSink has 7 new notify methods
NOTIFY_COUNT=$(grep -c 'func notifyFileReadStarted\|func notifyVerificationWarning\|func notifyVerificationFailed\|func notifyApprovalWaiting\|func notifyTaskCompleted\|func notifyErrorRecoveryStarted\|func notifyLongIdle\|resetIdleTimer' MyTeam/CharacterReactionEventSink.swift 2>/dev/null || true)
check "CharacterReactionEventSink has new notify methods (found: ${NOTIFY_COUNT:-0})" \
    "$([ "${NOTIFY_COUNT:-0}" -ge 7 ] && echo 1 || echo 0)"

# Check 4: WorkflowOrchestrator wires notifyTaskCompleted for assistOnly
check "WorkflowOrchestrator notifyTaskCompleted wired for assistOnly" \
    "$(grep -q 'notifyTaskCompleted' MyTeam/WorkflowOrchestrator.swift && echo 1 || echo 0)"

# Check 5: WorkflowOrchestrator wires notifyDocumentGenerationStarted
check "WorkflowOrchestrator notifyDocumentGenerationStarted wired" \
    "$(grep -q 'notifyDocumentGenerationStarted' MyTeam/WorkflowOrchestrator.swift && echo 1 || echo 0)"

# Check 6: WorkflowOrchestrator wires notifyApprovalWaiting
check "WorkflowOrchestrator notifyApprovalWaiting wired" \
    "$(grep -q 'notifyApprovalWaiting' MyTeam/WorkflowOrchestrator.swift && echo 1 || echo 0)"

# Check 7: Idle timer in CharacterReactionEventSink (5분 비활성 → sleeping)
check "CharacterReactionEventSink has idle timer (300s)" \
    "$(grep -q 'idleTimeoutSeconds.*300\|300.*idleTimeout' MyTeam/CharacterReactionEventSink.swift && echo 1 || echo 0)"

# Check 8: KSkillsAssistRuntimePolicy.md exists
check "KSkillsAssistRuntimePolicy.md created" \
    "$([ -f docs/KSkillsAssistRuntimePolicy.md ] && echo 1 || echo 0)"

# Check 9: KTXAssistSafetyPolicy.md exists
check "KTXAssistSafetyPolicy.md created" \
    "$([ -f docs/KTXAssistSafetyPolicy.md ] && echo 1 || echo 0)"

# Check 10: CLAUDE.md updated with Round 256A-260Z
check "CLAUDE.md updated with Round 256A-260Z" \
    "$(grep -q '256A' .claude/CLAUDE.md && echo 1 || echo 0)"

# Check 11: Character files all registered in pbxproj
CHAR_REG=$(grep -c 'WorkroomCharacterEvent\|CharacterReactionEngine\|CharacterReactionEventSink' MyTeam/MyTeam.xcodeproj/project.pbxproj 2>/dev/null || true)
check "Character bridge files registered in pbxproj (found: ${CHAR_REG:-0} refs)" \
    "$([ "${CHAR_REG:-0}" -ge 3 ] && echo 1 || echo 0)"

# Check 12: AnimationState (character system) still intact
check "AnimationState enum still intact (sacred)" \
    "$(grep -q 'enum AnimationState' MyTeam/CharacterSpriteScene.swift && echo 1 || echo 0)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && echo "ALL PASS" && exit 0 || exit 1
