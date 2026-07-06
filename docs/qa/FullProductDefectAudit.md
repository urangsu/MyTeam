# Full Product Defect Audit

Last updated: 2026-07-06 23:20 KST
Audited branch: main
Audited commit: 67d3c76946370be839fe78c90226a18be6ca346b
Audited build: not run for this audit inventory pass

## Summary

| Severity | Count | Meaning |
| --- | ---: | --- |
| P0-blocker | 1 | Blocks RC or risks fake success/user trust |
| P0-qa-blocked | 8 | Needs runtime/manual proof |
| P1-product-gap | 1 | Partial feature or incomplete user value |
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
| LIVE-PROVIDER-001 | P1-live-disabled | Public lookup providers | FIN/DART/KMA/NEWS/LAW/GOOGLE are disabled or unproven. | `docs/qa/LiveProviderQAMatrix.md` | DISABLED | Keep disabled or run live provider QA before enabling. | Provider QA | `python3 scripts/validate_release_qa_evidence.py --release-strict` plus provider screenshots/logs |
| QA-METADATA-001 | P0-qa-blocked | QA evidence | Manual QA docs reference stale `tested_commit` / build metadata. | `docs/qa/*ManualQA.md` | STALE | Refresh only after actual runtime QA on current HEAD/build. | QA doc update | `python3 scripts/validate_release_qa_evidence.py --strict` |
| SETTINGS-RUNTIME-001 | P0-qa-blocked | Settings/windowing | Recent Settings/team panel fixes are build-verified but need manual repeat QA. | commits `dac334d`, `c4b8869`, `67d3c76` | PARTIAL | Open Settings from Cmd+, menu, status item; test minimized, behind panels, new panels while Settings open. | Manual QA | Screenshot/video and HOME-004 PASS |
| TEAM-PANEL-001 | P0-qa-blocked | Team status panel | Recent clipping/drag fixes are build-verified but need manual repeat QA across display positions. | commits `c4b8869`, `67d3c76` | PARTIAL | Test onboarding, team list, workroom tab, bottom controls, drag/tuck behavior. | Manual QA | Screenshot/video and HOME-004 PASS |
| TTS-MANUAL-001 | P0-qa-blocked | Supertonic3/BubbleSpeech | Voice path is protected but live audio QA is not fully recorded for RC. | `docs/qa/ProductCompletenessInventory.md` | liveButNeedsManualQA | Run preview/playback/failure cases; verify no Apple TTS fallback and no BubbleSpeech passthrough success. | Audio QA | Runtime log + audio QA notes |
| OFFICE-PARTIAL-001 | P1-product-gap | File/office review | File/office features are partialTextOnly; not real Excel/PDF deep analysis. | `docs/qa/ProductCompletenessInventory.md` | PARTIAL | Keep copy modest or implement real parsing/evidence links. | Product decision | Home/manual QA plus fixture docs |

## Rules

- Do not mark any manual QA row PASS without evidence from the current tested commit and build.
- Do not treat `DISABLED` live providers as product-value PASS.
- Do not call `main` release-ready. Release readiness belongs to a release branch after strict/manual/live gates pass.
