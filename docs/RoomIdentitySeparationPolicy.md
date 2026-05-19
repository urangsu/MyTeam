# Room Identity Separation Policy

**Version:** Round 241A-CORE  
**Date:** 2026-05-19

---

## Rule

팀 워크룸(Team Workroom)과 개인 에이전트 대화(Personal Agent Conversation)는 완전히 분리된 공간이다.
어느 쪽을 선택해도 다른 쪽의 상태를 변경하지 않는다.

---

## Team Workroom

| 속성 | 값 |
|---|---|
| 식별자 | `selectedTeamWorkroomID: UUID?` |
| agentIDs | `["team_all"]` 또는 2개 이상 |
| 콘텐츠 | 팀 메시지, 팀 아티팩트 |
| UI | TeamStatusView |
| 선택 API | `selectTeamWorkroom(_ roomID: UUID)` |

### 불변 규칙
- `openPersonalChat(for:)` 호출 시 **절대 변경되지 않음**
- 팀 워크룸 탭 클릭 시에만 `selectTeamWorkroom`을 통해 변경
- TeamStatusView의 모든 콘텐츠(아티팩트, 메시지 전송, 워크플로 취소)는 `selectedTeamWorkroomID` 기준

---

## Personal Agent Conversation

| 속성 | 값 |
|---|---|
| 현재 에이전트 | `activePersonalAgentID: String?` |
| 방 ID 맵 | `selectedPersonalConversationIDByAgentID: [String: UUID]` |
| 방 매핑 | `selectedPersonalConversationIDByAgentID[agentID]` → 없으면 `rooms.first { $0.agentIDs == [agentID] }` |
| agentIDs | 정확히 1개 |
| 콘텐츠 | 에이전트와의 1:1 대화 |
| UI | AgentChatView |
| 공식 선택 API | `openPersonalConversation(for agentID: String)` |
| 호환 래퍼 | `openPersonalChat(for agentID: String)` → `openPersonalConversation` 위임 |

### 불변 규칙
- `selectedTeamWorkroomID`를 절대 변경하지 않음
- `activePersonalAgentID`는 `selectedTeamWorkroomID`와 독립적으로 추적
- 개인 대화 사이드바에 메시지 내용 preview 금지 (방 이름만 표시)
- `selectedPersonalConversationIDByAgentID`는 `returnToTeamWorkroom()` 시 **초기화하지 않음** — 복귀 후 재진입 시 이전 방 복원

### selectedPersonalConversationIDByAgentID

Round 241B에서 추가. 에이전트별 마지막 대화 방 UUID를 저장하여, Chiko → Luna → Chiko 전환 시 Chiko의 이전 대화로 복원됨.

```swift
@Published var selectedPersonalConversationIDByAgentID: [String: UUID] = [:]
```

`openPersonalConversation(for:)` 내부에서:
1. `selectedPersonalConversationIDByAgentID[agentID]`에 기존 방 ID가 있으면 그 방으로 이동
2. 없으면 `rooms.first(where: { $0.agentIDs == [agentID] })`로 탐색 후 저장
3. 방 없으면 새 방 생성 후 `selectedPersonalConversationIDByAgentID[agentID] = newRoom.id` 저장

---

## AgentQuickSwitchBar

- 클릭 → `openPersonalChat(for:)` → `activePersonalAgentID` 변경만
- `selectedTeamWorkroomID` 변경 금지
- `room.agentIDs` mutation 금지

---

## teamChatLogs 계산

```swift
var teamChatLogs: [ChatLog] {
    rooms.first(where: { $0.id == selectedTeamWorkroomID })?
        .messages.filter { !$0.isSystem } ?? []
}
```

`currentRoomID` 기준이 아님 — 개인 대화 전환 후에도 팀 메시지가 그대로 표시.

---

## 팀 워크룸으로 돌아가기

```swift
manager.returnToTeamWorkroom()
```

- `activePersonalAgentID = nil`
- `selectedTeamWorkroomID` 복원 (기존 팀 워크룸 or 새로 생성)
- `currentRoomID = selectedTeamWorkroomID`

---

## Composer Routing Invariant (Round 241C)

| Composer | 사용 ID | 금지 |
|---|---|---|
| 팀 워크룸 composer (`sendTeamInput`, `sendTeamMessage`) | `selectedTeamWorkroomID` | `currentRoomID`, `activePersonalAgentID` |
| 개인 대화 composer (`sendMessage` in AgentChatView) | `agentRoomID` (= `selectedPersonalConversationIDByAgentID[agentID]`) | `selectedTeamWorkroomID` |

`currentRoomID`는 legacy UI selection 용도로만 존재.  
메시지 전송, artifact reuse, sidebar preview에서는 explicit surface roomID만 사용.

---

## Unread Badge Semantics (Round 241C)

```swift
func unreadCount(for roomID: UUID) -> Int {
    let lastReadAt = lastReadAtByRoomID[roomID] ?? .distantPast
    return room.messages.filter { msg in
        msg.timestamp > lastReadAt
        && !msg.isUser    // 내가 보낸 메시지 제외
        && !msg.isSystem  // system/progress/artifact internal 제외
    }.count
}
```

- `markRoomRead(roomID)`: 방을 화면에 열 때만 호출. 메시지 전송 시 자동 호출 금지.
- badge = 0이면 숨김.

---

## 금지 사항

| 패턴 | 이유 |
|---|---|
| `openPersonalChat` 내부에서 `selectedTeamWorkroomID` 변경 | 팀 워크룸 콘텐츠 오염 |
| `room.agentIDs = [agentID]` (기존 팀 방 mutation) | 팀 워크룸 파괴 |
| 개인 대화 room을 팀 워크룸으로 재사용 | 타입 혼동 |
| 개인 대화 사이드바에 `room.messages.last.text` 표시 | 개인 정보 노출 |
| TeamStatusView에서 `activePersonalAgentID` 읽기 | 상태 오염 |
| 팀 composer에서 `currentRoomID` 사용 | 개인 대화 중이면 wrong room으로 전송 |
| unread badge에 `room.messages.count` 직접 사용 | 내 메시지/system 포함됨 |

---

## 구현 위치

| 컴포넌트 | 파일 | 역할 |
|---|---|---|
| `selectedTeamWorkroomID` | AgentWindowManager.swift | 팀 워크룸 독립 선택 |
| `activePersonalAgentID` | AgentWindowManager.swift | 개인 대화 독립 추적 |
| `selectTeamWorkroom` | AgentWindowManager.swift | 팀 워크룸 선택 API |
| `openPersonalChat` | AgentWindowManager.swift | 개인 대화 열기 (팀 상태 불변) |
| `returnToTeamWorkroom` | AgentWindowManager.swift | 팀 복귀 API |
| `teamChatLogs` | AgentWindowManager.swift | selectedTeamWorkroomID 기준 |
| TeamStatusView | TeamStatusView.swift | selectedTeamWorkroomID만 참조 |
| 사이드바 preview 제거 | AgentChatView.swift | projectRoomRow lastMsg 금지 |
