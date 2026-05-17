# System Bottleneck Audit

## Round 116C-135Z Result (Policy Centralization)

### Fixed / Reduced
- Policy fragmentation (4 centralized policy files created)
- Validator coupling (refactored to use policy references instead of inline checks)
- Release surface visibility ambiguity (ProductSurfacePolicy constant matrix)
- Starter action blocking lack of clarity (StarterActionPolicy sets)
- First result action state mapping (FirstResultActionPolicy enum)
- Connector capability visibility scattered (ConnectorSurfacePolicy centralized)
- Character release visibility scatter (ProductSurfacePolicy filtering)
- Build automation missing (3 Mac scripts: audit, register, merge)
- Compile-risk documentation gap (CompileRiskRegister.md assessment)

### Still Remaining
- Mac actual xcodebuild execution (requires Mac local)
- Runtime character asset production (deferred to Round 140A)
- Manual runtime QA scenarios (deferred to Round 140A)
- StoreKit sandbox/production purchase QA (deferred)
- Google Calendar live OAuth QA (deferred)
- Actual app submission (deferred post-QA)

---

## Round 40R + 41A-41F Result (In Progress)

### Fixed / Reduced
- Release readiness overclaim (differentiated build-ready vs submission-ready)
- First-launch / no-key / offline state ambiguity (RuntimeCapabilityMode enum)
- First-launch state tracking gap (FirstLaunchState struct)
- Starter action discoverability (StarterActionProvider enum + 4 actions)
- Documentation truthfulness (ReleaseWarningAudit + AppStorePackagingChecklist)

### Still Remaining
- Starter actions actual UI integration
- no-key / offline / connector-limited message display
- First result activation flow implementation
- SettingsView developer setting suppression
- RuntimeDiagnostics field enhancement
- RouterBurnInSuite case expansion
- Manual runtime QA (Round 42A)

---

## Round 40A-40D Result

### Fixed / Reduced
- App Store packaging uncertainty
- Release diagnostics overexposure (minimized)
- first launch / no-key / offline state ambiguity (clarified)
- sandbox / file access policy ambiguity (finalized)
- external write policy ambiguity (finalized)
- debug UI visibility in Release (hidden)
- model override visibility in Release (hidden)
- startup crash-prone paths (safety guards added)
- MainActor isolation warnings (6 warnings fixed)

### Still Remaining
- actual App Store archive submission (deferred to Round 41+)
- StoreKit production purchase QA (deferred)
- Google Calendar live OAuth (deferred until Desktop Client ID available)
- first-launch onboarding polish (Round 41A)
- PDF/DOCX/XLSX/PPTX parser implementation (announced as future)

---

## Round 38A-38D Result

### Fixed / Reduced
- Artifact absolute path persistence risk
- RecentArtifactIndex stale entry risk
- action log unbounded growth
- artifact missing/hash mismatch ambiguity

### Still Remaining
- encrypted memory store
- release runtime QA
- full connector QA
- actual cleanup approval UI

## Round 37A-37D Result

### Fixed / Reduced
- UserDefaults memory leakage risk
- automation task prompt persistence risk
- Release/debug ambiguity
- dynamic model drift in release
- diagnostics overexposure

### Still Remaining
- encrypted memory store
- ArtifactStore relative path migration
- release runtime QA
- full connector QA

## Executive Summary
- Overall risk: medium-high
- 가장 큰 병목: `WorkflowOrchestrator`가 아직 route 결정, workflow 실행, state 갱신, QA trace를 한 곳에서 계속 끌고 간다
- 다음 3라운드 우선순위: 1) orchestrator 책임 분리, 2) connector policy 단일화, 3) room/state store 경계 정리

## 1. Route / Workflow
### Findings
- `RouteResolver`는 deterministic route decision을 내리지만, 실제 실행 제어권은 여전히 `WorkflowOrchestrator`에 남아 있다.
- Daily Briefing, Universal Document, File Intake, App Launch, Privacy Terms가 모두 같은 orchestrator에서 분기된다.
- route trace는 늘고 있지만, 실행 경로와 trace가 다시 어긋날 여지는 남아 있다.

