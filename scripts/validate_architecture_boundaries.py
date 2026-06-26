#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    target = ROOT / path
    if not target.exists():
        raise SystemExit(f"FAIL: missing expected file: {path}")
    return target.read_text()


def method_body(source: str, signature: str) -> str:
    start = source.find(signature)
    if start == -1:
        raise SystemExit(f"FAIL: missing method signature: {signature}")
    brace = source.find("{", start)
    if brace == -1:
        raise SystemExit(f"FAIL: method has no body: {signature}")
    depth = 0
    for index in range(brace, len(source)):
        char = source[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[brace + 1:index]
    raise SystemExit(f"FAIL: unclosed method body: {signature}")


def main() -> None:
    failures: list[str] = []
    warnings: list[str] = []

    workflow = read("MyTeam/WorkflowOrchestrator.swift")
    workflow_input = read("MyTeam/WorkflowInputCoordinator.swift")
    context_provider = read("MyTeam/NaturalWorkContextProvider.swift")
    pending_coordinator = read("MyTeam/PendingNaturalWorkCoordinator.swift")
    entry_point = read("MyTeam/NaturalWorkEntryPoint.swift")
    agentic = read("MyTeam/AgenticToolOrchestration.swift")
    natural = read("MyTeam/NaturalWorkRouting.swift")
    plan_runner = read("MyTeam/NaturalWorkPlanRunner.swift")
    chat_sink = read("MyTeam/ChatResponseSink.swift")
    artifact_recorder = read("MyTeam/CompositeArtifactRecorder.swift")
    agent_chat = read("MyTeam/AgentChatView.swift")
    team_status = read("MyTeam/TeamStatusView.swift")
    tool_router = read("MyTeam/ToolExecutionRouter.swift")
    news_runner = read("MyTeam/ToolRunners/NewsToolRunner.swift")
    law_runner = read("MyTeam/ToolRunners/LawToolRunner.swift")
    weather_runner = read("MyTeam/ToolRunners/WeatherToolRunner.swift")
    finance_runner = read("MyTeam/ToolRunners/FinanceToolRunner.swift")
    dart_runner = read("MyTeam/ToolRunners/DARTToolRunner.swift")
    lookup_support = read("MyTeam/ToolRunners/PublicLookupRunnerSupport.swift")
    google_support = read("MyTeam/ToolRunners/GoogleRunnerSupport.swift")
    google_calendar_runner = read("MyTeam/ToolRunners/GoogleCalendarToolRunner.swift")
    google_sheets_runner = read("MyTeam/ToolRunners/GoogleSheetsToolRunner.swift")
    tool_formatters = read("MyTeam/ToolResultFormatters.swift")
    tool_log_view = read("MyTeam/ToolExecutionLogView.swift")
    work_artifact_detail = read("MyTeam/WorkArtifactDetailView.swift")
    worker = read("workers/basic-lookup-api/worker.js")
    project = read("MyTeam/MyTeam.xcodeproj/project.pbxproj")

    handle_body = method_body(workflow, "private func handleToolFastPath(")
    if "WorkflowInputCoordinator.shared.handle" not in handle_body:
        failures.append("WorkflowOrchestrator.handleToolFastPath must delegate to WorkflowInputCoordinator")
    for token in ["NaturalWorkRouter.route", "AgenticToolOrchestrator.plan", "MyTeamToolFastPathRouter.matchMany"]:
        if token in handle_body:
            failures.append(f"WorkflowOrchestrator.handleToolFastPath still owns routing detail: {token}")

    for token in [
        "NaturalWorkContextProvider.snapshot",
        "PendingNaturalWorkCoordinator.resolve",
        "NaturalWorkEntryPoint.resolve",
        "LegacyWorkflowFallbackRouter.shared.handle",
    ]:
        if token not in workflow_input:
            failures.append(f"WorkflowInputCoordinator missing expected step: {token}")
    for token in [
        "CompositeWorkArtifactWriter",
        "PendingNaturalWorkRequestStore.shared",
        "NaturalWorkContext(",
        "NaturalWorkRouter.route",
        "AgenticToolOrchestrator.plan",
    ]:
        if token in workflow_input:
            failures.append(f"WorkflowInputCoordinator owns a responsibility that must be delegated: {token}")
    if workflow_input.count("manager.addChatLog") >= 2:
        failures.append("WorkflowInputCoordinator must not directly create multiple chat log messages")

    if "PendingNaturalWorkRequestStore.shared" not in pending_coordinator:
        failures.append("PendingNaturalWorkCoordinator must own PendingNaturalWorkRequestStore access")
    if "NaturalWorkRouter.route" not in entry_point or "AgenticToolOrchestrator.plan" not in entry_point:
        failures.append("NaturalWorkEntryPoint must own deterministic and agentic planning order")
    if "agentID: String" not in entry_point or "agentConfig: AgentWindowManager.AgentConfig?" not in entry_point:
        failures.append("NaturalWorkEntryPoint.resolve must accept caller agent context")
    if 'agentID: "team_all"' in entry_point or "agentConfig: nil" in entry_point:
        failures.append("NaturalWorkEntryPoint must not hard-code team_all/nil agent context for planning")
    if "chatHistory: []" in agentic:
        failures.append("AgenticToolOrchestrator must pass recent chatHistory to AIService")
    if "NaturalWorkPlanValidator.planAfterValidation" not in plan_runner:
        failures.append("NaturalWorkPlanRunner must validate plans before execution")
    if "options: .composite" not in plan_runner:
        failures.append("NaturalWorkPlanRunner must execute composite work with ToolExecutionOptions.composite")
    if "ChatResponseSink.addProgress" not in plan_runner or "ChatResponseSink.updateOrAppend" not in plan_runner:
        failures.append("NaturalWorkPlanRunner must delegate chat message writes to ChatResponseSink")
    if "CompositeArtifactRecorder.write" not in plan_runner:
        failures.append("NaturalWorkPlanRunner must delegate artifact writes to CompositeArtifactRecorder")
    if "manager.addChatLog" not in chat_sink or "manager.updateChatLogText" not in chat_sink:
        failures.append("ChatResponseSink must own natural work chat response writes")
    if "CompositeWorkArtifactWriter.write" not in artifact_recorder:
        failures.append("CompositeArtifactRecorder must own composite artifact writer calls")
    if "activeArtifactID: nil" in workflow_input or "recentArtifacts: []" in workflow_input:
        failures.append("WorkflowInputCoordinator must not hard-code empty natural context fields")

    for file_name in [
        "WorkflowInputCoordinator.swift",
        "NaturalWorkContextProvider.swift",
        "PendingNaturalWorkCoordinator.swift",
        "NaturalWorkEntryPoint.swift",
        "NaturalWorkPlanRunner.swift",
        "ChatResponseSink.swift",
        "CompositeArtifactRecorder.swift",
    ]:
        if file_name not in project:
            failures.append(f"{file_name} is not included in the Xcode project")

    if re.search(r"\bToolNeedClassifier\b", agent_chat):
        failures.append("AgentChatView must not contain ToolNeedClassifier")
    if "ToolExecutionOptions" not in tool_router:
        failures.append("ToolExecutionRouter.run must accept ToolExecutionOptions")
    if "options.persistIndividualArtifact" not in tool_router:
        failures.append("ToolExecutionRouter must gate artifact persistence through ToolExecutionOptions")
    if "persistArtifact:" in tool_router:
        failures.append("ToolExecutionRouter.run must not expose legacy persistArtifact parameter")
    if "ToolExecutionDispatcher" not in tool_router or "ToolExecutionDispatcher.run" not in tool_router:
        failures.append("ToolExecutionRouter must delegate tool ID dispatch to ToolExecutionDispatcher")
    if "ResultFormatter" not in tool_formatters:
        failures.append("ToolResultFormatters.swift must define result formatter types")
    for file_name in ["ToolResultFormatters.swift", "WorkArtifactDetailView.swift"]:
        if file_name not in project:
            failures.append(f"{file_name} is not included in the Xcode project")
    for file_name in [
        "NewsToolRunner.swift",
        "LawToolRunner.swift",
        "WeatherToolRunner.swift",
        "FinanceToolRunner.swift",
        "FinancePeriodResolver.swift",
        "DARTToolRunner.swift",
        "PublicLookupRunnerSupport.swift",
        "GoogleRunnerSupport.swift",
        "GoogleCalendarToolRunner.swift",
        "GoogleSheetsToolRunner.swift",
    ]:
        if file_name not in project:
            failures.append(f"{file_name} is not included in the Xcode project")
    if "struct WorkArtifactDetailView" in tool_log_view:
        failures.append("WorkArtifactDetailView implementation must live outside ToolExecutionLogView.swift")
    if "struct WorkArtifactDetailView" not in work_artifact_detail:
        failures.append("WorkArtifactDetailView.swift must define WorkArtifactDetailView")
    if "artifactID != nil || entry.artifactFilename != nil" not in tool_log_view:
        failures.append("ToolExecutionLogView must expose artifact detail button for artifactID-only entries")

    markdown_sections_in_router = len(re.findall(r'"## ', tool_router))
    if markdown_sections_in_router > 0:
        failures.append("ToolExecutionRouter must not own Markdown section body formatting")
    formatter_residue = [
        "newsBriefingBody",
        "financeBody",
        "weatherSummaryParts",
        "spreadsheetPostprocessBody",
        "googleSheetsTableBody",
        "localBriefingBody",
        "dartBodyNotice",
        "lawResultState",
    ]
    for token in formatter_residue:
        if token in tool_router:
            failures.append(f"ToolExecutionRouter still owns formatter responsibility: {token}")
    for token in [
        "runNaverNews",
        "runKMAWeather",
        "runKoreanLaw",
        "runFinance",
        "runCompanyFinanceSummary",
        "runDART",
        "fetchFinanceData",
        "dartDirectFailureState",
        "CompanyFinanceRequest",
        "FinanceFetchResult",
        "runGoogleSheetsRead",
        "runGoogleCalendarToday",
        "GoogleSheetsReadRequest",
        "googleSheetsFailureState",
        "calendarFailureState",
    ]:
        if token in tool_router:
            failures.append(f"ToolExecutionRouter still owns provider runner body: {token}")
    expected_runner_dispatch = {
        "news.search": "NewsToolRunner.run",
        "weather.current": "WeatherToolRunner.run",
        "law.search": "LawToolRunner.run",
        "dart.disclosures.search": "DARTToolRunner.run",
        "finance.krx.stockPrice": "FinanceToolRunner.runStockPrice",
        "finance.krx.index": "FinanceToolRunner.runMarketIndex",
        "finance.company.statement": "FinanceToolRunner.runCompanyStatement",
        "calendar.events.today": "GoogleCalendarToolRunner.runToday",
        "spreadsheet.googleSheets.read": "GoogleSheetsToolRunner.runRead",
    }
    for tool_id, runner_call in expected_runner_dispatch.items():
        if runner_call not in tool_router:
            failures.append(f"ToolExecutionDispatcher must route {tool_id} through {runner_call}")
    runner_contracts = {
        "NewsToolRunner": news_runner,
        "LawToolRunner": law_runner,
        "WeatherToolRunner": weather_runner,
        "DARTToolRunner": dart_runner,
    }
    for type_name, source in runner_contracts.items():
        if f"enum {type_name}" not in source:
            failures.append(f"{type_name}.swift must define enum {type_name}")
        if "static func run(input: MyTeamToolInput) async -> ToolExecutionState" not in source:
            failures.append(f"{type_name} must expose static run(input:) returning ToolExecutionState")
    if "뉴스 검색어가 필요합니다" not in news_runner:
        failures.append("NewsToolRunner must reject missing search terms instead of silently defaulting")
    if "날씨 지역이 필요합니다" not in weather_runner:
        failures.append("WeatherToolRunner must reject missing region instead of defaulting to Seoul")
    if "법령 검색어가 필요합니다" not in law_runner:
        failures.append("LawToolRunner must reject missing law query instead of defaulting")
    if "enum FinanceToolRunner" not in finance_runner:
        failures.append("FinanceToolRunner.swift must define enum FinanceToolRunner")
    for signature in [
        "static func runStockPrice(input: MyTeamToolInput) async -> ToolExecutionState",
        "static func runMarketIndex(input: MyTeamToolInput) async -> ToolExecutionState",
        "static func runCompanyStatement(input: MyTeamToolInput) async -> ToolExecutionState",
    ]:
        if signature not in finance_runner:
            failures.append(f"FinanceToolRunner missing expected runner contract: {signature}")
    if "enum PublicLookupRunnerSupport" not in lookup_support:
        failures.append("PublicLookupRunnerSupport.swift must define enum PublicLookupRunnerSupport")
    for phrase in [
        "주식 기준일 시세 입력이 필요합니다",
        "시장 지수 입력이 필요합니다",
        "최신 사용 가능 재무기간을 자동 확인하지 못했습니다",
    ]:
        if phrase not in finance_runner:
            failures.append(f"FinanceToolRunner must reject missing inputs with explicit guidance: {phrase}")
    if "FinancePeriodResolver" not in finance_runner:
        failures.append("FinanceToolRunner must use FinancePeriodResolver for explicit/latest finance periods")
    if "runLatestAvailableCompanyStatement" not in finance_runner:
        failures.append("FinanceToolRunner must try latest available company finance periods internally")
    if "Calendar.current.component" in finance_runner:
        failures.append("FinanceToolRunner must not silently default company finance business year")
    finance_statement_index = natural.find('toolID: "finance.company.statement"')
    if finance_statement_index != -1:
        finance_window = natural[max(0, finance_statement_index - 900):finance_statement_index + 900]
        for token in ["Calendar.current.component", "currentYear", "currentYear - 1", "currentYear - 2", "fallbackInputs: fallbacks"]:
            if token in finance_window:
                failures.append(f"NaturalWorkRouting must not silently default company finance business year: {token}")
    for token in [
        'fallback: "삼성전자"',
        'fallback: "삼성전자 2024"',
        'fallback: "포스코"',
    ]:
        if token in finance_runner or token in tool_router:
            failures.append(f"Finance/DART runners must not use silent default fallback: {token}")
    if "Cloudflare DART" in dart_runner or "/dart/" in dart_runner:
        failures.append("DARTToolRunner must not use Cloudflare DART product routes")
    for phrase in ["개인 OpenDART API 키", "연결 설정에서 DART 키"]:
        if phrase not in dart_runner:
            failures.append(f"DARTToolRunner missing BYOK guidance phrase: {phrase}")
    if "enum GoogleRunnerSupport" not in google_support:
        failures.append("GoogleRunnerSupport.swift must define enum GoogleRunnerSupport")
    for token in ['Sheet1!A1:Z100', "defaultRange"]:
        if token in google_support or token in google_sheets_runner:
            failures.append(f"Google Sheets runner must not use implicit default range: {token}")
    if "enum GoogleCalendarToolRunner" not in google_calendar_runner:
        failures.append("GoogleCalendarToolRunner.swift must define enum GoogleCalendarToolRunner")
    if "static func runToday(input: MyTeamToolInput) async -> ToolExecutionState" not in google_calendar_runner:
        failures.append("GoogleCalendarToolRunner must expose static runToday(input:) returning ToolExecutionState")
    if "enum GoogleSheetsToolRunner" not in google_sheets_runner:
        failures.append("GoogleSheetsToolRunner.swift must define enum GoogleSheetsToolRunner")
    if "static func runRead(input: MyTeamToolInput) async -> ToolExecutionState" not in google_sheets_runner:
        failures.append("GoogleSheetsToolRunner must expose static runRead(input:) returning ToolExecutionState")
    for phrase in [
        "Google Sheets를 읽으려면 스프레드시트 URL 또는 ID와 범위가 필요합니다",
        "Google Sheets 읽기 연결",
    ]:
        if phrase not in google_sheets_runner and phrase not in google_support:
            failures.append(f"Google Sheets runner missing read-only guidance phrase: {phrase}")
    for token in ["시트를 수정했습니다", "값을 입력했습니다", "서식을 변경했습니다", "자동 정리 완료", "엑셀 후처리 완료"]:
        if token in google_sheets_runner or token in google_support:
            failures.append(f"Google Sheets runner must not include write/success-overclaim phrase: {token}")

    if "userRoutes: USER_ROUTES" not in worker or "diagnosticRoutes: DIAGNOSTIC_ROUTES" not in worker:
        failures.append("Worker /health must expose userRoutes and diagnosticRoutes")
    user_routes_match = re.search(r"const\s+USER_ROUTES\s*=\s*\[(.*?)\];", worker, re.S)
    if not user_routes_match:
        failures.append("Worker must define USER_ROUTES")
    elif "/dart/" in user_routes_match.group(1):
        failures.append("DART routes must stay out of USER_ROUTES")

    if "NSWorkspace.shared.open" in tool_log_view and "WorkArtifactDetailView" not in tool_log_view:
        warnings.append("ToolExecutionLogView still relies on external file open for artifact detail")

    if "ToolExecutionDispatcher" not in tool_router and "case \"news.search\"" in tool_router:
        warnings.append("ToolExecutionRouter still mixes runner dispatch and provider-specific execution")
    team_status_markers = [
        "sendTeamMessage",
        "workroomSidebar",
        "artifact",
        "TextEditor",
        "messageLog",
    ]
    present_markers = [marker for marker in team_status_markers if marker in team_status]
    if len(present_markers) >= 3:
        warnings.append(
            "TeamStatusView still combines multiple workroom responsibilities: "
            + ", ".join(present_markers)
        )

    if failures:
        print("FAIL: architecture boundary validation failed")
        for failure in failures:
            print(f"- {failure}")
        if warnings:
            print("\nWarnings:")
            for warning in warnings:
                print(f"- {warning}")
        sys.exit(1)

    if warnings:
        print("PASS: architecture P0 boundaries")
        print("Warnings:")
        for warning in warnings:
            print(f"- {warning}")
    else:
        print("PASS: architecture boundaries")


if __name__ == "__main__":
    main()
