# MyTeam Task Tracker

> 위치: `/Users/su/Desktop/MyTeam/TASK.md`
> 목적: 앞으로 가야 할 길만 관리한다. 완료 이력은 `DEVLOG.md`에 남긴다.
>
> **기준 브랜치: `main`** — 모든 작업은 main에서 시작하고 main에 커밋한다.
> `git-push`는 PR/배포 미러용이며 작업 기준이 아니다. main 커밋 후 `git push origin main:git-push`로 동기화.
>
> **경로 규칙:** 실제 Swift 파일 위치는 `MyTeam/MyTeam/*.swift` (flat).
> Antigravity/Claude/Codex는 이 경로만 수정한다. 루트 `MyTeam/*.swift`는 없다.
> 신규 파일도 `MyTeam/MyTeam/` flat에 추가 후 Xcode target에 포함.

---

## Current Execution Plan — 2026-05

### Product Positioning — Core Work Pack First

MyTeam은 앱 출시 전용 도구가 아니다.

MyTeam은 Mac 안에서 사용자의 자연어 요청을 받아, 문서/파일/표/메일/일정/웹자료를 팀원처럼 처리하는 AI 업무 팀이다.

핵심 사용자는 다음과 같다.

- 사무직 사용자
- 1인 창업자
- 콘텐츠 제작자
- 기획자
- 세무/회계/관리 업무 사용자
- 개발자/디자이너가 아니어도 반복 문서 업무가 많은 사람

원칙:

- 사용자는 자연어로 요청한다.
- 앱은 요청을 해석해서 알맞은 경로를 자동 선택한다.
- 명령어는 power user용 shortcut이다.
- 일반 사용자는 자연어만 써도 된다.
- 자연어 요청은 먼저 skill/router/policy를 거쳐 적합한 실행 경로로 간다.
- 위험 작업은 scope, risk, approval policy로 차단한다.
- 모델이 잘못된 tool을 선택해도 ToolExecutor hard guard에서 다시 막는다.
- LLM 호출 없이 처리 가능한 local skill은 LLM보다 먼저 실행한다.
- artifact 생성 요청은 가능한 한 명시적 파일 결과로 남긴다.
- 팀 협업창은 현재 어떤 agent/tool/workflow가 동작 중인지 보여줘야 한다.
- 모델 판단 자율성은 높이되, 실행은 scope / risk / approval policy로 통제한다.

### Autonomy Policy

- Level 1: Answer Only
- Level 2: Local Skill
- Level 3: LLM Skill
- Level 4: Artifact Workflow / Tool Workflow
- Level 5: External Write / Payment / Login

- Level 1~3은 비교적 자유롭게 실행 가능하다.
- Level 4는 scope / risk 검증이 필요하다.
- Level 5 이상은 기본 차단 또는 명시 승인 필요하다.
- 로그인, 결제, 예약, 외부 전송, destructive action은 자동 실행 금지다.

### Now

#### Round 163B-UXNAV — Agent Quick Navigation + Starter Copy Polish Pack

목표:
- 체크리스트 starter action 설명 문구 수정 ("업무 준비 요소를 체크리스트로 정리합니다")
- AgentQuickSwitchBar 신규 컴포넌트 추가
- 왼쪽 사이드바 하단에 팀원 얼굴 quick switcher 배치
- 팀 워크룸 ↔ 개별 대화 이동 개선
- 개인 대화 정체성 유지 (room agentIDs != 1 방지)
- 개인 대화에서 팀 워크룸 복귀 shortcut 추가
- RuntimeDiagnostics 5개 신규 필드
- ToolContractValidator 5개 신규 validator
- RouterBurnInSuite 3개 신규 케이스
- Debug/Release build warning 0 유지

### Recently Completed

#### Round 181A-195Z — Workroom Productization + Core Loop Surface Pack

진행 중 (2026-05-16):
- AgentChatView await warning 2개 정리 (Task 래퍼 제거, await 제거)
- WorkroomHomeModel.swift: UI projection (room-scoped data) 신규 파일
- WorkroomHomeView.swift: 워크룸 홈 대시보드 신규 파일
- WorkroomPrimaryAction enum: 3 main CTA (문서/파일/정리)
- WorkroomNextAction enum: 4 follow-up actions
- TeamStatusView / AgentChatView에 WorkroomHomeView 연결
- 문서 만들기를 primary CTA로 고정 (회의록 기본, 선택 가능)
- Workroom recent artifact rail 정리 (max 3, room-scoped only)
- Workroom next actions 정리 (최근 artifact 있을 때만 표시)
- Room goal/current goal 표시 (없으면 "무엇을 정리할까요?")
- RuntimeDiagnosticsService 8개 신규 필드 (workroom/await 관련)
- ToolContractValidator 5개 신규 validator
- RouterBurnInSuite 5개 신규 케이스 (workroom 관련)
  - workroom-open
  - workroom-new
  - workroom-create-document
  - workroom-today-organize
  - workroom-file-handoff
- 문서 2개 (WorkroomProductizationPolicy.md, WorkroomCoreLoop.md)

#### Round 164A-180Z — Document Creation Killer Workflow Pack

완료 (2026-05-16):
- DocumentCreationType enum (meetingMinutes, checklist, reportDraft) 정의
- LocalDocumentTemplate markdown 템플릿 생성 (로컬 fallback)
- DocumentCreationService (detectDocumentCreationIntent, createLocalDocument) 구현
- WorkResultKind enum (문서 유형별 아이콘, 제목, 색상) 정의
- WorkResultCardView에 kind 파라미터 추가 (조건부 헤더: kind vs agent)
- RouterBurnInSuite 10개 신규 테스트 케이스 추가
  - 문서 만들기 hub
  - 3가지 문서 타입 (meetingMinutes/checklist/reportDraft)
  - 4가지 follow-up actions (요약/표/체크리스트/액션아이템)
- RuntimeDiagnosticsService 9개 신규 필드 추가
- ToolContractValidator 5개 신규 validator 추가
- 문서 2개 (KillerWorkflowPolicy.md, DocumentCreationCoreFlow.md)
- Debug BUILD SUCCEEDED (AgentChatView 기존 warn 2개만 유지)
- Release BUILD SUCCEEDED (AgentChatView 기존 warn 2개만 유지)
- No duplicate build file warnings
- Commits: feat/docs-commit (TBD)