### Risks
- `WorkflowOrchestrator`가 다시 monolith로 커질 수 있다.
- daily briefing / file intake / document workflow가 서로를 가로채는 edge case가 증가할 수 있다.

### Recommended Fixes
- `WorkflowRunner`를 실제 실행 경계로 더 끌어올린다.
- route decision과 execution entrypoint를 분리한다.
- daily briefing과 file intake의 negative guard를 더 명시적으로 유지한다.

## 2. State / Context
### Findings
- room state는 `AgentWindowManager`에 많이 모여 있다.
- `activeTasksByRoom`, `roomGoalContexts`, `lastFileIntakeResultsByRoom`, `recentArtifacts`가 같은 객체에 함께 있다.
- in-memory 상태와 영속 상태의 경계가 아직 뚜렷하지 않다.

### Risks
- `AgentWindowManager`가 god object로 커질 수 있다.
- 최근 파일 / 최근 문서 / 최근 요청이 briefing과 document workflow에서 중복 해석될 수 있다.

### Recommended Fixes
- room runtime store를 별도 소유권으로 나눈다.
- recent artifact / recent file / goal context의 source of truth를 명확히 적는다.
- restart persistence 필요 항목만 따로 분리한다.

## 3. PlanRunner / AgentPipeline
### Findings
- `PlanRunner`는 아직 Universal Document 전용이다.
- `AgentPipelineRunner`는 skeleton 수준이고, 기본 route에는 연결하지 않는 것이 맞다.
- 둘 다 step/context/verification 개념은 공유하지만 실제 실행 계층은 분리되어 있다.

### Risks
- 나중에 두 runner가 서로 다른 방식으로 자라면 중복 실행 엔진이 된다.
- `@MainActor` 경계가 길어지면 장기 실행에서 병목이 될 수 있다.

### Recommended Fixes
- 공통 plan/pipeline contract를 늦지 않게 정의한다.
- main actor는 UI/state 업데이트에만 제한한다.
- verification/recovery 정책은 한쪽으로 수렴시킨다.

## 4. Tool / Connector
### Findings
- `ConnectorGuard`는 read-capability helper를 가졌지만, `AssistantConnectorPolicy`와 정책 어휘가 완전히 하나는 아니다.
- `calendarRead` token 유무와 `mailMetadataRead` unavailable은 안전하지만, 실제 live QA가 아직 부족하다.
- 외부 write는 계속 blocked 상태다.

### Risks
- 정책이 두세 군데로 갈라지면 문구와 실제 동작이 조금씩 어긋날 수 있다.
- token이 있다는 이유만으로 읽기 가능하다고 과신하면 안 된다.

### Recommended Fixes
- capability 정책의 단일 출처를 정한다.
- read/unavailable/requiresApproval/blocked 문구를 중앙화한다.

## 5. File Intake
### Findings
- txt/md/markdown/csv는 동작하고 planned/blocked 확장자는 정책으로 분리되어 있다.
- 파일 기반 document 연결은 되었지만, csv를 표로 파싱하지는 않는다.
- fileImporter sandbox UI와 Finder/path copy는 아직 backlog다.

### Risks
- 사용자는 `csv`를 표로 기대할 수 있는데 현재는 raw text 기반이다.
- planned 확장자가 계속 늘어나면 UX가 다시 길어질 수 있다.

### Recommended Fixes
- CSV 표 파싱은 다음 라운드의 명시적 scope로 둔다.
- planned/blocked 안내는 짧게 유지한다.
- sandbox / fileImporter UI는 deferred QA로 유지한다.

## 6. UI / UX
### Findings
- Daily Briefing 카드와 연결 상태 UI는 짧아졌지만 설정/연결 영역은 여전히 정보를 많이 담고 있다.
- status 메시지, 준비 중 메시지, 차단 메시지가 동시에 많아지면 앱이 미완성처럼 보일 수 있다.

### Risks
- Settings와 Connector 화면이 다시 길어질 수 있다.
- 같은 상태를 여러 화면에서 다른 톤으로 말하면 혼란이 생긴다.

### Recommended Fixes
- 상태 문구는 concise copy 가이드로 고정한다.
- 결과 카드/설정 카드의 줄 수 상한을 둔다.

