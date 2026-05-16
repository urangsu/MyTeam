# Room Kind Policy

> Round 146A-152Z에서 도입. 워크룸(팀 협업 공간)과 개인 대화의 시각적 구분 정책.

## 원칙

1. **Computed property** — `ChatRoom.computedRoomKind`는 `agentIDs` 기반으로 자동 판정한다. 별도 저장 필드 없음.
2. **판정 기준** — `agentIDs`에 `"team_all"`이 포함되거나 2개 이상이면 `.teamWorkroom`, 그 외 `.personalChat`.
3. **아이콘 분리** — 사이드바 방 목록에서 팀 워크룸은 `person.3.fill`, 개인 대화는 `person.fill`.

## RoomKind enum

```swift
enum RoomKind: String, Codable {
    case teamWorkroom    // 팀 전체 협업 공간
    case personalChat    // 개인 에이전트 대화
}
```

## UI 적용

- `TeamStatusView` 사이드바 `RoomRowView`: RoomKind별 아이콘 표시
- 향후: 방 생성 시 안내 텍스트 차별화 가능

## 검증

- `RuntimeDiagnosticsSnapshot.roomKindComputedAvailable`
- `RuntimeDiagnosticsSnapshot.teamWorkroomPersonalChatSeparated`
- `ToolContractValidator.validateRoomKindPolicy()`
- RouterBurnInSuite: `room-kind-team-workroom`, `room-kind-personal-chat`
