# Beginner Mode Product Spec
**Round 233B | 2026-05-17**

---

## 1. 목적

AI 도구에 익숙하지 않은 사용자가 프롬프트를 몰라도 워크룸에서 즉시 업무를 시작할 수 있도록 한다.

---

## 2. 핵심 원칙

1. **버튼 하나로 시작** — 텍스트 입력 없이 업무 카드 탭으로 시작 가능
2. **API 키 없이 동작** — `BeginnerExampleDocumentService`로 로컬 fallback 보장
3. **결과 중심** — 과정 설명 최소화, 결과물(문서) 우선 노출
4. **친절한 오류 안내** — 기술 용어 대신 사용자 언어로 복구 안내
5. **간편/기본 전환 자유** — 언제든 토글로 전환, 상태 보존

---

## 3. 컴포넌트 목록

| 파일 | 역할 |
|------|------|
| `BeginnerMode.swift` | BeginnerTaskCard, BeginnerGuidanceMessage, UserFacingTerm 정의 |
| `BeginnerTaskCardView.swift` | BeginnerTaskCardView, BeginnerGuidanceBar UI 컴포넌트 |
| `BeginnerExampleDocumentService.swift` | API 없이 샘플 회의록 생성 (로컬 전용) |
| `WorkroomHomeView.swift` | 간편/기본 모드 분기, 업무 카드 레이아웃 |
| `ArtifactCardView.swift` | 친절한 복구 UI (friendlyRecovery) |
| `SettingsView.swift` | 간편 모드 Toggle (사용자 설정 탭) |
| `AgentWindowManager.swift` | `isBeginnerMode` @AppStorage 상태 |
| `TeamStatusView.swift` | WorkroomHomeView 마운트 조건 |

---

## 4. BeginnerTaskCard 6가지

| case | 제목 | dispatchPrompt |
|------|------|----------------|
| `meetingMinutes` | 회의록 만들기 | "회의록 양식 만들어줘" |
| `checklist` | 체크리스트 만들기 | "체크리스트 만들어줘" |
| `reportDraft` | 보고서 초안 | "보고서 초안 만들어줘" |
| `fileSummary` | 파일 읽기 | "파일 읽기" |
| `todayPlan` | 오늘 할 일 | "오늘 할 일 정리해줘" |
| `tryExample` | 예시로 먼저 해보기 | (local template — API 키 불필요) |

---

## 5. BeginnerExampleDocumentService 플로우

```
사용자: "예시로 먼저 해보기" 탭
  → handleBeginnerCardTap(.tryExample)
  → BeginnerExampleDocumentService.shared.generateExampleMeetingMinutes(roomID:)
  → buildExampleMarkdown() — 하드코딩 마크다운 (API 호출 없음)
  → write to ArtifactStore.workspaceURL / 회의록_예시_YYYYMMDD_HHmmss.md
  → ArtifactStore.shared.registerArtifact(artifact)
  → NotificationCenter.post(.workflowCompleted, artifacts: [artifact])
    → CharacterReactionEventSink → .joy
```

---

## 6. ArtifactCardView 친절한 복구 UI

| healthStatus | 메시지 | 복구 버튼 |
|---|---|---|
| `.missingFile` | "파일을 찾을 수 없어요..." | 새 문서로 시작 |
| `.hashMismatch` | "파일 내용이 바뀐 것 같아요..." | 새 문서로 시작 |
| `.invalidExternalPath` | "파일을 열 수 없어요..." | 새 문서로 시작 |
| `.invalidRelativePath` | "파일을 열 수 없어요..." | 새 문서로 시작 |

복구 버튼은 `Notification.Name("myteam.beginnerNewDocument")` 알림을 발생시킨다.

---

## 7. UserFacingTerm 매핑

| 기술 용어 | 사용자 언어 |
|---|---|
| artifact | 문서 |
| connector | 연결 기능 |
| blocked | 자동 실행 안 함 |
| unavailable | 아직 사용할 수 없음 |
| skill | 기능 |
| token | 사용량 |
| model | AI 엔진 |
| diagnostic | 앱 상태 정보 |
| hash mismatch | 파일 내용이 바뀐 것 같아요 |

---

## 8. 모드 전환

- `AgentWindowManager.isBeginnerMode: Bool` @AppStorage ("MyTeam.isBeginnerMode")
- WorkroomHomeView 헤더 토글 버튼 (간편 모드 ↔ 기본 모드)
- SettingsView 사용자 설정 탭 Toggle
- 모드 전환 시 WorkroomHomeView 애니메이션 분기

---

## 9. 간편 모드에서 숨기는 것

- Starter Action 버튼 (업무 카드로 대체)
- 고급 워크플로우 설명
- 기술 용어 (artifact, connector, route, skill)
- 진단 정보 누출 (DiagnosticsVisibilityPolicy로 별도 제어)

---

## 10. 검증 체크리스트

- [ ] `scripts/preflight_beginner_round233.sh` 0 실패
- [ ] API 키 없이 "예시로 먼저 해보기" → 문서 생성 및 저장 확인
- [ ] 간편 모드 토글 → WorkroomHomeView 분기 전환 확인
- [ ] SettingsView 토글 → isBeginnerMode 동기화 확인
- [ ] ArtifactCardView missingFile → 친절한 복구 UI 표시 확인
- [ ] Debug + Release BUILD SUCCEEDED, 0 warnings

---

## 11. Round 234 완료 사항

- [x] `docs/qa/ManualRuntimeQA_Round234.md` — 4개 시나리오 수동 QA 체크리스트 작성
- [x] `scripts/preflight_sprite_round234.sh` — 11단계 preflight (sprite gate + build)
- [x] RouterBurnInSuite: `beginner-example-next-action-exists` 케이스 추가
- [x] ToolContractValidator: `validateBeginnerExampleArtifactPolicy` 추가
- [x] RuntimeDiagnostics: `beginnerExampleNextActionsAvailable` 필드 추가

## 12. 다음 단계 (Round 235+)

- BeginnerExampleDocumentService: AI 연결 시 실제 LLM 회의록 생성으로 전환
- fileSummary 카드: 파일 선택 UI 연결
- 복구 버튼에 실제 파일 선택 UI 연결 (현재는 새 문서 안내)
- 간편 모드 상태별 Chiko 감정 반응 세분화
- 수동 QA 완료 후 ManualRuntimeQA_Round234.md 결과 기록


---

## Round 235 — Contrast Improvements (2026-05-17)

- BeginnerTaskCardView 배경: `Color.mtCardBackground` (NSColor.controlBackgroundColor 기반) 적용
- 카드 내 텍스트: `mtTextSecondary` (0.64 opacity) 기준으로 상향, dark mode 자동 대응
- BeginnerGuidanceBar 변경 없음 — `.primary` / `.secondary` 사용 유지 (시스템 색상으로 이미 충분)
- Status: Build-ready, Manual QA pending
