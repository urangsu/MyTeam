#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    target = ROOT / path
    if not target.exists():
        raise SystemExit(f"FAIL: missing expected file: {path}")
    return target.read_text(encoding="utf-8")


def main() -> None:
    failures: list[str] = []

    agent_chat = read("MyTeam/AgentChatView.swift")
    workflow = read("MyTeam/WorkflowOrchestrator.swift")
    workflow_input = read("MyTeam/WorkflowInputCoordinator.swift")
    context_provider = read("MyTeam/NaturalWorkContextProvider.swift")
    plan_runner = read("MyTeam/NaturalWorkPlanRunner.swift")
    tool_router = read("MyTeam/ToolExecutionRouter.swift")
    artifact_recorder = read("MyTeam/CompositeArtifactRecorder.swift")
    artifact_detail = read("MyTeam/WorkArtifactDetailView.swift")
    matrix = read("docs/qa/NaturalWorkE2ESmokeMatrix.md")

    if "NaturalWorkEntryPoint.resolve" not in agent_chat:
        failures.append("AgentChatView must call NaturalWorkEntryPoint.resolve")
    if "MyTeamToolFastPathRouter.matchMany" in agent_chat:
        failures.append("AgentChatView must not call MyTeamToolFastPathRouter.matchMany directly")
    if "LegacyWorkflowFallbackRouter.shared.handle" not in agent_chat:
        failures.append("AgentChatView must call legacy fallback only after natural work fallback")
    if "WorkflowInputCoordinator.shared.handle" not in workflow:
        failures.append("WorkflowOrchestrator must delegate input handling to WorkflowInputCoordinator")
    if "NaturalWorkEntryPoint.resolve" not in workflow_input:
        failures.append("WorkflowInputCoordinator must call NaturalWorkEntryPoint.resolve")
    if "MyTeamToolFastPathRouter.matchMany" not in workflow_input:
        failures.append("WorkflowInputCoordinator must own the legacy fast-path fallback")
    if "recentArtifactIndexEntries(for: roomID)" not in context_provider:
        failures.append("NaturalWorkContextProvider must read recent artifact index entries")
    if "activeArtifactID: activeArtifactID" not in context_provider:
        failures.append("NaturalWorkContextProvider must pass activeArtifactID into NaturalWorkContext")
    if "manager.recentArtifacts(for: roomID)" not in context_provider:
        failures.append("NaturalWorkContextProvider must fill recentArtifacts from the room-scoped cache")
    if "recentArtifacts: []" in context_provider:
        failures.append("NaturalWorkContextProvider must not hard-code recentArtifacts as empty")

    for token in [
        "CompositeArtifactRecorder.write",
        "ChatResponseSink.addProgress",
        "ChatResponseSink.updateOrAppend",
    ]:
        if token not in plan_runner:
            failures.append(f"NaturalWorkPlanRunner missing E2E step: {token}")
    if "options: .composite" not in plan_runner and ".composite(parentWorkID:" not in plan_runner:
        failures.append("NaturalWorkPlanRunner must execute natural work with composite ToolExecutionOptions")
    if "options.persistIndividualArtifact" not in tool_router:
        failures.append("ToolExecutionRouter must suppress individual artifacts during composite execution")
    if "CompositeWorkArtifactWriter.write" not in artifact_recorder:
        failures.append("CompositeArtifactRecorder must persist composite work artifacts")
    for token in ["roomID", "workflowID"]:
        if token not in artifact_recorder:
            failures.append(f"CompositeArtifactRecorder must retain {token} context")
    if "ArtifactStore.shared.load" not in artifact_detail and "ArtifactStore.shared" not in artifact_detail:
        failures.append("WorkArtifactDetailView must read artifact content through ArtifactStore")

    required_cases = [
        "NW-001",
        "NW-002",
        "NW-003",
        "NW-004",
        "NW-005",
        "NW-006",
        "NW-007",
        "NW-008",
        "NW-009",
        "NW-010",
        "NW-011",
        "NW-012",
        "NW-013",
        "NW-014",
        "NW-015",
    ]
    for case_id in required_cases:
        if case_id not in matrix:
            failures.append(f"NaturalWorkE2ESmokeMatrix missing case {case_id}")

    if failures:
        print("FAIL: natural work E2E smoke failed")
        for failure in failures:
            print(f"- {failure}")
        sys.exit(1)

    print("PASS: natural work E2E smoke")


if __name__ == "__main__":
    main()
