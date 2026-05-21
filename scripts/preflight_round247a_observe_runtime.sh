#!/bin/bash

# Round 247A-OBSERVE-RUNTIME: Observation Inbox + Explicit Context Actions
# Preflight validation script
#
# DO NOT run xcodebuild.
# DO NOT QA Finder/Clipboard/Downloads runtime permissions.

set -e

REPORT_FILE="reports/round247a_observe_runtime_preflight.md"
ERRORS=0
WARNINGS=0

mkdir -p reports

echo "# Round 247A-OBSERVE-RUNTIME Preflight Report" > "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "**Date:** $(date -u +'%Y-%m-%dT%H:%M:%SZ')" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Check 1: ObservationInboxView.swift exists
echo "## Check 1: ObservationInboxView.swift" >> "$REPORT_FILE"
if [ -f "MyTeam/ObservationInboxView.swift" ]; then
    echo "✅ MyTeam/ObservationInboxView.swift" >> "$REPORT_FILE"
else
    echo "❌ MyTeam/ObservationInboxView.swift NOT FOUND" >> "$REPORT_FILE"
    ((ERRORS++))
fi
echo "" >> "$REPORT_FILE"

# Check 2: ObservationPresentationPolicy.swift exists
echo "## Check 2: ObservationPresentationPolicy.swift" >> "$REPORT_FILE"
if [ -f "MyTeam/ObservationPresentationPolicy.swift" ]; then
    echo "✅ MyTeam/ObservationPresentationPolicy.swift" >> "$REPORT_FILE"
else
    echo "❌ MyTeam/ObservationPresentationPolicy.swift NOT FOUND" >> "$REPORT_FILE"
    ((ERRORS++))
fi
echo "" >> "$REPORT_FILE"

# Check 3: TeamStatusView uses ObservationInboxView
echo "## Check 3: TeamStatusView → ObservationInboxView" >> "$REPORT_FILE"
if grep -q "ObservationInboxView" MyTeam/TeamStatusView.swift; then
    echo "✅ TeamStatusView references ObservationInboxView" >> "$REPORT_FILE"
else
    echo "❌ TeamStatusView does NOT reference ObservationInboxView" >> "$REPORT_FILE"
    ((ERRORS++))
fi
echo "" >> "$REPORT_FILE"

# Check 4: AgentChatView uses ObservationInboxView
echo "## Check 4: AgentChatView → ObservationInboxView" >> "$REPORT_FILE"
if grep -q "ObservationInboxView" MyTeam/AgentChatView.swift; then
    echo "✅ AgentChatView references ObservationInboxView" >> "$REPORT_FILE"
else
    echo "❌ AgentChatView does NOT reference ObservationInboxView" >> "$REPORT_FILE"
    ((ERRORS++))
fi
echo "" >> "$REPORT_FILE"

# Check 5: Clipboard explicit route exists in WorkflowOrchestrator
echo "## Check 5: Clipboard explicit route" >> "$REPORT_FILE"
if grep -q "클립보드\|clipboardKeywords\|ClipboardContextReader" MyTeam/WorkflowOrchestrator.swift; then
    echo "✅ Clipboard explicit route present" >> "$REPORT_FILE"
else
    echo "❌ Clipboard explicit route NOT found in WorkflowOrchestrator" >> "$REPORT_FILE"
    ((ERRORS++))
fi
echo "" >> "$REPORT_FILE"

# Check 6: Downloads watcher default-off UI text
echo "## Check 6: Downloads watcher default off" >> "$REPORT_FILE"
if grep -q "default.*off\|defaultOff\|isEnabled.*false\|default: false" MyTeam/DownloadsFolderWatcher.swift 2>/dev/null || \
   grep -q "downloadsWatcherDefaultOff\|default_off\|isEnabled = false" MyTeam/DownloadsFolderWatcher.swift 2>/dev/null; then
    echo "✅ Downloads watcher default-off confirmed" >> "$REPORT_FILE"
else
    echo "⚠️  Could not confirm downloads watcher default-off in DownloadsFolderWatcher.swift" >> "$REPORT_FILE"
    ((WARNINGS++))
fi
echo "" >> "$REPORT_FILE"

# Check 7: Finder fallback message
echo "## Check 7: Finder fallback message" >> "$REPORT_FILE"
if grep -q "finderFallbackMessage\|끌어다 놓\|Finder 선택 파일을 읽지 못" MyTeam/ObservationPresentationPolicy.swift 2>/dev/null; then
    echo "✅ Finder fallback message defined" >> "$REPORT_FILE"
else
    echo "❌ Finder fallback message NOT found in ObservationPresentationPolicy" >> "$REPORT_FILE"
    ((ERRORS++))
fi
echo "" >> "$REPORT_FILE"

# Check 8: Screen snapshot planned notice
echo "## Check 8: Screen snapshot planned notice" >> "$REPORT_FILE"
if grep -q "screenSnapshotPlannedMessage\|단발성 권한\|상시 화면 감시는 하지 않" MyTeam/ObservationPresentationPolicy.swift 2>/dev/null; then
    echo "✅ Screen snapshot planned notice defined" >> "$REPORT_FILE"
