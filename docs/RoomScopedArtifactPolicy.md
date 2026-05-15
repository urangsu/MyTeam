# Room-Scoped Artifact Policy

> Round 137A 제정. P0: 방 간 artifact 오염 방지.

## 문제

`AgentWindowManager.recentArtifacts`가 전역 배열이었다. 방 A에서 만든 artifact가 방 B에서도 "방금 만든 문서"처럼 표시될 수 있었다. 신뢰를 깨는 P0.

## 해결 (Round 137A)

`AgentWindowManager.recentArtifacts(for roomID: UUID) -> [IndexedArtifact]` facade 추가.

### 로직

1. `recentArtifactIndexEntries(for: roomID)` 로 room-scoped 인덱스 조회
2. 인덱스 hit → 해당 artifact만 반환
3. 인덱스 miss + `roomID == currentRoomID` → 전역 fallback (backward compat)
4. 다른 방 + 인덱스 miss → `[]` 반환 (오염 차단)

### 변경 파일

| 파일 | 변경 내용 |
|---|---|
| `AgentWindowManager.swift` | `recentArtifacts(for:)` facade 추가 |
| `TeamStatusView.swift` | `manager.recentArtifacts(for: currentRoomID)` 사용 |
| `AgentChatView.swift` | `manager.recentArtifacts(for: agentRoomID)` 사용 |
| `RecentArtifactContentResolver.swift` | `manager.recentArtifacts(for: roomID)` 사용 |
| `LocalTaskBriefingProvider.swift` | `manager.recentArtifacts(for: roomID)` 사용 |

## 규칙

- 전역 `manager.recentArtifacts` 직접 참조 금지 (facade 사용)
- 새 UI 컴포넌트는 반드시 `recentArtifacts(for: roomID)` 사용
- workflowCompleted notification에 roomID 추가는 Round 11 (P0 버그 수정 라운드)에서 진행

## 검증

- `RouterBurnInSuite`: "room-artifact-same-room" 케이스
- `ToolContractValidator`: `validateRoomScopedArtifactPolicy`
- `RuntimeDiagnostics`: `recentArtifactsRoomScoped = true`
