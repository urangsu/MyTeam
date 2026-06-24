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
    return target.read_text(encoding="utf-8")


def main() -> None:
    failures: list[str] = []
    warnings: list[str] = []

    agent_chat = read("MyTeam/AgentChatView.swift")
    workflow_input = read("MyTeam/WorkflowInputCoordinator.swift")
    fast_path = read("MyTeam/MyTeamToolFastPathRouter.swift")
    natural = read("MyTeam/NaturalWorkRouting.swift")
    tool_router = read("MyTeam/ToolExecutionRouter.swift")
    settings = read("MyTeam/SettingsView.swift")
    home = read("MyTeam/HomeDashboardView.swift")
    registry = read("MyTeam/MyTeamToolRegistry.swift")
    tool_card = read("MyTeam/ToolActionCardView.swift")
    file_policy = read("MyTeam/FileIntakePolicy.swift")
    team_status = read("MyTeam/TeamStatusView.swift")
    inventory = read("docs/qa/ProductCompletenessInventory.md")

    if "MyTeamToolFastPathRouter.matchMany" in agent_chat:
        failures.append("AgentChatView must not directly execute legacy fast-path routing")
    if "LegacyWorkflowFallbackRouter.shared.handle" not in agent_chat:
        failures.append("AgentChatView must use the shared legacy fallback runner")
    if "MyTeamToolFastPathRouter.matchMany" not in workflow_input:
        failures.append("WorkflowInputCoordinator must remain the single legacy fast-path fallback owner")

    forbidden_default_fragments = [
        'fallback: "경제"',
        'fallback: "서울"',
        'fallback: "근로기준법"',
        'fallback: "삼성전자"',
        'fallback: "삼성전자 2024"',
        'fallback: "포스코"',
        'fallback: label',
    ]
    for source_name, source in [
        ("MyTeamToolFastPathRouter.swift", fast_path),
        ("NaturalWorkRouting.swift", natural),
        ("ToolExecutionRouter.swift", tool_router),
    ]:
        for fragment in forbidden_default_fragments:
            if fragment in source:
                failures.append(f"{source_name} still contains silent default lookup fragment: {fragment}")

    if 'CharacterStoreSkeletonView()' in settings:
        failures.append("SettingsView must not expose CharacterStoreSkeletonView as product surface")
    if "텍스트 추출" not in file_policy:
        failures.append("FileIntakePolicy must describe file support as extraction/card generation, not full analysis")
    if "먼저 txt, md, csv 파일을 지원합니다" in team_status:
        failures.append("TeamStatusView file support copy is stale and under-reports supported intake formats")

    required_inventory_terms = [
        "productionReady",
        "liveButNeedsManualQA",
        "partialTextOnly",
        "plannedHidden",
        "developerOnly",
        "blocked",
        "Recommended surface",
        "primary",
        "secondary",
        "naturalOnly",
        "connectionOnly",
        "developerOnly",
        "hidden",
        "Natural work routing",
        "Public lookup tools",
        "File intake",
        "Character store",
    ]
    for term in required_inventory_terms:
        if term not in inventory:
            failures.append(f"ProductCompletenessInventory missing required term: {term}")

    if "ObservationInboxView(" in settings:
        failures.append("SettingsView must not expose observation/developer inbox surfaces")
    if "ConnectorStatusView(" in settings or "PlaywrightMCPStatusView(" in settings:
        failures.append("SettingsView must not expose developer diagnostics")

    if "DemoRoomSeeder" in settings or "SampleArtifactSeeder" in settings:
        failures.append("SettingsView must not expose demo seed controls until DemoMode seeding is productized")

    if "CharacterStoreSkeletonView.swift" in inventory and "plannedHidden" not in inventory:
        failures.append("Character store skeleton must be tracked as plannedHidden")

    quick_match = re.search(r"private\s+let\s+quickToolIDs\s*=\s*\[(.*?)\]", home, re.S)
    if not quick_match:
        failures.append("HomeDashboardView must define an auditable quickToolIDs list")
    else:
        quick_body = quick_match.group(1)
        forbidden_primary_tools = {
            "spreadsheet.postprocess": "spreadsheet review is hidden until it produces stronger artifacts",
            "spreadsheet.googleSheets.read": "Google Sheets read is hidden from primary surface until live QA is complete",
            "finance.company.statement": "company finance requires company/year context and belongs inside natural work",
            "weather.current": "weather requires explicit region and validated KMA readiness",
            "dart.disclosures.search": "DART requires BYOK and belongs inside company/disclosure natural work",
            "calendar.events.today": "Calendar read belongs behind natural intent/connection state",
            "voice.bubbleSpeech.preview": "voice lab is not a primary work dashboard action",
        }
        for tool_id, reason in forbidden_primary_tools.items():
            if f'"{tool_id}"' in quick_body:
                failures.append(f"HomeDashboardView primary quickToolIDs must not include {tool_id}: {reason}")

    for tool_id in ["spreadsheet.postprocess", "spreadsheet.googleSheets.read"]:
        descriptor_match = re.search(
            rf'id:\s+"{re.escape(tool_id)}".*?isUserFacing:\s*(true|false)',
            registry,
            re.S,
        )
        if not descriptor_match:
            failures.append(f"MyTeamToolRegistry missing auditable descriptor for {tool_id}")
        elif descriptor_match.group(1) != "false":
            failures.append(f"{tool_id} must remain hidden from user-facing tool surfaces until productized")

    if "삼성전자 2024" in home or "삼성전자 2024" in tool_card:
        failures.append("Home/ToolActionCard must not seed finance.company.statement with 삼성전자 2024")
    for source_name, source in [
        ("HomeDashboardView.swift", home),
        ("ToolActionCardView.swift", tool_card),
    ]:
        for forbidden in ['return "서울"', 'return "경제"', 'return "근로기준법"', 'return "삼성전자"']:
            if forbidden in source:
                failures.append(f"{source_name} must not use silent default query: {forbidden}")

    if failures:
        print("FAIL: product completeness audit failed")
        for failure in failures:
            print(f"- {failure}")
        if warnings:
            print("\nWarnings:")
            for warning in warnings:
                print(f"- {warning}")
        sys.exit(1)

    print("PASS: product completeness audit")
    if warnings:
        print("Warnings:")
        for warning in warnings:
            print(f"- {warning}")


if __name__ == "__main__":
    main()
