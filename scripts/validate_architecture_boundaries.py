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
    agent_chat = read("MyTeam/AgentChatView.swift")
    team_status = read("MyTeam/TeamStatusView.swift")
    tool_router = read("MyTeam/ToolExecutionRouter.swift")
    tool_log_view = read("MyTeam/ToolExecutionLogView.swift")
    worker = read("workers/basic-lookup-api/worker.js")
    project = read("MyTeam/MyTeam.xcodeproj/project.pbxproj")

    handle_body = method_body(workflow, "private func handleToolFastPath(")
    if "WorkflowInputCoordinator.shared.handle" not in handle_body:
        failures.append("WorkflowOrchestrator.handleToolFastPath must delegate to WorkflowInputCoordinator")
    for token in ["NaturalWorkRouter.route", "AgenticToolOrchestrator.plan", "MyTeamToolFastPathRouter.matchMany"]:
        if token in handle_body:
            failures.append(f"WorkflowOrchestrator.handleToolFastPath still owns routing detail: {token}")

    for token in [
        "PendingNaturalWorkRequestStore.shared.pending",
        "NaturalWorkRouter.route",
        "AgenticToolOrchestrator.plan",
        "LegacyWorkflowFallbackRouter.shared.handle",
    ]:
        if token not in workflow_input:
            failures.append(f"WorkflowInputCoordinator missing expected step: {token}")

    if "WorkflowInputCoordinator.swift" not in project:
        failures.append("WorkflowInputCoordinator.swift is not included in the Xcode project")

    if re.search(r"\bToolNeedClassifier\b", agent_chat):
        failures.append("AgentChatView must not contain ToolNeedClassifier")

    if "userRoutes: USER_ROUTES" not in worker or "diagnosticRoutes: DIAGNOSTIC_ROUTES" not in worker:
        failures.append("Worker /health must expose userRoutes and diagnosticRoutes")
    user_routes_match = re.search(r"const\s+USER_ROUTES\s*=\s*\[(.*?)\];", worker, re.S)
    if not user_routes_match:
        failures.append("Worker must define USER_ROUTES")
    elif "/dart/" in user_routes_match.group(1):
        failures.append("DART routes must stay out of USER_ROUTES")

    if "NSWorkspace.shared.open" in tool_log_view and "WorkArtifactDetailView" not in tool_log_view:
        warnings.append("ToolExecutionLogView still relies on external file open for artifact detail")

    if "private func run" in tool_router and "case \"news.search\"" in tool_router:
        warnings.append("ToolExecutionRouter still mixes runner dispatch and provider-specific execution")
    if "ToolResultFormatter" not in tool_router and "markdown" in tool_router.lower():
        warnings.append("ToolExecutionRouter still appears to own result formatting")

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
