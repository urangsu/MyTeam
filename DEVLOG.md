# MyTeam 개발 로그

> 위치: `/Users/su/Desktop/MyTeam/DEVLOG.md`
> 목적: 현재 앱 방향, 최근 결정, 완료 이력만 남기는 단일 개발 로그.
> 세부 TODO와 남은 로드맵은 `TASK.md`에 기록한다.

---

## 2026-05-10 (Round 28B — File Intake to Universal Document Workflow)

- lastFileIntakeResultByRoom added for per-room file state
- file reference detection now connects recent file contents into Universal Document sourceText
- file-based summary / report / table / checklist / meeting minutes / action item generation is wired
- completion messages now surface the source filename
- file-read immediate auto-generation is still avoided
- PDF / DOCX / XLSX / PPTX parsing is still unimplemented
- OCR and external upload remain unimplemented
- Gmail / OAuth / Calendar write unchanged

## 2026-05-10 (Round 28A — File Intake UX Foundation)

- FileIntakeRequest / FileIntakeResult / FileIntakePolicy / FileIntakeService / FileIntakeView added
- txt / md / markdown / csv first
- pdf / docx / xlsx / pptx are prepared but not parsed
- dangerous extensions blocked
- large files blocked
- Universal Document helper prepared for next round
- no automatic document generation
- Gmail / OAuth / Calendar write unchanged

## 2026-05-10 (Round 27D — AgentPipeline Foundation)

## 2026-05-10 (Round 27D — AgentPipeline Foundation)

- AgentRole / AgentWorkOrder / PipelineContext added
- AgentPipelineRunner skeleton added with researcher -> drafter -> reviewer flow
- AgentPipelineFactory added for default document review pipeline
- step output now feeds next step input through pipelineContext
- VerificationLevel reused
- artifact content keeps persona dialogue out
- TeamOrchestrator entrypoint stays minimal and non-default
- File Intake remains unimplemented
- ToolExecution remains skeleton-only

## 2026-05-10 (Round 27C — RouteResolver + WorkflowRunner Split + ToolExecution Skeleton)

- RouteDecision / RouteResolver / GoalGate added
- WorkflowRunner / ToolExecutionLayer / ConnectorGuard skeleton added
- PlanExecutionResult gained failureReason for safe fallback control
- Universal Document plan path can now use WorkflowRunner wrapper
- PlanRunner safety / verification / budget failures stay out of legacy fallback
- existing route order remains intact
- File Intake, AgentPipeline remain unimplemented
- OAuth / Gmail / Calendar write / StoreKit / entitlement unchanged

## 2026-05-10 (Round 27B — PlanRunner Foundation with Feature Flag)

- FeatureFlags / VerificationLevel / WorkPlan / WorkStep / RecoveryAction / PlanExecutionResult added
- PlanRunner skeleton added for Universal Document
- UniversalDocumentPlanFactory added and feature-flag path prepared
- default path remains legacy Universal Document workflow
- planRunner fallback path prepared for future use
- File Intake, AgentPipeline, ToolExecutionLayer remain unimplemented
- OAuth / Gmail / Calendar write / StoreKit / entitlement unchanged

## 2026-05-10 (Round 27A — Runtime Safety + Context Gate)

- room별 `activeTasksByRoom`로 workflow task 관리 전환
- blocked capability는 dispatch 초반에서 early return
- RoomGoalContext / recent artifact reference skeleton 추가
- ClarificationPolicy를 sourceText / context 기반으로 보강
- Universal Document vague organize guard 강화
- ResultVerifier error는 저장 금지 + 1회 재생성 후 실패 안내
- Router burn-in에 blocked / context gate 회귀 케이스 보강
- File Intake는 이번 라운드에서 시작하지 않음
- OAuth / Gmail / Calendar write / StoreKit / entitlement unchanged

## 2026-05-10 (Round 26B — Universal Document Workflow Polish)

- Universal Document 과잉 감지를 줄이기 위해 generic 정리 요청 guard를 추가
- source text extraction을 fenced block / marker 기반으로 보강
- title / filename fallback을 type-specific + time suffix 방식으로 개선
- completion message를 유형 / 파일명 / 다음 액션 중심으로 다듬음
- ResultVerifier warning은 검토 메모 톤으로 정리
- Router burn-in에 App Launch / PrivacyTerms / PPT / XLSX / 잡담 회귀 케이스를 보강
- Gmail remains unimplemented
- Calendar write remains unimplemented
- OAuth / StoreKit / entitlement unchanged

## 2026-05-10 (Round 26A — Universal Document Workflows Foundation)