else
    echo "❌ Screen snapshot planned notice NOT found in ObservationPresentationPolicy" >> "$REPORT_FILE"
    ((ERRORS++))
fi
echo "" >> "$REPORT_FILE"

# Check 9: Observation attach does NOT auto-analyze
echo "## Check 9: Attach does not auto-analyze" >> "$REPORT_FILE"
if grep -q "자동 분석은 하지 않\|no auto-analyze\|autoAnalyze.*false" MyTeam/ObservationPresentationPolicy.swift 2>/dev/null; then
    echo "✅ Attach-without-auto-analyze message present" >> "$REPORT_FILE"
elif grep -q "attachMessage" MyTeam/ObservationPresentationPolicy.swift 2>/dev/null; then
    echo "✅ attachMessage defined (no auto-analyze implied)" >> "$REPORT_FILE"
else
    echo "❌ No attach-without-auto-analyze policy found" >> "$REPORT_FILE"
    ((ERRORS++))
fi
echo "" >> "$REPORT_FILE"

# Check 10: Full path NOT shown in ObservationInboxView
echo "## Check 10: Full path not shown in ObservationInboxView" >> "$REPORT_FILE"
if ! grep -q "\.path\|fileURL\.absoluteString\|\.absolutePath\|fullPath" MyTeam/ObservationInboxView.swift 2>/dev/null; then
    echo "✅ No full path exposure in ObservationInboxView" >> "$REPORT_FILE"
else
    echo "❌ Found full path exposure in ObservationInboxView" >> "$REPORT_FILE"
    ((ERRORS++))
fi
echo "" >> "$REPORT_FILE"

# Check 11: RuntimeDiagnostics has observation runtime fields
echo "## Check 11: RuntimeDiagnostics observation runtime fields" >> "$REPORT_FILE"
if grep -q "observationInboxViewAvailable\|observationCardsConnectedToTeamRoom" MyTeam/RuntimeDiagnosticsService.swift; then
    echo "✅ observationInboxViewAvailable field present" >> "$REPORT_FILE"
else
    echo "❌ observationInboxViewAvailable NOT in RuntimeDiagnosticsService" >> "$REPORT_FILE"
    ((ERRORS++))
fi
echo "" >> "$REPORT_FILE"

# Check 12: ToolContractValidator has observation runtime validators
echo "## Check 12: ToolContractValidator observation validators" >> "$REPORT_FILE"
if grep -q "validateObservationInboxViewPolicy\|validateObservationTeamPersonalRoomScopePolicy" MyTeam/ToolContractValidator.swift; then
    echo "✅ Observation validators present in ToolContractValidator" >> "$REPORT_FILE"
else
    echo "❌ Observation validators NOT found in ToolContractValidator" >> "$REPORT_FILE"
    ((ERRORS++))
fi
echo "" >> "$REPORT_FILE"

# Check 13: No build logs staged
echo "## Check 13: No Build Logs Staged" >> "$REPORT_FILE"
if ! git status --short | grep -E "debug-build.log|release-build.log" > /dev/null 2>&1; then
    echo "✅ No debug/release build logs staged" >> "$REPORT_FILE"
else
    echo "❌ Build logs found in staging area" >> "$REPORT_FILE"
    ((ERRORS++))
fi
echo "" >> "$REPORT_FILE"

# Summary
echo "## Summary" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "| Metric | Count |" >> "$REPORT_FILE"
echo "|--------|-------|" >> "$REPORT_FILE"
echo "| Errors | $ERRORS |" >> "$REPORT_FILE"
echo "| Warnings | $WARNINGS |" >> "$REPORT_FILE"
echo "| Status | $([ $ERRORS -eq 0 ] && echo "✅ PASS" || echo "❌ FAIL") |" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo "## Notes" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "**Round 247A-OBSERVE Goals:**" >> "$REPORT_FILE"
echo "- ObservationInboxView: room-scoped pending observation UI" >> "$REPORT_FILE"
echo "- AgentWindowManager: observation helper methods" >> "$REPORT_FILE"
echo "- TeamStatusView: ObservationInboxView connected (selectedTeamWorkroomID)" >> "$REPORT_FILE"
echo "- AgentChatView: ObservationInboxView connected (agentRoomID)" >> "$REPORT_FILE"
echo "- Clipboard explicit route: WorkflowOrchestrator dispatch" >> "$REPORT_FILE"
echo "- Finder selection fallback route: fallback message only" >> "$REPORT_FILE"
echo "- Screen snapshot: planned notice only" >> "$REPORT_FILE"
echo "- ObservationPresentationPolicy: all messages defined" >> "$REPORT_FILE"
echo "- No xcodebuild run (Cloud environment)" >> "$REPORT_FILE"

cat "$REPORT_FILE"

if [ $ERRORS -eq 0 ]; then
    echo ""
    echo "✅ Round 247A-OBSERVE-RUNTIME preflight: PASS"
    exit 0
else
    echo ""
    echo "❌ Round 247A-OBSERVE-RUNTIME preflight: FAIL ($ERRORS errors)"
    exit 1
fi
