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
| 식별자 | `activePersonalAgentID: String?` |
| 방 매핑 | `rooms.first { $0.agentIDs == [agentID] }` |
| agentIDs | 정확히 1개 |
| 콘텐츠 | 에이전트와의 1:1 대화 |
| UI | AgentChatView |
| 선택 API | `openPersonalChat(for agentID: String)` |

### 불변 규칙
- `selectedTeamWorkroomID`를 절대 변경하지 않음
- `activePersonalAgentID`는 `selectedTeamWorkroomID`와 독립적으로 추적
- 개인 대화 사이드바에 메시지 내용 preview 금지 (방 이름만 표시)

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

## 금지 사항

| 패턴 | 이유 |
|---|---|
| `openPersonalChat` 내부에서 `selectedTeamWorkroomID` 변경 | 팀 워크룸 콘텐츠 오염 |
| `room.agentIDs = [agentID]` (기존 팀 방 mutation) | 팀 워크룸 파괴 |
| 개인 대화 room을 팀 워크룸으로 재사용 | 타입 혼동 |
| 개인 대화 사이드바에 `room.messages.last.text` 표시 | 개인 정보 노출 |
| TeamStatusView에서 `activePersonalAgentID` 읽기 | 상태 오염 |

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