- 6개 문서 유형 요약 / 보고서 초안 / 체크리스트 / 표 정리 / 회의록 정리 / 액션아이템 추출 추가
- 자연어 기반 문서 라우팅과 Markdown artifact 저장 경로 연결
- GoalInterpreter 관측 결과와 충돌하지 않도록 route trace / turn profile 정리
- Router burn-in에 universal document 경계 케이스 추가
- ResultVerifier는 artifact 생성 후 warning 수준으로만 반영
- Gmail remains unimplemented
- Calendar write remains unimplemented
- OAuth / StoreKit / entitlement unchanged

## 2026-05-10 (Round 25C — Compact Team Window UX + Settings Cleanup)

- 팀 협업창 스케줄 팝업을 compact / scrollable 형태로 정리
- 하단 아이콘 바가 창 밖으로 밀리지 않도록 정리
- 팀 이름 명패 기본 배경 / 테두리를 transparent로 전환
- 명패 팔레트를 축소하고 Settings 미리보기를 제거
- CharacterGallery 설명을 단순화하고 개발 정보 agentID를 기본 화면에서 숨김
- Google OAuth client ID 입력을 DEBUG / 개발자 설정으로 분리
- OAuth 발급 안내는 QA 문서로 이동
- Gmail remains unimplemented
- Calendar write remains unimplemented

## 2026-05-10 (Round 25B-ManualQA — Calendar OAuth Live Test)

- live OAuth QA attempted
- Google Cloud Console Desktop OAuth client ID was not available in the workspace
- Google approval screen / callback / token exchange / Keychain / Calendar fetch runtime QA not completed
- Gmail remains unimplemented
- Calendar write remains unimplemented
- token / code logs remain forbidden
- StoreKit / entitlement unchanged

## 2026-05-10 (Round 25B-QA — Calendar OAuth Runtime Verification)

- TASK roadmap aligned to runtime verification state
- OAuth runtime QA checklist added
- Settings Google Calendar connection UX clarified
- OAuth error handling tightened for callback / token / keychain failures
- Calendar fetch error and empty states made more explicit
- Gmail remains unimplemented
- Calendar write remains unimplemented
- token / code logs remain forbidden
- StoreKit / entitlement unchanged

## 2026-05-10 (Round 25B — Google Calendar Desktop OAuth Connection)

- Google Calendar Desktop OAuth 연결
- Calendar read-only scope만 요청
- PKCE 추가
- token exchange 추가
- Keychain token storage 추가
- Calendar read-only events fetch 추가
- DailyBriefing calendar provider 연결
- Gmail 미구현
- 일정 생성 / 수정 / 삭제 미구현
- token / client secret 로그 없음
- StoreKit / entitlement 미수정

## 2026-05-10 (Round 25A.3 — Autonomy Observation Layer)

- GoalInterpreter를 dispatch 초반 관측층으로 연결
- room별 last goal 저장
- RouteTrace에 goalInterpreted 추가
- RuntimeDiagnostics에 goal / capability summary 추가
- RouterBurnInSuite에 goal evaluation 추가
- 기존 routing / skill execution 변경 없음
- 실제 OAuth / API 호출 없음
- StoreKit / entitlement 미수정

## 2026-05-09 (Round 25A.1-A.2 — OAuth Prep Polish + Autonomy Core Skeleton)

- TASK roadmap를 Round 25A.1-A.2 기준으로 정리
- TeamNameplate 색상 ColorPicker를 고정 팔레트 버튼으로 교체
- Google OAuth 준비 UI 문구 / naming polish
- GoalInterpretation / GoalInterpreter / ClarificationPolicy / CapabilityAwareRouter / ResultVerifier 추가
- 메일 read/write scope 분리 준비, user-initiated OAuth / automatic login 구분 준비
- 실제 OAuth / API 호출 / token exchange 미구현
- LLM 호출 추가 없음
- StoreKit / entitlement 미수정

## 2026-05-09 (Round 25A — Calendar Read-only Integration Preparation)

- GoogleOAuthConfigStore / GoogleOAuthConfigValidator 추가
- GoogleCalendarEvent / GoogleCalendarClient skeleton 추가
- DailyBriefingCalendarProvider 추가
- AssistantConnectorCatalog가 Google OAuth config readiness를 반영하도록 개선
- Settings에 Google OAuth 설정 준비 UI 추가
- 실제 OAuth / API 호출 / token exchange / Calendar fetch 미구현
- LLM 호출 추가 없음
- StoreKit / entitlement 미수정

## 2026-05-09 (Round 24 — Daily Briefing Skeleton)

- DailyBriefingModels / DailyBriefingService / DailyBriefingCardView 추가
- Settings에 briefing preview 추가
- connector 미연결 empty state 및 placeholder sections 구성
- 실제 OAuth / API 호출 / 메일 발송 / 일정 생성·삭제는 미구현
- LLM 호출 추가 없음
- StoreKit / entitlement 미수정

## 2026-05-09 (Round 23 — Google OAuth Connector Foundation)

