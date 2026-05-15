# Work Surface Simplification Plan

> Round 137A-145Z 기준. 단계별 단순화 계획.

## Round 137A 완료 항목

| 항목 | 내용 |
|---|---|
| Room-scoped artifact | `recentArtifacts(for:)` facade 적용 |
| 용어 통일 | 채팅방→워크룸, 스케줄 근무→예약 작업 |
| 에이전트 switcher 제거 | AgentChatView 사이드바 하단 avatar 행 삭제 |
| TypingIndicator timer leak | `onDisappear` invalidate 추가 |
| 기본 방 이름 | "기본 프로젝트" → "워크룸 1" |

## 다음 단계 (Round 146A 이후)

### TeamStatusView 경량화 (P1)
현재 TeamStatusView는 에이전트 리스트 + 채팅 로그 + artifact 카드 + 스케줄 + 커넥터 상태 + API key 상태를 모두 포함.
목표: 팀 상태 + 현재 작업 + 빠른 입력 + starter 3개 + 워크플로우 중단 버튼.

### Empty State 단순화 (P2)
`FirstLaunchBannerView`와 `LocalOnlyModeCardView` 동시 표시 방지.
상태카드 1개 + 주요 액션 3개로 정리.

### Result/Conversation 분리 (P3)
긴 답변 = 넓은 블록, artifact = 카드 스타일.
`ResultMessageBlockView` 신규 컴포넌트.

### sendMessage await (P3)
`ConversationMemory.handleChatCommand()` 비동기 완료 후 LLM 호출.

## 변경 금지 사항

- StoreKit 플로우 변경 없음
- Google OAuth 플로우 변경 없음
- Connector 정책 완화 없음
