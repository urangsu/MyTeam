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
    router = read("MyTeam/ToolExecutionRouter.swift")
    pbxproj = read("MyTeam/MyTeam.xcodeproj/project.pbxproj")

    require_contains("Xcode project", pbxproj, "NaturalWorkRouting.swift")
    require_contains("NaturalWorkRouteDecision", natural, "case clarification")
    require_contains("PendingNaturalWorkRequestStore", natural, "final class PendingNaturalWorkRequestStore")
    require_contains("PendingNaturalWorkRequestStore", natural, "func mergeAnswer")
    require_contains("PendingNaturalWorkRequestStore", natural, "func mergedText")
    require_contains("NaturalWorkPlanValidationResult", natural, "struct NaturalWorkPlanValidationResult")
    require_contains("NaturalWorkPlanValidator", natural, "enum NaturalWorkPlanValidator")

    require_contains("AgentChatView natural route", chat, "NaturalWorkRouter.route")
    require_contains("AgentChatView pending", chat, "PendingNaturalWorkRequestStore.shared.pending")
    require_contains("AgentChatView artifact", chat, "CompositeWorkArtifactWriter.write")
    require_order(
        "AgentChatView routing order",
        chat,
        "NaturalWorkRouter.route",
        "MyTeamToolFastPathRouter.matchMany",
    )

    require_contains("WorkflowOrchestrator natural route", workflow, "NaturalWorkRouter.route")
    require_contains("WorkflowOrchestrator pending", workflow, "PendingNaturalWorkRequestStore.shared.pending")
    require_contains("WorkflowOrchestrator artifact", workflow, "CompositeWorkArtifactWriter.write")
    require_order(
        "WorkflowOrchestrator routing order",
        workflow,
        "NaturalWorkRouter.route",
        "MyTeamToolFastPathRouter.matchMany",
    )

    require_contains("Composite route artifact suppression", natural, "persistArtifact: false")
    require_contains("ToolExecutionRouter persist option", router, "persistArtifact: Bool = true")

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