- Google Calendar / Gmail connector foundation 추가
- macOS Desktop OAuth 전제 명시
- Web Server OAuth / CLI / gcloud 의존성 배제
- Calendar read-only 1순위, Gmail metadata 2순위, Gmail body read-only는 추후 승인 필요로 분리
- Settings에 비서 연결 준비 UI 추가
- 실제 OAuth / API 호출 / 메일 발송 / 일정 생성·수정·삭제는 미구현
- LLM 호출 추가 없음
- StoreKit / entitlement 미수정

## 2026-05-09 (Round 22R — Product Scope Reset)

- App Launch Pack 확장 보류
- MyTeam을 앱 출시 전용 도구가 아니라 범용 업무 팀으로 재정렬
- Core Work Pack 우선순위로 전환
- App Launch Pack 기존 4개는 유지
- 신규 App Launch 5개는 deferred

## 2026-05-09 (Round 21 — Router Burn-in + Tool Contract Validation)

### 빌드 목표
- 자연어 라우팅 회귀 케이스를 로컬에서 고정
- ToolRegistry / SkillRegistry / workflowTemplate 정합성 검증
- LLM 호출 없이 burn-in summary와 contract summary를 diagnostics에 노출

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| router burn-in | RouterBurnInCase.swift / RouterBurnInSuite.swift | App Launch / Delegation / PrivacyTerms / LocalSkill / Artifact / Direct Chat / Team Discussion 경계 케이스 추가 |
| tool contract validation | ToolContractValidator.swift | tool name / skill id / allowedScopes / workflowTemplate 정합성 검증 추가 |
| registry helpers | ToolRegistry.swift / SkillRegistry.swift | read-only helper 추가 |
| diagnostics | RuntimeDiagnosticsService.swift | router burn-in / tool contract summary 반영 |

### 주요 결정사항

- **LLM 호출 미추가**: burn-in과 validation은 로컬 문자열 / registry 데이터만 사용한다.
- **StoreKit / entitlement 미수정**: 결제·해금 경로는 건드리지 않는다.
- **실제 XCTest target 미추가**: burn-in은 로컬 validator로 운영한다.

### 빌드 상태
- BUILD SUCCEEDED ✅
- new warning 0 ✅

### 다음 단계
- Round 22: App Launch Pack Expansion

## 2026-05-09 (Round 20 — App Launch Result UX + Artifact UX)

### 빌드 목표
- App Launch Pack 결과 메시지를 제품답게 정리
- artifact 카드에 파일명 / 타입 / 저장 위치 / Finder 열기 / 경로 복사를 명확히 노출
- 위임모드 auto-resume과 충돌하지 않도록 유지

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| prompt quality | AppLaunchSkillService.swift | 앱 이름 질문 UX / 작성 가정 / 공통 규칙 강화 |
| completion message | AppLaunchArtifactWriter.swift | 완료 메시지와 실패 메시지 helper 추가 |
| workflow messaging | WorkflowOrchestrator.swift | App Launch 완료/실패 문구를 helper 기반으로 정리 |
| artifact card UX | ArtifactCardView.swift | 파일명, 타입, 저장 위치, Finder에서 열기, 경로 복사 표시 강화 |

### 주요 결정사항

- **artifact 저장 구조 유지**: ArtifactStore / IndexedArtifact는 건드리지 않는다.
- **실제 자동 실행 미수정**: delegation auto-resume은 유지하고 App Launch와 충돌하지 않게만 정리한다.
- **LLM 호출 미추가**: prompt와 메시지 품질만 개선한다.
- **StoreKit / entitlement 미수정**: 결제·해금 경로는 건드리지 않는다.

### 빌드 상태
- BUILD SUCCEEDED ✅
- new warning 0 ✅

### 다음 단계
- Round 21: Router Burn-in + Tool Contract Validation

## 2026-05-09 (Round 19.7 — Delegation Resume + Safe Auto-Continue)

### 빌드 목표
- 위임 요청의 원래 실행 의도를 room별 pending request로 보관
- 승인 시 안전한 요청만 기존 routing으로 자동 재개
- blocked / requires-reapproval 범위는 자동 재개하지 않음

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| pending execution | DelegatedExecutionRequest.swift | room별 pending delegated execution request 모델 추가 |
| detector | DelegatedWorkflowDetector.swift | normalized execution message / route hint / execution request 생성 helper 추가 |
| room 저장 | AgentWindowManager.swift | pending delegated execution request room별 메모리 저장 추가 |
| recursion guard | WorkflowOrchestrator.swift | delegation 자동 재개 시 `skipDelegationMode`로 재귀 감지 방지 |
| safe resume | WorkflowOrchestrator.swift | 승인 후 안전한 pending request는 기존 routing으로 재진입 |
| diagnostics | RuntimeDiagnosticsService.swift | pending delegation route hint / status 요약 추가 |

### 주요 결정사항

