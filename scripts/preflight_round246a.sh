#!/usr/bin/env bash
# preflight_round246a.sh
# Round 246A-UNBLOCK: 기능 막는 요소 감사 및 해소 검증
# Cloud 환경 — xcodebuild 실행하지 않음

set -euo pipefail
PASS=0; FAIL=0
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MT="$ROOT/MyTeam"

ok()   { echo "  ✅  $1"; ((PASS++)) || true; }
fail() { echo "  ❌  $1"; ((FAIL++)) || true; }

echo ""
echo "══════════════════════════════════════════"
echo "  Round 246A-UNBLOCK Preflight"
echo "══════════════════════════════════════════"
echo ""

# P0-1: blockedDecision 코드 사용 제거 (주석 제외, executionFallbackDecision으로 rename)
grep -v "^[[:space:]]*//" "$MT/WorkflowOrchestrator.swift" "$MT/GoalGate.swift" 2>/dev/null \
  | grep -q "blockedDecision" \
  && fail "blockedDecision 코드에 잔존 — executionFallbackDecision으로 rename 미완료" \
  || ok "blockedDecision 코드 제거 완료 (rename 완료)"

# P0-1: executionFallbackDecision 존재
grep -q "executionFallbackDecision" "$MT/GoalGate.swift" \
  && ok "GoalGate.executionFallbackDecision 존재" \
  || fail "GoalGate.executionFallbackDecision 없음"

# P0-1: runDirectChatFallback 존재 (LLM까지 연결)
grep -q "runDirectChatFallback" "$MT/WorkflowOrchestrator.swift" \
  && ok "WorkflowOrchestrator.runDirectChatFallback 존재" \
  || fail "WorkflowOrchestrator.runDirectChatFallback 없음"

# P0-1: runChitchatOnly 호출 (LLM 실제 호출)
grep -q "runChitchatOnly" "$MT/WorkflowOrchestrator.swift" \
  && ok "runDirectChatFallback이 runChitchatOnly 호출 (LLM 연결 확인)" \
  || fail "runChitchatOnly 호출 없음 — LLM 미연결"

# P0-2: ToolResultStatus.approvalRequired 존재
grep -q "case approvalRequired" "$MT/AgentTool.swift" \
  && ok "ToolResultStatus.approvalRequired 존재" \
  || fail "ToolResultStatus.approvalRequired 없음"

# P0-2: ToolResultStatus.planned 존재
grep -q "case planned" "$MT/AgentTool.swift" \
  && ok "ToolResultStatus.planned 존재" \
  || fail "ToolResultStatus.planned 없음"

# P0-2: ToolResultStatus.unavailable 존재
grep -q "case unavailable" "$MT/AgentTool.swift" \
  && ok "ToolResultStatus.unavailable 존재" \
  || fail "ToolResultStatus.unavailable 없음"

# P0-2: .future → .planned 반환 (더 이상 .blocked로 뭉개지 않음)
grep -q "resultStatus = .planned" "$MT/ToolExecutionLayer.swift" \
  && ok "ToolExecutionLayer .future → .planned 반환" \
  || fail "ToolExecutionLayer .future → .planned 변환 없음"

# P0-2: .requiresApproval → .approvalRequired 반환
grep -q "resultStatus = .approvalRequired" "$MT/ToolExecutionLayer.swift" \
  && ok "ToolExecutionLayer .requiresApproval → .approvalRequired 반환" \
  || fail "ToolExecutionLayer .approvalRequired 반환 없음"

# P0-3: PendingApprovalRequest 모델 존재
grep -q "struct PendingApprovalRequest" "$MT/ApprovalPolicy.swift" \
  && ok "PendingApprovalRequest 모델 존재" \
  || fail "PendingApprovalRequest 모델 없음"

# P0-3: ApprovalStatus enum 존재
grep -q "enum ApprovalStatus" "$MT/ApprovalPolicy.swift" \
  && ok "ApprovalStatus enum 존재" \
  || fail "ApprovalStatus enum 없음"

