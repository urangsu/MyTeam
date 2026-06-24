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

    fixture_path = ROOT / "tests/fixtures/natural_work_routing_cases.json"
    if not fixture_path.exists():
        fail("tests/fixtures/natural_work_routing_cases.json missing")
    cases = json.loads(fixture_path.read_text(encoding="utf-8"))
    if len(cases) < 4:
        fail("natural work routing fixture has too few cases")
    for required_input in ["삼성전자 알려줘", "뉴스 기사처럼 써줘", "회의록 만들어줘", "예산안 이상한 항목 찾아줘"]:
        if not any(case.get("input") == required_input for case in cases):
            fail(f"fixture missing case: {required_input}")

    print("PASS: natural work routing static validation")


if __name__ == "__main__":
    main()
