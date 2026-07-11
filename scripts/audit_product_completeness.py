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

    for swift_file in (ROOT / "MyTeam").rglob("*.swift"):
        if "fatalError(" in swift_file.read_text(encoding="utf-8"):
            failures.append(f"Product runtime must not contain fatalError: {swift_file.relative_to(ROOT)}")

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
    kma_region_mapper = read("MyTeam/KMARegionGridMapper.swift")
    kma_base_policy = read("MyTeam/KMABaseTimePolicy.swift")
    public_api_connector = read("MyTeam/PublicAPIConnectorValidator.swift")
    worker = read("workers/basic-lookup-api/worker.js")
    quality_workflow = read(".github/workflows/quality-gate.yml")
    ai_model_policy = read("MyTeam/AIModelPolicy.swift")
    ai_service = read("MyTeam/AIService.swift")
    openai_responses = read("MyTeam/OpenAIResponsesAdapter.swift")
    xcode_project = read("MyTeam/MyTeam.xcodeproj/project.pbxproj")
    credential_health = read("MyTeam/CredentialHealth.swift")
    credential_store = read("MyTeam/SecureCredentialStore.swift")
    dart_resolver = read("MyTeam/DARTCompanyResolver.swift")
    dart_runner = read("MyTeam/ToolRunners/DARTToolRunner.swift")
    myteam_app = read("MyTeam/MyTeamApp.swift")
    agent_window_manager = read("MyTeam/AgentWindowManager.swift")
    floating_panel = read("MyTeam/FloatingPanel.swift")
    character_gallery = read("MyTeam/CharacterGalleryView.swift")
    character_entitlement = read("MyTeam/CharacterEntitlementManager.swift")
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

    for token in [
        "enum LLMReadinessStage",
        "case smokeTesting",
        "case ready",
        "struct LLMReadinessEvidence",
        "actor LLMReadinessCache",
    ]:
        if token not in credential_health:
            failures.append(f"LLM readiness must preserve exact model smoke evidence: {token}")
    validate_key_match = re.search(
        r"func validateKey\((?P<body>.*?)\n    \}",
        ai_service,
        re.S,
    )
    if not validate_key_match:
        failures.append("AIService must expose selected-model credential validation")
    else:
        validate_key_body = validate_key_match.group("body")
        if "/v1/models" in validate_key_body:
            failures.append("AI key validation must not treat /v1/models as readiness")
        if "providerCandidates" in validate_key_body:
            failures.append("AI readiness smoke must never use provider fallback candidates")
        for token in ["readinessRequest", "readinessOutput", "LLMReadinessCache.shared"]:
            if token not in validate_key_body:
                failures.append(f"AI readiness smoke is missing required contract: {token}")
    if "llmReadiness: evidence" not in credential_store:
        failures.append("SecureCredentialStore must preserve exact model readiness evidence")
    for token in [
        "enum LLMFallbackPolicy",
        "case disabled",
        "case sameProviderOnly",
        "case crossProviderAllowed",
        "return .disabled",
    ]:
        if token not in ai_service:
            failures.append(f"LLM fallback must be explicit and default off: {token}")
    provider_candidates_match = re.search(
        r"func providerCandidates\((?P<body>.*?)\n    \}",
        ai_service,
        re.S,
    )
    if not provider_candidates_match:
        failures.append("AIService must expose auditable provider fallback candidates")
    else:
        candidate_body = provider_candidates_match.group("body")
        if "fallbackPolicy == .disabled" not in candidate_body:
            failures.append("AIService provider routing must stop at the preferred provider by default")
        if "validatedFallbackEvidence" not in candidate_body:
            failures.append("Cross-provider fallback must require fresh selected-model smoke evidence")
    fallback_stream_match = re.search(
        r"private func fallbackProviderStream\((?P<body>.*?)\n    \}",
        ai_service,
        re.S,
    )
    if not fallback_stream_match or "crossProviderAllowed" not in fallback_stream_match.group("body"):
        failures.append("Gemini cooldown fallback must require explicit cross-provider permission")
    elif "validatedFallbackCall" not in fallback_stream_match.group("body"):
        failures.append("Gemini cooldown fallback must pin the model that passed smoke validation")
    if 'modelId: "openrouter/auto"' in ai_service:
        failures.append("OpenRouter auto model must not be used as a hidden fallback")
    if "404 → 모델 재발견 재시도" in ai_service:
        failures.append("Model 404 must not silently rediscover and retry another model")
    for required in [
        "OpenAIResponsesAdapter.swift",
        "OpenAIResponsesAdapter.supports",
        "OpenAIResponsesAdapter.makeRequest",
        "OpenAIResponsesAdapter.parseEvent",
        "OpenAIResponsesAdapter.outputText",
    ]:
        source = xcode_project if required == "OpenAIResponsesAdapter.swift" else ai_service
        if required not in source:
            failures.append(f"GPT-5.6 runtime must use the Responses adapter contract: {required}")
    for required in [
        '"https://api.openai.com/v1/responses"',
        '"store": false',
        '"max_output_tokens"',
        '"reasoning"',
        '"safety_identifier"',
        'case "response.output_text.delta"',
        'case "response.completed"',
        'case "response.incomplete"',
        'case "response.failed"',
    ]:
        if required not in openai_responses:
            failures.append(f"OpenAI Responses adapter missing required contract: {required}")
    if '"previous_response_id"' in openai_responses:
        failures.append("OpenAI Responses runtime must remain stateless until conversation storage is explicitly approved")
    if "configuredModelID(for: provider" not in ai_service or "model: resolvedCall.modelID" not in ai_service:
        failures.append("LLM runtime must resolve and log the exact configured model before execution")
    if ai_service.count("if !fullText.isEmpty { throw error }") < 2:
        failures.append("Non-streaming LLM paths must not change provider after partial output")
    if "defaultRegion" in kma_region_mapper:
        failures.append("KMA region resolution must not default missing input to Seoul")
    if "서울 기본 격자" in chain_runtime or "private static func weatherGrid" in chain_runtime:
        failures.append("KSkill weather evidence must use the shared region resolver without a Seoul fallback")
    for required in [
        "case ultraShortNowcast",
        "case ultraShortForecast",
        "case villageForecast",
        'TimeZone(identifier: "Asia/Seoul")',
        "villageHours = [2, 5, 8, 11, 14, 17, 20, 23]",
    ]:
        if required not in kma_base_policy:
            failures.append(f"KMA base-time policy missing official product schedule contract: {required}")
    if "KMABaseTimePolicy.candidates" not in public_api_connector or "limit: 2" not in public_api_connector:
        failures.append("KMA direct lookup must use official base slots with a limited previous-slot retry")
    for forbidden in ["minutes % 30", "now.getMinutes() - 45", "now.getMinutes() - 40"]:
        if forbidden in worker:
            failures.append(f"Worker KMA schedule must not use generic half-hour rounding: {forbidden}")
    for required in ["export function kmaBaseCandidates", "attemptedBaseSlots", 'resultCode === "03"']:
        if required not in worker:
            failures.append(f"Worker KMA lookup missing schedule/retry evidence: {required}")
    for required in [
        "ubuntu-24.04",
        "macos-26",
        "/Applications/Xcode_26.2.app/Contents/Developer",
        "python3 scripts/validate_myteam_release.py",
        "python3 scripts/validate_architecture_boundaries.py",
        "python3 scripts/validate_natural_work_routing.py",
        "build-for-testing",
        "test-without-building",
        "-configuration Release",
    ]:
        if required not in quality_workflow:
            failures.append(f"GitHub quality gate missing required contract: {required}")
    if "secrets." in quality_workflow:
        failures.append("Pull-request quality gate must not load live provider secrets")
    for forbidden in ["private static let seeds", "case manualSeed", "resolution(seed:"]:
        if forbidden in dart_resolver:
            failures.append(f"DART resolver must not use a product seed fallback: {forbidden}")
    for required in [
        "corpCode.xml",
        "DARTCompanyIndexStore",
        "officialStockCodeIndex",
        "officialCompanyNameIndex",
        "isIndexStale",
        "corpCodesByNameGram",
        "Task.detached(priority: .utility)",
    ]:
        if required not in dart_resolver:
            failures.append(f"DART resolver is missing official cached-index behavior: {required}")
    if "try await DARTCompanyResolver.resolve" not in dart_runner:
        failures.append("DARTToolRunner must await the official company index resolver")
    dart_formatter_index = finance_formatter.find("enum DARTResultFormatter")
    if dart_formatter_index != -1:
        dart_formatter_window = finance_formatter[dart_formatter_index:dart_formatter_index + 1800]
        if "if items.isEmpty" in dart_formatter_window and ".checkedEmpty(" not in dart_formatter_window:
            failures.append("DART empty result must be checkedEmpty, not succeeded")
    no_results_index = finance_formatter.find("nonisolated static func noResultsState")
    if no_results_index != -1:
        no_results_window = finance_formatter[no_results_index:no_results_index + 800]
        if ".succeeded(" in no_results_window:
            failures.append("ToolResultFormatters.noResultsState must not return .succeeded")
        if ".checkedEmpty(" not in no_results_window:
            failures.append("ToolResultFormatters.noResultsState must return .checkedEmpty")

    if "DemoRoomSeeder" in settings or "SampleArtifactSeeder" in settings:
        failures.append("SettingsView must not expose demo seed controls until DemoMode seeding is productized")
    if (ROOT / "MyTeam/DemoMode.swift").exists():
        failures.append("Unused DemoMode sample-data stubs must not remain in the product target")

    if "showsCharacterDLCInRelease = true" in surface_policy:
        failures.append("ProductSurfacePolicy must hide unfinished Character DLC in release")
    if "ProductSurfacePolicy.dlcVisibilityInRelease()" not in character_gallery:
        failures.append("Character gallery must honor the Release DLC visibility policy")
    for forbidden in ["CharacterUnlockStateStore", "markUnlocked(characterID:"]:
        if forbidden in character_entitlement:
            failures.append(f"Character entitlement must not trust a local fake-unlock path: {forbidden}")
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
