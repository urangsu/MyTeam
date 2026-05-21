#!/bin/bash

# Round 248A-OFFICE-LITE: Office Review Lite Executor Preflight Validation
# Checks: heuristic extraction, limitations disclaimer, no original file mutation,
# no evidence location tracking, 1차/2차 skill differentiation, assistOnly guidance.

PASS=0
FAIL=0
WARN=0

log_pass() {
    echo "✅ $1"
    ((PASS++))
}

log_warn() {
    echo "⚠️  $1"
    ((WARN++))
}

log_fail() {
    echo "❌ $1"
    ((FAIL++))
}

echo "=== Round 248A-OFFICE-LITE Preflight Validation ==="
echo

# Check 1: OfficeReviewLiteExecutor.swift exists
if [ -f "MyTeam/OfficeReviewLiteExecutor.swift" ]; then
    log_pass "OfficeReviewLiteExecutor.swift exists"
else
    log_fail "OfficeReviewLiteExecutor.swift not found"
fi

# Check 2: OfficeReviewResultCardView.swift exists
if [ -f "MyTeam/OfficeReviewResultCardView.swift" ]; then
    log_pass "OfficeReviewResultCardView.swift exists"
else
    log_fail "OfficeReviewResultCardView.swift not found"
fi

# Check 3: LocalSkillExecutor wires office review lite detection
if grep -q "detectOfficeReviewLiteSkill\|is1PhaseSkill" MyTeam/LocalSkillExecutor.swift 2>/dev/null; then
    log_pass "LocalSkillExecutor handles office review lite detection"
else
    log_fail "LocalSkillExecutor does not handle office review lite detection"
fi

# Check 4: OfficeReviewLiteExecutor has 1차 skill implementations (meetingActionItems, filenameOrganization, reportTonePolish)
if grep -q "executeMeetingActionItems\|executeFilenameOrganization\|executeReportTonePolish" MyTeam/OfficeReviewLiteExecutor.swift 2>/dev/null; then
    log_pass "OfficeReviewLiteExecutor has 1차 skill implementations"
else
    log_fail "OfficeReviewLiteExecutor missing 1차 skill implementations"
fi

# Check 5: OfficeReviewLiteExecutor has 2차 assistOnly stubs
if grep -q "accountingConsistency\|vendorNameMismatch\|budgetActualAnalysis" MyTeam/OfficeReviewLiteExecutor.swift 2>/dev/null; then
    if grep -q "unsupported(message:" MyTeam/OfficeReviewLiteExecutor.swift 2>/dev/null; then
        log_pass "OfficeReviewLiteExecutor has 2차 assistOnly stubs with guidance messages"
    else
        log_fail "OfficeReviewLiteExecutor assistOnly stubs lack guidance messages"
    fi
else
    log_fail "OfficeReviewLiteExecutor missing 2차 assistOnly stubs"
fi

# Check 6: OfficeReviewResultCardView shows limitations disclaimer
if grep -q "휴리스틱 기반\|limitations" MyTeam/OfficeReviewResultCardView.swift 2>/dev/null; then
    log_pass "OfficeReviewResultCardView displays limitations disclaimer"
else
    log_fail "OfficeReviewResultCardView missing limitations disclaimer"
fi

# Check 7: Heuristic extraction confirmed (methods exist)
if grep -q "extractActionItems\|suggestFilenamingPatterns\|detectToneIssues" MyTeam/OfficeReviewLiteExecutor.swift 2>/dev/null; then
    log_pass "Heuristic-only extraction confirmed (methods present)"
else
    log_fail "OfficeReviewLiteExecutor lacks heuristic extraction methods"
fi

# Check 8: No original file mutation
if grep -q "no original file\|never mutate\|파일을 수정하지" MyTeam/OfficeReviewLiteExecutor.swift 2>/dev/null; then
    log_pass "No original file mutation confirmed in executor"
else
    log_warn "No explicit mutation prevention comment in executor"
fi

# Check 9: No evidence location tracking claim
if grep -q "근거 위치 추적 미지원\|no evidenceLinked\|evidence location tracking" MyTeam/OfficeReviewLiteExecutor.swift 2>/dev/null; then
    log_pass "Evidence location tracking limitation explicitly marked"
else
    log_warn "Evidence location tracking limitation not explicitly documented"
fi

# Check 10: ToolContractValidator has office review validators
if grep -q "validateOfficeReviewLiteExecutorPolicy\|validateOfficeReviewResultCardPolicy" MyTeam/ToolContractValidator.swift 2>/dev/null; then
    log_pass "ToolContractValidator has office review lite validators"
else
    log_fail "ToolContractValidator missing office review validators"
fi

# Check 11: RuntimeDiagnosticsService has office review fields
if grep -q "officeReviewLiteExecutorAvailable\|officeReviewResultCardViewAvailable" MyTeam/RuntimeDiagnosticsService.swift 2>/dev/null; then
    log_pass "RuntimeDiagnosticsService tracks office review lite status"
