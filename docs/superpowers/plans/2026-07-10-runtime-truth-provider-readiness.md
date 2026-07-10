# MyTeam Runtime Truth and Provider Readiness Plan

## Decision Summary

This plan is based on the current `main` source, not the older external audit snapshot.

Accepted findings:

- `ChainOrchestrator` projected work from evidence but marked unexecuted steps as succeeded and fabricated 0.02 second durations.
- DART company resolution only supports a single seeded company plus direct eight-digit corp codes.
- LLM key validation proves list access, not selected-model generation capability.
- Release model discovery can promote an endpoint-incompatible or access-restricted model from `/models`.
- Provider fallback can change the data processor and cost path without an explicit user-facing policy.
- Natural work and AI service files are too broad, but must be split only after behavior contracts exist.

Rejected or corrected findings:

- Worker timeout, diagnostic authentication, request limiting, and deploy metadata are already implemented. Do not rewrite them as missing.
- Current Release provider gates are manifest-backed and fail-closed; they are no longer hardcoded QA booleans.
- GPT-5.6 exists only as a limited partner preview as of 2026-07-10. Do not make it a general Release default.
- Do not perform a broad NaturalWorkRouting rewrite before runtime and fixture contracts protect current behavior.

## P0 Order

1. Runtime projection truth
   - Rename active usage to `ChainEvidenceProjector`.
   - Add `evidenceAvailable`, `planned`, and `projected` states.
   - Remove fabricated step durations.
   - Keep `succeeded` only for work actually completed by local code or a runner.

2. Release model selection safety
   - Disable dynamic provider model promotion in Release.
   - Keep discovery in Debug for diagnostics.
   - Promote a model into the registry only after endpoint, streaming, permission, and minimal-generation contract tests pass.

3. LLM connection capability state
   - Separate `stored`, `authenticated`, `selectedModelSmokePassed`, and `ready`.
   - Run a minimal generation call against the exact selected model and production endpoint.
   - Do not display ready when only `/models` succeeds.

4. DART company master
   - Download and parse official `corpCode.xml` using the user's DART key.
   - Build an atomic local index for company name, stock code, and corp code.
   - Record source timestamp and refresh policy.
   - Keep the current seed only as a temporary bootstrap fallback until live master QA passes.

5. Provider fallback truth
   - Preserve the preferred provider after its first token.
   - Before the first token, allow fallback only under an explicit user policy.
   - Surface the actual provider/model in an unobtrusive result detail, without exposing prompts or credentials.

6. Worker quota durability
   - Keep current timeout, diagnostic token, response-size guard, and deploy metadata.
   - Add Cache API TTL by route and a durable rate-limit backend before enabling public Release routes.
   - Treat isolate-local maps as load-shedding only, not a security quota boundary.

## P1 Order

1. KMA nationwide location resolution and official base-time tests.
2. GitHub Actions for static validators, Worker syntax/contract tests, and Debug/Release builds where signing permits.
3. Responsibility split for `NaturalWorkRouting.swift` and `AIService.swift`, one behavior-preserving extraction at a time.
4. Deployment target review based on actual API usage and App Store product strategy.
5. Google Calendar/Sheets live OAuth read-only QA and recovery action verification.

## Release Conditions

- Static/build success does not imply launch readiness.
- External providers remain Release-disabled until generated RC manifest evidence exists.
- GPT-5.6 remains opt-in only for accounts with confirmed preview access and a passing Responses API smoke.
- APPTERM/NW/ART/HOME manual evidence and live provider evidence remain separate release gates.
