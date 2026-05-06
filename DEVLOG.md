# MyTeam 개발 로그

> 위치: `/Users/su/Desktop/MyTeam/DEVLOG.md`
> 목적: 현재 앱 방향, 최근 결정, 완료 이력만 남기는 단일 개발 로그.
> 세부 TODO와 남은 로드맵은 `TASK.md`에 기록한다.

---

## 2026-05-06 (Round 9 — Korean Privacy Terms Artifact Skill)

### 빌드 목표
- LLM 기반 개인정보처리방침·이용약관 artifact 생성 스킬 구현
- 사용자 요청에서 회사명, 서비스명 추출
- 생성된 Markdown을 Workspace artifact로 저장
- 안전 면책문구 포함 및 budget 관리

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| 서비스 레이어 | KoreanPrivacyTermsService.swift | 요청 추출, 프롬프트 빌드, 파일명 생성 |
| Artifact 저장 | KoreanPrivacyTermsArtifactWriter.swift | LLM 생성 결과를 Workspace에 저장, artifact 등록 |
| Workflow 라우팅 | WorkflowOrchestrator.swift | privacy-terms 스킬 감지 → runPrivacyTermsWorkflow() 실행 |
| LLM 호출 | AIService.swift | generatePrivacyTerms(prompt:) — 사용 가능한 provider 우선순위로 탐색 |
| Budget 관리 | AICallBudgetManager.swift | .privacyTermsGen 호출 타입 추가, 요청당 1회 제한 |
| Skill 설정 | BuiltInKoreanSkills.swift | korean.privacy-terms 스킬 이미 등록됨 (defaultEnabled: true) |

### 스킬 흐름

1. 사용자 메시지: "회사명 서비스명의 개인정보처리방침 만들어줘"
2. SkillRegistry.matchEnabledSkills() → korean.privacy-terms 감지
3. KoreanPrivacyTermsService.extractRequest() → 회사명, 서비스명, 문서타입 추출
4. WorkflowOrchestrator.runPrivacyTermsWorkflow()
   - 프롬프트 빌드
   - AIService.generatePrivacyTerms() → LLM 호출
   - 안전 면책문구 추가
   - KoreanPrivacyTermsArtifactWriter.saveArtifact() → Workspace에 저장
5. ✅ 완료: artifact 등록, 사용자에게 결과 표시

### 검증 완료
- BUILD SUCCEEDED ✅
- 신규 파일 2개 project.pbxproj 등록 ✅
- AICallBudgetManager switch 문 exhaustive ✅
- KoreanPrivacyTermsService 타입 정의 완료 ✅

### 주요 결정사항
- **Workflow-based**: 스킬이 LLM 호출이므로 WorkflowEngine이 아닌 직접 AIService 호출로 빠른 응답
- **Budget 카운트**: privacy-terms-gen은 별도 타입으로 요청당 1회만 허용
- **Markdown + 면책**: AI 생성 결과에 필수 면책문구 자동 추가
- **파일명**: "회사_서비스_개인정보처리방침_연도.md" 형식

### 남은 과제
- Privacy-terms artifact card UI (SkillResultRendererView 추가 TODO 주석 이미 있음)
- 맞춤법 검사 실제 구현
- RuntimeDiagnostics full UI
- User Skill import UI
- korean.accounting-tax 파일 업로드 기반 정리

---

## 2026-05-06 (Round 8-4 — Finalize Skill Center + Diagnostics Placeholder)

### 빌드 목표
- SkillResultRendererView 공통화 완료 (중복 분기 제거)
- SettingsView 스킬 센터 기본 구현 확인
- RuntimeDiagnostics 미니 placeholder 추가
- 추가 스킬 렌더러 TODO 주석 추가

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| 스킬 렌더러 통합 | SkillResultRendererView.swift | KoreanTextMetricsResultCardView 직접 사용, 중복 카드 제거 |
| AgentChatView 정리 | AgentChatView.swift | `if log.skillID != nil` 체크로 일반화, direct character-count 분기 제거 |
| TeamStatusView 정리 | TeamStatusView.swift | `if log.skillID != nil` 체크로 일반화, direct character-count 분기 제거 |
| RuntimeDiagnostics UI | SettingsView.swift | 시스템 진단 섹션 추가 (워크플로우, 이벤트, Gemini 상태 표시) |
| 향후 스킬 TODO | SkillResultRendererView.swift | korean.spell-check, korean.privacy-terms, runtime.diagnostics, korean.accounting-tax 카드 TODO 추가 |

### 검증 완료
- AgentChatView 'korean.character-count' 검색 0건 ✅
- TeamStatusView 'korean.character-count' 검색 0건 ✅
- SkillResultRendererView 중복 카드 검색 0건 ✅
- BUILD SUCCEEDED ✅

### 남은 과제
- 개인정보처리방침·이용약관 artifact skill
- 맞춤법 검사 실제 구현
- RuntimeDiagnostics full UI + ActivityTimeline
- User Skill import UI
- korean.accounting-tax 파일 업로드 기반 정리

---

## 2026-05-05 (Round 8-3 — Skill Result Renderer + Skill Center Polish)

### 빌드 목표
- 스킬 결과 렌더링을 공통화하여 AgentChatView/TeamStatusView의 중복 분기 제거
- SettingsView의 스킬 탭을 "스킬 센터"처럼 정리
- RuntimeDiagnostics 미니 placeholder 추가 (정식 UI 아님)

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| 스킬 결과 공통 렌더러 | SkillResultRendererView.swift (신규) | ViewBuilder 함수로 skillID에 따라 카드 또는 텍스트 반환, 중복 분기 제거 |
| AgentChatView 정리 | AgentChatView.swift | character-count 직접 분기 제거, SkillResultRendererView 사용 |
| TeamStatusView 정리 | TeamStatusView.swift | character-count 직접 분기 제거, SkillResultRendererView 사용 |
| SettingsView 개선 | SettingsView.swift | 검색 기능 유지, card 형태 row, risk/processing label, skill center 느낌 |

### 스킬 렌더링 통합
- `SkillResultRendererView(skillID: log.skillID, text: log.text, isDarkMode: manager.isDarkMode, isUser: log.isUser)`
- skillID에 따라 적절한 카드 렌더링, 미지원하면 일반 텍스트
- 파싱 실패 시에도 graceful fallback

### 다음 작업 후보
- KoreanTextMetricsResultCardView.swift 정리 (SkillResultRendererView.swift의 KoreanCharacterCountCardView와 통합)
- RuntimeDiagnostics full UI
- ActivityTimeline
- User skill import UI
- 개인정보처리방침/약관 생성 artifact skill

---

## 2026-05-05 (Round 8-2 — Skill Result Card UI + Local Skill Polish)

### 빌드 목표
- `korean.character-count`는 계속 **완전 로컬 처리**
- local skill 경로에서는 `AICallBudgetManager`, `IntentRouter`, `WorkflowEngine` 미호출
- SettingsView는 대규모 리팩터링 없이 검색/토글 반응성만 보강

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| 로컬 글자 수 계산 서비스 | KoreanTextMetricsService.swift (신규) | 입력 텍스트 추출, 글자 수/bytes/줄 수/문단 수 계산, 카드용 결과 파싱 추가 |
| local skill executor | LocalSkillExecutor.swift (신규) | `korean.character-count` 요청을 LLM 없이 즉시 처리 |
| 결과 카드 UI | KoreanTextMetricsResultCardView.swift (신규) | 제목, `로컬 처리` 배지, metric grid, 제출폼 기준 안내를 카드 형태로 렌더링 |
| budget 이전 local skill 처리 | WorkflowOrchestrator.swift | skill match 후 local skill handled/needsInput이면 `beginSession()` 이전에 즉시 반환 |
| chat log skill 식별 | ChatModels.swift, AgentWindowManager.swift | `ChatLog.skillID` 추가, `addChatLog(... skillID:)` 지원 |
| skill card 렌더링 | TeamStatusView.swift, AgentChatView.swift | `skillID == "korean.character-count"`이면 일반 말풍선 대신 카드 렌더링 |
| Settings 스모크 개선 | SettingsView.swift | 검색 필드, `skillRefreshToken`, enabled count 즉시 반영 |

