# Fallback Execution Policy

**Round:** 246B-ACTION  
**원칙:** 막히면 가능한 것을 한다. 빈손으로 보내지 않는다.

---

## Fallback 결정 계층

```
1. GoalGate.executionFallbackDecision()
   └── capability .blocked → .directChat (LLM 호출, 초안 제공)

2. SkillAvailabilityResolver.availability(for:)
   └── .assistOnly → runDirectChatFallback (API 없이 LLM만으로 가능한 도움)

3. CapabilityFallbackService.fallbackAction(availability:)
   └── .planned → plannedNotice + directChat
   └── .approvalBound → approvalRequired + directChat
   └── .blocked → hardBlock (정말 안 되는 것만)

4. CapabilityFallbackService.fallbackAction(toolResultStatus:)
   └── .approvalRequired → askForConfirmation
   └── .planned → plannedNotice
   └── .unavailable → directChat
   └── .blocked → hardBlock

5. ToolResultPresentationPolicy.presentation(for:)
   └── ToolResult.status → ToolResultPresentation (UI 레이어 매핑)
```

---

## FallbackAction 종류

| FallbackAction | 의미 | 사용자 경험 |
|---|---|---|
| `.directChat(message)` | LLM으로 초안/정리 제공 | "도와드릴 수 있는 범위에서 정리해드릴게요" |
| `.draftOnly(prompt)` | 초안만, 실행 없음 | "실행 없이 초안을 먼저 보여드릴게요" |
| `.askForFile(message)` | 파일 요청 | "검토할 파일을 올려주세요" |
| `.askForConfirmation(request)` | 승인 배너 표시 | ApprovalRequiredCardView |
| `.plannedNotice(message)` | 준비 중 안내 + 가능한 도움 | "아직 직접 실행은 준비 중입니다. 정리해드릴게요." |
| `.hardBlock(message)` | 안전 정책 차단 | "이 작업은 실행할 수 없습니다." |

---

## 레이어 책임 분리

```
ToolExecutionLayer:
  - typed ToolResultStatus만 반환
  - LLM 호출 없음
  - UI 참조 없음

WorkflowEngine:
  - ToolResult 수집 + typed 상태 분류
  - WorkflowResult에 approvalRequiredRequests / plannedMessages 포함

WorkflowOrchestrator:
  - WorkflowResult 받아 후처리
  - addPendingApproval() 호출
  - runDirectChatFallback() 호출
  - CapabilityFallbackService로 pivot 결정

CapabilityFallbackService:
  - FeatureAvailability → FallbackAction 변환
  - ToolResultStatus → FallbackAction 변환
  - LLM/UI 직접 호출 없음 (결정만)
```

---

## directChat fallback 필수 조건

`runDirectChatFallback()`은 반드시 실제 LLM 호출까지 이어진다.
"안내 메시지만 띄우고 return" 패턴은 금지.

```swift
// ✅ 올바른 패턴
await runDirectChatFallback(
    userMessage: "\(fallbackMessage)\n\n원래 요청: \(userMessage)",
    roomID: roomID,
    manager: manager,
    reason: "planned skill fallback"
)

// ❌ 금지 패턴
manager.addChatLog(text: "아직 준비 중입니다.")
return  // LLM 호출 없이 종료
```
