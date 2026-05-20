#!/usr/bin/env bash
# preflight_round246b.sh — Round 246B-ACTION 검증
# 15개 체크: Approval Store/Banner/Card, ToolResultPresentationPolicy,
#             WorkflowEngine typed status, Orchestrator fallback wiring,
#             OfficeReview/Observation UX, docs, no forbidden patterns
set -euo pipefail

MT="$(cd "$(dirname "$0")/.." && pwd)/MyTeam"
SCRIPTS="$(dirname "$0")"
PASS=0; FAIL=0; WARN=0

ok()   { echo "  ✅ $*"; PASS=$((PASS + 1)); }
fail() { echo "  ❌ $*"; FAIL=$((FAIL + 1)); }
warn() { echo "  ⚠️  $*"; WARN=$((WARN + 1)); }

echo "=== Round 246B-ACTION preflight ==="
echo ""

# ─────────────────────────────────────────────────────────
# 1. PendingApprovalStore 존재 및 room-scoped 구조 확인
# ─────────────────────────────────────────────────────────
echo "[1] PendingApprovalStore"
if grep -q "class PendingApprovalStore" "$MT/PendingApprovalStore.swift" 2>/dev/null; then
  ok "PendingApprovalStore 정의 존재"
else
  fail "PendingApprovalStore.swift 없음 또는 정의 없음"
fi
if grep -q "requestsByRoomID" "$MT/PendingApprovalStore.swift" 2>/dev/null; then
  ok "room-scoped requestsByRoomID 구조 확인"
else
  fail "requestsByRoomID 없음 — room scope 미구현"
fi

# ─────────────────────────────────────────────────────────
# 2. ApprovalRequiredCardView 존재
# ─────────────────────────────────────────────────────────
echo ""
echo "[2] ApprovalRequiredCardView"
if grep -q "struct ApprovalRequiredCardView" "$MT/ApprovalRequiredCardView.swift" 2>/dev/null; then
  ok "ApprovalRequiredCardView 정의 존재"
else
  fail "ApprovalRequiredCardView.swift 없음"
fi
# 승인 재실행 구현 금지 확인 (246B는 상태 변경만)
if grep -q "executeApproved\|ToolExecutionLayer.*approved\|rerun.*approved" "$MT/ApprovalRequiredCardView.swift" 2>/dev/null; then
  fail "ApprovalRequiredCardView에 실제 재실행 로직이 있음 — 246B는 상태 변경만"
else
  ok "재실행 로직 없음 — 상태 변경만 확인"
fi

# ─────────────────────────────────────────────────────────
# 3. PendingApprovalBannerView 존재
# ─────────────────────────────────────────────────────────
echo ""
echo "[3] PendingApprovalBannerView"
if grep -q "struct PendingApprovalBannerView" "$MT/PendingApprovalBannerView.swift" 2>/dev/null; then
  ok "PendingApprovalBannerView 정의 존재"
else
  fail "PendingApprovalBannerView.swift 없음"
fi
if grep -q "approvalDraftOnlyRequested" "$MT/PendingApprovalBannerView.swift" 2>/dev/null; then
  ok "approvalDraftOnlyRequested Notification 존재"
else
  warn "approvalDraftOnlyRequested 없음 — draft-only 연결 확인 필요"
fi

# ─────────────────────────────────────────────────────────
# 4. ToolResultPresentationPolicy
# ─────────────────────────────────────────────────────────
echo ""
echo "[4] ToolResultPresentationPolicy"
if grep -q "enum ToolResultPresentation" "$MT/ToolResultPresentationPolicy.swift" 2>/dev/null; then
  ok "ToolResultPresentation enum 존재"
else
  fail "ToolResultPresentation enum 없음"
fi
if grep -q "enum ToolResultPresentationPolicy" "$MT/ToolResultPresentationPolicy.swift" 2>/dev/null; then
  ok "ToolResultPresentationPolicy enum 존재"
else
  fail "ToolResultPresentationPolicy 없음"
fi
# 4가지 필수 케이스 확인
for CASE in "normalMessage" "approvalRequired" "plannedNotice" "hardBlock"; do
  if grep -q "case $CASE" "$MT/ToolResultPresentationPolicy.swift" 2>/dev/null; then
    ok "ToolResultPresentation.${CASE} 존재"
  else
    fail "ToolResultPresentation.${CASE} 없음"
  fi
done

# ─────────────────────────────────────────────────────────
# 5. WorkflowResult typed status 전파
# ─────────────────────────────────────────────────────────
echo ""
echo "[5] WorkflowResult typed status"
if grep -q "approvalRequiredRequests" "$MT/WorkflowModels.swift" 2>/dev/null; then
  ok "WorkflowResult.approvalRequiredRequests 필드 존재"
else
  fail "WorkflowResult.approvalRequiredRequests 없음"
