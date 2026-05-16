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

## Round 146A-152Z 완료 항목

| 항목 | 내용 |
|---|---|
| FirstResultActionStrip 단일화 | TeamStatusView에서 제거, AgentChatView만 유지 (WP6) |
| 협업 배너 압축 | 2줄 카드 → 1줄 컴팩트 바 (WP7) |
| WorkResultCardView | 500자+/마크다운 헤더/표 → 전체 너비 카드 (WP2-lite) |
| 버블 확장 | 어시스턴트 maxWidth 260→480 |
| ChatLog artifactIDs | 메시지-artifact 연결 필드 |
| ArtifactCardView 상태 순화 | 진단 용어 → 사용자 친화적 텍스트 |
| RoomKind | 워크룸/개인 대화 자동 판정 + 아이콘 분리 |

## 다음 단계 (Round 153A 이후)

### sendMessage await (P3)
`ConversationMemory.handleChatCommand()` 비동기 완료 후 LLM 호출.

### WP4 확장: 방 생성 안내 텍스트 (P2)
팀 워크룸 생성 시 "모든 팀원이 함께 작업합니다" 안내.

## 변경 금지 사항

- StoreKit 플로우 변경 없음
- Google OAuth 플로우 변경 없음
- Connector 정책 완화 없음
