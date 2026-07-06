# Full Product Defect Audit

Last updated: 2026-07-06 23:36 KST
Audited branch: main
Audited commit: aba56558d700f7170c8b6bd7fb2c11459b17bfed
Audited build: not run for this audit inventory pass

## Summary

| Severity | Count | Meaning |
| --- | ---: | --- |
| P0-blocker | 5 | Blocks RC or risks fake success/user trust |
| P0-qa-blocked | 12 | Needs runtime/manual proof |
| P1-product-gap | 4 | Partial feature or incomplete user value |
| P1-live-disabled | 1 | Intentionally hidden/disabled until provider QA |
| P2-polish | 0 | Quality improvement after RC |

## Inventory

| ID | Severity | Area | Symptom / Risk | Evidence | Current Status | Required Fix or QA | Owner Action | Verification |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| APPTERM-MANUAL-001 | P0-qa-blocked | App termination | APPTERM-001~006 are still BLOCKED. Process-level quit is not proven. | `docs/qa/AppTerminationManualQA.md` | BLOCKED | Run Cmd+Q, menu quit, AppleScript quit, TTS quit, tool quit, artifact detail quit in Debug and Release. | Manual QA | `python3 scripts/validate_release_qa_evidence.py --strict` |
| NW-MANUAL-001 | P0-qa-blocked | Natural work routing | NW-001~013 are still BLOCKED. One-bubble composite routing is not proven in runtime. | `docs/qa/NaturalWorkE2EManualQA.md` | BLOCKED | Run all personal chat and team workroom scenarios. | Manual QA | Runtime screenshots/logs plus strict validator |
| ART-MANUAL-001 | P0-qa-blocked | Artifact reopen | ART-001~004 are still BLOCKED. Internal artifact detail reopen is not proven. | `docs/qa/ArtifactReopenManualQA.md` | BLOCKED | Generate composite artifact, reopen recent artifact, test artifactID-only and long body. | Manual QA | Runtime screenshots/logs plus strict validator |
| HOME-MANUAL-001 | P0-qa-blocked | Home/Settings surface | HOME-001~004 and HOME-006 are still BLOCKED. Product surface is not manually proven. | `docs/qa/HomeSurfaceManualQA.md` | BLOCKED | Inspect Home, Settings, DLC/Pro, developer diagnostics, Settings layering, team panel. | Manual QA | Runtime screenshots plus strict validator |
| WORKER-PROD-001 | P0-blocker | Cloudflare Worker | Production `/health` returns `routes` only; missing `userRoutes` and `diagnosticRoutes`. | `python3 scripts/validate_worker_production_health.py` | FAIL | Redeploy repository Worker source to Cloudflare production. | Cloudflare deploy | `python3 scripts/validate_worker_production_health.py` |
| WORKER-DIAG-001 | P0-blocker | Cloudflare Worker | DART diagnostic routes were listed separately but still publicly callable without diagnostic auth. | `workers/basic-lookup-api/worker.js` | PARTIAL | Require diagnostic token for `/dart/*`, redeploy Worker, verify unauthenticated `/dart/*` returns 401/403/404. | Code + Cloudflare deploy | `node --check workers/basic-lookup-api/worker.js`; `python3 scripts/validate_worker_production_health.py` |
| LIVE-PROVIDER-001 | P1-live-disabled | Public lookup providers | FIN/DART/KMA/NEWS/LAW/GOOGLE are disabled or unproven. | `docs/qa/LiveProviderQAMatrix.md` | DISABLED | Keep disabled or run live provider QA before enabling. | Provider QA | `python3 scripts/validate_release_qa_evidence.py --release-strict` plus provider screenshots/logs |
| RELEASE-MANIFEST-001 | P0-blocker | Release capability gate | Hardcoded live QA booleans create a QA cycle: QA passes on one commit, then code changes to enable providers. | `MyTeam/ProductSurfacePolicy.swift` | OPEN | Introduce release capability manifest or equivalent build input tied to tested commit/build. | Architecture fix | Manifest validator plus release branch QA |
| QA-METADATA-001 | P0-qa-blocked | QA evidence | Manual QA docs reference stale `tested_commit` / build metadata. | `docs/qa/*ManualQA.md` | STALE | Refresh only after actual runtime QA on current HEAD/build. | QA doc update | `python3 scripts/validate_release_qa_evidence.py --strict` |
| QA-EVIDENCE-002 | P0-blocker | QA evidence | Markdown PASS values alone are not durable proof; evidence path/hash/build identity can be forged or omitted. | `scripts/validate_release_qa_evidence.py` | PARTIAL | Require current HEAD/build metadata and durable evidence path or command in strict manual QA. | Validator hardening | `python3 scripts/validate_release_qa_evidence.py --strict` |
| HOME-PROFILE-001 | P0-qa-blocked | Home/Settings surface | HOME expectations were not profile-specific; Release fail-closed provider hiding can conflict with Developer-visible surfaces. | `docs/qa/HomeSurfaceManualQA.md` | OPEN | Split HOME expected results by Developer, Release Candidate, and App Store profiles. | QA doc update | Profile-specific screenshots and strict validator |
| APPTERM-AUDIO-001 | P0-qa-blocked | App termination | APPTERM-004 requires active audio playback, but Release surface may not expose a user path to create it. | `docs/qa/AppTerminationManualQA.md` | OPEN | Add a release-equivalent internal audio QA harness or explicit capability-aware N/A rule. | QA harness decision | Audio termination log plus APPTERM-004 evidence |
| NW-CONC-001 | P0-qa-blocked | Workflow concurrency | Room-scoped workflow state and global workflow state can race when multiple rooms run or finish workflows concurrently. | `MyTeam/WorkflowOrchestrator.swift` | OPEN | Add concurrent room/workflow QA: two rooms, room switching, cancellation, personal + team execution, artifact completion. | Runtime QA / fix if reproduced | New NW-CONC evidence rows |
| STATE-MIG-001 | P0-qa-blocked | Persistence migration | `checkedEmpty` / `partial` execution states require backward-compatible decode and old artifact/log reopen checks. | `MyTeam/ToolExecutionState.swift`; `MyTeam/ToolExecutionLog.swift` | OPEN | Add old succeeded-empty fixture decode, unknown state fallback, old artifact index recovery tests. | Migration QA | Fixture tests plus artifact reopen QA |
| REL-RUNTIME-001 | P0-blocker | Release runtime gate | Hiding a feature from Home does not prove natural routing, saved actions, or direct dispatch cannot execute disabled providers. | `ProductSurfacePolicy`; natural work entrypoint | OPEN | Re-evaluate ReleaseLiveProviderGate at dispatcher/runtime execution boundaries, not only UI surface. | Runtime gate audit | Release-profile natural/direct action smoke |
| SETTINGS-RUNTIME-001 | P0-qa-blocked | Settings/windowing | Recent Settings/team panel fixes are build-verified but need manual repeat QA. | commits `dac334d`, `c4b8869`, `67d3c76` | PARTIAL | Open Settings from Cmd+, menu, status item; test minimized, behind panels, new panels while Settings open. | Manual QA | Screenshot/video and HOME-004 PASS |
| TEAM-PANEL-001 | P0-qa-blocked | Team status panel | Recent clipping/drag fixes are build-verified but need manual repeat QA across display positions. | commits `c4b8869`, `67d3c76` | PARTIAL | Test onboarding, team list, workroom tab, bottom controls, drag/tuck behavior. | Manual QA | Screenshot/video and HOME-004 PASS |
| TTS-MANUAL-001 | P0-qa-blocked | Supertonic3/BubbleSpeech | Voice path is protected but live audio QA is not fully recorded for RC. | `docs/qa/ProductCompletenessInventory.md` | liveButNeedsManualQA | Run preview/playback/failure cases; verify no Apple TTS fallback and no BubbleSpeech passthrough success. | Audio QA | Runtime log + audio QA notes |
| OFFICE-PARTIAL-001 | P1-product-gap | File/office review | File/office features are partialTextOnly; not real Excel/PDF deep analysis. | `docs/qa/ProductCompletenessInventory.md` | PARTIAL | Keep copy modest or implement real parsing/evidence links. | Product decision | Home/manual QA plus fixture docs |
| ART-INTEGRITY-001 | P1-product-gap | Artifact storage | Artifact QA covers reopen but not atomic write, missing file recovery, stale index rebuild, hash mismatch, or concurrent save. | `docs/qa/ArtifactReopenManualQA.md` | OPEN | Add ART-005~009 integrity cases before treating artifacts as durable product memory. | QA expansion | Artifact corruption/recovery fixtures |
| UPGRADE-001 | P1-product-gap | Install/upgrade | Clean install and upgrade paths are not covered: old defaults, panel positions, credentials, artifact indexes, old execution states. | QA docs | OPEN | Add clean install and upgrade QA matrix. | QA expansion | UPG-001~006 evidence |
| CREDENTIAL-LIFECYCLE-001 | P1-product-gap | Credentials | Key replacement, deletion, Keychain failure, offline, revoked key, and stale connected state are not fully covered. | `docs/qa/LiveProviderQAMatrix.md` | OPEN | Add credential lifecycle cases per provider before enabling Release surfaces. | QA expansion | Credential lifecycle evidence |

## Rules

- Do not mark any manual QA row PASS without evidence from the current tested commit and build.
- Do not treat `DISABLED` live providers as product-value PASS.
- Do not call `main` release-ready. Release readiness belongs to a release branch after strict/manual/live gates pass.