fi
if grep -q "plannedStepMessages" "$MT/WorkflowModels.swift" 2>/dev/null; then
  ok "WorkflowResult.plannedStepMessages 필드 존재"
else
  fail "WorkflowResult.plannedStepMessages 없음"
fi
if grep -q "unavailableStepMessages" "$MT/WorkflowModels.swift" 2>/dev/null; then
  ok "WorkflowResult.unavailableStepMessages 필드 존재"
else
  fail "WorkflowResult.unavailableStepMessages 없음"
fi

# ─────────────────────────────────────────────────────────
# 6. WorkflowEngine typed status 처리
# ─────────────────────────────────────────────────────────
echo ""
echo "[6] WorkflowEngine typed status 처리"
if grep -q "case .approvalRequired:" "$MT/WorkflowEngine.swift" 2>/dev/null; then
  ok "WorkflowEngine에서 .approvalRequired 처리"
else
  fail "WorkflowEngine에서 .approvalRequired 처리 없음"
fi
if grep -q "case .planned:" "$MT/WorkflowEngine.swift" 2>/dev/null; then
  ok "WorkflowEngine에서 .planned 처리"
else
  fail "WorkflowEngine에서 .planned 처리 없음"
fi
if grep -q "case .unavailable:" "$MT/WorkflowEngine.swift" 2>/dev/null; then
  ok "WorkflowEngine에서 .unavailable 처리"
else
  fail "WorkflowEngine에서 .unavailable 처리 없음"
fi

# ─────────────────────────────────────────────────────────
# 7. Orchestrator approval 자동 등록
# ─────────────────────────────────────────────────────────
echo ""
echo "[7] Orchestrator approval 자동 등록"
if grep -q "addPendingApproval" "$MT/WorkflowOrchestrator.swift" 2>/dev/null; then
  ok "WorkflowOrchestrator에서 addPendingApproval 호출"
else
  fail "WorkflowOrchestrator에서 addPendingApproval 없음"
fi
if grep -q "approvalRequiredRequests" "$MT/WorkflowOrchestrator.swift" 2>/dev/null; then
  ok "WorkflowOrchestrator에서 approvalRequiredRequests 처리"
else
  fail "WorkflowOrchestrator에서 approvalRequiredRequests 처리 없음"
fi

# ─────────────────────────────────────────────────────────
# 8. assistOnly 스킬 감지 wiring
# ─────────────────────────────────────────────────────────
echo ""
echo "[8] AssistOnly 스킬 감지 wiring"
if grep -q "SkillAvailabilityResolver.availability" "$MT/WorkflowOrchestrator.swift" 2>/dev/null; then
  ok "WorkflowOrchestrator에서 SkillAvailabilityResolver.availability 호출"
else
  fail "WorkflowOrchestrator에서 SkillAvailabilityResolver.availability 없음"
fi
if grep -q "assistOnly" "$MT/WorkflowOrchestrator.swift" 2>/dev/null; then
  ok "WorkflowOrchestrator에서 assistOnly 처리 확인"
else
  fail "WorkflowOrchestrator에서 assistOnly 처리 없음"
fi

# ─────────────────────────────────────────────────────────
# 9. OfficeReview assistOnly UX
# ─────────────────────────────────────────────────────────
echo ""
echo "[9] OfficeReview assistOnly UX"
if grep -q "noFileProvidedMessage" "$MT/OfficeReviewInputPolicy.swift" 2>/dev/null; then
  ok "OfficeReviewInputPolicy.noFileProvidedMessage 존재"
else
  fail "OfficeReviewInputPolicy.noFileProvidedMessage 없음"
fi
if grep -q "executionStatusMessage" "$MT/OfficeReviewInputPolicy.swift" 2>/dev/null; then
  ok "OfficeReviewInputPolicy.executionStatusMessage 존재"
else
  fail "OfficeReviewInputPolicy.executionStatusMessage 없음"
fi

# ─────────────────────────────────────────────────────────
# 10. Observation implementationLevel userFacingStatus
# ─────────────────────────────────────────────────────────
echo ""
echo "[10] Observation ImplementationLevel UX"
if grep -q "userFacingStatus" "$MT/ObservationModels.swift" 2>/dev/null; then
  ok "ImplementationLevel.userFacingStatus 존재"
else
  fail "ImplementationLevel.userFacingStatus 없음"
fi

# ─────────────────────────────────────────────────────────
# 11. 금지 패턴 확인
# ─────────────────────────────────────────────────────────
echo ""
echo "[11] 금지 패턴 확인"
# Gmail send 구현 금지
if grep -rq "GmailSend\|sendEmail.*compose\|MFMailCompose" "$MT/" 2>/dev/null; then
  fail "Gmail send 구현 감지 — 246B 금지"
else
  ok "Gmail send 구현 없음"
