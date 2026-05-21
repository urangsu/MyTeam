# Finder Selection Fallback Policy

## Round 247A-OBSERVE-RUNTIME

### 정책

- Cloud 환경에서 Finder 선택 파일 실제 AppleScript/Accessibility QA 금지
- `FinderSelectionReader.readCurrentFinderSelection()` → Cloud에서 throws
- 실패 시 fallback 메시지로 안내 (drag & drop 유도)
- full path 절대 표시 금지
- 자동 파일 분석 금지

### 트리거 문구

WorkflowOrchestrator.handleExplicitContextRoute에서 감지:

- "finder에서 선택한 파일"
- "선택한 파일 가져와"
- "지금 선택한 파일"

### 처리 흐름

1. 사용자 입력에 위 키워드 포함 확인
2. `FinderSelectionReader.readCurrentFinderSelection()` 호출 (try?)
3. 성공 시:
   - `LocalObservationService.addDetectedObservation(obs)` 호출
   - attach 메시지 chat log에 추가
4. 실패 시 (Cloud 환경 포함):
   - `ObservationPresentationPolicy.finderFallbackMessage()` 표시

### Fallback 메시지

> "권한 또는 환경 때문에 Finder 선택 파일을 읽지 못했습니다. 파일을 이 방으로 끌어다 놓아 주세요."

### Round 249TTS 이후 Mac 로컬에서

- `AXIsProcessTrustedWithOptions` 권한 확인
- Accessibility API로 실제 Finder 선택 파일 URL 읽기
- `PermissionStatus.granted` 시 실제 동작, 아니면 fallback 유지