### local skill 경로 보장

기대 로그:
```
[Skill] local execute korean.character-count
[Skill] local result posted roomID=...
```

없어야 하는 로그:
```
[AICall] callType=intent_classify
[AICall] callType=workflow_plan
```

### 남은 과제

- SkillResultPayload 구조화
- 한국어 맞춤법 검사 실제 구현
- 개인정보처리방침/약관 생성 완성
- User skill import UI
- RuntimeDiagnostics UI

---

## 2026-05-05 (P0 안정화 Round 7-2 — Skill allowedScopes 실행 경로 연결 + 보안 마무리 + 핫픽스)

### 핫픽스
- **allowedScopes shadowing 버그** — WorkflowEngine 루프 내부에서 로컬 allowedScopes 재선언으로 함수 파라미터 덮어쓰던 버그 수정. 
  - korean.naver-news의 browserDOM scope가 ToolExecutor까지 전달 안 되던 문제 해결
  - 로컬 선언 제거, 함수 파라미터 allowedScopes 그대로 전달
  - 시작 로그에 allowedScopes 출력

### 빌드 결과
- **BUILD SUCCEEDED** · error 0 · warning 0

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| allowedScopes 실제 주입 | WorkflowOrchestrator, WorkflowEngine | dispatch()에서 effectiveScopes 계산 → runWorkflow/planWorkflow/attemptPlan/buildPlannerPrompt → WorkflowEngine.run(allowedScopes:) 전달. skill match 없으면 [.chatBasic, .artifactGeneration] 기본값 |
| SkillIDValidator 공통화 | SkillRegistry | nonisolated static isValidSkillID(_ id: String) 추가. a-z A-Z 0-9 . _ - 만 허용, / \ .. ~ 공백 금지 |
| 검증 규칙 강화 | SkillRegistry | validateSkill() Rule 1-1: id whitelist 검증. UserSkillStore는 같은 validator 재사용 |
| Disabled vs high-risk 분리 | SkillRegistry + WorkflowOrchestrator | nonisolated static isHighRiskSkill(_ skill: SkillManifest) 추가. enabled high-risk: "현재 버전 실행 불가". disabled high-risk: "민감 작업 비활성". disabled safe: "설정에서 활성화" |
| SettingsView skill toggle | SettingsView | skill 목록 표시, 각 항목 enabled toggle, high-risk disabled는 toggle disabled 처리. law-search/dart 토글 가능 |

### allowedScopes 전달 파이프라인 로그 예시

```
[Skill] matched enabled korean.naver-news scopes=[chatBasic,browserDOM]
[WorkflowOrchestrator] 파일 생성 요청 감지 → workflow 즉시 실행 scopes=[artifactGeneration,browserDOM,chatBasic]
```

### Disabled/High-risk 안내 분리

```
사용자: "법령 검색해줘"
→ [Skill] matched disabled 'korean.law-search'
→ 시스템: "'한국 법령 검색' 스킬은 현재 비활성화되어 있습니다. 설정 > 스킬 탭에서 활성화할 수 있습니다."

사용자: (future high-risk skill match 상황)
→ 시스템: "'{스킬명}' 스킬은 로그인/개인정보/예약/결제 등 민감 작업이므로 아직 비활성화되어 있습니다. 현재 버전에서는 사용할 수 없습니다."
```

### SkillIDValidator 정책

✅ `good.skill-1`, `my-custom_skill`, `korean.law-search`
❌ `../evil`, `evil/skill`, `bad skill`, `skill..name`, `~home`

### Settings toggle 검증

- korean.law-search off → "법령 검색" → disabled 안내 → Settings toggle on → 다시 "법령 검색" → enabled match + 로그
- high-risk disabled skill → toggle disabled (UI 비활성)
- 외부 API 호출: 없음 (manifest-only)

### 미구현 (Round 8+)

- User skill import UI
- korean.accounting-tax 파일 업로드 기반 실행
- CODEF/홈택스/은행/카드/증권 자동화 (BYOK + 명시 승인)

---

## 2026-05-05 (P0 안정화 Round 6 — Korean Skill Catalog)

### 빌드 결과
- **BUILD SUCCEEDED** · error 0 · warning 0
- 기준 커밋: Round 5 (main 브랜치)

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| ToolScope Codable 추가 | AgentTool.swift | `SkillManifest.allowedScopes: [ToolScope]` Codable 합성을 위해 `Codable` 프로토콜 추가 |
| SkillManifest 구조 정의 | SkillManifest.swift (신규) | SkillCategory·SkillPermission·SkillRiskLevel·SkillOutputType enum + SkillManifest struct. `backendHint: String?`, `notes: [String]?` 미래 확장 필드 포함 |
| BuiltInKoreanSkills 10개 | BuiltInKoreanSkills.swift (신규) | 날씨·미세먼지·맞춤법·글자수·네이버뉴스·블로그리서치·개인정보약관·HWP·법령검색·DART. 기본 활성 8개, 비활성 2개(law-search, dart) |
| SkillRegistry 싱글턴 | SkillRegistry.swift (신규) | `final class`, `UserDefaults` 기반 enable/disable 영속화, trigger match, validation 6-rule |
| UserSkillStore 스켈레톤 | UserSkillStore.swift (신규) | `actor`, `~/Library/Application Support/MyTeam/UserSkills/` 저장, dangerous permission warning flags |
| Skill match 라우팅 | WorkflowOrchestrator.swift | `dispatch()` 상단에 `SkillRegistry.shared.matchSkills()` 삽입. high-risk(reservation/payment/accountLogin) 조기 반환 + 시스템 메시지 |
| SettingsView 스킬 탭 | SettingsView.swift | 4번째 탭 "스킬" 추가, frame 380→420, `skillsTab` 플레이스홀더 (built-in 10개 / 활성화 8개 / high-risk 0개 표시) |

### Built-in 스킬 10개 목록

| # | ID | 카테고리 | defaultEnabled | riskLevel |
|---|----|---------|--------------:|-----------|
| 1 | korean.weather | koreanLife | ✅ true | publicData |
| 2 | korean.fine-dust | koreanLife | ✅ true | publicData |
| 3 | korean.spell-check | koreanWriting | ✅ true | safeReadOnly |
| 4 | korean.character-count | koreanWriting | ✅ true | safeReadOnly |
| 5 | korean.naver-news | koreanLife | ✅ true | publicData |
| 6 | korean.naver-blog-research | koreanWriting | ✅ true | publicData |
| 7 | korean.privacy-terms | koreanBusiness | ✅ true | publicData |
| 8 | korean.hwp-read | document | ✅ true | safeReadOnly |
| 9 | korean.law-search | koreanLegal | ❌ false | publicData |
| 10 | korean.dart | koreanFinance | ❌ false | publicData |

### High-risk 스킬 정책 (기본 비활성 — Round 6 미구현)

`riskLevel` ∈ `{reservation, payment, accountLogin}` → `validateSkill` 에서 `defaultEnabled=false` 강제.

