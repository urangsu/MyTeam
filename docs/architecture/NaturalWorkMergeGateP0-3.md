# Natural Work Merge Gate P0-3

## Scope

This gate verifies the current `codex/main-product-stabilization-p0` natural work path before main merge. It is a code and validator gate, not a new feature pass.

## Personal Chat Call Chain

`AgentChatView.sendMessageAsync` uses the shared natural work path before legacy fast path:

1. `NaturalWorkContextProvider.snapshot(roomID:manager:pendingAttachments:)`
2. `PendingNaturalWorkCoordinator.resolve(userMessage:roomID:manager:)`
3. `NaturalWorkEntryPoint.resolve(text:context:chatHistory:)`
4. `NaturalWorkPlanRunner.run(_:originalText:roomID:manager:path:)`
5. `NaturalWorkPlanExecutor.execute(_:path:options:)`
6. `ToolExecutionRouter.run(... options: .composite(parentWorkID:))`
7. `CompositeArtifactRecorder.write(result:originalText:roomID:manager:)`
8. `ChatResponseSink.updateOrAppend(...)`

If `NaturalWorkEntryPoint` returns `.plan`, the method returns after `NaturalWorkPlanRunner.run`, so legacy fast path does not run. Legacy fast path only runs when natural routing returns `.fallback`.

## Team Workroom Call Chain

`WorkflowOrchestrator.handleToolFastPath` delegates to `WorkflowInputCoordinator.shared.handle(...)`.

`WorkflowInputCoordinator.handle` then sequences:

1. `NaturalWorkContextProvider.snapshot(roomID:manager:)`
2. `PendingNaturalWorkCoordinator.resolve(userMessage:roomID:manager:)`
3. `NaturalWorkEntryPoint.resolve(text:context:chatHistory:)`
4. `NaturalWorkPlanRunner.run(_:originalText:roomID:manager:)`
5. `LegacyWorkflowFallbackRouter.shared.handle(...)` only after natural routing fallback

`WorkflowInputCoordinator` does not directly create natural work chat messages, write composite artifacts, access `PendingNaturalWorkRequestStore.shared`, construct `NaturalWorkContext`, or call `NaturalWorkRouter.route` / `AgenticToolOrchestrator.plan`.

## Agentic Tool Orchestrator

`AgenticToolOrchestrator.plan` is an actual LLM planning path when a provider is available.

- Provider selection: `agentConfig?.llmProvider`, then `UserDefaults.defaultLLMProvider`, then `.gemini`.
- Provider availability: `AIService.shared.providerCandidates(preferred:requiresToolUse: true)`.
- Manifest: `ToolSemanticManifestCatalog.manifests()` builds LLM-facing manifests from implemented, user-facing tool descriptors.
- Planner prompt: `ToolPlanningPromptBuilder.build(...)`.
- Provider call: `AIService.shared.getResponse(... requiresToolUse: true, toolDescriptorCount: manifests.count, selectedAgentCount: 1)`.
- JSON validation: `decodePlannerResponse` decodes `AgenticPlannerResponse` or direct `AgenticWorkPlan`.
- Plan validation: `ToolPlanValidator.validate(...)`.
- Invalid tool IDs: rejected because planned `toolID` must exist in manifest IDs and `MyTeamToolRegistry`.
- Missing credentials and unavailable steps: converted into missing sections or validated failure states, not fake success.
- Fallback: deterministic `NaturalWorkRouter.plan` is returned when planning is unavailable, invalid, or failed.

## Artifact Contract

Composite natural work uses `ToolExecutionOptions.composite(parentWorkID:)`.

- `persistIndividualArtifact == false`
- `executionMode == .compositeWork`
- Individual tool artifacts are suppressed during composite execution.
- `CompositeArtifactRecorder.write` resolves room workflow ID and calls `CompositeWorkArtifactWriter.write(... roomID:workflowID:)`.
- `CompositeWorkArtifactWriter` writes one markdown artifact and registers it in `RecentArtifactIndex` for the room.
- Partial failures are preserved in `NaturalWorkResult.artifactMarkdown` under missing or unconfirmed sections.

## Merge Gate Status

Code-level gate passes when:

- `scripts/validate_architecture_boundaries.py` passes P0 checks.
- `scripts/validate_natural_work_routing.py` passes routing checks.
- Existing release validators pass.
- Debug and Release builds pass.

Manual UI QA remains separate and should verify:

- Personal chat: `삼성전자 알려줘`
- Team workroom: `삼성전자 주가랑 공시랑 재무상황 알려줘`
- Team workroom clarification: `회의록 만들어줘`
- Team workroom clarification: `이 회사 재무상황 알려줘`