#### Round 153A-162Z FINAL — Inline Artifact Resolver + Result Card Completion Pack

완료 (2026-05-16):
- AgentWindowManager / RoomRuntimeStore에 room-scoped artifact lookup 추가
- ChatLog.artifactIDs → IndexedArtifact resolver 구현
- AgentChatView에서 artifact resolve 및 WorkResultCardView에 전달
- WorkResultCardView 내부에 compact ArtifactCardView inline 표시
- AgentChatView 하단 artifact 목록에서 inline 표시된 artifact dedup
- SkillResultRendererView generic fallback polish 완성
- RuntimeDiagnostics 4개 신규 필드, ToolContractValidator 3개 신규 validator
- RouterBurnInSuite 신규 케이스
- Debug + Release BUILD SUCCEEDED
- Commits: ea38e91, ff0ef76, 8520219, 543b761, docs/ManualRuntimeQAResult.md

#### Round 146A-152Z — Result Presentation + Room Kind + UX Surface Polish

완료 (2026-05-15):
- WP6: FirstResultActionStrip 중복 제거 (TeamStatusView에서 제거, AgentChatView만 유지)
- WP7: 협업 상태 배너 압축 (2줄 카드 62px → 1줄 컴팩트 바 ~32px)
- WP2-lite: WorkResultCardView 도입 (긴 어시스턴트 응답 260px 버블 탈출, 500자+ 접기/펼치기)
- 어시스턴트 메시지 버블 maxWidth 260→480
- ChatLog에 artifactIDs 필드 추가 (기본값 [], 디코딩 호환)
- ArtifactCardView 상태 텍스트 순화
- RoomKind computed property (teamWorkroom/personalChat 구분, 아이콘 분리)
- RuntimeDiagnostics 8개 신규 필드
- ToolContractValidator 5개 신규 validator
- RouterBurnInSuite 6개 신규 케이스
- 문서 3개 (ResultPresentationPolicy.md, RoomKindPolicy.md, ProductIAPolicy/WorkSurfaceSimplificationPlan 갱신)
- Debug + Release BUILD SUCCEEDED
- Commit: ea38e91

### Next

#### Round 160A+ — Submission Pack

### Next (후순위)

### Later

#### Round 160A+ — Submission Pack

목표:

- App Store archive 생성
- App Store Connect upload
- Review 대기 및 승인
- 실제 submission
- Finder/path copy 확인
- File intake sandbox 확인
- StoreKit sandbox purchase QA
- Google OAuth live QA

### Recently Completed

- Round 137A-145Z — Product IA Hardening + Room-Scoped Artifact + Work Surface Simplification ✅
  - Room-scoped recentArtifacts, 용어 정책 통일, TeamStatusView 단순화
  - AgentChatView switcher 제거, 온보딩 통합, timer leak 수정
  - WP3+WP5+WP1 (설정 누출 차단, 예약 작업 통합, 온보딩 표면 통합)
- Round 136A — Mac Local Sync + Target Registration + Build Repair Pack ✅
  - git pull origin main (889a269, 7b39c7d, 9426434 포함 확인)
  - pbxproj target audit: 15/15 present (audit script 쿼트 버그 수정 포함)
  - 4개 파일 target 등록: ProductSurfacePolicy, ConnectorSurfacePolicy, FirstResultActionPolicy, StarterActionPolicy
  - 6개 compile 에러 수정 (CharacterAssetAvailability 중복, artifactGeneration 케이스, connectorRead scope, fileExists, missing init args 등)
  - Debug xcodebuild: BUILD SUCCEEDED, warning 0, duplicate 0
  - Release xcodebuild: BUILD SUCCEEDED, warning 0, duplicate 0
  - cloud preflight: privacy clean ✅, CharacterID ✅, StarterAction ✅, pbxproj 15/15 ✅
- Round 76A-95Z — Release Gate Audit + Policy Enforcement + Internal Review Pack ✅
- Round 43R-FIX — Push Recovery + Target Registration + Real Surface Completion Pack ✅
- Round 43A-47H — Product Completion Without QA Pack (components/docs prepared) ✅
- Round 40R + 41A-41F — Release Truthfulness Repair + First Launch Activation Pack (Structural Foundation) ✅
- Round 40A-40D — App Store Submission Hardening Pack ✅
- Round 39A-39D — Release Runtime QA + Packaging Readiness Pack ✅
- Round 38A-38D — ArtifactStore Relative Path + Compaction Pack ✅
- Round 37A-37D — Memory Security + Release Stability Pack ✅
- Round 36A-36D — Tool Execution Layer Real Adoption + Capability Surface Pack
- Round 35B-35E — Runtime Safety Closure + File Workflow Completion Pack
- Round 34C-Repair (Step 4 & 6) — Verification fail-closed + Runtime diagnostics ✅
- Round 34C — Artifact / Verification / Store Performance Pack ✅
- Round 34B-2 — Local Scheduler Command Completion Pack ✅
- Round 34B — Local Scheduler Command Routing Infrastructure ✅
- Round 34A — Runtime Safety Contract Hotfix Pack
- Round 35A — File Intake Planned Types + Persistence Hardening
- Round 33B-33D — Actionable Briefing + Scheduler Commands + Artifact Reuse Polish
- Round 33A — Recent Artifact Reuse Pack
- Round 32B — Local Task Briefing Runtime QA + Action Integrity Polish
- Round 32A — Local Task Briefing Pack
- Round 31D — PlanRunner / AgentPipeline Contract Alignment
- Round 31C — Workflow Runner Boundary Expansion + Runtime Store Hardening
- Round 31B — Room Runtime Store Boundary
- Round 31A — Bottleneck Fix Pack
- Round 30C — Daily Briefing Runtime QA + System Bottleneck Audit
- Round 30B — Daily Briefing Runtime UX + Connector Guard Polish
- Round 30A — Daily Briefing / Connector Runtime Prep
- Round 29B — Runtime QA Verification + Small Fix Pack
- Round 29A — Workflow QA Burn-in Pack
- Round 28C — File Intake UX Polish + Planned Types
- Round 28B — File Intake to Universal Document Workflow
- Round 28A — File Intake UX Foundation
- Round 27D — AgentPipeline Foundation
- Round 27C — RouteResolver + WorkflowRunner Split + ToolExecution Skeleton
- Round 27B — PlanRunner Foundation with Feature Flag
- Round 27A — Runtime Safety + Context Gate
- Round 26B — Universal Document Workflow Polish
- Round 26A — Universal Document Workflows Foundation
- Round 25C — Compact Team Window UX + Settings Cleanup
- Round 25B-ManualQA — Calendar OAuth Live Test
- Round 25B-QA — Calendar OAuth Runtime Verification
- Round 25B — Google Calendar Desktop OAuth Connection
- Round 25A.3 — Autonomy Observation Layer
- Round 25A.1-A.2 — OAuth Prep Polish + Autonomy Core Skeleton
- Round 25A — Calendar Read-only Integration Preparation
- Round 24 — Daily Briefing Skeleton
- Round 23 — Google OAuth Connector Foundation
- Round 22R — Product Scope Reset
- Round 21 — Router Burn-in + Tool Contract Validation
- Round 20 — App Launch Result UX + Artifact UX
- Round 19.7 — Delegation Resume + Safe Auto-Continue
- Round 19.6 — Delegation Mode Activation
- Round 19.5 — TurnProfile + RouteTrace + DryRun Skeleton
- Round 19 — Team Runtime Cohesion + Collaboration Status

