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
