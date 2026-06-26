#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def fail(message: str) -> None:
    print(f"FAIL: {message}")
    sys.exit(1)


def require_contains(label: str, haystack: str, needle: str) -> None:
    if needle not in haystack:
        fail(f"{label} missing {needle!r}")


def require_order(label: str, haystack: str, first: str, second: str) -> None:
    first_index = haystack.find(first)
    second_index = haystack.find(second)
    if first_index == -1:
        fail(f"{label} missing {first!r}")
    if second_index == -1:
        fail(f"{label} missing {second!r}")
    if first_index > second_index:
        fail(f"{label} expected {first!r} before {second!r}")


def require_fixture(cases: list[dict], case_id: str) -> dict:
    for case in cases:
        if case.get("id") == case_id:
            return case
    fail(f"fixture missing id: {case_id}")


def window_around(source: str, needle: str, radius: int = 500) -> str:
    index = source.find(needle)
    if index == -1:
        fail(f"source missing required marker: {needle}")
    return source[max(0, index - radius):index + len(needle) + radius]


def main() -> None:
    natural = read("MyTeam/NaturalWorkRouting.swift")
    chat = read("MyTeam/AgentChatView.swift")
    workflow = read("MyTeam/WorkflowOrchestrator.swift")
    workflow_input = read("MyTeam/WorkflowInputCoordinator.swift")
    entry_point = read("MyTeam/NaturalWorkEntryPoint.swift")
    pending = read("MyTeam/PendingNaturalWorkCoordinator.swift")
    runner = read("MyTeam/NaturalWorkPlanRunner.swift")
    router = read("MyTeam/ToolExecutionRouter.swift")
    pbxproj = read("MyTeam/MyTeam.xcodeproj/project.pbxproj")

    require_contains("Xcode project", pbxproj, "NaturalWorkRouting.swift")
    require_contains("NaturalWorkRouteDecision", natural, "case clarification")
    require_contains("PendingNaturalWorkRequestStore", natural, "final class PendingNaturalWorkRequestStore")
    require_contains("PendingNaturalWorkRequestStore", natural, "func mergeAnswer")
    require_contains("PendingNaturalWorkRequestStore", natural, "func mergedText")
    require_contains("NaturalWorkPlanValidationResult", natural, "struct NaturalWorkPlanValidationResult")
    require_contains("NaturalWorkPlanValidator", natural, "enum NaturalWorkPlanValidator")

    require_contains("NaturalWorkEntryPoint route", entry_point, "NaturalWorkRouter.route")
    require_contains("NaturalWorkEntryPoint agentic", entry_point, "AgenticToolOrchestrator.plan")
    require_contains("NaturalWorkEntryPoint agent context", entry_point, "agentID: String")
    require_contains("NaturalWorkEntryPoint agent config", entry_point, "agentConfig: AgentWindowManager.AgentConfig?")
    require_contains("PendingNaturalWorkCoordinator pending", pending, "PendingNaturalWorkRequestStore.shared.pending")
    require_contains("NaturalWorkPlanRunner artifact", runner, "CompositeArtifactRecorder.write")
    require_contains("AgentChatView natural entrypoint", chat, "NaturalWorkEntryPoint.resolve")
    require_contains("AgentChatView pending coordinator", chat, "PendingNaturalWorkCoordinator.resolve")
    require_contains("AgentChatView runner", chat, "NaturalWorkPlanRunner.run")
    require_contains("AgentChatView shared legacy fallback", chat, "LegacyWorkflowFallbackRouter.shared.handle")
    if "MyTeamToolFastPathRouter.matchMany" in chat:
        fail("AgentChatView must not directly own legacy fast-path matching")
    require_order(
        "AgentChatView routing order",
        chat,
        "NaturalWorkEntryPoint.resolve",
        "LegacyWorkflowFallbackRouter.shared.handle",
    )

    require_contains("WorkflowOrchestrator coordinator", workflow, "WorkflowInputCoordinator.shared.handle")
    require_contains("WorkflowInputCoordinator entrypoint", workflow_input, "NaturalWorkEntryPoint.resolve")
    require_contains("WorkflowInputCoordinator pending coordinator", workflow_input, "PendingNaturalWorkCoordinator.resolve")
    require_contains("WorkflowInputCoordinator runner", workflow_input, "NaturalWorkPlanRunner.run")
    require_order(
        "WorkflowInputCoordinator routing order",
        workflow_input,
        "NaturalWorkEntryPoint.resolve",
        "MyTeamToolFastPathRouter.matchMany",
    )

    require_contains("Composite route artifact suppression", natural, "options: options")
    require_contains("ToolExecutionRouter options", router, "options: ToolExecutionOptions = .standalone")
    require_contains("ToolExecutionRouter option gate", router, "options.persistIndividualArtifact")

    false_positive_phrases = [
        "뉴스 기사처럼",
        "캘린더 형식",
        "공시 양식처럼",
        "주가처럼",
        "법적으로 자연스럽게",
    ]
    for phrase in false_positive_phrases:
        if phrase not in natural and phrase not in read("MyTeam/AgenticToolOrchestration.swift"):
            fail(f"false-positive phrase missing from routing code: {phrase}")

    finance_runner = read("MyTeam/ToolRunners/FinanceToolRunner.swift")
    finance_formatter = read("MyTeam/ToolResultFormatters.swift")
    finance_period = read("MyTeam/ToolRunners/FinancePeriodResolver.swift")
    require_contains("NaturalWorkRouting latest finance period", natural, "FinancePeriodResolver.query")
    require_contains("FinancePeriodResolver latest token", finance_period, "latestAvailable")
    require_contains("FinanceToolRunner latest period", finance_runner, "runLatestAvailableCompanyStatement")
    require_contains("Finance formatter period label", finance_formatter, "기준 기간")
    require_contains("Finance formatter automatic selection", finance_formatter, "자동 선택")
    require_contains("Finance formatter available period wording", finance_formatter, "조회 가능한 최신 기준 기간")
    finance_window = window_around(natural, 'toolID: "finance.company.statement"', radius=900)
    for forbidden in [
        "Calendar.current.component",
        "currentYear",
        "currentYear - 1",
        "currentYear - 2",
    ]:
        if forbidden in finance_window:
            fail(f"finance.company.statement must not use silent business-year default: {forbidden}")
    if "fallbackInputs: fallbacks" in finance_window:
        fail("finance.company.statement must not use current-year fallback inputs")
    if "FinancePeriodResolver.query" not in finance_window:
        fail("finance.company.statement must use FinancePeriodResolver.query for explicit/latest period hints")
    if 'toolID: "spreadsheet.postprocess"' in natural:
        fail("NaturalWorkRouting must not route hidden spreadsheet.postprocess as a natural work step")
    spreadsheet_window = window_around(natural, "private static func spreadsheetReviewPlan", radius=1800)
    require_contains("spreadsheet review safe route", spreadsheet_window, 'toolID: "document.rewrite"')
    require_contains("spreadsheet review notice", spreadsheet_window, "직접 수정")
    require_contains("spreadsheet review notice", spreadsheet_window, "보장하지 않습니다")

    fixture_path = ROOT / "tests/fixtures/natural_work_routing_cases.json"
    if not fixture_path.exists():
        fail("tests/fixtures/natural_work_routing_cases.json missing")
    cases = json.loads(fixture_path.read_text(encoding="utf-8"))
    if len(cases) < 4:
        fail("natural work routing fixture has too few cases")
    for required_input in ["삼성전자 알려줘", "뉴스 기사처럼 써줘", "회의록 만들어줘", "예산안 이상한 항목 찾아줘"]:
        if not any(case.get("input") == required_input for case in cases):
            fail(f"fixture missing case: {required_input}")
    required_fixture_ids = [
        "company-overview-latest-finance",
        "finance-company-latest-period",
        "finance-company-explicit-year",
        "budget-review-hidden-spreadsheet-safe-route",
        "closing-variance-hidden-spreadsheet-safe-route",
    ]
    for case_id in required_fixture_ids:
        require_fixture(cases, case_id)
    latest_period = require_fixture(cases, "finance-company-latest-period")
    if "finance.company.statement" not in latest_period.get("expectedTools", []):
        fail("finance-company-latest-period fixture must require finance.company.statement")
    if "latestAvailable" not in latest_period.get("expectedQueryFragments", []):
        fail("finance-company-latest-period fixture must require latestAvailable")
    overview = require_fixture(cases, "company-overview-latest-finance")
    if "finance.company.statement" not in overview.get("expectedTools", []):
        fail("company-overview-latest-finance fixture must include finance.company.statement")
    explicit_year = require_fixture(cases, "finance-company-explicit-year")
    if "finance.company.statement" not in explicit_year.get("expectedTools", []):
        fail("finance-company-explicit-year fixture must require finance.company.statement")
    if "latestAvailable" not in explicit_year.get("forbiddenQueryFragments", []):
        fail("finance-company-explicit-year fixture must forbid latestAvailable")
    safe_route = require_fixture(cases, "budget-review-hidden-spreadsheet-safe-route")
    if "spreadsheet.postprocess" not in safe_route.get("expectedToolsAbsent", []):
        fail("budget-review-hidden-spreadsheet-safe-route must forbid spreadsheet.postprocess")
    if "document.rewrite" not in safe_route.get("expectedTools", []):
        fail("budget-review-hidden-spreadsheet-safe-route must use document.rewrite")

    print("PASS: natural work routing static validation")


if __name__ == "__main__":
    main()