### Deferred Runtime QA Backlog

#### UI Interaction QA
- Finder open
- path copy
- fileImporter sandbox
- action chip tap

#### Multi-room Runtime QA
- active task isolation
- wrong-room artifact reuse
- pending delegation resume

#### Connector QA
- Google Calendar live OAuth
- Gmail metadata later

#### Release QA
- debug toggles hidden
- diagnostics minimized
- PlanRunner default false

### Legacy / Deferred

- Round 34D — Artifact UX + Recent Reuse Polish
- artifact card와 recent artifact reuse UX polish
- 최근 문서 재사용 실패 메시지 개선
- Finder / path copy deferred QA 일부 회수 가능
- RecentArtifactIndex persistence 검토
- Release / DEBUG PlanRunner path distinction 문서화

#### Round 25B-Blocked — Waiting for Google OAuth Desktop Client ID

목표:

 - Google OAuth Desktop client ID 준비 대기
 - live QA 재시도
 - Calendar read-only 연결 검증
 - Gmail / Calendar write 미구현 유지

#### Round 26 — Gmail Metadata Briefing

목표:

 - Gmail metadata scope
 - 새 메일 수
 - 발신자 / 제목 / snippet
 - 본문 읽기 없음
 - 발송 / 삭제 없음

#### Round 29 — Email / Reply Draft Pack

목표:

- 메일 초안
- 답장 초안
- 정중한 거절
- 업무 요청
- 회의 일정 제안
- 실제 발송은 금지

#### Round 30 — Blog / Content Pack

목표:

- 네이버 블로그 제목 후보
- 모바일 최적화 본문
- 썸네일 문구
- SEO 키워드
- 맛집 / 체험단 후기 구조
- 인스타 / 스레드 요약 문구

#### Round 31 — Accounting / Tax Helper

목표:

- 엑셀 장부 정리
- 계정과목 후보
- 증빙 체크리스트
- 부가세 / 면세 / 과세 구분 보조
- 법적 판단 / 신고 대행 금지
- “검토용 초안” 원칙 유지

### Deferred

- App Launch Pack은 optional/founder pack으로 분류한다.
- App Launch Pack Expansion
- Developer Repo Review Pack
- Finance Pack
- Public Data / Law Pack
- Premium Character Team Add Flow
- StoreKit entitlement propagation
- SwiftData migration
- TTS retuning
- Full QA regression
- StoreKit production purchase
- Pro gating enforcement

---

## 목표

Mac App Store에 출시 가능한 macOS 네이티브 AI 팀 앱.
기준은 “애플 퍼스트파티급 반응성, 안정성, 마감감”이다.

작업 전 체크:

1. Mac App Store 샌드박스에서 동작하는가?
2. 외부 Python 서버, 절대경로, 평문 API 키, destructive automation이 없는가?
3. 사용자가 캐릭터와 팀을 이해하고 신뢰할 수 있는가?
4. TTS가 캐릭터별로 일관되고 3~4초 목표에 가까운가?

---

> 아래 P0~P5는 legacy backlog다. 현재 작업 우선순위는 상단 Current Execution Plan을 따른다.

## P0 — 출시 경로 블로커

### 현재 상주 문제

- [x] Qwen3 TTS는 voice clone OFF 상태에서도 5초대 발화에 합성 5~7초, RTF 1.04~1.32로 즉각 반응 목표 미달.
- [x] 앱 컨테이너 HuggingFace 캐시가 비어 있으면 샌드박스 앱에서 모델 다운로드 단계에 묶임.
- [x] `Backup_claude_worktrees/`, `xcodebuild_out.txt`, pbxproj backup, 레거시 TTS 파일이 graph/search/build 판단을 계속 오염시킴. → .gitignore 격리 + 루트 스크립트 `tools/legacy/` 이동.
- [x] `print()` 중심 로그가 TTS/Audio/legacy noise로 런타임 콘솔을 묻음. → Qwen3TTSService/AudioPlaybackService/AIService의 print를 AppLog로 전환.
- [x] 팀 대화 selector 실패 시 랜덤 fallback이 있어 판단 품질이 흔들림. → deterministic fallback 적용.
- [x] TTS 대기 루프가 최대 120초라 팀 대화 진행을 막을 수 있음. → 팀 대화 텍스트 진행과 TTS 대기 분리.
- [x] 창 위치/크기 저장이 `UserDefaults` 키 분산 방식이라 패널별 정책이 섞임. → 패널 타입별 persistence policy 분리.
- [x] App Store 기준 `/open`, 외부 파일, 모델 캐시, 자동 스케줄 실행 정책이 아직 코드 레벨로 분리되지 않음. → `AutomationPolicy.swift` + `/open` Release 빌드 URL-only 제한.

### 다음 실행 순서

1. App Store sandbox/캐시/권한 경로를 먼저 고정한다.
2. 빌드 경고와 런타임 로그를 정리한다.
3. 설정창/스케줄/창 크기 UX를 안정화한다.
4. 팀/개인 대화 판단 로직 품질을 올린다.
5. TTS는 별도 게이트 통과 전까지 재튜닝하지 않는다.