- **approval UI 미구현**: 승인 흐름은 텍스트 기반 skeleton만 유지한다.
- **안전한 pending request auto-resume 구현**: 승인 후 허용 범위의 pending request는 기존 routing으로 자동 재개한다.
- **위험 작업 자동 실행 미구현**: 결제 / 로그인 / 삭제 / 외부 전송은 자동으로 진행하지 않는다.
- **LLM 호출 미추가**: pending request 저장과 재개 판단은 로컬 문자열 / 상태 기반이다.
- **StoreKit / entitlement 미수정**: 결제·해금 경로는 건드리지 않는다.

### 빌드 상태
- BUILD SUCCEEDED ✅
- new warning 0 ✅

### 다음 단계
- Round 20: App Launch Result UX + Artifact UX

## 2026-05-09 (Round 19.6 — Delegation Mode Activation)

### 빌드 목표
- 자연어 위임 표현을 room별 delegation contract / plan / state로 기록
- 승인 전에는 실제 자동 실행을 시작하지 않음
- 결제 / 로그인 / 삭제는 차단 정책으로 분리

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| delegation state | DelegationModeState.swift | room별 delegation mode 상태 모델 추가 |
| delegation contract | DelegationContract.swift | 위임 범위, 차단 범위, 승인 범위를 담는 contract 모델 추가 |
| delegation plan | DelegatedWorkflowPlan.swift | 위임 작업의 단계 skeleton 추가 |
| approval policy | ApprovalPolicy.swift | auto allowed / approval required / blocked 정책 추가 |
| delegation detector | DelegatedWorkflowDetector.swift | 위임 요청 / 승인 / 종료 문구 감지 helper 추가 |
| room 저장 | AgentWindowManager.swift | delegation state / contract / plan room별 메모리 저장 추가 |
| routing | WorkflowOrchestrator.swift | 위임 요청 시 awaitingApproval 상태 저장, 승인/종료 skeleton 연결 |
| diagnostics | RuntimeDiagnosticsService.swift | delegation 상태 / goal / plan step count 요약 추가 |

### 주요 결정사항

- **실제 자동 실행 미구현**: 위임모드는 준비 상태와 승인 흐름만 기록한다.
- **approval UI 미구현**: 상태 전환과 안내 메시지만 남긴다.
- **LLM 호출 미추가**: 위임 감지와 plan 생성은 로컬 문자열 기반으로만 처리한다.
- **StoreKit / entitlement 미수정**: 결제·해금 경로는 건드리지 않는다.

### 빌드 상태
- BUILD SUCCEEDED ✅
- new warning 0 ✅

### 다음 단계
- Round 20: App Launch Result UX + Artifact UX

## 2026-05-09 (Round 19.5 — TurnProfile + RouteTrace + DryRun Skeleton)

### 빌드 목표
- 자연어 요청의 실행 경로를 turn profile과 route trace로 구조화
- room별 마지막 turn profile과 최근 route trace를 진단용으로 보관
- 실제 dry-run UI나 approval UI는 아직 구현하지 않음

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| turn profile | TurnProfile.swift | route, reason, scopes, skill IDs, candidate tools를 담는 lightweight model 추가 |
| route trace | RouteTrace.swift | routing 판단 흐름을 step/message/timestamp로 남기는 모델 추가 |
| dry-run skeleton | DryRunPlan.swift | 향후 approval preview용 action skeleton 추가 |
| room별 profile 저장 | AgentWindowManager.swift | `lastTurnProfileByRoom`, `routeTracesByRoom` 및 기록 helper 추가 |
| routing 기록 | WorkflowOrchestrator.swift | skill match, local skill, app launch, privacy terms, file creation, intent classification, direct chat, team discussion trace 기록 |
| diagnostics | RuntimeDiagnosticsService.swift | 마지막 route/profile 요약과 route trace 개수 스냅샷 추가 |

### 주요 결정사항

- **저장용 DB 아님**: 모든 profile/trace는 메모리 기반 진단용 상태로만 유지
- **LLM 호출 미추가**: route trace와 turn profile은 기존 경로를 따라 기록만 수행
- **기존 런타임 유지**: TeamRuntimeState, BYOK, 팀 이름 명패, App Launch Pack, Markdown 렌더링은 그대로 유지
- **실제 dry-run UI 미구현**: `/why`, `/last`에 대응할 기반만 먼저 마련

### 빌드 상태
- BUILD SUCCEEDED ✅
- new warning 0 ✅

### 다음 단계
- Round 20: App Launch Result UX + Artifact UX

## 2026-05-08 (Round 13 — StoreKit Local Test + Sena Purchase Wiring)