| 카테고리 | 해당 스킬/기능 | 이유 |
|---|---|---|
| accountLogin | CODEF 자동 수집 (은행·카드·증권) | 타사 계정 크리덴셜 필요 |
| accountLogin | 홈택스 / 정부24 자동화 | 공공 계정 로그인, 민감 세금 정보 |
| reservation | KTX/SRT 예매, 캐치테이블/야놀자 | 실제 예약/결제 수반 |
| payment | 쿠팡 / 번개장터 구매 | 실제 결제 |
| sendsMessage | 카카오톡 메시지 전송 | 메시지 오발송 위험 |

Round 7 이상에서 BYOK + 명시 승인 구조로만 구현.

### UserSkillStore 저장 경로
```
~/Library/Application Support/MyTeam/UserSkills/<id>.skill.json
```
- `isEnabled: false` 고정 (설치 즉시 활성화 불가)
- dangerous permission 포함 시 `warningFlags` 기록

### Skill match 로그 예시
```
[Skill] matched korean.weather scopes=[chatBasic]
[Skill] matched korean.naver-news,korean.naver-blog-research scopes=[chatBasic,browserDOM,chatBasic,browserDOM,artifactGeneration]
```

### FutureKoreanSkills 후보 (DEVLOG 기록만 — BuiltInKoreanSkills.all 미포함)

**korean.accounting-tax** (한국 사업자 장부·세무 정리)
- `riskLevel: .personalData`, `defaultEnabled: false`, `requiresApprovalEveryRun: true`
- 1단계: 업로드 파일(CSV/엑셀) 기반 장부 정리만 허용
- 2단계(CODEF/홈택스/은행/카드): BYOK + 명시 승인 단계에서만 구현
- `backendHint: nil` — 1단계는 로컬 파일만

### 수동 검증 체크리스트

- [ ] `SkillRegistry.shared.builtInSkills().count` == 10
- [ ] `SkillRegistry.shared.allEnabledSkills().count` == 8
- [ ] `SkillRegistry.shared.matchSkills(for: "오늘 날씨 어때").first?.id` == `"korean.weather"`
- [ ] "오늘 날씨 어때" dispatch 로그: `[Skill] matched korean.weather scopes=[chatBasic]`
- [ ] SettingsView "스킬" 탭: 등록된 built-in 10개, 활성화됨 8개, high-risk(비활성) 0개
- [ ] `validateSkill` — triggers 비어 있는 스킬 → `SkillValidationError.emptyTriggers`
- [ ] `validateSkill` — riskLevel=.reservation, requiresApprovalEveryRun=false → `highRiskRequiresApproval`
- [ ] `UserSkillStore.skillsDirectory` 경로: `~/Library/Application Support/MyTeam/UserSkills/`
- [ ] 스킬 match 없는 메시지 ("안녕") → `matchedSkills.isEmpty`, 기존 dispatch 흐름 유지

### 미구현 (Round 7 이후)
- 실제 외부 API 호출 (날씨/미세먼지/DART/법령검색 등)
- Skill Gallery UI, remote install
- `SkillRegistry.userSkills()` — UserSkillStore 연동
- SkillManifest 기반 allowedScopes → WorkflowEngine 동적 주입
- korean.accounting-tax (파일 업로드 기반부터 단계적 구현)

---

## 2026-05-04 (P0 안정화 Round 5 — DirectChat 통합 + ToolScope 전수 + evidence 오탐 제거 + finish 순서)

### 빌드 결과
- **BUILD SUCCEEDED** · error 0 · warning 0
- 기준 커밋: `a20ca6c` (Round 4)

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| DirectChat silent mode 통합 | AgentChatView.swift | `getResponse()` 단발 경로 제거. silent mode도 `getResponseStream()` → 토큰 누적 → 말풍선 1개. `[DirectChat] silent getResponseStream opened` 로그 추가 |
| DirectChat roomID/targetID 캡처 | AgentChatView.swift | `roomIDAtSend` / `targetIDAtSend` 캡처변수로 두 경로(silent/normal) 통일. 오염 방지 |
| evidence gate 오탐 제거 | AgentChatView.swift | "알려줘", "찾아줘", "찾아봐" 단독 키워드 삭제. 외부정보(최신/뉴스/날씨/주가/환율/가격/버전)와 명시적웹(웹/검색/인터넷/구글)만 evidence 허용 |
| evidence reason 세분화 | AgentChatView.swift | `attachment` / `url` / `explicit_web` / `external_info_keyword` 4종 |
| ToolScope 전수 분류 | ReadFileTool, WriteTextFileTool, OpenURLTool | `.documentEditing` / `.artifactGeneration` / `.browserDOM` 명시 |
| Google 툴 scope 수정 | CreateGoogleSlidesTool, CreateGoogleSheetsTool | `.artifactGeneration` → `.officeLive` |
| ToolRegistry scope 경고 | ToolRegistry.swift | `register()` 시 file/artifact/url/export 계열이 `.chatBasic`이면 `[ToolRegistry] scope 누락 의심` warning |
| finish/event 순서 보장 | WorkflowOrchestrator.swift | `finishWorkflowRun()` 헬퍼 추가. 단일 Task에서 `WorkflowRunStore.finish` → `AgentEventBus.publish` 순서 보장 |
| RuntimeDiagnostics event 정보 | RuntimeDiagnosticsService.swift | `recentEventCount` + `latestEventSummary` 필드 추가. `snapshot()` async화 |
| OpenURLTool warning 수정 | OpenURLTool.swift | `_ = await MainActor.run` (unused result 경고 제거) |

### ToolScope 분류표 (전체)

| 도구 | scope |
|------|-------|
| read_file | `.documentEditing` |
| write_text_file | `.artifactGeneration` |
| create_markdown_report | `.artifactGeneration` |
| create_presentation_plan | `.artifactGeneration` |
| create_spreadsheet_plan | `.artifactGeneration` |
| generate_pptx | `.artifactGeneration` |
| generate_xlsx | `.artifactGeneration` |
| export_document | `.artifactGeneration` |
| create_google_slides | `.officeLive` |
| create_google_sheets | `.officeLive` |
| open_url | `.browserDOM` |

### 수동 검증 항목

| 시나리오 | 기대 결과 | 확인 |
|----------|-----------|------|
| silent mode ON → 치코 개인창 | `[DirectChat] silent getResponseStream opened` 로그, 치코 방에만 말풍선 | ☐ |
| silent mode OFF → 치코 개인창 | SpeechManager TTS 재생, 치코 방에만 말풍선 | ☐ |
| "오늘 기분 어때?" → DirectChat | `evidence skipped (no URL/keyword/attachment)` | ☐ |
| "이 UI 느낌 알려줘" → DirectChat | `evidence skipped` | ☐ |
| "최신 뉴스 알려줘" → DirectChat | `evidence enabled reason=external_info_keyword` | ☐ |
| "웹에서 찾아줘" → DirectChat | `evidence enabled reason=explicit_web` | ☐ |
| 첨부파일 있음 → DirectChat | `evidence enabled reason=attachment` | ☐ |
| artifactGeneration workflow | `open_url` / `create_google_slides` 실행 시 `[ToolExecutor] scope 차단` | ☐ |
| workflow 완료 | finish 로그 → workflowCompleted 로그 순서 | ☐ |
| 취소 | finish cancelled 1회, workflowCancelled 1회 | ☐ |
| RuntimeDiagnostics dump | `recentEvents: N | latest: workflowCompleted wf=...` | ☐ |

### evidence 로그 예시 (기대)
```
[DirectChat] evidence skipped (no URL/keyword/attachment)
[DirectChat] evidence enabled reason=external_info_keyword
[DirectChat] evidence enabled reason=explicit_web
[DirectChat] evidence enabled reason=attachment
```