### TTS 안정화

- [x] 앱 런타임 `MYTEAM_TTS_PROBE=1` 측정 경로 추가. 결과는 앱 컨테이너 `Application Support/MyTeam/TTSBench/`에 JSON/WAV로 남긴다.
- [x] voice clone 기본 OFF 정책 고정. `MyTeam.TTS.useQwenVoiceClone == true`일 때만 개발 검증 모드로 켠다.
- [x] 앱 컨테이너 모델 캐시 병목 확인. 비샌드박스 캐시는 앱스토어 런타임과 별개라 컨테이너/ODR/초기 다운로드 정책이 필요하다.
- [x] 2026-05-01 부분 측정: Qwen3 base도 5초대 발화에 합성 5~7초, RTF 1.04~1.32로 즉각 반응 목표 미달. TTS는 측정 기반 보류 후 다른 P0 품질 작업 우선.
- [ ] 캐릭터별 TTS 실청 테스트: 레오, 루나, 래키, 렉스, 모코, 치코, 핀, 폴라, 케이, 몽몽, 올리버.
- [x] `동물의숲 효과`를 TTS 후처리 토글로 복원하고 기본값 OFF 유지.
- [x] 캐릭터별 pitch/rate를 catalog 구조로 분리하고 안전 범위 clamp 적용.
- [ ] 각 캐릭터별 reference 로드 여부 로그 확인.
- [x] reference 파일 존재 여부 확인 + `voices-audit.md` 초안 작성. → 11개 모두 존재, 길이 기준(4~7s) 초과(13~21s) — clipping 후 사용 중이므로 즉각 위험 없음. 실청 검수 필요.
- [ ] 5/25/50/100자 합성 시간, RTF, 메모리 사용량 측정.
- [ ] Qwen3를 계속 쓸지 판단하는 게이트 정의: 앱 컨테이너 캐시 완료, cold start, 25자 이하 응답, RTF, 실청 통과 기준.
- [ ] 3~4초 목표를 넘는 문장 길이 기준을 정하고 UI에 “생성 중” 상태를 자연스럽게 표시.
- [ ] `Qwen3TTSService.cancelCurrentInference()` barge-in 회귀 테스트.
- [x] reference voice clone이 특정 캐릭터에서 기계음으로 붕괴하면 즉시 기본 합성 fallback 또는 해당 캐릭터 비활성 정책 결정. → `TTSFallbackReason` + quality gate + 연속 3회 세션 비활성 구현 완료.
- [ ] voice clone을 다시 켤 조건 정의: 4~7초 reference, punctuation-only 입력 0건, RTF 목표 통과, 실청 통과.
- [ ] TTS 재개 게이트: 앱 컨테이너 캐시/모델 확보 정책, 25자 이하 cold/warm 측정, RTF/실대기시간, punctuation-only 0건, 기본 발화 실청 통과.
- [x] **[BUG] 캐릭터 음성 일관성**: 같은 캐릭터가 문장(청크)마다 다른 사람 목소리로 들리는 문제. → 1차 완화: `MLXRandom.seed()` FNV-1a 해시 고정. **2차 근본 해결: 세션 앵커(Session Voice Anchor)** — 캐릭터 첫 합성 출력을 앵커로 저장, 이후 모든 합성은 `synthesizeWithVoiceClone(anchor)` 호출로 동일 목소리 고정. `clearSessionAnchors()` / `clearSessionAnchor(for:)` API 추가. 2026-05-02 완료.

### App Store 샌드박스

- [x] Debug target `ENABLE_APP_SANDBOX=YES` 적용.
- [x] 앱 내부 생성 데이터는 `Application Support/MyTeam/`, 측정/캐시는 앱 컨테이너 `Application Support/MyTeam/TTSBench/` 및 `Library/Caches/qwen3-speech/`만 사용.
- [x] Qwen3 모델 자동 다운로드는 출시 경로에서 금지. 후보는 On-Demand Resources, 첫 실행 명시 다운로드, TTS 기능 출시 보류.
- [x] `ENABLE_APP_SANDBOX=YES` 기준 Release build 확인.
- [x] 앱 컨테이너 밖 직접 파일 접근 제거. → 하드코딩 `/Users/su/` 경로가 있던 `MLXModelManager.swift`, `BPETokenizer.swift` 포함 레거시 17파일 전부 삭제. 나머지 활성 코드에 절대경로 없음 확인.
- [x] `/open /Users/...` 개발 편의 명령은 출시 빌드에서 정책 제한 검토. → `#if DEBUG` 분기, Release는 http/https URL만 허용.
- [x] `Backup_claude_worktrees/` 프로젝트 외부 이동 또는 `.gitignore` 격리. → `.gitignore`에 추가.
- [x] 루트 일회성 스크립트와 레거시 도구를 `tools/legacy/`로 정리하거나 삭제. → 이동 완료.
- [x] `UserInterfaceState.xcuserstate` 등 개인 Xcode 상태 파일 추적 제외. → `.gitignore`에 `*.xcuserstate` 추가.

### 빌드/런타임 검증

- [x] Debug/Release 모두 clean build. → 2026-05-02 확인. 경고: mlx-swift C++17 외부 패키지만, 앱 코드 경고 0.
- [x] MyTeam 코드 경고와 외부 패키지/Xcode 안내 경고를 분리 기록.
- [x] `AppLog` 래퍼 기준으로 debug/release 로그 레벨을 분리하고 legacy TTS/WebSocket noise를 기본 비활성화.
- [ ] 첫 실행, 설정창 열기/닫기, 팀창 열기/닫기, 개인창 전환 테스트.
- [ ] 네트워크 없는 상태에서 앱이 크래시 없이 동작하는지 확인.
- [ ] API 키가 없을 때 사용자에게 이해 가능한 오류 표시.
- [x] 앱 종료 시 Metal/Xcode Stop 크래시 #1. → 원인: MLX C++ `unordered_map` (Metal 셰이더 캐시) 접근 중 Swift 객체 해제 → `__hash__()` EXC_BAD_ACCESS. **해결: `cancelCurrentInference()` + `Thread.sleep(1.0)` drain.** 2026-05-02.
- [x] 앱 종료 시 크래시 #2. → 원인: AVAudioEngine 렌더 콜백 in-flight 중 ObjC AVAudioNode 해제 → `(*pProc)(pObj, selector, args...)` EXC_BAD_ACCESS. **해결: `stopEngineForTermination()` (engine.stop() 명시) + DispatchSemaphore TTS actor 완료 대기 + 타임아웃 5초.** 2026-05-03.