### 빌드 목표
- StoreKit 2 skeleton을 DEBUG용 local test wiring까지 연결
- 세나 1개만 테스트 구매 버튼 활성화
- `purchasedProductIDs`에 세나 product id가 들어오는지 확인 가능한 UI 뼈대 추가
- entitlement propagation, premium 해금, 팀 편입은 다음 단계로 보류

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| product helper | PurchaseManager.swift | `product(for:)`, `isPurchased(_:)`, `loadProductsIfNeeded()` 추가 |
| DEBUG 구매 wiring | CharacterGalleryView.swift | DEBUG에서만 세나 `테스트 구매` 버튼 활성화 |
| 구매 상태 확인 | CharacterGalleryView.swift | 세나 구매 시 `구매 확인됨` debug badge 표시 |
| restore skeleton | CharacterGalleryView.swift | DEBUG에서 `구매 상태 새로고침` 버튼 추가 |
| release 보호 | CharacterGalleryView.swift | release에서는 구매 버튼 비활성 상태 유지 |
| StoreKit config | - | `.storekit` 파일은 이번 라운드에 자동 생성하지 않았고 Xcode 수동 생성 필요로 유지 |

### 주요 결정사항

- **세나만 테스트**: 카이/유나는 계속 비활성 상태 유지
- **StoreKit import 범위 최소화**: `PurchaseManager.swift`와 DEBUG UI가 있는 `CharacterGalleryView.swift`로 제한
- **premium 미해금 유지**: `purchasedProductIDs`는 debug 상태 확인용이며 entitlement에는 아직 반영하지 않음
- **팀 편입 미구현**: 세나 구매가 확인돼도 팀에 자동 추가하지 않음

### 빌드 상태
- BUILD SUCCEEDED ✅
- 세나 DEBUG 구매 버튼 wiring 완료 ✅
- premium entitlement 미반영 유지 ✅

### 다음 단계
- MyTeam.storekit Xcode 수동 생성 + sandbox test
- entitlement propagation
- CharacterEntitlementManager 연결
- restore purchases 정식 UI
- Pro subscription gating
- purchase error UX

---

## 2026-05-08 (Round 12 — StoreKit 2 Skeleton for Character Products)

### 빌드 목표
- Character 상품 결제를 위한 StoreKit 2 skeleton 추가
- 첫 premium character 상품은 세나를 기준으로 product catalog 정리
- 실제 구매 버튼 연결, entitlement propagation, premium 해금은 다음 단계로 보류
- 기존 BYOK / Pro / CharacterDLC / Markdown / PrivacyTerms 동작 유지

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| 상품 ID 카탈로그 | ProductIDCatalog.swift | 캐릭터 DLC 및 Pro 구독 product id 상수 정의 |
| StoreKit skeleton | PurchaseManager.swift | `Product.products`, `purchase`, `Transaction.updates`, `currentEntitlements` 뼈대 추가 |
| productID 상수화 | CharacterCatalog.swift | premium 캐릭터 productID를 `ProductIDCatalog` 상수로 교체 |
| mapping validator | CharacterCatalog.swift | DEBUG에서 built-in `agentID` ↔ `agentPersonas` 경고 로그 추가 |
| DEBUG 노출 정리 | CharacterGalleryView.swift | 내부 `agentID` 텍스트를 DEBUG에서만 노출하도록 정리 |
| 갤러리 문구 보강 | CharacterGalleryView.swift | 구매 버튼 비활성 / StoreKit 다음 단계 안내 문구 추가 |

### 주요 결정사항

- **StoreKit import 위치 제한**: `StoreKit` import는 `PurchaseManager.swift`에만 추가
- **실제 구매 미연결**: 구매 버튼은 계속 disabled, `PurchaseManager.purchase()` UI 연결 없음
- **entitlement 미연결**: `AppEntitlementManager`, `CharacterEntitlementManager`는 StoreKit 결과를 아직 반영하지 않음
- **premium 미해금 유지**: 구매 성공 가정 로직을 넣지 않았고, premium 상태는 그대로 `출시 예정/잠김`
- **StoreKit config 파일은 이번 라운드 제외**: Xcode local StoreKit configuration은 수동 생성 필요로 남김

### 빌드 상태
- BUILD SUCCEEDED ✅
- StoreKit import는 `PurchaseManager.swift`에만 존재 ✅
- 실제 구매 버튼 미연결 ✅
- premium 캐릭터 미해금 ✅

### 다음 단계
- StoreKit config sandbox test
- Character purchase button wiring
- restore purchases UI
- entitlement propagation
- Pro subscription gating

---

## 2026-05-07 (Round 11.5 — Monetization Foundation before StoreKit)