### finish/event 순서 로그 예시 (기대)
```
[WorkflowOrchestrator] finishWorkflowRun status=completed workflowID=a1b2c3d4
[AgentEvent] workflowCompleted workflow=a1b2c3d4
```

### getResponse 단발 경로 제거 여부
- AgentChatView.swift DirectChat silent mode: **제거 완료** (`getResponse` → `getResponseStream` + 토큰 누적)
- WorkflowOrchestrator.swift planner/repair 경로: `getResponse` 유지 (스트림 불필요한 플래너 JSON 파싱 경로, 의도적)

---

## 2026-05-04 (P0 안정화 Round 4 — 단일-종료 + 스코프 가드 + evidence 게이트)

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| finish() 단일화 | WorkflowOrchestrator.swift | `finalStatus`/`finalEvent` + `defer` 패턴. 모든 분기가 `finish()` 1회만 호출. `manager.currentWorkflowID = nil`도 defer에 통합 |
| event 단일화 | WorkflowOrchestrator.swift | `workflowCompleted`/`workflowCancelled`/`workflowFailed` 이벤트도 defer 내 1회만 발행 |
| DirectChat evidence gate | AgentChatView.swift | `directChatNeedsEvidence()` — URL/외부키워드/첨부파일 없으면 `ToolEvidenceService.gather` 완전 스킵. 불필요한 웹 검색 API 호출 차단 |
| ToolScope executor guard | ToolExecutor.swift + WorkflowEngine.swift | `execute(allowedScopes:)` 파라미터 추가. WorkflowEngine은 `[.chatBasic, .artifactGeneration]`만 허용. scope 불일치 시 실행 전 차단 |
| workflowID default 제거 | ToolExecutionContext.swift | `current(workflowID: UUID = UUID())` → `current(workflowID: UUID)`. 누락 시 컴파일 오류 |
| consecutive429Count 노출 | AIService.swift | `private` → `private(set)`. 진단 읽기 허용 |
| RuntimeDiagnostics 연결 | RuntimeDiagnosticsService.swift | `geminiConsecutive429Count` — `0` 하드코딩 → `ai.consecutive429Count` 실값 연결 |

### 수동 검증 항목

| 시나리오 | 기대 결과 | 확인 |
|----------|-----------|------|
| "최신 뉴스 알려줘" → DirectChat | evidence enabled (keyword=최신/뉴스) | ☐ |
| "오늘 기분 어때?" → DirectChat | evidence skipped | ☐ |
| "이 파일 분석해줘" + 첨부 → DirectChat | evidence enabled (attachment) | ☐ |
| WorkflowEngine 실행 중 취소 | finish() 1회 / workflowCancelled 1회 | ☐ |
| ToolScope 차단 시 로그 | `[ToolExecutor] scope 차단: ...` | ☐ |
| RuntimeDiagnostics dump | `geminiCooldown: none` vs `429×N` 실값 | ☐ |

### 알려진 남은 항목 (TASK.md 참조)
- DirectChat 무음 모드 경로에서 getResponse → getResponseStream 통합 미완
- AgentEventBus subscriber 연결 (UI 이벤트 스트림) 미구현
- ToolScope `.schedule` / `.diagnostics` 도구 분류 미완

---

## 2026-05-03 (2차 — 안정화 마무리 + 데모 검증)

### 안정화 완료 사항

| 항목 | 내용 |
|------|------|
| Rolling budget | beginSession()에서 rollingCallLog 초기화 제거. 60초/5회 제한 실제 동작 |
| Artifact 카드 필터 | workflowID 기준 필터. 이전 workflow 파일 오염 없음 |
| ArtifactCardView | cloud/local 분기, path 비면 disabled, Finder 버튼 cloud에서 숨김 |
| 취소→네트워크 | Gemini/Claude/OpenAI/OpenRouter 4개 provider 모두 withTaskCancellationHandler 적용 |
| Validator | 필수 XML 내용 읽기 실패 = validation failure (silent skip 제거) |
| Validator | deflate(method=8) 항목은 .compressedContent 에러 throw (MiniZipWriter 계약 명시) |
| workflowID 통일 | notification userInfo 키를 "workflowID"로 통일. "sessionID" fallback + warning |
| room scope TODO | recentArtifacts 전역 한계 TODO 주석 추가 |

### 데모 테스트 — PPTX/XLSX 생성 파이프라인

**테스트 날짜:** 2026-05-03  
**테스트 환경:** 코드 정적 분석 + ZIP 구조 검증 기준 (앱 런타임 실행은 수석님이 직접 확인 필요)

**PPTX 파이프라인 분석:**
```
"MyTeam 회사원들을 소개할 PPT 만들어줘"
→ requiresFileCreation() → true (ppt 명사 + 만들어 동사)
→ 플래너 LLM: create_presentation_plan → generate_pptx 2단계
→ PPTXWriter → MiniZipWriter(stored) → .pptx
→ DocumentPackageValidator.validatePPTX():
   [Content_Types].xml ✓, ppt/presentation.xml ✓
   ppt/_rels/presentation.xml.rels ✓ (slide 관계 검사)
   ppt/slides/slideN.xml × N ✓ (slide 수 일치)
   content type "presentationml.slide" ✓
→ ArtifactCardView "열기" 버튼 표시
```

**XLSX 파이프라인 분석:**
```
"MyTeam 기능을 표로 정리해서 엑셀 파일로 만들어줘"
→ requiresFileCreation() → true (엑셀 명사 + 만들어 동사)
→ 플래너 LLM: create_spreadsheet_plan → generate_xlsx 2단계
→ XLSXWriter → MiniZipWriter(stored) → .xlsx
→ DocumentPackageValidator.validateXLSX():
   [Content_Types].xml ✓, xl/workbook.xml ✓
   xl/_rels/workbook.xml.rels ✓ (sheet 참조)
   xl/worksheets/sheetN.xml ✓ (sheet 수 일치)
   xl/sharedStrings.xml ✓ (si 개수 불일치 경고)
   xl/styles.xml ✓
→ ArtifactCardView "열기" + "Finder" 버튼 표시
```

**런타임 테스트 결과 (수석님 직접 확인 항목):**
| 항목 | 결과 |
|------|------|
| .pptx — Keynote/PowerPoint 열기 | ☐ 미확인 |
| .pptx — 한글 깨짐 | ☐ 미확인 |
| .xlsx — Numbers/Excel 열기 | ☐ 미확인 |
| .xlsx — 한글 깨짐 | ☐ 미확인 |
| ArtifactCard "열기" 버튼 | ☐ 미확인 |
| ArtifactCard "Finder" 버튼 | ☐ 미확인 |
| 취소 버튼 (■) → 작업 중단 | ☐ 미확인 |

**알려진 제약:**
- PPTX 슬라이드 레이아웃: 단일 레이아웃 (title + bullets). 디자인 커스텀 없음.
- XLSX 셀 스타일: 헤더 bold + freeze row. 색상/병합 없음.
- Google Slides/Sheets: stub (OAuth 연결 필요 메시지만 반환).

---

## 2026-05-03

### WorkflowOrchestrator + 업무 실행 엔진 추가

**구현 완료:**
- `TextSanitizer.removeNameTags` 버그픽스: agentPersonas 이름 목록과 일치할 때만 태그 제거. "좋아: 그렇게" 같은 일반 문장 보존.
- `AIService text passthrough` 코드 인스펙션 완료 — 버그 없음 확인. geminiStream/claudeStream/openAIStream/openRouterStream 모두 text 올바르게 전달.
- `Keychain 마이그레이션` 이미 완료됨 확인 (MyTeamApp.swift:121, KeychainManager.migrateFromUserDefaultsIfNeeded).