---

## P1 — 대화 품질과 팀 구조

### 팀 대화

- [x] 팀 리더 지정 UX 개선: crown 배지 이미 있음 확인, AgentMenuPopup에 "팀장 설정/해제" 메뉴 추가. 2026-05-03.
- [ ] 멘션 우선순위 테스트: “레오가 답해줘”, “없는 캐릭터가 답해줘”.
- [x] 팀에 없는 캐릭터를 부를 때 대체 발화 톤 다듬기. → `unavailableNoticeText()` 11캐릭터 개별 문구 추가. 2026-05-03.
- [ ] 팀 대화에서 첫 발화만 TTS로 나오는 정책을 설정으로 노출할지 결정.
- [ ] 업무 질문은 길게, 잡담/확인은 짧게 답하는 규칙을 실제 대화 샘플로 튜닝.

### 개인창

- [x] 개인창 응답 정책을 캐릭터별 직업/전문성에 더 강하게 연결. → `buildPersonalResponsePolicy()`에 `specialty` + `role` 힌트 주입. 2026-05-03.
- [ ] 개인창에서 다른 캐릭터를 부르면 “팀창으로 넘길지” 제안하는 UX 검토.
- [x] `/compact` 요약 품질 개선: `AIService.quickSummary()` 비스트리밍 호출 추가, `/compact` LLM 요약본 + 최근 8개 메시지 유지 구현. 실패 시 static fallback. 2026-05-03.
- [ ] `/remember` 저장 전 사용자가 확인할 수 있는 UI 또는 취소 기능 검토.

### 장기 기억

- [x] `keyFacts`를 전역 1개 배열에서 사용자/방/캐릭터 scope로 분리. → `keyFactsScoped: [String:[String]]` (V2), `/remember @이름`, `/remember :global` 문법 추가. V1 레거시 병합 유지. 2026-05-03.
- [ ] `/memory` UI를 설정창 또는 별도 패널로 시각화.
- [ ] 기억 삭제/수정 UX 추가.
- [ ] 민감 정보는 기억 저장하지 않도록 필터링.

---

## P2 — 도구, 웹, 금융, 스케줄 업무

### 웹/검색

- [x] DuckDuckGo Instant Answer 한계를 보완할 공식 검색 API 결정. → Gemini 그라운딩 > OpenAI web_search > DuckDuckGo 3단계 폴백 구조로 결정. 2026-05-03.
- [x] Gemini Grounding 또는 OpenAI `web_search` 연동 PoC. → `fetchGeminiGrounding()` (google_search 도구) + `fetchOpenAIWebSearch()` (Responses API web_search_preview) 추가. API 키 있으면 자동 사용. 2026-05-03.
- [x] URL fetch HTML 본문 추출 품질 개선: title, meta description, article 본문 우선. → `extractMainContent()` 추가: article/main/p 태그 우선 추출, meta description 별도 표시. `cleanHTML()` nav/header/footer/aside 제거 강화. 2026-05-03.
- [ ] 출처 칩 디자인 polish: provider, 조회 시각, 열기 affordance.
- [ ] “오늘 주요뉴스” 같은 최신 뉴스 질문은 날짜와 출처를 명확히 표시.

### 금융

- [x] Yahoo Finance chart API → 한국 주식은 NAVER 금융 공개 API 우선 호출, 실패 시 Yahoo Finance v8 폴백. User-Agent 헤더 추가로 차단 방어. 2026-05-03.
- [x] 한국 종목 alias 확대: 카카오, 네이버, 현대차, SK하이닉스 등. → 한국 대형주 15종목 + 암/팔란티어/솔라나 등 추가. 2026-05-03.
- [ ] 금융 답변 고지 문구가 모든 경로에서 빠지지 않는지 테스트.
- [ ] 매수/매도 단정 표현 방지 프롬프트 강화.
- [ ] 환율/지수/원자재 지원 범위 결정.

### 스케줄 업무

- [x] 팀 채팅창의 상시 노출 스케줄 스트립을 입력창 왼쪽 아이콘 호출형 패널로 변경.
- [x] 스케줄 패널에서 시간/담당 캐릭터/업무 내용 직접 등록.
- [x] 담당 캐릭터가 현재 팀에 없으면 대체 화자가 대신 수행.
- [x] `/schedule` 파서 확장: `tomorrow 09:00`, `매일 9시`, `every day 09:00`. → `내일/tomorrow`, `매일/daily/every day`, `매주 요일`, `N시 M분`, `매주 {요일}` 패턴 추가. 2026-05-03.
- [x] 스케줄 업무 편집 UI 추가. → `/edit-task {ID} {HH:MM|--disable|--enable|--approval on|off}` 명령 추가. 2026-05-03.
- [x] 스케줄 업무 실행 전 알림/승인 옵션 추가. → `requiresApproval: Bool` 필드, `/approve {id}` / `/skip {id}` 명령, 2분 타임아웃 자동 실행. 2026-05-03.
- [ ] 앱이 꺼져 있을 때의 정책 결정: 미실행 유지, 다음 실행 시 catch-up, 또는 알림만.
- [ ] 스케줄 결과가 어느 방에 남을지 명확히 표시.
- [x] destructive action 금지 정책을 코드 레벨로 분리. → `AutomationPolicy.swift` 등록+실행 시점 양쪽 차단.

---

## P3 — 설정, 모델 라우팅, API 품질

### API 설정

- [ ] 실제 API 검증 실패 메시지 UI 다듬기.
- [x] provider별 “사용 가능한 모델 목록”을 설정창에서 보여주는 UI 추가. → 고급 모델 설정 DisclosureGroup에 `LLMConfigCatalog.discoveredModels` 목록 표시, 탭 선택, 갱신 버튼 추가. 2026-05-03.
- [ ] 기본 provider와 데스크별 provider가 실제 activeAgents에 즉시 반영되는지 테스트.
- [ ] OpenAI/OpenRouter 모델 ID 직접 입력 대신 추천/최근 사용 목록 제공.
- [x] API 키 삭제 버튼 추가. → SettingsView 검증 버튼 옆 trash icon, KeychainManager.delete 연동.