## 7. QA / Diagnostics
### Findings
- `Deferred Runtime QA Backlog`는 유지되고 있다.
- diagnostics는 민감정보를 피하면서도 충분한 요약을 보여준다.
- 실제 UI runtime recheck는 아직 일부 unverified다.

### Risks
- code-reviewed pass와 runtime pass가 섞이면 QA 신뢰도가 떨어진다.
- deferred 항목이 쌓이면 실제 미확인 상태를 놓칠 수 있다.

### Recommended Fixes
- runtime pass / runtime failed / still unverified를 엄격히 분리한다.
- QA helper는 DEBUG 전용으로만 유지한다.

## P0 / P1 / P2 Backlog
### P0
- `WorkflowOrchestrator` route / execution 분리
- connector policy 단일화

### P1
- room runtime store 경계 정리
- PlanRunner / AgentPipeline 공통 contract 정리
- file intake CSV 기대치 정리

### P2
- Settings / Connector copy 정리

## Round 35B-35E Note

### Accepted
- Tool risk registry 기준 고정
- action log redaction
- recent artifact room/source binding
- workspace overwrite guard
- scheduler document bridge

### Deferred
- full ToolExecutionLayer real adoption
- debug/runtime diagnostic refactor 전면화
- local scheduler command pack의 최종 UX polish
- diagnostics 수치형 요약 더 압축
- deferred UI QA 재검증

## Round 31A Fix Plan

### Scope
- WorkflowRunner daily briefing entrypoint
- ConnectorCapabilityPolicy centralization

### Out of Scope
- Full orchestrator rewrite
- ToolExecutionLayer full adoption
- Gmail API
- Calendar write

## Round 31B Fix Plan

### Scope
- RoomRuntimeStore 추가
- roomGoalContext / lastFileIntakeResult / activeTask ownership 분리
- AgentWindowManager facade 유지

### Out of Scope
- Full AgentWindowManager rewrite
- SwiftData persistence
- route / execution full migration

## Round 31C Fix Plan / Result

### Scope
- WorkflowRunner Universal Document boundary
- RoomRuntimeStore actor boundary
- Diagnostics flag cleanup

### Findings
- Universal Document plan wrapper is now routed through WorkflowRunner, so orchestrator execution branching is shorter.
- RoomRuntimeStore now serves as the room-state facade boundary while remaining main-actor owned for UI-facing access.
- diagnostics flags were renamed / grouped to better separate capability flags from actual state.

### Risks
- WorkflowOrchestrator still owns the broader route dispatch surface.
- App Launch / PrivacyTerms / File Intake / AgentPipeline boundaries remain intentionally out of scope.

### Recommended Fixes
- Keep the Universal Document wrapper logic in WorkflowRunner and avoid re-inlining fallback logic into orchestrator.
- Treat the room runtime store as the single source of truth for room-level runtime state.
- Defer remaining route/execution contract alignment to Round 31D.

## Round 31D Result

### Fixed / Reduced
- PlanRunner / AgentPipeline contract drift reduced
- legacy fallback outcome ambiguity reduced
- artifactCount misreporting risk reduced

### Remaining
- App Launch / PrivacyTerms execution boundary
- ToolExecutionLayer full adoption
- Deferred runtime QA

## Round 32A Note

Local Task Briefing은 OAuth 없이 앱 내부 상태를 먼저 브리핑 품질로 연결하는 단계다.
최근 파일, 최근 artifact, 스케줄, pending approval, pending delegation, 최근 실패 workflow를 한 묶음으로 보여주는 쪽에 집중한다.

## Round 32B Note

Local briefing은 실제 지원되는 다음 액션만 제안해야 한다.
방금 만든 문서 표로 바꿔줘는 recent artifact content resolver가 있을 때만 노출한다.

## Round 33A Note

Recent Artifact Reuse는 최근 artifact의 markdown/txt 내용을 다시 문서화하는 연결점이다.
외부 API 없이 Daily Briefing의 다음 액션을 실제 실행 가능한 문서 재활용 경로로 이어 준다.

## Round 33B Note