fi
# Calendar write 구현 금지 (EKEvent.save() 실제 실행 코드만 — 정책 선언/테스트 제외)
if grep -rn "EKEvent().*save\|ekStore\.save\|\.save(event\|EKEvent.*\.save(" "$MT/" 2>/dev/null | grep -v "RouterBurnInSuite\|StarterActionPolicy\|ConnectorCapabilityPolicy\|//.*calendarWrite" | grep -q .; then
  fail "Calendar write 실제 구현 감지 — 246B 금지"
else
  ok "Calendar write 실제 구현 없음"
fi
# 자동 결제/로그인 금지 (246B 신규 파일에 StoreKit 결제 실행 추가 금지)
# PurchaseManager.swift, CharacterGalleryView.swift 는 기존 파일 — 제외
if grep -rn "\.purchase(\|autoLogin()" "$MT/" 2>/dev/null \
    | grep -v "PurchaseManager.swift\|CharacterGalleryView.swift\|//.*\|AppLog" \
    | grep -q .; then
  fail "자동 결제/로그인 신규 구현 감지 — 246B 금지"
else
  ok "자동 결제/로그인 없음"
fi

# ─────────────────────────────────────────────────────────
# 12. RuntimeDiagnosticsSnapshot 246B 필드
# ─────────────────────────────────────────────────────────
echo ""
echo "[12] RuntimeDiagnosticsSnapshot 246B 필드"
for FIELD in "approvalStoreAvailable" "approvalBannerViewAvailable" "toolResultPresentationPolicyAvailable" "assistOnlySkillDetectionWired" "workflowTypedStatusHandled"; do
  if grep -q "let $FIELD" "$MT/RuntimeDiagnosticsService.swift" 2>/dev/null; then
    ok "RuntimeDiagnosticsSnapshot.$FIELD 존재"
  else
    fail "RuntimeDiagnosticsSnapshot.$FIELD 없음"
  fi
done

# ─────────────────────────────────────────────────────────
# 13. ToolContractValidator 246B validators
# ─────────────────────────────────────────────────────────
echo ""
echo "[13] ToolContractValidator 246B validators"
for FUNC in "validateApprovalStoreAvailablePolicy" "validateToolResultPresentationPolicyAvailable" "validateWorkflowTypedStatusHandledPolicy" "validateApprovalRequiredAutoRegisteredPolicy"; do
  if grep -q "$FUNC" "$MT/ToolContractValidator.swift" 2>/dev/null; then
    ok "ToolContractValidator.$FUNC 존재"
  else
    fail "ToolContractValidator.$FUNC 없음"
  fi
done

# ─────────────────────────────────────────────────────────
# 14. 246A 전제조건 확인 (246B는 246A 위에 있음)
# ─────────────────────────────────────────────────────────
echo ""
echo "[14] 246A 전제조건 확인"
if grep -q "executionFallbackDecision" "$MT/GoalGate.swift" 2>/dev/null; then
  ok "GoalGate.executionFallbackDecision 존재 (246A P0-1)"
else
  fail "GoalGate.executionFallbackDecision 없음 — 246A P0-1 미완"
fi
if grep -q "enum AICallBudgetTier" "$MT/AICallBudgetManager.swift" 2>/dev/null; then
  ok "AICallBudgetTier enum 존재 (246A P1-2)"
else
  fail "AICallBudgetTier enum 없음 — 246A P1-2 미완"
fi
if grep -q "enum FeatureAvailability" "$MT/FeatureAvailability.swift" 2>/dev/null; then
  ok "FeatureAvailability.swift 분리 존재 (246A-HOTFIX)"
else
  fail "FeatureAvailability.swift 없음 — 246A-HOTFIX 미완"
fi

# ─────────────────────────────────────────────────────────
# 15. git 상태 (uncommitted files 경고)
# ─────────────────────────────────────────────────────────
echo ""
echo "[15] git 상태"
UNTRACKED=$(git -C "$(dirname "$MT")" status --porcelain 2>/dev/null | grep "^??" | wc -l | tr -d ' ')
MODIFIED=$(git -C "$(dirname "$MT")" status --porcelain 2>/dev/null | grep -v "^??" | wc -l | tr -d ' ')
if [ "$UNTRACKED" -gt 0 ] || [ "$MODIFIED" -gt 0 ]; then
  warn "미커밋 변경 ${MODIFIED}개, 미추적 파일 ${UNTRACKED}개 — 커밋 전 확인 필요"
else
  ok "작업 트리 clean"
fi

# ─────────────────────────────────────────────────────────
echo ""
echo "=== 결과: ✅ ${PASS}  ❌ ${FAIL}  ⚠️  ${WARN} ==="
if [ "$FAIL" -gt 0 ]; then
  echo "❌ preflight 실패 — ${FAIL}개 항목 수정 필요"
  exit 1
else
  echo "✅ Round 246B-ACTION preflight 통과"
  exit 0
fi