### 모델 라우팅

- [x] `LLMConfigCatalog.swift` 신규 생성. `LLMProviderConfig` (supportsToolUse, supportsWebSearch, discoveredModels, lastDiscoveryDate), `LLMCapability` enum, `bestProvider(for:)`, `routeOrDefault(_:fallback:)` 구현. 2026-05-03.
- [x] 모델 discovery 결과 캐시 만료 정책 추가. → TTL 1시간, UserDefaults 영속화, 절전 해제 시 `refreshAllIfNeeded()` 호출. 2026-05-03.
- [x] tool use가 필요한 질문은 tool-capable provider를 우선 선택하는 라우팅. → AgentChatView에서 `ToolPolicy.needsTool` 시 `LLMConfigCatalog.routeOrDefault()` 호출, `AgentConfig.withProvider()` 오버라이드. 2026-05-03.
- [ ] 캐릭터별 provider/모델 판매 정책과 충돌하지 않게 구조화.

---

## P4 — TTS 자산 정책과 레거시 정리

### TTS 자산

- [x] `Resources/ReferenceAudio/POLICY.md` 작성. → 기준: 4~7초, 24kHz mono, -20 LUFS, fade out 0.1s.
- [ ] reference 기준: 4~7초, 24kHz mono, 16-bit, -20 LUFS, 앞뒤 무음 최소화, 끝단 fade.
- [x] `voices-audit.md` 작성. → 11개 모두 존재. 길이 13~21s(기준 초과), clipping 적용 중. 실청/loudness 검수 미완.
- [ ] reference 파일명을 캐릭터 이름 직접 매핑에서 catalog 기반으로 분리.
- [x] Qwen3 voice clone 실패 시 캐릭터별 fallback 정책 도입. → `TTSFallbackReason` + quality gate + `CharacterTTSPolicy` in ModelCatalog.

### 레거시 코드

- [x] 사용처 0 확인 후 삭제: `MLXInferenceService`, `MLXModelManager`, `T3MLXModel`, `T3Model`, `LlamaModel`, `T3CondEnc`, `HiFTGenerator`, `VoiceEncoder`, `BPETokenizer`, `KanaDecomposer`, `ChatterboxPipeline`, `ChatterboxConfig`, `OnDeviceTTSManager`, `TTSServiceManager`, `WebSocketClient`, `WebSocketStreamManager`, `LiveAudioManager` — **17파일 삭제 완료 2026-05-02**
- [x] 삭제 전 각 파일의 현행 참조 여부 확인. → 활성 파일(SpeechManager, AIService 등)에서 참조 없음 확인.
- [x] project.pbxproj에서 소스/리소스 참조 제거. → 64줄 제거 (16파일 × 4위치).
- [x] 삭제 후 clean build. → BUILD SUCCEEDED.

---

## P5 — 데이터, 저장소, 품질

### 데이터 저장

- [ ] UserDefaults 기반 `rooms`를 SwiftData 또는 파일 기반 store로 이전할지 결정.
- [ ] 대화 로그 백업/복원 설계.
- [ ] 방별 검색 기능.
- [ ] source/reference/automation task를 대화와 함께 안정적으로 저장.

### QA

- [ ] 첫 실행 시나리오.
- [ ] API 키 없음/잘못됨/만료됨.
- [ ] 네트워크 offline/timeout.
- [ ] TTS 모델 최초 다운로드/로드 실패.
- [ ] 창 위치가 화면 밖으로 나간 상태 복구.
- [ ] 다크/라이트 모드.
- [ ] 긴 메시지, 긴 URL, 긴 출처 제목 layout.

### 성능

- [ ] 앱 시작 시간 측정.
- [ ] 첫 TTS cold start 측정.
- [ ] LLM streaming 시작까지 걸리는 시간 측정.
- [ ] 메모리 고점 측정.
- [ ] 모델 unload/warm cache 정책 결정.

---

## 완료된 큰 결정

- [x] 런타임 TTS를 `Qwen3TTSService`로 고정.
- [x] 팀 리더 지정과 멘션 우선 응답 추가.
- [x] 개인창/팀창에 tool policy와 source chip 연결.
- [x] 금융 답변 고지 정책 추가.
- [x] `/clear`, `/compact`, `/remember`, `/forget` 등 기본 명령 추가.
- [x] `/open`, `/fetch`, `/search`, `/schedule`, `/tasks`, `/cancel` 추가.
- [x] 팀 채팅창 하단 스케줄 업무 UI 추가.
- [x] 실제 API 키 검증 도입.
- [x] 기본 provider/데스크별 provider 라우팅 연결.
- [x] 창 크기 저장/복원 및 개인창 강제 리사이즈 완화.

---

## 전체 로드맵 요약 (2026-05-02 기준)

> P0 기반 안정화 → P1 대화 품질 → P2 도구 → P3 모델 라우팅 → P4 TTS 자산 → P5 데이터/QA

### 즉시 실행 가능 (P0 미완)

1. **빌드/런타임 수동 확인**: 첫 실행, 설정창 열기/닫기, 팀창/개인창 전환 시나리오 직접 테스트
2. **네트워크 offline 테스트**: Wi-Fi 끊은 상태에서 앱 실행 → 크래시 없는지 확인
3. **API 키 없음 시나리오**: 키 미설정 상태에서 메시지 전송 → "API Key가 없습니다" 에러 채팅창 표시 확인
4. **앱 종료 시 크래시**: Xcode Stop 버튼 vs 앱 직접 종료 시 Metal 크래시 재확인
5. **캐릭터별 TTS 실청 테스트**: voice clone OFF 상태, 11캐릭터 각 1문장씩 합성음 확인

### 단기 (P1 — 대화 품질)

6. **팀 리더 UX**: 현재 리더 표시, 교체 정책 명확화
7. **장기 기억 scope 분리**: keyFacts를 사용자/방/캐릭터 단위로 분리, 삭제 UI 추가
8. **업무/잡담 답변 길이 조율**: 실제 샘플로 프롬프트 튜닝
9. **`/compact` LLM 요약**: 단순 문자열 잘라내기 → LLM 기반 요약

### 중기 (P2 — 도구)