### 빌드 목표
- StoreKit 2 구현 전 수익화/권한 모델 skeleton 정리
- CharacterDLC와 기존 agent 시스템을 나중에 연결할 수 있도록 agentID 매핑 필드 추가
- Pro / BYOK / 기본 제공량 정책을 코드 상수와 placeholder entitlement로 정리
- 기존 채팅, 스킬, Markdown, 캐릭터 갤러리 동작 유지

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| agent 연결 필드 | CharacterDLC.swift / CharacterCatalog.swift | `agentID` optional 추가, built-in 11명에 기존 `agent_1` ~ `agent_11` 매핑 반영 |
| 플랜 skeleton | MonetizationPlan.swift | `MyTeamPlan`, `PlanLimits`, `MonetizationPlanCatalog` placeholder 정책 추가 |
| 앱 entitlement | AppEntitlementManager.swift | 현재 plan / limits / BYOK / 캐릭터 보유 여부를 읽는 placeholder 추가 |
| BYOK 정책 | BYOKPolicy.swift | BYOK 지원 여부, 기본 제공량 분리 원칙, 지원 provider 목록 명시 |
| 설정 UI 보강 | SettingsView.swift | 캐릭터 탭 상단에 plan summary 카드 추가, `Pro 준비 중` disabled 버튼 추가 |
| 갤러리 문구 보강 | CharacterGalleryView.swift | StoreKit 예정 / BYOK 권장 문구와 built-in agentID 표시 추가 |

### 주요 결정사항

- **StoreKit 미구현**: 결제 프레임워크 import, transaction 처리, restore purchase는 아직 연결하지 않음
- **Enforcement 미구현**: included usage / artifact / active agents 제한은 정책값만 두고 실제 차단은 하지 않음
- **BYOK 우선 구조**: 포함 사용량은 온보딩용 placeholder로만 두고, 초과 사용은 개인 API 키 연결 정책을 코드에 명시
- **agentID는 표시용 매핑만**: 기존 라우팅, 팀 편입, agent 배열은 건드리지 않음

### 빌드 상태
- BUILD SUCCEEDED ✅
- StoreKit import 없음 ✅
- 실제 결제 / 차단 로직 없음 ✅

### 다음 단계
- StoreKit 2 skeleton
- ProductID catalog
- Transaction listener
- restore purchases
- first premium character sandbox test

---

## 2026-05-07 (Round 10 — Native Markdown Rendering)

### 빌드 목표
- 모든 LLM 응답을 plain Text가 아니라 Markdown으로 렌더링
- AttributedString(markdown:) 기반 네이티브 구현 (외부 패키지 무)
- fenced code block 분리 및 syntax highlight 미지원 버전
- 기존 SkillResultRendererView, character-count 카드 동작 유지

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| Markdown 렌더러 | MarkdownTextView.swift | AttributedString(markdown:) 기반, fenced code block 파싱 + fallback |
| 코드 블록 뷰 | CodeBlockView.swift | 언어명 표시, 복사 버튼, monospaced font, 둥근 테두리 |
| Chat 렌더링 | (Step 3 예정) | AgentChatView/TeamStatusView: Text → MarkdownTextView 교체 |
| Skill 렌더러 | (Step 4 예정) | SkillResultRendererView: fallback → MarkdownTextView |
| 회귀 테스트 | DEVLOG 기록 | privacy-terms artifact 표시 + character-count 카드 유지 |

### 지원 Markdown 범위

✅ **지원**:
- 제목: `#`, `##`, `###` (AttributedString 자동 처리)
- 굵게: `**text**` 또는 `__text__`
- 기울임: `*text*` 또는 `_text_`
- 인라인 코드: `` `code` ``
- 불릿 리스트: `- item`
- 번호 리스트: `1. item`
- 인용: `> quote`
- 링크: `[text](url)` (클릭 처리는 기본만)
- Fenced code block: ` ``` language ... ``` `

❌ **미지원 (v1)**:
- Markdown table (HTML로 fallback)
- Mermaid 다이어그램 (SVG 미렌더링)
- LaTeX 수식
- HTML 직접 렌더링
- Syntax highlighting (monospaced만)

### 주요 결정사항