# P0-4: 위임 모드가 capability gate를 우회하지 않음
# runDirectChatFallback이 isDelegationRequest 조건과 분리되어야 함
grep -q "!DelegatedWorkflowDetector.isDelegationRequest" "$MT/WorkflowOrchestrator.swift" \
  && fail "isDelegationRequest가 여전히 capability gate를 우회합니다 (P0-4 미완)" \
  || ok "P0-4: delegation gate 우회 제거 확인"

# P1-2: AICallBudgetTier enum 존재
grep -q "enum AICallBudgetTier" "$MT/AICallBudgetManager.swift" \
  && ok "AICallBudgetTier enum 존재" \
  || fail "AICallBudgetTier enum 없음"

# P1-2: beginSession(tier:) 존재
grep -q "func beginSession.*tier.*AICallBudgetTier" "$MT/AICallBudgetManager.swift" \
  && ok "beginSession(tier:) 함수 존재" \
  || fail "beginSession(tier:) 없음"

# P1-2: rolling limit 완화 확인 (5 → 10)
grep -q "rollingWindowLimit.*10\|10.*rollingWindowLimit" "$MT/AICallBudgetManager.swift" \
  && ok "rolling limit 완화 (10회)" \
  || fail "rolling limit 미완화 (여전히 5회)"

# P1-3: FeatureAvailability enum 존재 (HOTFIX 후: FeatureAvailability.swift로 분리)
grep -q "enum FeatureAvailability" "$MT/FeatureAvailability.swift" 2>/dev/null \
  && ok "FeatureAvailability enum 존재 (FeatureAvailability.swift)" \
  || fail "FeatureAvailability enum 없음"

# P1-3: DART assistOnly 명시
grep -q "assistOnly" "$MT/BuiltInKoreanSkills.swift" \
  && ok "DART assistOnly 명시" \
  || fail "DART assistOnly 없음"

# P1-5: ImplementationLevel enum 존재
grep -q "enum ImplementationLevel" "$MT/ObservationModels.swift" \
  && ok "ImplementationLevel enum 존재" \
  || fail "ImplementationLevel enum 없음"

# P1-5: DownloadsFolderWatcher에 implementationLevel 필드
grep -q "implementationLevel" "$MT/DownloadsFolderWatcher.swift" \
  && ok "DownloadsFolderWatcher.implementationLevel 존재" \
  || fail "DownloadsFolderWatcher.implementationLevel 없음"

# P1-5: ClipboardContextReader implementationLevel
grep -q "implementationLevel" "$MT/ClipboardContextReader.swift" \
  && ok "ClipboardContextReader.implementationLevel 존재" \
  || fail "ClipboardContextReader.implementationLevel 없음"

# P1-5: ScreenObservationPolicy implementationLevel
grep -q "implementationLevel" "$MT/ScreenObservationPolicy.swift" \
  && ok "ScreenObservationPolicy.implementationLevel 존재" \
  || fail "ScreenObservationPolicy.implementationLevel 없음"

# P1-6: OfficeReviewExecutionStatus 존재
grep -q "enum OfficeReviewExecutionStatus" "$MT/OfficeReviewInputPolicy.swift" \
  && ok "OfficeReviewExecutionStatus enum 존재" \
  || fail "OfficeReviewExecutionStatus enum 없음"

# P1-6: "supported" 표현 제거 (case 선언에서)
grep -q "case supported" "$MT/OfficeReviewInputPolicy.swift" \
  && fail "OfficeReviewInputPolicy에 'case supported' 잔존 — 제거 필요" \
  || ok "OfficeReviewInputPolicy 'case supported' 제거 완료"

# RuntimeDiagnosticsService 246A fields
grep -q "goalGateFallbackFunctional\|toolLayerTypedResultAvailable" "$MT/RuntimeDiagnosticsService.swift" \
  && ok "RuntimeDiagnosticsService 246A 필드 존재" \
  || fail "RuntimeDiagnosticsService 246A 필드 없음"

# ToolContractValidator 246A validators
grep -q "validateGoalGateFallbackPolicy\|validateToolLayerTypedResultPolicy" "$MT/ToolContractValidator.swift" \
  && ok "ToolContractValidator 246A validators 존재" \
  || fail "ToolContractValidator 246A validators 없음"