10. **검색 API 결정**: DuckDuckGo 대안 확정 (Gemini Grounding, OpenAI web_search, Brave Search)
11. **스케줄 편집 UI**: 등록 후 시간/담당자/내용 수정 기능
12. **스케줄 실행 전 승인 옵션**: 배경 자동 실행 vs 알림 후 승인 선택지
13. **Yahoo Finance → 공식 API**: 출시 전 제3자 scraping 제거

### 중기 (P3 — 모델 라우팅)

14. **LLMProviderConfig catalog**: provider 목록을 JSON/plist 기반으로 코드에서 분리
15. **모델 discovery 캐시 만료 정책**: 1시간 이상 캐시 무효화
16. **tool-capable provider 우선 라우팅**: web_search/tool_use 필요 시 자동 선택

### 중기 (P4 — TTS 자산)

17. **Reference audio 실청 검수**: voices-audit.md 갱신, 기준(4~7s, -20 LUFS) 미달 파일 재녹음
18. **TTS 재개 게이트 통과 후 voice clone 재활성**: RTF < 1.0, punctuation-only 0건, 실청 통과
19. **합성 시간 벤치마크**: 25자/50자/100자 × cold/warm RTF, 메모리 고점
20. **"생성 중" UI 자연화**: 3~4초 초과 발화는 스트리밍 진행 표시기 노출

### 장기 (P5 — 데이터/QA)

21. **SwiftData 이전 결정**: UserDefaults 기반 rooms/logs → SwiftData 또는 파일 store
22. **대화 로그 백업/복원 + 방별 검색**: export/import JSON, 키워드 검색
23. **QA 시나리오 전체 통과**: 첫 실행, API 키 없음, 네트워크 offline, TTS 다운로드 실패, 창 위치 복구, 다크/라이트 모드

---

---

## Round 196A-230Z + Round 231A Completion (2026-05-17)

### Completed (Round 196A-230Z)
- [x] WorkroomActionTypes.swift created (canonical enum source)
- [x] Enum deduplication (removed from TeamStatusView, WorkroomHomeModel)
- [x] pbxproj registration (file ref + build file + sources phase)
- [x] TeamStatusView handlers refactored to use dispatchPrompt
- [x] Room scope enforcement: 10 scoped calls, 0 global calls
- [x] Character system preservation verified (4 core files, 11 referencing files)
- [x] CharacterReactionBridgeBacklog.md documented
- [x] SpriteSheetProductionSpec.md documented (실제 AnimationState 기준 보정 완료)
- [x] CharacterReactionEnginePlan.md documented
- [x] RuntimeDiagnosticsService enhanced (14 Workroom fields + 11 CharacterReaction fields)
- [x] ToolContractValidator enhanced (9 Round 196 + 3 Round 231A validators)
- [x] RouterBurnInSuite: 존재 확인 (ToolContractValidator/RouterBurnInSuite 미존재 표현 정정)
- [x] CLAUDE.md project config created
- [x] Command scripts created (.claude/commands/)
- [x] Preflight script updated (scripts/preflight_workroom_round196.sh)
- [x] Workroom review report created

### Completed (Round 231A)
- [x] WorkroomCharacterEvent.swift created — 5개 이벤트 (workroomOpened/workflowStarted/documentCreated/artifactReuse/multiRoomSwitched)
- [x] CharacterReactionEngine.swift created — event 처리, 30s cooldown, delegate 패턴
- [x] CharacterReactionEventSink.swift created — AgentWindowManager.agentEmotions 직접 연결
- [x] 3개 파일 pbxproj 등록 (PBXFileReference + PBXBuildFile + PBXSourcesBuildPhase + PBXGroup)
- [x] WorkroomHomeView.onAppear → workroomOpened event
- [x] handleWorkroomAction(.createDocument) → documentGenerationStarted event
- [x] handleWorkroomAction(.handoffFile) → artifactReuseRequested event
- [x] handleWorkroomNextAction → documentGenerationStarted event
- [x] CharacterReactionEventSink → agentEmotions[agentID] = state (agentID no-op 안전 처리)
- [x] AnimationState 기존 enum 재사용 (CharacterMood/CharacterActivity 미도입)
- [x] CharacterDialogues/SpriteAgentView/CharacterSpriteScene/AgentSeatView 미수정
- [x] RuntimeDiagnosticsService snapshot 초기화 fix (14 + 11 필드)
- [x] Debug BUILD SUCCEEDED — 0 Swift warnings
- [x] Release BUILD SUCCEEDED — 0 Swift warnings

### Completed (Round 232 — Character Reaction Surface + Sprite Handoff)
- [x] workflowCompleted → notifyDocumentCreated bridge (NotificationCenter, artifact 있을 때만 .joy)
- [x] TeamStatusView room tap → notifyRoomSwitched (prev ≠ new roomID 조건)
- [x] CharacterReactionEventSink: setupWorkflowCompletedObserver() 추가 (WorkflowEngine 구조 변경 없음)
- [x] RuntimeDiagnosticsService: 8개 Round 232 필드 추가 (eventSinkConnected/agentEmotionsConnected/delegateDeferred/workflowCompletedBridge/roomSwitchBridge/handoff/roster/delegateDecision)
- [x] ToolContractValidator: 3개 Round 232 validators 추가 (SpriteSheetHandoff/DelegatePolicy/RosterPolicy)
- [x] RouterBurnInSuite: 7개 Round 232 character reaction policy cases 추가 (backlog 2개 포함)
- [x] SpriteSheetProductionSpec.md 재보정 (전체 AnimationState 목록, 3자리 index, Round 232 status)
- [x] ChikoSpriteSheetHandoff.md 신규 생성 (v1 필수 12개 clip 상세 명세)
- [x] CharacterSpriteRosterRoadmap.md 신규 생성 (치코/세나/카이/유나 로드맵 + DLC 노출 정책)
- [x] CharacterReactionDelegateDecision.md 신규 생성 (agentEmotions 경로 우선, delegate deferred 결정)
- [x] scripts/preflight_character_round231.sh 신규 생성 (character 전용 preflight)
- [x] Debug BUILD SUCCEEDED — 0 Swift warnings
- [x] Release BUILD SUCCEEDED — 0 Swift warnings

