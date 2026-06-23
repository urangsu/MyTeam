# MyTeam Connection Audit

Date: 2026-06-23
Branch: `codex/main-product-stabilization-p0`

## MyTeam/MyTeamApp.swift

- 현재 책임: 앱 생명주기, 종료 인사, termination reply, floating panel/window bootstrap.
- 너무 많이 가진 책임: 종료 음성 정책과 앱 종료 응답 타이밍이 같은 생명주기 경로에 있음.
- 호출되는 위치: macOS app delegate/runtime.
- 호출하는 대상: `SpeechManager`, `AudioPlaybackService`, floating window setup.
- 분리 필요 여부: 예.
- 우선순위: P1. 종료 hang 재발 시 P0.

## MyTeam/WorkflowOrchestrator.swift

- 현재 책임: 팀 워크룸 입력의 최상위 dispatch, legacy workflow, budget, route trace, event publish.
- 너무 많이 가진 책임: 이전에는 자연어 라우팅, pending clarification, agentic planning, legacy fast path까지 직접 보유.
- 호출되는 위치: `TeamStatusView.sendTeamMessage`.
- 호출하는 대상: `WorkflowInputCoordinator`, `GoalInterpreter`, `CapabilityAwareRouter`, workflow runners.
- 분리 필요 여부: 예.
- 우선순위: P0 완료 범위: 자연어/agentic/legacy fast path 진입부를 `WorkflowInputCoordinator`로 이동. P1: legacy workflow runners 추가 분리.

## MyTeam/ToolExecutionRouter.swift

- 현재 책임: readiness, permission, execution log, timeout, tool dispatch, result persistence.
- 너무 많이 가진 책임: provider별 실행과 일부 결과 formatting/persistence가 같은 파일에 남아 있음.
- 호출되는 위치: 업무 카드, 개인 채팅 fast path, 팀 워크룸 planner, natural work executor.
- 호출하는 대상: public API clients, Google clients, local draft tools, `ArtifactStore`, `ToolExecutionLogStore`.
- 분리 필요 여부: 예.
- 우선순위: P1. `ToolRunners/`와 `ToolFormatters/` 분리 필요. 이번 P0에서는 validator warning으로 추적.

## MyTeam/AgentChatView.swift

- 현재 책임: 개인 채팅 입력/표시, pending clarification resume, natural routing, agentic planning, fallback chat.
- 너무 많이 가진 책임: View 파일이 routing entrypoint까지 일부 소유.
- 호출되는 위치: 개인 채팅 UI.
- 호출하는 대상: `NaturalWorkRouter`, `AgenticToolOrchestrator`, `NaturalWorkPlanExecutor`, `CompositeWorkArtifactWriter`, `AIService`.
- 분리 필요 여부: 예.
- 우선순위: P1. `ChatInputDispatcher` 도입 시 View는 입력 전달과 표시만 담당.

## MyTeam/TeamStatusView.swift

- 현재 책임: 팀 워크룸 sidebar, room log, 입력, artifact strip, quick actions, status UI.
- 너무 많이 가진 책임: 하나의 View가 workroom container와 하위 패널을 대부분 가짐.
- 호출되는 위치: 설정/업무 UI의 팀 협업 surface.
- 호출하는 대상: `WorkflowOrchestrator`, `AgentWindowManager`, workroom stores.
- 분리 필요 여부: 예.
- 우선순위: P1. `TeamWorkroomSidebarView`, `TeamWorkroomLogView`, `TeamWorkroomInputBar`, `TeamWorkroomArtifactStrip`로 분리.

## MyTeam/HomeDashboardView.swift

- 현재 책임: 업무 홈, 최근 실행, 도구 카드, 연결 진입, 결과 표시.
- 너무 많이 가진 책임: 자연어 업무 중심 surface와 직접 도구 실행 surface가 섞임.
- 호출되는 위치: 설정/업무 탭.
- 호출하는 대상: `ToolExecutionRouter`, connection callbacks, result cards.
- 분리 필요 여부: 예.
- 우선순위: P1. 오늘 업무/최근 산출물/확인 필요 항목을 상단으로 올리고 도구 grid는 보조 surface로 낮춤.

## MyTeam/ToolExecutionLog.swift

- 현재 책임: 최근 실행 상태, duration, timeout, artifact filename, sanitized summary persistence.
- 너무 많이 가진 책임: 현재 범위에서는 적정. 상세 artifact model과 연결되면 log와 artifact store 책임을 더 분리해야 함.
- 호출되는 위치: `ToolExecutionRouter`, `ToolExecutionLogView`.
- 호출하는 대상: UserDefaults-backed log storage.
- 분리 필요 여부: 일부.
- 우선순위: P2.

## MyTeam/ToolExecutionLogView.swift

- 현재 책임: 최근 실행 목록과 상세 sheet.
- 너무 많이 가진 책임: artifact 재오픈이 앱 내부 상세보다 외부 파일 열기에 치우침.
- 호출되는 위치: 업무 홈.
- 호출하는 대상: `ArtifactStore`, `NSWorkspace`.
- 분리 필요 여부: 예.
- 우선순위: P1. `WorkArtifactDetailView` 도입 후 외부 파일 열기는 보조 버튼으로 낮춤.

## workers/basic-lookup-api/worker.js

- 현재 책임: Cloudflare basic lookup proxy, news/KMA/finance/law user routes, DART diagnostic routes.
- 너무 많이 가진 책임: provider별 handler가 단일 파일에 밀집.
- 호출되는 위치: 앱 public lookup clients, live route gate.
- 호출하는 대상: Naver, KMA, public data portal, Korean law, DART diagnostic upstream.
- 분리 필요 여부: 예.
- 우선순위: P0 완료 범위: `/health`의 `userRoutes`/`diagnosticRoutes` 분리. P1: route manifest/handler map 파일 분리.

## Current P0 Boundary

- 개인 채팅: `AgentChatView`에서 pending clarification과 natural work가 처리됨. P1에서 `ChatInputDispatcher`로 이동 필요.
- 팀 워크룸: `WorkflowOrchestrator.dispatch`가 `WorkflowInputCoordinator`를 호출하고, coordinator가 pending clarification, natural route, agentic route, legacy fast path를 순서대로 처리함.
- ToolExecution: 아직 `ToolExecutionRouter`가 runner/formatter/persistence 일부를 함께 보유. P1 분리 대상.
- Artifact: composite natural work artifact는 저장되지만 최근 실행 상세는 내부 artifact detail 중심으로 완전히 전환되지 않음.
- Worker: DART는 diagnostic route에만 표시하고 user route에서는 제외함.

## Next Refactor Order

1. `ChatInputDispatcher`로 개인 채팅 입력 경로 분리.
2. `ToolRunners/` 도입 후 `ToolExecutionRouter`에서 provider 실행 코드 이동.
3. `WorkArtifactDetailView`로 앱 내부 artifact 재오픈 구현.
4. `TeamStatusView` 하위 View 분리.
5. Worker route manifest/handler map 분리.
