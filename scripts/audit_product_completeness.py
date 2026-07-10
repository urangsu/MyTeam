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
    surface_policy = read("MyTeam/ProductSurfacePolicy.swift")
    registry = read("MyTeam/MyTeamToolRegistry.swift")
    tool_card = read("MyTeam/ToolActionCardView.swift")
    file_policy = read("MyTeam/FileIntakePolicy.swift")
    team_status = read("MyTeam/TeamStatusView.swift")
    google_support = read("MyTeam/ToolRunners/GoogleRunnerSupport.swift")
    google_sheets_runner = read("MyTeam/ToolRunners/GoogleSheetsToolRunner.swift")
    finance_runner = read("MyTeam/ToolRunners/FinanceToolRunner.swift")
    finance_formatter = read("MyTeam/ToolResultFormatters.swift")
    tool_state = read("MyTeam/ToolExecutionState.swift")
    chain_step = read("MyTeam/ChainStep.swift")
    chain_projection = read("MyTeam/ChainOrchestrator.swift")
    chain_runtime = read("MyTeam/KSkillAssistRuntime.swift")
    ai_model_policy = read("MyTeam/AIModelPolicy.swift")
    myteam_app = read("MyTeam/MyTeamApp.swift")
    agent_window_manager = read("MyTeam/AgentWindowManager.swift")
    floating_panel = read("MyTeam/FloatingPanel.swift")
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
        "Code policy",
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
    settings_scene_match = re.search(r"Settings\s*\{(?P<body>.*?)\n\s*\}", myteam_app, re.S)
    if settings_scene_match and "SettingsView(" in settings_scene_match.group("body"):
        failures.append("SwiftUI Settings scene must not create a second SettingsView instance")
    if "CommandGroup(replacing: .appSettings)" not in myteam_app or "AgentWindowManager.shared.showSettingsWindow()" not in myteam_app:
        failures.append("macOS Settings command must route through AgentWindowManager.showSettingsWindow")
    settings_window_index = agent_window_manager.find('agentID: "settings_window"')
    if settings_window_index != -1:
        window = agent_window_manager[max(0, settings_window_index - 200):settings_window_index + 260]
        if "FloatingPanel(" in window:
            failures.append("Settings window must use a normal NSWindow, not FloatingPanel")
    if "private var settingsPanel: FloatingPanel?" in agent_window_manager:
        failures.append("AgentWindowManager must not store Settings as a FloatingPanel")
    if "private var settingsWindow: NSWindow?" not in agent_window_manager:
        failures.append("AgentWindowManager must keep Settings in a normal NSWindow")
    if "private func presentSettingsWindow(_ window: NSWindow)" not in agent_window_manager:
        failures.append("AgentWindowManager must present Settings through a shared helper")
    if "presentSettingsWindow(settingsWindow)" not in agent_window_manager:
        failures.append("Existing Settings window must be brought forward through presentSettingsWindow")
    if "presentSettingsWindow(window)" not in agent_window_manager:
        failures.append("New Settings window must be brought forward through presentSettingsWindow")
    if "lowerFloatingPanelsForSettings()" not in agent_window_manager or "restoreFloatingPanelsAfterSettings()" not in agent_window_manager:
        failures.append("Settings presentation must demote and restore app-owned FloatingPanel levels")
    if "settingsSuppressedPanelLevels" not in agent_window_manager:
        failures.append("Settings presentation must remember suppressed FloatingPanel levels for restore")
    for token in [
        "applySettingsPresentationPolicy(to:",
        "keepSettingsFrontIfNeeded()",
        "bringSettingsWindowToFront",
    ]:
        if token not in agent_window_manager:
            failures.append(f"Settings window layering must include runtime panel policy: {token}")
    suppression_match = re.search(
        r"private func floatingPanelsForSettingsSuppression\(\) -> \[FloatingPanel\] \{(?P<body>.*?)\n    \}",
        agent_window_manager,
        re.S,
    )
    if suppression_match and "teamPanel" in suppression_match.group("body"):
        failures.append("Settings presentation must not demote the team member panel")
    if '"settings_window"' in floating_panel:
        failures.append("FloatingPanel must not contain settings_window special cases")
    tuck_ids_match = re.search(
        r"allowedPanelIDs:\s*Set<String>\s*=\s*\[(?P<body>.*?)\]",
        floating_panel,
        re.S,
    )
    if tuck_ids_match and '"status_window"' in tuck_ids_match.group("body"):
        failures.append("status_window must not be edge-tuckable; it causes team collaboration panel snap/drag behavior")
    background_drag_match = re.search(
        r"private var allowsBackgroundDragging:\s*Bool\s*\{(?P<body>.*?)\n    \}",
        floating_panel,
        re.S,
    )
    if not background_drag_match or 'case "status_window":' not in background_drag_match.group("body") or "return false" not in background_drag_match.group("body"):
        failures.append("status_window must explicitly disable background dragging")
    if "panelChromePadding" not in team_status or "windowHeight" not in team_status:
        failures.append("TeamStatusView must size the status window with chrome padding included")
    status_size_match = re.search(
        r"func updateStatusWindowSize\(width:\s*CGFloat,\s*height:\s*CGFloat\)\s*\{(?P<body>.*?)\n    \}",
        agent_window_manager,
        re.S,
    )
    if not status_size_match or "PanelTuckGeometry.clampedExpandedFrame" not in status_size_match.group("body"):
        failures.append("updateStatusWindowSize must clamp the resized status window inside the visible screen")

    for token in ["case checkedEmpty", "case partial"]:
        if token not in tool_state:
            failures.append(f"ToolExecutionState must distinguish non-success result state: {token}")

    for token in ["case evidenceAvailable", "case planned", "case projected"]:
        if token not in chain_step:
            failures.append(f"Chain projection must preserve non-execution state: {token}")
    if "enum ChainEvidenceProjector" not in chain_projection:
        failures.append("Chain evidence projection must not present itself as an execution orchestrator")
    if "addingTimeInterval(0.02)" in chain_projection:
        failures.append("Chain evidence projection must not fabricate 0.02 second execution durations")
    for pattern in [
        r"hasTextAttachment\s*\?\s*\.succeeded",
        r"hasMailSource\s*\?\s*\.succeeded",
    ]:
        if re.search(pattern, chain_projection):
            failures.append("Chain evidence projection must not mark attachment presence as executed success")
    if "ChainEvidenceProjector.createShell" not in chain_runtime or "ChainEvidenceProjector.updateRun" not in chain_runtime:
        failures.append("KSkillAssistRuntime must use the truthful ChainEvidenceProjector entrypoint")

    discovery_match = re.search(
        r"static var dynamicModelDiscoveryAllowed: Bool \{(?P<body>.*?)\n    \}",
        ai_model_policy,
        re.S,
    )
    if not discovery_match:
        failures.append("AIModelPolicy must define an auditable dynamic model discovery gate")
    else:
        discovery_body = discovery_match.group("body")
        if "#if DEBUG" not in discovery_body or "#else" not in discovery_body or "return false" not in discovery_body:
            failures.append("Release must not auto-promote models discovered from provider model lists")
    no_results_index = finance_formatter.find("nonisolated static func noResultsState")
    if no_results_index != -1:
        no_results_window = finance_formatter[no_results_index:no_results_index + 800]
        if ".succeeded(" in no_results_window:
            failures.append("ToolResultFormatters.noResultsState must not return .succeeded")
        if ".checkedEmpty(" not in no_results_window:
            failures.append("ToolResultFormatters.noResultsState must return .checkedEmpty")

    if "DemoRoomSeeder" in settings or "SampleArtifactSeeder" in settings:
        failures.append("SettingsView must not expose demo seed controls until DemoMode seeding is productized")

    if "showsCharacterDLCInRelease = true" in surface_policy:
        failures.append("ProductSurfacePolicy must hide unfinished Character DLC in release")
    for phrase in ["DLC 해금", "Pro 결제", "스토어"]:
        if phrase in settings:
            failures.append(f"SettingsView must not expose unfinished commerce phrase: {phrase}")

    if "CharacterStoreSkeletonView.swift" in inventory and "plannedHidden" not in inventory:
        failures.append("Character store skeleton must be tracked as plannedHidden")

    if "private let quickToolIDs" in home:
        failures.append("HomeDashboardView must use ProductSurfacePolicy instead of a direct quickToolIDs array")
    if "ProductSurfacePolicy.shouldShowInHomePrimary" not in home:
        failures.append("HomeDashboardView primary surface must be driven by ProductSurfacePolicy")
    if "ProductSurfacePolicy.shouldShowInConnectionSection" not in home:
        failures.append("HomeDashboardView connection surface must be driven by ProductSurfacePolicy")

    for forbidden in [
        "workerProductionHealthPassed",
        "googleLiveQAPassed",
        "financeLiveQAPassed",
        "dartLiveQAPassed",
        "kmaLiveQAPassed",
        "newsLiveQAPassed",
        "lawLiveQAPassed",
    ]:
        if forbidden in surface_policy:
            failures.append(f"ProductSurfacePolicy must use ReleaseCapabilityManifest, not hardcoded boolean: {forbidden}")
    if re.search(r"default:\s*return\s+true", surface_policy):
        failures.append("ReleaseLiveProviderGate must not default unknown capabilities to enabled")

    release_manifest = read("MyTeam/ReleaseCapabilityManifest.swift")
    manifest_template = read("MyTeam/Resources/ReleaseCapabilityManifest.template.json")
    if "ReleaseCapabilityManifest.generated" not in release_manifest:
        failures.append("ReleaseCapabilityManifestStore must load generated RC evidence, not template evidence")
    if "ReleaseCapabilityManifest.template" not in release_manifest:
        failures.append("ReleaseCapabilityManifestStore must keep template and generated evidence separate")
    if '"production_health": "DISABLED"' not in manifest_template:
        failures.append("ReleaseCapabilityManifest template must keep Worker fail-closed")
    for provider in ["google", "finance", "dart", "kma", "news", "law"]:
        if f'"{provider}": "DISABLED"' not in manifest_template:
            failures.append(f"ReleaseCapabilityManifest template must keep provider fail-closed: {provider}")

    for required in [
        "enum ProductSurfaceTier",
        "enum ReleaseLiveProviderGate",
        "ReleaseCapabilityManifestStore.status",
        "workerIsRuntimeCompatible",
        "isKnownLocalSafeCapability",
        "static func isEnabledInCurrentReleaseSurface",
        "case primary",
        "case secondary",
        "case naturalOnly",
        "case connectionOnly",
        "case developerOnly",
        "case hidden",
        "static func tier(for descriptor: MyTeamToolDescriptor)",
        "static func shouldShowInHomePrimary",
        "static func shouldShowInHomeSecondary",
        "static func shouldShowInConnectionSection",
    ]:
        if required not in surface_policy:
            failures.append(f"ProductSurfacePolicy missing required product surface contract: {required}")

    if "guard isEnabledInCurrentReleaseSurface(descriptor) else" not in surface_policy:
        failures.append("ProductSurfacePolicy must fail closed before assigning release-visible tiers")

    required_surface_mappings = {
        '"spreadsheet.postprocess"': ".hidden",
        '"spreadsheet.googleSheets.read"': ".hidden",
        '"spreadsheet.merge"': ".hidden",
        '"dart.disclosures.search"': ".naturalOnly",
        '"weather.current"': ".naturalOnly",
        '"calendar.events.today"': ".naturalOnly",
        '"finance.company.statement"': ".naturalOnly",
        '"voice.supertonic.preview"': ".developerOnly",
        '"voice.bubbleSpeech.preview"': ".developerOnly",
    }
    for tool_id, expected_tier in required_surface_mappings.items():
        index = surface_policy.find(tool_id)
        if index == -1:
            failures.append(f"ProductSurfacePolicy missing tier mapping for {tool_id}")
            continue
        window = surface_policy[index:index + 240]
        if expected_tier not in window:
            failures.append(f"ProductSurfacePolicy must map {tool_id} to {expected_tier}")

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
    if 'toolID: "spreadsheet.postprocess"' in natural:
        failures.append("NaturalWorkRouting must not route hidden spreadsheet.postprocess")
    if "FinancePeriodResolver.query" not in natural:
        failures.append("NaturalWorkRouting must use FinancePeriodResolver for company finance period hints")
    if "runLatestAvailableCompanyStatement" not in finance_runner:
        failures.append("FinanceToolRunner must resolve latest available finance periods internally")
    for phrase in ["기준 기간", "자동 선택", "조회 가능한 최신 기준 기간"]:
        if phrase not in finance_formatter:
            failures.append(f"Finance formatter must disclose inferred finance period: {phrase}")
    for token in ["Sheet1!A1:Z100", "defaultRange"]:
        if token in google_support or token in google_sheets_runner:
            failures.append(f"Google Sheets read must not use implicit default range: {token}")
    finance_statement_index = natural.find('toolID: "finance.company.statement"')
    if finance_statement_index != -1:
        finance_window = natural[max(0, finance_statement_index - 900):finance_statement_index + 900]
        for token in ["Calendar.current.component", "currentYear", "fallbackInputs: fallbacks"]:
            if token in finance_window:
                failures.append(f"NaturalWorkRouting must not seed finance.company.statement from current year: {token}")

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
