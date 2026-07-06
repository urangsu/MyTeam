# Full Product Defect Audit Runbook

## 1. Static Evidence

Run from `/Users/su/Desktop/MyTeam`:

```bash
git status --short --branch
git diff --check
node --check workers/basic-lookup-api/worker.js
python3 scripts/validate_myteam_release.py
python3 scripts/validate_architecture_boundaries.py
python3 scripts/validate_natural_work_routing.py
python3 scripts/audit_product_completeness.py
python3 scripts/smoke_natural_work_e2e.py
python3 scripts/validate_app_termination_architecture.py
python3 scripts/validate_tool_recovery_actions.py
python3 scripts/validate_result_presentation.py
python3 scripts/validate_release_checklist.py
python3 scripts/validate_skill_packages.py
python3 scripts/precommit_safety_check.py
python3 scripts/report_character_dialogues.py --check-only
```

## 2. Build Evidence

Run Debug and Release sequentially:

```bash
xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Debug -destination 'platform=OS X,arch=arm64' build
xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Release -destination 'platform=OS X,arch=arm64' build
```

## 3. Expected Failing Gates Before Manual QA

```bash
python3 scripts/validate_release_qa_evidence.py --strict
```

Expected: FAIL until APPTERM/NW/ART/HOME manual rows are PASS.

```bash
python3 scripts/validate_worker_production_health.py
```

Expected: FAIL until Cloudflare production Worker exposes `userRoutes` and `diagnosticRoutes`.

## 4. Manual QA Order

1. HOME-004 Settings/windowing QA.
2. TEAM-PANEL-001 onboarding/team panel clipping and drag QA.
3. APPTERM-001~006 termination QA.
4. NW-001~013 natural work QA.
5. ART-001~004 artifact reopen QA.
6. HOME-001~006 product surface QA.
7. Worker production deploy and health QA.
8. Live provider QA only for providers intended to be enabled.

## 4.1 Additional P0 QA Tracks

### Worker Diagnostic Route Access

After deploying Worker source, run:

```bash
python3 scripts/validate_worker_production_health.py
```

Expected:

- `/health` exposes `userRoutes` and `diagnosticRoutes`.
- DART routes are absent from `userRoutes`.
- Unauthenticated `/dart/*` requests return `401`, `403`, or `404`.

### Release Runtime Gate

Release surface hiding is not sufficient. Verify these runtime cases:

- Disabled `news.search` through natural language does not perform a network request.
- Disabled finance action ID cannot execute through direct dispatcher paths.
- Disabled KMA workflow restored from pending state is blocked.
- Old saved starter actions re-evaluate `ReleaseLiveProviderGate` before execution.

### Workflow Concurrency

Run these as manual/runtime QA:

- NW-CONC-001: room A and room B run natural work at the same time.
- NW-CONC-002: switch rooms while room A workflow is running.
- NW-CONC-003: cancel one workflow while another is running.
- NW-CONC-004: personal chat and team workroom run simultaneously.
- NW-CONC-005: artifact completes after room switch.

Expected:

- Progress bubble and status remain room-scoped.
- Artifacts keep the correct room ID.
- Cancellation does not leak across rooms.
- `currentWorkflowID` does not clear an unrelated running workflow.

### App Termination Audio Harness

APPTERM-004 must be proven with actual audio playback. If Release surface cannot start user-visible playback, use a release-equivalent internal QA harness that exercises `AudioPlaybackService` and Supertonic3/BubbleSpeech playback without adding a public skeleton feature.

### State Migration

Before treating `checkedEmpty` and `partial` as safe persistence states, add fixture coverage for:

- old succeeded-empty execution log decode,
- new checkedEmpty save and reopen,
- unknown future state decode fallback,
- old artifact index recovery.

## 4.2 Additional P1 QA Tracks

- ART-005 atomic artifact write.
- ART-006 missing artifact file recovery.
- ART-007 stale artifact index rebuild.
- ART-008 content hash mismatch handling.
- ART-009 concurrent artifact save.
- UPG-001 clean install.
- UPG-002 previous version upgrade.
- UPG-003 old onboarding state.
- UPG-004 stale panel coordinates.
- UPG-005 old credential migration.
- UPG-006 old execution state decode.
- CRED-001 key replacement.
- CRED-002 key deletion.
- CRED-003 Keychain read failure.
- CRED-004 offline provider access.
- CRED-005 revoked key.
- CRED-006 stale connected state after app restart.

## 5. Evidence Rule

Do not mark PASS without one of:

- screenshot path,
- video path,
- command output,
- provider response sample,
- runtime log path,
- explicit build path.

## 6. Release Decision Rule

- `main` is an integration branch.
- Release Candidate readiness requires `python3 scripts/validate_release_qa_evidence.py --strict` to pass on the tested build.
- Release tag readiness also requires `python3 scripts/validate_release_qa_evidence.py --release-strict` and `python3 scripts/validate_worker_production_health.py`.
- `DISABLED` provider rows are safe fail-closed states, not proof that the feature is valuable to users.
- A provider should not be enabled by changing hardcoded QA booleans after QA on a different commit. The release capability decision must be tied to the tested commit/build, preferably through a manifest or equivalent release input.