Daily Briefing은 상태 표시에서 실행 가능한 액션 허브로 확장된다.
이번 라운드는 prompt action과 로컬 system action을 분리해, 실행 가능한 다음 단계만 노출하는 쪽에 집중한다.

## Round 33B-33D Note

Daily Briefing이 상태 표시를 넘어 실행 가능한 액션 허브로 정리된다.
최근 파일, recent artifact reuse, 스케줄 브리지, 승인 대기, 위임 대기를 같은 액션 경계로 묶어 사용자 흐름을 이어 준다.

## Round 34A Result

### Fixed / Reduced
- Tool runtime trust boundary is now registry-risk driven
- Recent artifact wrong-room/stale action risk is reduced through binding revalidation
- AgentWorkOrder execution contract ID ambiguity is removed
- approval config/runtime state ambiguity is reduced

### Still Remaining
- ArtifactStore unbounded index
- Verification fail-closed by document type
- Release/Debug PlanRunner path distinction
- Deferred Runtime QA

## Round 36A-36D Result

### Fixed / Reduced
- ToolExecutionLayer skeleton gap
- Planner-visible stub tool risk
- Capability future/requiresApproval route ambiguity
- ToolResultStatus aggregation drift
- ActionLog redaction regression risk

### Still Remaining
- Memory Security Pack
- Release AI model pinning
- ArtifactStore relative path migration
- Full deferred runtime QA

## Round 35B-35E Note

Safety contract closure와 file workflow completion을 함께 진행한다.
Tool risk registry enforcement, artifact binding 재검증, deterministic execution contract, recent artifact persistence lifecycle, local scheduler document bridge를 같은 안정성 경계로 묶는다.

## Round 76A-95Z Update (2026-05-15)

### Fixed / Resolved

- **Swift 6 actor isolation warnings** — `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` 환경에서 `nonisolated` 명시로 앱 코드 warning 0 달성
- **Privacy copy overclaiming** — "완전 로컬" 등 금지 표현 Swift 소스 전체 제거. preflight 자동 검사 추가
- **Character Release gate missing** — `CharacterAssetManifest` + `CharacterAssetAvailability` + `ReleaseVisibleCharacterPolicy` 3-layer 시스템으로 단일 정책 게이트 구축
- **CharacterAssetRegistry placeholder 휴리스틱** — `_placeholder` substring 검사로 production/placeholder 판별 자동화
- **ToolContractValidator character asset gap** — `validateCharacterAssetPipeline()` 추가로 Release 노출 gate 정적 검증

### Still Remaining / Known Gaps

| 항목 | 위험도 | 계획 |
|---|---|---|
| 치코 working/success/screenshot 스프라이트 미제작 | 중 — App Store 스크린샷 블로킹 | Round 96A Visual Asset |
| `CharacterAssetRegistry` 하드코딩 | 낮음 — 캐릭터 추가 시 코드 수정 필요 | Round 100+ plist/JSON 전환 |
| Premium DLC 구매 경로 미완성 | 높음 — 수익화 블로킹 | Round 96A 이후 |
| App Store 스크린샷 0장 | 중 — 심사 제출 블로킹 | Round 96A 완료 후 |
| TestFlight 베타 미배포 | 중 — 외부 검증 없음 | v1.0 제출 전 |

### Round 76 Preflight Result

```
PASS=16, WARN=2, FAIL=0
(WARN: InternalReviewReport 생성 전 → 생성 후 해소, git uncommitted)
```


### Round 235 — UI Overlay/Contrast Issue Resolution (2026-05-17)

- Low-opacity glass overlays burying chat text: resolved — MT Readability Tokens introduced, glass backgrounds replaced with NSColor.controlBackgroundColor-based tokens
- Input placeholder contrast below WCAG AA: resolved — inputBgColor and subTextColor raised to mtInputBackground / mtTextSecondary
- BeginnerTaskCard / WorkroomHomeView card surfaces near-invisible: resolved — mtCardBackground applied
- Agent nameplate click not switching chat room: resolved — openPersonalChat(for:) wired to both TeamTableView and TeamStatusView taps
- Status: Build-ready, Manual QA pending