- **Native AttributedString**: swift-markdown 패키지 추가 안 함 (v2에서)
- **Code block 분리**: ` ``` ` 감지 → CodeBlockView 별도 렌더링
- **Parse 실패 fallback**: 에러 발생 시 plain Text 표시 (crash 방지)
- **SKillRenderer 유지**: character-count, korean.spell-check 등 기존 카드는 깨지지 않음
- **User message는 plain Text 유지**: 사용자가 Markdown을 입력했을 때 렌더링 원치 않을 수 있음

### 빌드 상태
- BUILD SUCCEEDED ✅
- MarkdownTextView.swift 신규 추가 ✅
- CodeBlockView.swift 신규 추가 ✅
- Xcode 자동 인식 ✅

### Round 10-1 구현 결과 (완료)

**완료:**
✅ MarkdownTextView.swift — 신규 struct 작성, AttributedString(markdown:) 기반 파싱
✅ CodeBlockView.swift — 신규 struct 작성, 언어명+복사 버튼+monospaced rendering
✅ pbxproj 등록 — PBXFileReference, PBXBuildFile, PBXSourcesBuildPhase 추가
✅ SkillResultRendererView — fallback에 Markdown 적용 (user: Text, assistant/system: MarkdownTextView)
✅ ChatComponents.swift IMMessageBubble — assistant/system 메시지를 MarkdownTextView로 렌더링
✅ TeamStatusView.swift chatroomLogView — 팀 채팅 로그에 Markdown 적용
✅ 빌드 성공 — BUILD SUCCEEDED (error 0, new warning 0)
✅ Character-count 카드 회귀 유지

**특징:**
- Assistant/System 메시지: Markdown 지원
- User 메시지: Plain text 유지 (rendering 불필요)
- Privacy-terms artifact: Markdown 표시 가능
- Fenced code block: 언어명 표시 + monospaced font + 복사 버튼
- Parse 실패: Plain text fallback

**미지원:**
- Table, Mermaid, LaTeX, syntax highlighting

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

## 2026-05-06 (Round 9 Hotfix — Korean Privacy Terms Security Hardening)

### 보안 강화 목표
- 위조 기업 문서 생성 방지 (ownership confirmation)
- 서비스명 필수 입력 검증 (빈 값 거부)
- LLM 호출 비용 관리 (provider fallback 제한)
- UUID 기반 artifact 추적 강화

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| 요청 검증 | KoreanPrivacyTermsService.swift | extractRequest() returns nil if serviceName empty; added needsMoreInfo() + needsOwnershipConfirmation() |
| 소유권 확인 | WorkflowOrchestrator.swift | dispatch() 상단에 ownership check → 기업명 키워드 + 소유 문맥 검증 후 early return |
| Provider 제한 | AIService.swift | generatePrivacyTerms() Gemini 먼저 시도, 쿨다운 시 Claude 1회만 fallback (OpenAI 제외) |
| Artifact 저장 | KoreanPrivacyTermsArtifactWriter.swift | write() 시그니처 변경 (UUID workflowID/roomID), 추적 로그 강화 |
| 면책문구 | KoreanPrivacyTermsArtifactWriter.swift | "출시 준비용 초안", "법무팀 검토 필수", "기술 검수" 명시 |
| 워크플로우 정리 | WorkflowOrchestrator.swift | serviceName 부재/ownership 실패 시 isWorkflowRunning 설정 전 early return (UI stuck 방지) |

### 주요 검증 항목

| 검증 항목 | 기대 결과 | 상태 |
|---|---|---|
| serviceName 비어있을 때 | extractRequest() returns nil, 사용자 프롬프트 "회사/서비스명을 말씀해 주세요" | ✅ |
| "삼성 갤럭시 개인정보처리방침 만들어줘" | needsOwnershipConfirmation() 감지 → 정책 위반 경고 early return | ✅ |
| "우리 갤럭시 앱 개인정보처리방침 만들어줘" | ownership context 있음 → 계속 진행 | ✅ |
| Gemini 쿨다운 중 요청 | Claude fallback 1회만, OpenAI 시도 없음 | ✅ |
| 프라이버시 생성 budget 초과 | AICallBudgetManager 1회 제한, 초과 시 차단 메시지 | ✅ |
| Artifact roomID/workflowID 로그 | `[KoreanPrivacyTermsWriter] artifact 저장: ... workflowID=xxxx... roomID=yyyy...` | ✅ |

### 모든 hotfix 항목 완료
- ✅ KoreanPrivacyTermsRequest 구조 강화 (serviceName 필수)
- ✅ needsMoreInfo() 구현
- ✅ needsOwnershipConfirmation() + WorkflowOrchestrator 통합
- ✅ 키워드 플래그 추출 (detectAds, detectPayments 등)
- ✅ buildPrompt() 강화 (기능별 사용 현황 섹션)
- ✅ Provider fallback 제한 (Gemini → Claude 1회만)
- ✅ ArtifactWriter UUID 추적 (workflowID, roomID)
- ✅ 면책문구 강화 (출시 준비용 초안, 법무팀 검토)
- ✅ WorkflowOrchestrator 상태 정리 (early return)
- ✅ BUILD SUCCEEDED

### 주의사항
- **High-risk 스킬 차단**: riskLevel ∈ {reservation, payment, accountLogin} 의 스킬은 defaultEnabled: false + requiresApprovalEveryRun: true 필수
- **Provider 추가 금지**: OpenAI를 privacy-terms 생성에 사용하지 않음 (비용 관리)
- **Gemini 쿨다운 존중**: 1분 내 429 응답 1회 → 120초 전체 provider 차단 (fallback만 사용)

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

## 2026-05-07 (Round 11 — CharacterDLC Model + Read-only Character Gallery)

### 빌드 결과
- **BUILD SUCCEEDED** · error 0 · new warning 0

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| CharacterDLC 모델 | `CharacterDLC.swift` | persona, sprite, role, bundled skill preset, preview voice/theme, 향후 StoreKit product id까지 담는 판매 단위 모델 추가 |
| CharacterCatalog | `CharacterCatalog.swift` | built-in 11명과 premium 3명(세나/카이/유나)을 read-only catalog로 분리 |
| entitlement placeholder | `CharacterEntitlementManager.swift` | built-in은 owned, premium은 comingSoon/locked로만 판정하는 결제 전 단계 관리자 |
| read-only 갤러리 UI | `CharacterGalleryView.swift` | 기본 캐릭터/프리미엄 캐릭터 섹션, 상태 배지, bundled skill chips, disabled 버튼 제공 |
| Settings 캐릭터 탭 | `SettingsView.swift` | 5번째 탭 `캐릭터` 추가, 폭만 `420 → 460`으로 소폭 조정 |

### 정책 고정

- StoreKit 2 **미구현**
- premium 캐릭터 **실제 팀 편입 미연결**
- 구매 버튼 **전부 disabled**
- 기존 Agent roster / team routing / Markdown / skill 실행 경로 **미변경**

### Round 11 premium 후보

| 이름 | 역할 | productID | 표시가 |
|------|------|-----------|--------|
| 세나 | 앱 출시 PM | `com.myteam.character.sena` | `₩3,900` |
| 카이 | 코드 리뷰 아키텍트 | `com.myteam.character.kai` | `₩3,900` |
| 유나 | 콘텐츠 전략가 | `com.myteam.character.yuna` | `₩3,900` |

### 다음 단계

- StoreKit 2 skeleton
- first premium character product wiring
- character asset pipeline
- feature gating
- BYOK/basic usage gating

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

## Round 14 - BYOK Center / Team Nameplate / Collaboration Status

- Added BYOK provider center cards for OpenAI, Claude, Gemini, and OpenRouter.
- Added usage policy summary card with Free/Pro placeholder limits.
- Added team nameplate ON/OFF and color settings in Settings.
- Added collaboration status banner and idle rotation text in the team view.
- Added schedule popover for the clock/schedule button.
- API key values remain hidden; no usage enforcement or StoreKit entitlement wiring was added.

## Round 14.1 - BYOK Status Refresh / Keychain Key Verification

- BYOK provider center now reloads status on appear and through a manual refresh button.
- Verified provider keychain keys: `geminiAPIKey`, `openAIAPIKey`, `claudeAPIKey`, `openRouterAPIKey`.
- API key values remain hidden; no API test call or routing change was added.

## Round 15 - App Launch Pack Artifact Skills

- Added 4 app launch pack skills: app store copy, onboarding copy, launch checklist, and monetization review.
- App name is required before artifact generation; missing app name returns a question prompt instead of generating a file.
- Generated output is written as Markdown artifact in the workspace with a safety disclaimer appended.
- No external API, web search, or App Store Connect call was added.
- StoreKit, entitlement, premium unlock, and existing BYOK/team status behavior were left unchanged.

## Round 15.1 - App Launch Skill Routing Hotfix

- App launch skill detection now prefers explicit document types first.
- Monetization routing now requires explicit monetization document intent.
- Advertising, subscription, and in-app purchase terms are treated as supporting details unless the user explicitly asks for monetization review.
- App name extraction was strengthened for common "app name + app/document" phrasing.

## Round 16 - Agent Replacement / Store UX Cleanup

- Replaced user-visible "미구현" placeholder UX with coming-soon copy in the agent swap screen.
- Store/hire-style buttons now read as launch-ready placeholders instead of dead actions.
- Premium characters remain unavailable for team insertion.
- StoreKit, entitlement, and premium unlock wiring remain untouched.
- Built-in agent swap behavior remains unchanged.

## Round 17 - App Launch Pack Result UX + Prompt Quality

- App Launch Pack prompt quality was tightened for app-store copy, onboarding, launch checklist, and monetization review.
- App name missing flows now use a more natural question prompt, while optional fields are handled as drafting assumptions instead of hard blockers.
- Artifact completion messages now include the filename plus Workspace/Finder guidance.
- StoreKit, entitlement, premium unlock, BYOK, team nameplate, and collaboration status flows were left untouched.

## Round 19 - Team Collaboration Window Deep Polish

- Team runtime cohesion now records discussion start, speaker selection, agent turn start/completion, and discussion completion/failure states.
- TeamStatusView reflects workflow activity and the current team runtime state with short-lived completion/failure states.
- Idle copy rotates through character-flavored lines without LLM calls or routing changes.
- The collaboration refresh loop is task-backed and cancels cleanly when the window disappears.
- The schedule/clock button now opens a compact coming-soon popover instead of a dead or heavy panel.
- IntentRouter double-calls were reduced by passing precomputed routing into TeamOrchestrator.
- StoreKit, entitlement, premium unlock, BYOK, and App Launch Pack flows were left untouched.

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
