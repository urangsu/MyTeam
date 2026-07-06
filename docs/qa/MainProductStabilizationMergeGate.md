# Main Product Stabilization Launch Readiness Gate

## 1. Branch Summary

- Branch policy: `main` is the integration branch. `release/*` is the strict Release Candidate gate.
- Current HEAD reviewed: `837276699a11268112a09c78bc1bb60bb954c781`.
- Current evidence timestamp: `2026-07-06 00:08:59 KST`.
- Purpose: prove stabilization work before any Release Candidate or release tag decision.
- Current gate status: BLOCKED for Release Candidate until manual QA documents move required runtime cases from BLOCKED to PASS.

## 2. Included P0 Items

- Natural work common routing
- Pending clarification
- Agentic planning entrypoint
- LegacyWorkflowFallbackRouter sharing
- ToolExecutionOptions composite artifact suppression
- ToolExecutionDispatcher
- ToolResultFormatters
- News / Weather / Law runners
- Finance / DART runners
- Google Calendar / Sheets runners
- ProductSurfacePolicy
- ProductCompletenessInventory
- Product value pruning
- AppTerminationCoordinator
- Worker health userRoutes/diagnosticContract

## 3. Excluded Items

- New public API routes
- DART Cloudflare product route
- Spreadsheet actual file editing
- Google Sheets write
- Calendar write
- Character commerce
- Release tag

## 4. Static Validators

| Case ID | Scenario | Input / Action | Expected result | Forbidden result | Actual result | PASS / FAIL / BLOCKED | Evidence | Notes |
|---|---|---|---|---|---|---|---|---|
| MG-STATIC-001 | Static validator suite | Run release/static validators listed in this gate | Validators pass before merge review | Ignoring failing validator | Static validators passed in this pass | PASS | `git diff --check`; `node --check`; `validate_release_qa_evidence.py`; app termination, natural work, product completeness, architecture, release, checklist, skill package, precommit, character dialogue validators | Manual QA remains separate. |
| MG-BUILD-001 | Debug build | `xcodebuild ... Debug ... build` | Build succeeds | Debug-only failures ignored | Debug build passed for current working tree | PASS | 2026-07-06 local run ended with `** BUILD SUCCEEDED **` | Release build also required. |
| MG-BUILD-002 | Release build | `xcodebuild ... Release ... build` | Build succeeds | Release build failure ignored | Release build passed for current working tree | PASS | 2026-07-06 local run ended with `** BUILD SUCCEEDED **` | Manual QA remains separate. |

## 5. Build Results

- Debug: PASS. Evidence: 2026-07-06 local `xcodebuild ... Debug ... build` ended with `** BUILD SUCCEEDED **`.
- Release: PASS. Evidence: 2026-07-06 local `xcodebuild ... Release ... build` ended with `** BUILD SUCCEEDED **`.

## 6. Manual QA Results

- AppTermination: BLOCKED. See `docs/qa/AppTerminationManualQA.md`.
- Natural Work E2E: BLOCKED. See `docs/qa/NaturalWorkE2EManualQA.md`.
- Artifact reopen: BLOCKED. See `docs/qa/ArtifactReopenManualQA.md`.
- Home/Product Surface: BLOCKED. See `docs/qa/HomeSurfaceManualQA.md`.

## 7. Live Provider QA Results

- Google Calendar: DISABLED in Release until OAuth live QA passes.
- Google Sheets: DISABLED in Release until OAuth live QA passes.
- Finance: DISABLED in Release until Worker health and finance live QA pass.
- DART: DISABLED in Release until direct BYOK live QA passes.
- KMA: DISABLED in Release until Worker health and KMA live QA pass.
- News: DISABLED in Release until Worker health and news live QA pass.
- Law: DISABLED in Release until Worker health and law live QA pass.
- Worker production health: DISABLED for Release because public lookup surfaces are disabled. Live check currently fails until production Worker is redeployed from repository source.

Details are in `docs/qa/LiveProviderQAMatrix.md`.

## 7.1 Gate Commands

- Integration branch gate: static validators and Debug/Release builds.
- Release Candidate gate: `python3 scripts/validate_release_qa_evidence.py --strict`
- Release Candidate alias: `python3 scripts/validate_launch_readiness.py --release-candidate`
- Release tag gate: `python3 scripts/validate_release_qa_evidence.py --release-strict`
- Release tag also requires Worker production `/health` live confirmation.

## 8. Worker Deploy Status

- Source validation can pass independently.
- Production deploy is not asserted by source validation.
- Live check on `https://late-waterfall-c95c.urange.workers.dev/health` returned version `0.3.0` and build `public-lookup-0.3.0`, but did not expose the current `userRoutes` / `diagnosticContract` contract.
- Public lookup release surfaces remain disabled until the repository Worker source is redeployed and `python3 scripts/validate_worker_production_health.py` passes.

## 9. App Termination Status

- Static architecture exists and is validator-backed.
- Manual process-level quit QA remains BLOCKED.

## 10. Known Risks

- Manual app termination behavior has not been proven in this QA pass.
- Natural-work runtime behavior in personal chat/team workroom has not been proven in this QA pass.
- Artifact reopen has not been manually proven in this QA pass.
- Live provider states and OAuth failure modes have not been proven in this QA pass, so Release surfaces are fail-closed.

## 11. Release Candidate Decision

Current decision: BLOCKED.

Release Candidate is not allowed until:

- Static validators PASS.
- Debug and Release builds PASS.
- APPTERM-001 through APPTERM-006 PASS.
- NW-001 through NW-013 PASS.
- ART-001 through ART-004 PASS.
- HOME-001 through HOME-006 PASS.
- Live provider QA is either PASS or the relevant Release surface is DISABLED.

## 12. Release Tag Decision

Release tag decision: BLOCKED.

Release tag is not allowed while Release Candidate manual QA remains BLOCKED. Live provider release-strict cases are allowed only when `PASS` or `DISABLED`; enabling any live provider requires Worker production live gate and provider live QA closure first.
