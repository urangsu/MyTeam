# Observation Layer Policy

**Round 243A-OBSERVE** — local observation foundation

---

## 관찰 계층이란

MyTeam이 사용자의 실제 업무 자료를 읽어올 수 있는 입력 채널 모음.
파일 드롭, 다운로드 폴더 감지, 클립보드, Finder 선택, 화면 스냅샷이 포함된다.

---

## Observation Source

| Source | 자동 감지 | 내용 분석 | 상태 |
|---|---|---|---|
| chatAttachment | 즉시 감지 | 사용자 요청 후 | 구현됨 |
| downloadsFolder | 메타데이터만 (기본 OFF) | 사용자 확인 후 | skeleton |
| clipboard | 상시 감시 금지 | 명시 요청만 | 구현됨 |
| finderSelection | 명시 요청만 | 사용자 확인 후 | skeleton |
| screenSnapshot | 상시 캡처 금지 | 명시 요청만 | planned |
| manualFileImport | 즉시 감지 | 사용자 요청 후 | 구현됨 |

---

## Room-Scoped Attachment

```
파일 감지/첨부
  ↓
LocalObservation 생성
  ├─ roomID 있음 → observationsByRoom[roomID]
  └─ roomID 없음 → pendingObservations (어느 방에 붙일지 사용자 결정)
  
사용자 확인
  ↓
attachObservation(_:to:) → 방에 배정
  ↓
(분석 후) artifact 생성 가능
```

---

## 절대 금지

1. **자동 외부 업로드** — 파일을 외부 서버에 자동 전송 금지
2. **자동 파일 수정/삭제** — observation은 읽기 전용
3. **상시 클립보드 감시** — 사용자 명시 요청만
4. **상시 화면 캡처** — hardBlocked
5. **다른 방 자동 노출** — roomID 격리 강제
6. **원문 장기 저장** — displayName + summary만 저장

---

## 구현 파일

| 파일 | 역할 |
|---|---|
| `ObservationModels.swift` | 핵심 타입 (LocalObservation, ObservationSource 등) |
| `ObservationPermissionPolicy.swift` | source별 정책, hard blocks |
| `LocalObservationService.swift` | room-scoped 저장소 |
| `DownloadsFolderWatcher.swift` | 다운로드 감시 (기본 OFF) |
| `ClipboardContextReader.swift` | 명시적 클립보드 읽기 |
| `FinderSelectionReader.swift` | Finder 선택 (skeleton) |
| `ScreenObservationPolicy.swift` | 화면 관찰 정책 + stub |
| `FileIntakeEventCardView.swift` | 카드 UI |
| `OfficeReviewInputPolicy.swift` | 사무 검토 입력/skill 정책 |

## Round 247A-OBSERVE-RUNTIME 업데이트

- ObservationInboxView.swift 추가: pending observation을 방별 UI로 표시
- ObservationPresentationPolicy.swift 추가: 사용자 메시지 정책 중앙화
- AgentWindowManager observation helpers 추가: pendingObservations(for:), analyzeObservation, ignoreObservation, attachObservation
- TeamStatusView: selectedTeamWorkroomID 기준 ObservationInboxView 연결
- AgentChatView: agentRoomID 기준 ObservationInboxView 연결
- WorkflowOrchestrator: 클립보드/Finder/화면 명시 라우트 추가 (자동 감시 없음)