**신규 파일 (MyTeam/MyTeam/*.swift flat):**
| 파일 | 역할 |
|------|------|
| AgentTool.swift | WorkflowTool 프로토콜, ToolInput/ToolResult/ToolError, safeWorkspaceURL |
| ToolExecutionContext.swift | Workspace URL, sessionID, isDryRun |
| ArtifactStore.swift | action_log.jsonl append-only 기록 |
| WorkflowModels.swift | WorkflowPlan/Step/Result/Artifact |
| ReadFileTool.swift | Workspace 내 파일 읽기 |
| WriteTextFileTool.swift | Workspace 내 파일 쓰기 |
| CreateMarkdownReportTool.swift | .md 보고서 생성 |
| CreatePresentationPlanTool.swift | deck_plan.json 생성 |
| CreateSpreadsheetPlanTool.swift | workbook_plan.json 생성 |
| OpenURLTool.swift | http/https URL 열기 |
| ToolRegistry.swift | MVP 도구 싱글턴 등록 |
| ToolExecutor.swift | step 단위 실행 + 로그 + high/destructive 차단 |
| WorkflowEngine.swift | 순차 실행, isRequired 실패 시 중단 |
| WorkflowOrchestrator.swift | LLM 플래너 + IntentRouter 라우팅 진입점 |

**TeamStatusView 변경:**
- `TeamOrchestrator.runTeamDiscussion()` 직접 호출 → `WorkflowOrchestrator.dispatch()`로 교체.
- CHITCHAT/QUICK_ANSWER → TeamOrchestrator 위임.
- TASK/RESEARCH/DECISION → WorkflowEngine 실행.

**보안:**
- Workspace = `~/Library/Application Support/MyTeam/Workspace/` (샌드박스 안전).
- path traversal(`../`) 차단, Workspace 외부 접근 금지.
- OpenURLTool: http/https scheme만 허용.
- high/destructive riskLevel 도구 실행 차단 (MVP).
- 모든 tool call → `action_log.jsonl` append.

**경로 규칙 명시:**
- Swift 파일 실제 위치: `MyTeam/MyTeam/*.swift` (flat).
- Antigravity/Claude/Codex는 이 경로만 수정.

---

## 프로젝트 기준

MyTeam은 macOS 데스크톱에 4명의 캐릭터 AI 에이전트가 상주하는 SwiftUI/AppKit 앱이다.
목표는 Mac App Store 배포 가능한 퍼스트파티급 네이티브 앱이다.

### 현재 기술 스택

| 영역 | 현재 기준 |
| --- | --- |
| 앱 | Swift 6, SwiftUI, AppKit `NSPanel`, SpriteKit |
| 상태 관리 | `AgentWindowManager` + `ChatRoom` / `ChatLog` |
| LLM | `AIService` 직접 호출: Gemini, OpenAI, Claude, OpenRouter |
| API 키 | `KeychainManager` |
| TTS | `Qwen3TTSService` + `ModelCatalog` + Qwen3-TTS MLX |
| 음성 재생 | `SpeechManager` + `AudioPlaybackService` |
| 팀 대화 | `TeamOrchestrator` + `IntentRouter` + `ToolPolicy` |
| 웹/금융 자료 | `ToolEvidenceService`, 출처 칩 `SourceReference` |

### 현재 고정 결정

- 런타임 TTS는 `Qwen3TTSService` 기준이다.
- Apple TTS/AVSpeechSynthesizer는 폴백으로도 사용하지 않는다.
- Python TTS 서버, ONNX Chatterbox, MLXInferenceService 기반 실험은 아카이브다.
- 캐릭터 음성은 pitch/rate 보정이 아니라 레퍼런스 음성 자산 품질로 관리한다.
- LLM 모델명은 가능한 동적 발견/설정 기반으로 둔다. `gemini-1.5`, `gpt-4o` 같은 특정 모델 하드코딩은 지양한다.
- Mac App Store 배포를 막는 절대경로, 외부 프로세스, 평문 API 키 저장은 블로커로 본다.

---

## 핵심 파일

| 파일 | 역할 |
| --- | --- |
| `MyTeam/AgentWindowManager.swift` | 앱 전역 상태, 방/메시지/창/스케줄 업무 관리 |
| `MyTeam/AgentConfig.swift` | 캐릭터 설정, LLM provider, 데스크 라우팅 |
| `MyTeam/ChatModels.swift` | `ChatRoom`, `ChatLog`, `SourceReference`, `AutomationTask` |
| `MyTeam/AgentChatView.swift` | 개인 채팅창 |
| `MyTeam/TeamStatusView.swift` | 팀 채팅/스케줄 업무 UI |
| `MyTeam/TeamTableView.swift` | 메인 플로팅 팀 창 |
| `MyTeam/TeamOrchestrator.swift` | 팀 대화 진행, 리더/멘션 우선순위 |
| `MyTeam/IntentRouter.swift` | 업무/잡담/도구 필요 판단 |
| `MyTeam/AIService.swift` | LLM 호출, 모델 발견, API 키 검증 |
| `MyTeam/AgentToolKit.swift` | 도구 정책, 웹/금융/URL 자료 수집 |
| `MyTeam/ConversationMemory.swift` | 첨부 컨텍스트, `/clear`, `/compact`, `/schedule` 등 명령어 |
| `MyTeam/Qwen3TTSService.swift` | Qwen3 TTS 런타임, 캐릭터 레퍼런스 voice clone |
| `MyTeam/ModelCatalog.swift` | TTS 모델 ID 기본값 |
| `MyTeam/SpeechManager.swift` | STT, TTS 스트림 연결, barge-in |
| `MyTeam/FloatingPanel.swift` | 위치/크기 저장 복원, 패널 드래그 |
| `MyTeam/SettingsView.swift` | API 키, provider, 데스크 라우팅, 사용자/팀 설정 |

---

## 작업 규칙

- 메시지 추가는 `AgentWindowManager.addChatLog()`를 사용한다.
- 팀 대화는 `TeamOrchestrator.runTeamDiscussion()`로 보낸다.
- 개인 대화는 개인창 응답 정책과 `ToolPolicy`를 거친다.
- 최신 정보/금융/URL 질문은 도구 자료와 출처 칩을 붙인다.
- 금융/투자 답변은 “최종 선택과 책임은 사용자 본인에게 있고 AI/외부 데이터는 틀릴 수 있다”는 고지를 유지한다.
- 스케줄 업무는 앱이 켜져 있을 때만 실행한다. 파일 삭제/결제/외부 글쓰기 같은 destructive action은 금지한다.

---

## 최근 완료 이력

### 2026-05-01

#### P0 품질 기준 정리

- `xcodebuild -quiet -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Debug -destination 'platform=macOS' build` 성공.
- `xcodebuild -quiet -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Release -destination 'platform=macOS' build` 성공.
- MyTeam 타겟 Swift 경고는 quiet Debug/Release 기준 0건. 남은 출력은 Xcode destination 선택 안내뿐이며, 일반 Release 빌드에서 보였던 `mlx-swift` Metal C++17 경고는 외부 패키지 경고로 분리.
- `ToolPolicyDecision`, `ToolEvidenceResult`에 `Sendable`을 붙이고 automation timer의 불필요한 `Task { @MainActor ... }` 캡처를 줄임.
- `IntentRouter.classify()`의 `toolPolicy` 기본값을 메시지 기반 평가로 바꿔 도구 판단이 빈 문자열에 묶이지 않게 수정.
- P0 상주 문제를 `TASK.md`에 별도 섹션으로 고정. TTS/캐시/로그/창/대화 fallback을 한 번에 보이도록 정리.
- 앱 로그는 `AppLog` 래퍼를 기준으로 점진 전환. legacy TTS/WebSocket/OnDevice 로그는 기본 비활성화할 수 있는 구조로 이동.
- 팀 대화 selector 실패 시 랜덤 fallback을 deterministic fallback으로 교체하고, TTS 첫 발화 대기 때문에 텍스트 진행이 막히는 구조를 제거.
- `FloatingPanel`의 window restoration을 명시적으로 끄고 패널별 크기 저장 정책을 함수로 분리.
- Qwen3 모델 캐시가 앱 컨테이너에 없으면 자동 다운로드로 조용히 빠지지 않고 명확한 오류를 내도록 preflight를 추가.

#### TTS 측정과 보류 결정

- 앱 런타임 전용 `MYTEAM_TTS_PROBE=1` 측정 경로를 추가. 결과는 앱 컨테이너 `Application Support/MyTeam/TTSBench/`에 JSON/WAV로 저장.
- voice clone 기본값은 OFF로 고정. `UserDefaults("MyTeam.TTS.useQwenVoiceClone") == true`일 때만 개발 검증 모드로 사용.
- 앱스토어 샌드박스 기준에서는 기존 비샌드박스 HuggingFace 캐시를 자동 공유하지 못해 앱 컨테이너 캐시/초기 다운로드/ODR 정책이 별도 P0임을 확인.
- 2026-05-01 부분 측정: 루나 base는 모델 준비 3.84s, 합성 6.67s, 오디오 5.56s, RTF 1.20. 11캐릭터 base 부분 측정도 RTF 1.04~1.32 범위로 즉각 반응 목표와 거리가 있음.
- 결론: TTS는 “감상”이 아니라 측정 기반으로 관리하되, 현 Qwen3 경로는 출시 품질 블로커다. 당장은 다른 P0 앱 품질 작업을 우선하고 TTS는 별도 게이트로 재평가한다.

#### TTS 후처리와 스케줄 UX 정리

- `동물의숲 효과`를 고객용 음성 토글과 분리된 TTS 후처리 기능으로 복원.
- 캐릭터별 pitch/rate 값을 `VoiceStyleCatalog`로 분리하고 안전 범위로 clamp.
- 스케줄 패널에서 담당 캐릭터 지정 추가. 현재 팀에 없는 캐릭터는 메뉴/칩에 `없음`으로 표시.
- 담당 캐릭터가 팀에 없으면 대체 화자가 짧은 대신 수행 메시지를 남긴 뒤 실행.
- OpenAI/OpenRouter 모델 ID는 고급 설정으로 유지하고, 비워두면 자동 선택 경로를 사용.

### 2026-05-02

#### 레거시 코드 완전 제거 (P4)

- 활성 코드에서 참조 없음을 확인 후 17개 dead code 파일 삭제:
  - Chatterbox/ONNX 파이프라인 클러스터: `MLXInferenceService`, `MLXModelManager`, `T3MLXModel`, `T3Model`, `LlamaModel`, `T3CondEnc`, `HiFTGenerator`, `VoiceEncoder`, `BPETokenizer`, `KanaDecomposer`, `ChatterboxPipeline`, `ChatterboxConfig`
  - 외부 Python WebSocket 클러스터: `WebSocketClient`, `WebSocketStreamManager`, `LiveAudioManager`
  - On-device TTS 관리자: `OnDeviceTTSManager`, `TTSServiceManager`
- project.pbxproj에서 총 68줄 제거 (파일 참조 4위치 × 17파일).
- `/Users/su/` 하드코딩된 절대경로(`MLXModelManager`, `BPETokenizer`)가 이 삭제로 해소됨 → P0 샌드박스 블로커 해제.
- Debug/Release clean build 성공. 외부 패키지(mlx-swift C++17) 경고 외 앱 코드 경고 0건.

#### [BUG FIX] 캐릭터 음성 일관성 (P0 TTS)

- **원인**: `SamplingConfig`에 seed 파라미터 없음. 내부 `MLXRandom.gumbel()` 매 호출마다 새 랜덤 시퀀스 생성 → 같은 캐릭터도 청크마다 다른 음성 토큰 경로.
- **해결**: `Qwen3TTSService`에 `import MLX` 추가, `characterSeed(for:)` (FNV-1a 해시) 함수 추가, 합성 직전 `MLXRandom.seed(characterSeed(for: characterName))` 고정.
- 결과: 동일 캐릭터 → 동일 seed → 동일 gumbel noise → 일관된 토큰 경로 → 일관된 음성.

#### Reference Audio 자산 정리 (P4)

- `voices-audit.md` 작성: 11개 파일 모두 존재(216~340KB, 추정 13~21s), clipping 적용 중. 실청 검수 미완.
- `POLICY.md` 작성: 4~7초, 24kHz mono, -20 LUFS ±2, 앞뒤 무음 <0.2s, fade out 0.1s 기준 문서화.

#### [BUG FIX] 앱 종료 크래시 + 캐릭터 음성 일관성 2차 수정 (2026-05-02 추가)

**종료 크래시 (EXC_BAD_ACCESS in __hash__)**
- 증상: 앱 종료 시 Task 154 `com.apple.root.user-initiated-qos.cooperative` 에서 `__hash__()` 크래시
- 원인: MLX Metal 셰이더 캐시(C++ `unordered_map`)를 백그라운드 스레드가 접근 중에 Swift 래퍼 객체 해제
- 해결: `applicationWillTerminate`에 `Task.detached(@Qwen3TTSActor) { cancelCurrentInference() }` + `Thread.sleep(1.0)` drain 대기 추가

**음성 일관성 2차 수정 — 세션 앵커**
- 1차 seed 고정은 "동일 텍스트 재현성"만 보장. 다른 텍스트는 여전히 다른 speaker zone → 다른 목소리
- 해결: `sessionVoiceAnchors: [String: [Float]]` — 캐릭터 첫 합성 출력을 앵커 저장, 이후 발화는 `synthesizeWithVoiceClone(anchor)` 호출 (temperature 0.30, topK 20으로 낮춰 안정성 확보)
- 경로: 파일 voice clone(ON) > 세션 앵커 clone > 첫 base 합성+앵커 저장
- `clearSessionAnchors()` / `clearSessionAnchor(for:)` 세션 리셋 API 추가

#### Debug/Release clean build 검증 (P0)

- Debug + Release 모두 `BUILD SUCCEEDED` 재확인.

---

### 2026-05-03

#### [BUG FIX] 앱 종료 크래시 #2 — ObjC EXC_BAD_ACCESS in objc_msgSend

**증상**: 앱 종료 시 Task 272 `com.apple.root.user-initiated-qos.cooperative` 에서 `(*pProc)(pObj, selector, args...)` — `objc_msgSend` 에서 EXC_BAD_ACCESS(code=1)

**원인**: `applicationWillTerminate`가 `Thread.sleep(1.0)`으로 대기하는 동안 AVAudioEngine의 CoreAudio 렌더 스레드(실시간 OS 스레드)가 계속 동작. 이 상태에서 Swift가 AVAudioNode(ObjC 객체)를 해제하면 렌더 콜백이 이미 해제된 포인터에 ObjC 메시지를 보내 크래시 발생. voice clone 합성은 최대 11초인데 sleep(1.0)은 부족.

**해결**:
- `AudioPlaybackService.stopEngineForTermination()` 추가: `playerNode.stop()` → `engine.stop()` 명시 호출 → 노드 분리. CoreAudio 렌더 스레드를 즉시 정지시켜 in-flight 콜백 차단.
- `applicationWillTerminate`를 `DispatchSemaphore` 방식으로 전면 교체:
  1. `stopEngineForTermination()` 비동기 호출 + 50ms 드레인
  2. `Task.detached(@Qwen3TTSActor)` → `cancelCurrentInference()` 호출 후 `sem.signal()`
  3. `sem.wait(timeout: .now() + 5.0)` — 최대 5초 대기 (actor 확인 보장)
  4. Metal command queue drain용 `Thread.sleep(0.5)`

#### [QUALITY] TTS 앵커 패딩 — 짧은 앵커 반복 오디오 방지

**증상**: 세션 앵커가 1.88초(≈22 codec tokens)처럼 짧으면 voice clone 합성이 75-token safety limit에 걸려 6초짜리 반복 오디오 생성 → quality gate 실패 → base fallback → 루프

**해결** (`Qwen3TTSService.swift`):
- `paddedClippedReferenceAudio(_:)` 추가: 앵커가 3초(72,000 samples) 미만이면 루프 패딩으로 3초 채운 뒤 7초(168,000 samples) 상한 적용
- `isQualityGateFailed()` 에 `isVoiceClone: Bool = false` 파라미터 추가: voice clone 경로는 per-char 상한 배율을 0.8x → 1.5x로 완화 (prosody 확장 고려)
- voice clone 경로(3-b)에서 `clippedReferenceAudio(anchor)` → `paddedClippedReferenceAudio(anchor)`로 교체

#### P1: 팀장 배지 + 컨텍스트 메뉴

- `AgentMenuPopupView`: `isTeamLeader: Bool`, `onSetLeader: (() -> Void)?` 파라미터 추가
- `TeamTableView`: 에이전트 셀에서 `AgentWindowManager.shared.teamLeader()?.id == agent.id` 조건으로 팀장 여부 전달, "팀장 설정/해제" 메뉴 항목 (`crown.fill`/`crown` SF Symbol) 연결
- 팀장 지정: `AgentWindowManager.shared.setTeamLeader(agentID:)` 호출

#### P1: 장기 기억 Scope V2 분리 (global / room / character)

- **저장 구조 변경**: `@AppStorage("MyTeam.keyFacts")` 전역 배열 → `MyTeam.keyFactsV2` 키 딕셔너리 `[String: [String]]`
  - `"global"` — 수석님(사용자) 관련 기기 공유 사실
  - `"room_{UUID}"` — 방별 컨텍스트
  - `"char_{name}"` — 캐릭터별 기억
- `/remember` 문법 확장: `/remember @루나 텍스트` → character scope, `/remember :global 텍스트` → global scope, 기본 → room scope
- `/memory` — 현재 방 + 현재 캐릭터 + global 3개 scope 전체 표시
- `/forget` — scoped + legacy V1 양쪽 검색/삭제
- `buildMemoryContext()` → `scopedMemoryContext(agentName:roomID:)` — 3 scope 병합 → 시스템 프롬프트 주입

#### P1: /compact LLM 요약

- `AIService.quickSummary(prompt:)` 추가: Gemini → Claude → OpenAI 순서로 single-turn 요약 호출. API 키 없으면 정적 요약으로 폴백.
- `/compact` 핸들러 업데이트: `quickSummary()` 호출 후 `"[LLM 요약됨] ..."` 단일 메시지로 교체. 응답 없으면 기존 static 요약 사용.

#### P2: /edit-task, /approve, /skip 명령어

- `AgentWindowManager.editAutomationTask(idPrefix:option:)`:
  - `HH:MM` 형식 → 다음 실행 시간 변경
  - `--disable` / `--enable` → 활성화 토글
  - `--approval on/off` → 승인 요청 토글
- `ChatModels.AutomationTask`에 `requiresApproval: Bool = false` 필드 추가
- `runDueAutomationTasks()`: `requiresApproval == true`이면 채팅창에 승인 요청 메시지 표시, 2분 타임아웃 후 자동 실행. `pendingApprovalTaskIDs: Set<UUID>` 관리.
- `ConversationMemory`: `/edit-task`, `/approve`, `/skip` 핸들러 추가. `/tasks` 표시에 상태 이모지(✅/⏸), 승인 플래그, 짧은 ID prefix 추가.

#### P2: 금융 API — NAVER 금융 추가

- `AgentToolKit.fetchNaverFinanceQuote(symbol:)` 추가: `https://m.stock.naver.com/api/stock/{code}/basic` (한국 주식 6자리 코드 또는 .KS/.KQ)
- `fetchYahooFinanceQuote(symbol:)`: Yahoo Finance v8 `/v8/finance/chart/` + User-Agent 헤더로 안정성 강화
- 라우팅 로직: 6자리 숫자 코드나 `.KS`/`.KQ` suffix → NAVER 우선, 실패 시 Yahoo fallback. 해외 주식은 Yahoo 직접.

#### P3: LLMConfigCatalog — 신규 파일

- `LLMConfigCatalog.swift` 신규 생성:
  - `LLMCapability` enum: `.webSearch`, `.toolUse`, `.longContext`, `.vision`
  - `LLMProviderConfig: Codable`: selectedModelId, supportsToolUse, supportsWebSearch, discoveredModels, lastDiscoveryDate
  - `@MainActor LLMConfigCatalog`: UserDefaults 캐시, TTL 1시간 discovery 갱신, `bestProvider(for:)`, `routeOrDefault(_:fallback:)`
  - `extension AIService`: `discoverModel(for:apiKey:)` 브릿지, discovery 함수 internal 노출

#### P3: Tool-capable 라우팅

- `AgentChatView`: ToolPolicy 평가 후 `.needsFinance || .needsWeb` → `.webSearch` capability, 나머지 → `.toolUse`. `LLMConfigCatalog.routeOrDefault()` 로 최적 provider 결정 후 `agentConfig.withProvider(best)` 임시 오버라이드.
- `AgentConfig.withProvider(_:)` 추가: 원본 불변, 오버라이드 복사본 반환.
- `AgentWindowManager.handleWake()`: `LLMConfigCatalog.shared.refreshAllIfNeeded()` 호출로 포그라운드 복귀 시 TTL 체크.

#### Debug/Release clean build 검증

- Debug + Release 모두 `BUILD SUCCEEDED`. 앱 코드 Swift 경고 0건.
- TASK.md 크래시/P1/P2/P3 체크박스 9개 ✅ 업데이트.

#### P1: 없는 캐릭터 대체 발화 톤 + 개인창 전문성 연결

- `TeamOrchestrator.unavailableNoticeText(speaker:unavailableName:)` 추가: 11캐릭터 각각 성격에 맞는 부재 안내 문구로 교체 (레오 — 절제된 분석, 루나 — 밝고 에너지, 렉스 — 느긋하고 꼼꼼, 몽몽 — 친절 공감 등).
- `ConversationMemory.buildPersonalResponsePolicy()` 강화: `agentPersonas` 에서 `specialty`/`role` 읽어 개인창 시스템 프롬프트에 "핵심 전문 분야 '\(specialty)'에서 특히 깊이 있는 답변을" 힌트 주입.

#### P2: Gemini Grounding + OpenAI web_search 연동 PoC

- `ToolEvidenceService.fetchWebEvidence()` 3단계 폴백 구조:
  1. `fetchGeminiGrounding()`: `tools: [{"google_search": {}}]` — Google 실시간 검색, `groundingChunks` 출처 추출
  2. `fetchOpenAIWebSearch()`: Responses API `web_search_preview` 도구 — gpt-4o-mini 기반 웹 검색
  3. `fetchDuckDuckGo()`: 기존 DuckDuckGo Instant Answer 폴백
- API 키가 없으면 자동으로 다음 단계로 fall through. 출처 칩에 "Google 검색" / "OpenAI" 표시.

#### P2: /schedule 파서 확장

- `parseSchedule()` 전면 개편:
  - `내일/tomorrow HH:MM 내용` → 내일 해당 시간 1회 실행
  - `매일/daily/every day HH:MM 내용` → 매일 반복 (repeatInterval = 86400s)
  - `매주 {요일} HH:MM 내용` / `every {weekday} HH:MM 내용` → 매주 반복 (604800s)
  - `N시 [M분] 내용` → 한국어 시간 표기 지원
  - `every 30m/2h 내용` 기존 interval 방식 유지
- `/schedule` 도움말 메시지 multi-line으로 개선.

#### P2: URL fetch HTML 본문 추출 품질 개선

- `extractMainContent()` 추가: `<article>` → `<main>` → content class/id div → `<p>` 단락 집합 → 전체 스트립 순서로 본문 추출. 200자 미만이면 다음 전략으로 fall through.
- `extractMetaDescription()` 추가: `og:description`, `name=description` meta 태그 추출, URL 본문 앞에 "요약:" 으로 표시.
- `cleanHTML()` 강화: `<nav>`, `<header>`, `<footer>`, `<aside>`, HTML 주석(`<!-- -->`) 제거 추가. HTML 숫자 엔티티 (`&#NNNN;`) 디코딩 추가.

#### P2: 금융 alias 확대

- `extractFinanceSymbols()` 한국 대형주 15종목 추가: SK하이닉스, 카카오, 네이버, 현대차/기아, 셀트리온, LG에너지솔루션, 삼성바이오로직스, 크래프톤 등.
- 가상자산: 솔라나(SOL-USD), 리플(XRP-USD) 추가.
- 미국: ARM, AVGO(브로드컴), 팔란티어(PLTR), QCOM(퀄컴) 추가.

#### P3: 설정창 모델 목록 UI

- `SettingsView.apiSettingsTab` 고급 모델 설정 섹션 개선:
  - `LLMConfigCatalog.shared.configs[selectedProvider]?.discoveredModels` 목록 표시
  - 모델 탭하면 `openAIModelId` / `openRouterModelId` 자동 입력
  - 선택된 모델 체크마크 표시
  - 갱신(↺) 버튼 → `LLMConfigCatalog.refreshIfNeeded()` 호출
  - 모델 없으면 "자동 선택 (검증 후 갱신)" 안내 텍스트

#### Debug/Release clean build 검증 (2차)

- Debug + Release `BUILD SUCCEEDED`. 경고: 기존 3건 (await 없는 await, NSOrderedSet cast, var→let) 유지, 신규 없음.

---

### 2026-04-30

#### 팀/개인 대화 구조 개선

- 팀방에 `leaderAgentID` 추가.
- 팀 리더 지정 UI 추가.
- 캐릭터 이름을 부르면 해당 캐릭터가 우선 응답.
- 팀에 없는 캐릭터를 부르면 리더/대체 화자가 대신 응답.
- 팀 대화 TTS는 첫 발화만 나오도록 정리.

#### 페르소나/직업 설정 연결

- `AgentSettingsView`의 직업/성격 설정이 `AIService.buildSystemPrompt()`에 반영되도록 수정.
- 커스텀 persona가 기본 캐릭터 persona를 덮어쓰지 않고 보조 설정으로 붙도록 변경.

#### 도구 정책, 출처, 금융 정보

- `ToolPolicy` 추가.
- 최신/뉴스/검색/URL/금융 질문 감지.
- `ToolEvidenceService` 추가.
- Yahoo Finance 기반 주식/코인 시세 컨텍스트 추가.
- DuckDuckGo Instant Answer 기반 웹 자료 수집 추가.
- URL 직접 읽기 `/fetch` 지원.
- 답변 아래 출처 칩 표시 및 클릭 열기 지원.

#### 명령어와 장기 기억

- `/help`, `/clear`, `/compact`, `/remember`, `/memory`, `/forget`, `/silent`, `/voice` 추가.
- `/open`, `/fetch`, `/search`, `/schedule`, `/tasks`, `/cancel` 추가.
- `keyFacts` 장기 기억을 개인창 응답 컨텍스트에 연결.

#### 스케줄 업무

- `AutomationTask` 모델 추가.
- 앱 내부 timer 기반 스케줄 업무 실행.
- 팀 채팅창 하단에 “스케줄 업무” 스트립 추가 후, 시선 방해가 커서 입력창 왼쪽 아이콘 호출형 패널로 변경.
- 스케줄 패널에서 등록 업무 확인/삭제 가능.

#### 설정/API/창 구조

- API 키 검증을 provider별 실제 models list 호출로 교체.
- 기본 LLM provider와 데스크별 provider/model routing 연결.
- 설정창 X 버튼이 `hideSettingsWindow()`를 호출하도록 정리.
- 패널 위치/크기 저장 복원 개선.
- 개인창 열 때 저장된 크기를 덮어쓰지 않도록 수정.
- 상태창 크기 변경 API를 폭/높이 통합으로 정리.

#### TTS

- 런타임 TTS를 `Qwen3TTSService`로 고정.
- 긴 reference audio 기반 voice clone에서 음질 붕괴와 과도한 생성 시간이 확인되어 기본 런타임은 한국어 기본 합성으로 임시 전환.
- voice clone은 `UserDefaults("MyTeam.TTS.useQwenVoiceClone") == true`인 개발 검증 모드에서만 사용.
- voice clone 검증 시 reference audio는 최대 7초로 잘라 사용.
- `!` 같은 의미 없는 punctuation-only 청크가 TTS로 들어가지 않도록 필터링.
- TTS 청크 길이를 90자로 제한해 safety limit 폭주 가능성을 낮춤.
- `SpeechManager.speak()`가 `agentID`로 캐릭터 이름을 역추적해 루나 fallback 남발을 줄이도록 수정.
- 샘플링 temperature/topK를 낮춰 같은 캐릭터가 매번 다른 목소리처럼 흔들리는 현상을 완화.
- 단발성 TTS 경로의 pitch 값을 원본 유지값 `0.0`으로 수정.

#### App Store 샌드박스

- Debug 앱 target의 `ENABLE_APP_SANDBOX`를 Release와 동일하게 `YES`로 변경.
- outgoing network, audio input, user-selected readonly 파일 접근 설정은 유지.

#### 검증

- `xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Debug -destination 'platform=macOS' build`
- 결과: `BUILD SUCCEEDED`
- Debug sandbox enabled 상태에서 build 성공.

#### Push

- `8461f0a feat: add chat commands and scheduled tasks`
- `20ff8b4 feat: improve LLM settings and window behavior`
- `3e669f1 fix: pin character TTS to reference voices`
- `origin/main` push 완료.

---

## 아카이브 요약

과거 ONNX/Chatterbox/MLXInferenceService 기반 TTS 실험은 다음 이유로 현행 개발 기준에서 제외한다.

- ONNX Chatterbox는 속도, 음질, 모델 입출력 복원 비용 문제로 출시 경로가 아니다.
- Python/FastAPI/WebSocket TTS 서버는 Mac App Store 배포 경로가 아니다.
- Apple TTS는 캐릭터성/음질 요구를 만족하지 못해 폴백으로도 쓰지 않는다.
- 기존 레거시 파일은 삭제 전 `TASK.md`의 P2 단계에서 사용처 0 확인 후 정리한다.

상세 과거 로그가 필요하면 git history에서 이전 `DEVLOG.md`를 확인한다.
