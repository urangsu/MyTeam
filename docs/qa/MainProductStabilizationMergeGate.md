# Main Product Stabilization Merge Gate

## 1. Branch Summary

- Branch: `codex/main-product-stabilization-p0`
- Purpose: prove stabilization work before any main merge decision.
- Current gate status: BLOCKED for main merge until manual QA documents move required runtime cases from BLOCKED to PASS.

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
- Worker health userRoutes/diagnosticRoutes

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
| MG-BUILD-001 | Debug build | `xcodebuild ... Debug ... build` | Build succeeds | Debug-only failures ignored | Debug build passed in this pass | PASS | `/tmp/myteam_qa_gate_debug.log`; output ended with `** BUILD SUCCEEDED **` | Release build also required. |
| MG-BUILD-002 | Release build | `xcodebuild ... Release ... build` | Build succeeds | Release build failure ignored | Release build passed in this pass | PASS | `/tmp/myteam_qa_gate_release.log`; output ended with `** BUILD SUCCEEDED **` | Manual QA remains separate. |

## 5. Build Results

- Debug: PASS. Evidence: `/tmp/myteam_qa_gate_debug.log`.
- Release: PASS. Evidence: `/tmp/myteam_qa_gate_release.log`.

## 6. Manual QA Results

- AppTermination: BLOCKED. See `docs/qa/AppTerminationManualQA.md`.
- Natural Work E2E: BLOCKED. See `docs/qa/NaturalWorkE2EManualQA.md`.
- Artifact reopen: BLOCKED. See `docs/qa/ArtifactReopenManualQA.md`.
- Home/Product Surface: BLOCKED. See `docs/qa/HomeSurfaceManualQA.md`.

## 7. Live Provider QA Results

- Google Calendar: BLOCKED.
- Google Sheets: BLOCKED.
- Finance: BLOCKED.
- DART: BLOCKED.
- KMA: BLOCKED.
- News: BLOCKED.
- Law: BLOCKED.
- Worker production health: BLOCKED.

Details are in `docs/qa/LiveProviderQAMatrix.md`.

## 7.1 Gate Commands

- Main merge gate: `python3 scripts/validate_release_qa_evidence.py --strict`
- Release tag gate: `python3 scripts/validate_release_qa_evidence.py --release-strict`
- Release tag also requires Worker production `/health` live confirmation.

## 8. Worker Deploy Status

- Source validation can pass independently.
- Production deploy is not asserted by this document.
- Worker live gate remains BLOCKED until `/health` is checked against the deployed endpoint.

## 9. App Termination Status

- Static architecture exists and is validator-backed.
- Manual process-level quit QA remains BLOCKED.

## 10. Known Risks

- Manual app termination behavior has not been proven in this QA pass.
- Natural-work runtime behavior in personal chat/team workroom has not been proven in this QA pass.
- Artifact reopen has not been manually proven in this QA pass.
- Live provider states and OAuth failure modes have not been proven in this QA pass.

## 11. Main Merge Decision

Current decision: BLOCKED.

Main merge is not recommended until:

- Static validators PASS.
- Debug and Release builds PASS.
- APPTERM-001 through APPTERM-006 PASS.
- NW-001 through NW-013 PASS.
- ART-001 through ART-004 PASS.
- HOME-001 through HOME-006 PASS.
- Live provider QA is either PASS or explicitly documented as non-release-blocking known risk.

## 12. Release Tag Decision

Release tag decision: BLOCKED.

Release tag is not allowed from this branch. Release tag requires post-merge validation plus Worker production live gate and provider live QA closure or release-surface disabling. `--release-strict` accepts only `PASS` or `DISABLED` for live provider and Worker release-surface cases.
