# Approval UX Policy

**Round:** 246B-ACTION  
**원칙:** 위험한 실행만 막는다. 기능 자체를 막지 않는다.

---

## 승인 흐름 개요

```
ToolExecutionLayer
  └── result.status == .approvalRequired
        ↓
WorkflowEngine
  └── PendingApprovalRequest 생성 → approvalRequiredRequests 수집
        ↓
WorkflowOrchestrator
  └── manager.addPendingApproval(request)
        ↓
AgentWindowManager
  └── PendingApprovalStore.shared.add(request)
        ↓
PendingApprovalBannerView (composer 위 배너)
  └── 사용자가 열면 ApprovalRequiredCardView 표시
        ↓
사용자 선택:
  ├── "초안만 보기" → approvalDraftOnlyRequested Notification → directChat fallback
  ├── "취소" → status: .rejected
  └── "승인 대기 등록" → status: .approved (재실행은 246C에서 연결)
```

---

## 하드 블록 vs 승인 대기

| 상황 | 처리 | 근거 |
|---|---|---|
| `mailSend`, `calendarCreate` | `.blocked` (하드 블록) | 외부 쓰기, 실행 취소 불가 |
| `automaticLogin`, 결제, 파일 삭제 | `.blocked` (하드 블록) | 보안/개인정보 |
| `highRisk` 스킬 | `.approvalRequired` | 위험하지만 사용자가 확인 가능 |
| 기타 작업 | `.succeeded` 또는 `.failed` | 일반 실행 |

---

## PendingApprovalRequest 구조

```swift
struct PendingApprovalRequest: Identifiable, Sendable {
    let id: UUID
    let roomID: UUID          // room-scoped, 다른 방에 표시 안 함
    let toolName: String
    let input: [String: String]
    let riskLevel: ToolRiskLevel
    let reason: String
    let createdAt: Date
    let expiresAt: Date?      // nil = 만료 없음, 기본 24시간
    var status: ApprovalStatus // .pending / .approved / .rejected / .expired
}
```

---

## Room 격리 정책

- `PendingApprovalStore`는 `roomID`별로 요청을 격리한다.
- `PendingApprovalBannerView`는 현재 room의 pending만 표시한다.
- 다른 방의 approval은 보이지 않는다.

---

## 246B 제약 (다음 단계에서 해소)

- 승인 버튼: 상태만 변경 (`.pending` → `.approved`)
- 실제 재실행: 246C에서 `executeApproved(requestID:)` 연결
- diff preview / original write 승인 흐름: 246C+

---

## 금지 사항

- 승인 없이 `mailSend`, `calendarCreate` 실행 — 절대 금지
- Approval request를 room 외부로 표시 — 금지
- 만료 후 `expiresAt`을 갱신하여 재사용 — 금지