# 246A-HOTFIX: FeatureAvailability.swift 분리 확인
[ -f "$MT/FeatureAvailability.swift" ] \
  && ok "FeatureAvailability.swift 존재 (분리 완료)" \
  || fail "FeatureAvailability.swift 없음"

# 246A-HOTFIX: BuiltInKoreanSkills 내부 enum FeatureAvailability 없음
grep -q "^enum FeatureAvailability" "$MT/BuiltInKoreanSkills.swift" 2>/dev/null \
  && fail "BuiltInKoreanSkills.swift에 enum FeatureAvailability 잔존 — 분리 필요" \
  || ok "BuiltInKoreanSkills 내부 FeatureAvailability 제거 완료"

# 246A-HOTFIX: SkillAvailabilityResolver.swift 존재
[ -f "$MT/SkillAvailabilityResolver.swift" ] \
  && ok "SkillAvailabilityResolver.swift 존재" \
  || fail "SkillAvailabilityResolver.swift 없음"

# 246A-HOTFIX: SkillAvailabilityResolver가 korean.dart를 assistOnly로 처리
grep -q "korean.dart" "$MT/SkillAvailabilityResolver.swift" \
  && ok "SkillAvailabilityResolver에 korean.dart assistOnly 처리 존재" \
  || fail "SkillAvailabilityResolver korean.dart 처리 없음"

# 246A-HOTFIX: CapabilityFallbackService.swift 존재
[ -f "$MT/CapabilityFallbackService.swift" ] \
  && ok "CapabilityFallbackService.swift 존재" \
  || fail "CapabilityFallbackService.swift 없음"

# 246A-HOTFIX: FallbackAction enum 존재
grep -q "enum FallbackAction" "$MT/CapabilityFallbackService.swift" \
  && ok "FallbackAction enum 존재" \
  || fail "FallbackAction enum 없음"

# 246A-HOTFIX: OfficeReviewInputPolicy 중복 case 없음
grep -q "taxInvoiceComparison, .taxInvoiceComparison" "$MT/OfficeReviewInputPolicy.swift" \
  && fail "OfficeReviewInputPolicy에 .taxInvoiceComparison 중복 case 잔존" \
  || ok "OfficeReviewInputPolicy 중복 case 제거 완료"

# 246A-HOTFIX: RuntimeDiagnostics HOTFIX 필드 존재
grep -q "featureAvailabilitySeparatedFileAvailable\|skillAvailabilityResolverAvailable\|capabilityFallbackServiceAvailable" "$MT/RuntimeDiagnosticsService.swift" \
  && ok "RuntimeDiagnosticsService HOTFIX 필드 존재" \
  || fail "RuntimeDiagnosticsService HOTFIX 필드 없음"

# 246A-HOTFIX: ToolContractValidator HOTFIX validators 존재
grep -q "validateFeatureAvailabilitySeparatedPolicy\|validateCapabilityFallbackServicePolicy" "$MT/ToolContractValidator.swift" \
  && ok "ToolContractValidator HOTFIX validators 존재" \
  || fail "ToolContractValidator HOTFIX validators 없음"

# pbxproj 등록 확인
if grep -q "FeatureAvailability\|SkillAvailabilityResolver\|CapabilityFallbackService" "$MT/MyTeam.xcodeproj/project.pbxproj" 2>/dev/null; then
  ok "pbxproj에 신규 파일 등록됨"
else
  fail "pbxproj 신규 파일 미등록 — Mac build 후 등록 필요"
fi

# git diff whitespace check
cd "$ROOT"
git diff --check HEAD 2>/dev/null \
  && ok "git diff --check 통과 (whitespace 오류 없음)" \
  || fail "git diff --check 실패"

echo ""
echo "══════════════════════════════════════════"
if [ "$FAIL" -eq 0 ]; then
  echo "  ✅  PASSED  $PASS/$((PASS+FAIL))"
else
  echo "  ❌  FAILED  PASS=$PASS FAIL=$FAIL"
fi
echo "══════════════════════════════════════════"
echo ""
echo "  ⚠️  Cloud 환경 — xcodebuild 실행 안 함"
echo "  Mac build: xcodebuild -scheme MyTeam -configuration Debug build"
echo ""

[ "$FAIL" -eq 0 ]