### Completed (Round 234 — Sprite Asset Gate + Beginner Flow QA Prep)
- [x] Sprites/ intake 폴더 scaffold — README + 치코/세나/카이/유나 폴더 및 README
- [x] CharacterSpriteManifest.swift — static struct, requiredStates/optionalStates, 4개 캐릭터, DLC gate
- [x] CharacterSpriteAssetPolicy.swift — ValidationResult, validate(), isReadyForRelease(), summary()
- [x] pbxproj 등록 — BC234A001/002 (CharacterSpriteManifest + CharacterSpriteAssetPolicy)
- [x] scripts/validate_sprites.sh — 4단계 검증 (intake 구조, 런타임 폴더, 파일명 컨벤션, state frame count)
- [x] macOS NFD Python 대응 — 모든 한국어 파일명 검사를 Python os.listdir()+re로 처리
- [x] RuntimeDiagnosticsService.swift — Round 234 sprite + beginner 필드 8개 추가
- [x] ToolContractValidator.swift — validateSpriteAssetPolicy/BeginnerExampleArtifactPolicy/FriendlyRecoveryActionPolicy 추가
- [x] RouterBurnInSuite.swift — 6개 sprite/recovery 케이스 추가
- [x] scripts/preflight_sprite_round234.sh — 11단계 preflight (git, 폴더, validator, 파일, 금지 문구, Debug/Release 빌드)
- [x] docs/qa/ManualRuntimeQA_Round234.md — 4개 시나리오 수동 QA 체크리스트
- [x] Debug BUILD SUCCEEDED (0 Swift warnings)
- [x] Release BUILD SUCCEEDED (0 Swift warnings)

### Completed (Round 233B — Beginner Mode UX Complete)
- [x] BeginnerExampleDocumentService.swift 신규 생성 — API 키 없이 샘플 회의록 생성 (로컬 전용)
- [x] pbxproj 등록 — BC233B001FR/BF 추가 (BeginnerExampleDocumentService.swift)
- [x] WorkroomHomeView.swift — handleBeginnerCardTap(.tryExample) BeginnerExampleDocumentService 연결
- [x] WorkroomHomeView.swift — onPromptDispatched 콜백으로 업무 카드 → AgentChatView dispatch 연결
- [x] SettingsView.swift — 간편 모드 Toggle 추가 (사용자 설정 탭)
- [x] ArtifactCardView.swift — friendlyRecovery: RecoveryInfo 친절한 복구 UI 추가 (4개 오류 케이스)
- [x] RuntimeDiagnosticsService.swift — Round 233B beginner 필드 9개 추가
- [x] ToolContractValidator.swift — validateBeginnerModePolicy/ExampleFlowPolicy/FriendlyRecoveryPolicy 추가
- [x] RouterBurnInSuite.swift — 5개 beginner 케이스 추가
- [x] scripts/preflight_beginner_round233.sh 생성
- [x] docs/beginner/BeginnerModeProductSpec.md 생성
- [x] Debug BUILD SUCCEEDED (0 Swift warnings)

### Completed (Round 233A — Beginner Mode)
- [x] BeginnerMode.swift 신규 생성 — BeginnerTaskCard(6), BeginnerGuidanceMessage, UserFacingTerm 구현
- [x] BeginnerTaskCardView.swift 신규 생성 — 초보자 업무 카드 UI (사용자/치코 역할 분리)
- [x] BeginnerGuidanceBar — 치코 안내 문구 뷰 (BeginnerTaskCardView.swift 내)
- [x] WorkroomHomeView.swift 재작성 — 초보자/표준 모드 분기, 치코 안내, 예시 시작하기
- [x] AgentWindowManager.isBeginnerMode @AppStorage 추가
- [x] TeamStatusView.chatroomLogView에 WorkroomHomeView 마운트 (초보자모드 or 빈 대화)
- [x] pbxproj 등록 — WorkroomHomeView/HomeModel 누락 BF 추가 + BeginnerMode/TaskCardView 신규 등록
- [x] WorkroomHomeModel Equatable 제거 (IndexedArtifact 비Equatable 호환)
- [x] Debug BUILD SUCCEEDED + Release BUILD SUCCEEDED (0 Swift warnings)

### Pending (Manual QA)
- [ ] Runtime QA: workroom 열기, 문서 생성, artifact 재사용, room 전환 시 치코 반응 확인
- [ ] workflowCompleted → .joy 전환 실기 확인 (artifact 생성 후)
- [ ] Beginner Mode 실기 확인 — 업무 카드 탭 → 프롬프트 dispatch → 결과
- [ ] "예시로 먼저 해보기" 실기 확인 — 샘플 회의록 생성 (API 키 없이)
- [ ] Character sprite asset production (디자인팀 — idle/typing/greeting/joy/backwork 우선)
- [ ] sleeping state 연결 (long idle timer hook — backlog)
- [ ] artifactVerificationFailed → .sad/.confused 연결 (ResultVerifier hook — backlog)
- [ ] App Store submission review

### Status
- **Build**: ✅ Debug + Release BUILD SUCCEEDED, 0 warnings (Round 234)
- **Code Validation**: ✅ COMPLETE (ToolContractValidator 6개 validator, RouterBurnInSuite 11개 case, RuntimeDiagnostics 17개 필드 — Round 233B+234 합산)
- **Beginner Mode**: ✅ 간편/기본 분기 + 예시 플로우 + 친절한 복구 + Settings 토글 완성
- **Character Reaction**: ✅ 6개 이벤트 연결
- **Sprite Asset Gate**: ✅ Round 234 — CharacterSpriteManifest + AssetPolicy + validate_sprites.sh (macOS NFD 대응)
- **Sprite Production**: ⏳ 디자인팀 핸드오프 대기 (치코 674 PNG 확인, 세나/카이/유나 DLC 대기)
- **Sprite Handoff**: ✅ ChikoSpriteSheetHandoff.md + CharacterSpriteRosterRoadmap.md 완료
- **Delegate Strategy**: ✅ agentEmotions 경로 우선, delegate deferred
- **Manual QA**: ⏳ PENDING — docs/qa/ManualRuntimeQA_Round234.md 4개 시나리오 미완
- **Submission**: ❌ NOT READY (character assets + manual QA 필요)

---

## Archive 메모

ONNX, Chatterbox Multilingual Python 서버, VITS2/Piper/Kokoro 비교, TTSEngine 프로토콜 초안은 모두 과거 실험 기록이다.
새 작업자는 이 파일의 P0~P5만 기준으로 삼는다.
