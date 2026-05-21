# Observation Runtime UX Policy

## Round 247A-OBSERVE-RUNTIME

### 핵심 원칙

- **감지 ≠ 분석** — 파일/텍스트를 감지해도 자동 분석하지 않는다.
- **Attach ≠ 분석** — 방에 붙이는 것은 분석이 아니다.
- **분석은 사용자 action 이후** — "요약해줘", "분석해줘" 명시 요청 후 실행.
- **Room-scoped observation only** — 다른 방 observation은 절대 표시하지 않는다.
- **Pending attach = 방 선택 전 상태** — roomID nil = 어느 방에도 배정 안 됨.
- **No auto upload** — 자동 외부 업로드 절대 없음.
- **No background screen capture** — 백그라운드 화면 캡처 절대 없음.

### UI 연결

| 표면 | 기준 | 연결 방식 |
|------|------|----------|
| TeamStatusView | selectedTeamWorkroomID | ObservationInboxView |
| AgentChatView | agentRoomID (개인 대화) | ObservationInboxView |

### ObservationInboxView 정책

- `pendingObservations.filter { $0.roomID == nil && $0.isPending }` 만 표시
- 이미 다른 roomID 배정된 observation 표시 금지
- full path 표시 금지 (`displayName`만 사용)
- 파일 내용 미리 보여주거나 자동 분석하는 UI 금지
- "이 방에서 분석" 버튼 → `analyzeObservation(_:in:)` → attach + 준비 메시지 (LLM 분석 없음)
- "무시" 버튼 → `ignoreObservation(_:)` → `ignorePendingObservation` 호출

### AgentWindowManager 헬퍼

```swift
func pendingObservationsForCurrentSurface() -> [LocalObservation]
func pendingObservations(for roomID: UUID) -> [LocalObservation]
func attachObservation(_ observation: LocalObservation, to roomID: UUID)
func analyzeObservation(_ observation: LocalObservation, in roomID: UUID)
func ignoreObservation(_ observation: LocalObservation)
```

`analyzeObservation`이 추가하는 chat log 메시지:
> "이 파일을 이 방에 붙였어요. 자동 분석은 하지 않았습니다. 원하시면 요약/검토 기준을 먼저 잡아드릴게요."

### Round 249TTS 이후 단계

- `analyzeObservation`에서 실제 LLM 분석 파이프라인 연결
- ONNX Runtime 활성화 시 Supertonic3InferencePipeline과 observation 연동
