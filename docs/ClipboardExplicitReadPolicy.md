# Clipboard Explicit Read Policy

## Round 247A-OBSERVE-RUNTIME

### 정책

- 상시 클립보드 감시 절대 금지 (`ClipboardContextReader.continuousMonitoringAllowed = false`)
- 앱 시작 시 자동 읽기 없음
- 사용자 명시 요청 시에만 `ClipboardContextReader.readAsObservation(roomID:)` 호출
- 원문 장기 저장 금지
- credential-like 내용 (token/password/API key) 원문 표시 절대 금지

### 트리거 문구

WorkflowOrchestrator.handleExplicitContextRoute에서 감지:

- "클립보드"
- "복사한 내용"
- "붙여넣은 내용"

### 처리 흐름

1. 사용자 입력에 위 키워드 포함 확인
2. `ClipboardContextReader.readAsObservation(roomID:)` 호출
   - credential 패턴 감지 시 `nil` 반환
   - 빈 클립보드면 `nil` 반환
3. `nil` 반환 시: `ObservationPresentationPolicy.clipboardBlockedMessage()` 표시
4. 정상 반환 시:
   - `LocalObservationService.addDetectedObservation(obs)` 호출
   - `ObservationPresentationPolicy.attachMessage(for: obs)` chat log에 추가
   - ObservationInboxView에 자동 표시 (publish 갱신)

### 차단 메시지

> "클립보드에서 비밀번호나 API 키처럼 보이는 내용이 감지되어 읽지 않았습니다. 민감하지 않은 텍스트를 복사 후 다시 시도해 주세요."

### 첨부 후 메시지 (자동 분석 없음)

> "[표시명]을(를) 이 방에 붙였어요. 자동 분석은 하지 않았습니다. 원하시면 '요약해줘', '검토 기준을 먼저 잡아줘'처럼 말씀해 주세요."