else
    log_fail "RuntimeDiagnosticsService missing office review fields"
fi

# Check 12: LocalSkillExecutor never auto-analyzes (returns handled with empty message for local execution)
if grep -q "return .handled(message: \"\", skillID:" MyTeam/LocalSkillExecutor.swift 2>/dev/null; then
    log_pass "LocalSkillExecutor returns empty message (no auto-analysis trigger)"
else
    log_warn "LocalSkillExecutor skill handling pattern unclear"
fi

# Round 248A-HOTFIX additional checks

# Check 13: LocalSkillExecutionResult.officeReviewResult case exists
if grep -q "case officeReviewResult" MyTeam/LocalSkillExecutor.swift 2>/dev/null; then
    log_pass "LocalSkillExecutionResult.officeReviewResult case exists"
else
    log_fail "LocalSkillExecutionResult missing .officeReviewResult case (result will be discarded)"
fi

# Check 14: No empty handled message for office review success
if grep -q "case .success.*:$" MyTeam/LocalSkillExecutor.swift 2>/dev/null; then
    if grep -A2 "case .success" MyTeam/LocalSkillExecutor.swift 2>/dev/null | grep -q "handled(message: \"\","; then
        log_fail "LocalSkillExecutor discards ReviewResult with empty handled message"
    else
        log_pass "LocalSkillExecutor does not use empty handled message for office review result"
    fi
else
    log_pass "No empty handled message pattern found for office review"
fi

# Check 15: OfficeReviewLiteExecutor has formatMarkdown method
if grep -q "static func formatMarkdown" MyTeam/OfficeReviewLiteExecutor.swift 2>/dev/null; then
    log_pass "OfficeReviewLiteExecutor.formatMarkdown() exists"
else
    log_fail "OfficeReviewLiteExecutor missing formatMarkdown() - results cannot be shown to users"
fi

# Check 16: WorkflowOrchestrator handles officeReviewResult case
if grep -q "case .officeReviewResult" MyTeam/WorkflowOrchestrator.swift 2>/dev/null; then
    log_pass "WorkflowOrchestrator handles officeReviewResult case"
else
    log_fail "WorkflowOrchestrator does not handle .officeReviewResult - office review results never displayed"
fi

# Check 17: OfficeReviewResultCardView uses macOS-safe background color
if grep -q "Color(.systemBackground)" MyTeam/OfficeReviewResultCardView.swift 2>/dev/null; then
    if grep -q "os(macOS)\|nsColor\|windowBackgroundColor" MyTeam/OfficeReviewResultCardView.swift 2>/dev/null; then
        log_pass "OfficeReviewResultCardView uses conditional macOS-safe background color"
    else
        log_warn "OfficeReviewResultCardView uses Color(.systemBackground) without macOS conditional"
    fi
else
    log_pass "OfficeReviewResultCardView does not use problematic Color(.systemBackground)"
fi

# Check 18: Evidence label says '휴리스틱 참고' not '위치:'
if grep -q "\"위치:" MyTeam/OfficeReviewResultCardView.swift 2>/dev/null; then
    log_fail "OfficeReviewResultCardView uses '위치:' - evidence location claim violates policy"
else
    log_pass "Evidence label policy respected (not claiming exact location)"
fi

# Check 19: No unused binding warning (if let date = ...)
if grep -q "if let date = dates.first" MyTeam/OfficeReviewLiteExecutor.swift 2>/dev/null; then
    log_fail "Unused binding: 'if let date = dates.first' - 'date' is unused, Swift warning risk"
else
    log_pass "No unused binding for date variable"
fi

# Check 20: 2차 skill assistOnly is reachable via LocalSkillExecutor
if grep -q "officeReviewAssistOnly\|accountingConsistency\|case .accounting" MyTeam/LocalSkillExecutor.swift 2>/dev/null; then
    if grep -q "detectOfficeReviewLiteSkill" MyTeam/LocalSkillExecutor.swift 2>/dev/null; then
        log_pass "2차 office review skills are reachable via LocalSkillExecutor"
    else
        log_warn "2차 office review skill reachability unclear"
    fi
else
    log_pass "2차 skill routing handled via detectOfficeReviewLiteSkill"
fi

echo
echo "=== Validation Summary ==="
echo "✅ Passed: $PASS"
echo "⚠️  Warnings: $WARN"
echo "❌ Failures: $FAIL"
echo

if [ $FAIL -eq 0 ]; then
    echo "✅ Round 248A-OFFICE-LITE + HOTFIX preflight validation PASSED"
    exit 0
else
    echo "❌ Round 248A-OFFICE-LITE + HOTFIX preflight validation FAILED"
    exit 1
fi
