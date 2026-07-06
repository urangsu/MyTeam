# MyTeam Launch Readiness Runbook

This runbook is the release-candidate gate for turning MyTeam into a general-user app. It does not replace manual QA evidence. Do not mark cases as PASS without running the scenario.

## 1. Static Gate

Run from `/Users/su/Desktop/MyTeam`:

```bash
git diff --check
node --check workers/basic-lookup-api/worker.js

python3 scripts/validate_myteam_release.py
python3 scripts/validate_architecture_boundaries.py
python3 scripts/validate_natural_work_routing.py
python3 scripts/audit_product_completeness.py
python3 scripts/smoke_natural_work_e2e.py
python3 scripts/validate_app_termination_architecture.py
python3 scripts/validate_tool_recovery_actions.py
python3 scripts/validate_launch_readiness.py
python3 scripts/validate_release_checklist.py
python3 scripts/validate_skill_packages.py
python3 scripts/precommit_safety_check.py
python3 scripts/report_character_dialogues.py --check-only
```

Then run both builds:

```bash
xcodebuild -project MyTeam/MyTeam.xcodeproj \
  -scheme MyTeam \
  -configuration Debug \
  -destination 'platform=OS X,arch=arm64' \
  build

xcodebuild -project MyTeam/MyTeam.xcodeproj \
  -scheme MyTeam \
  -configuration Release \
  -destination 'platform=OS X,arch=arm64' \
  build
```

## 2. Release Candidate Gate

Run:

```bash
python3 scripts/validate_launch_readiness.py --release-candidate
```

Required evidence:

- `docs/qa/AppTerminationManualQA.md`: APPTERM-001 through APPTERM-006 are PASS.
- `docs/qa/NaturalWorkE2EManualQA.md`: NW-001 through NW-013 are PASS.
- `docs/qa/ArtifactReopenManualQA.md`: ART-001 through ART-004 are PASS.
- `docs/qa/HomeSurfaceManualQA.md`: HOME-001 through HOME-006 are PASS.

Any BLOCKED row must keep its reason and next action. Any FAIL row requires a fix commit and retest.

`python3 scripts/validate_launch_readiness.py --main-merge` remains as a backward-compatible alias, but new release work should use `--release-candidate`.

## 2.1 Performance and Window QA Targets

Release Candidate manual QA must record whether these targets were met:

- Settings open to front: within 300ms after menu/Cmd+, no duplicate SwiftUI Settings window.
- Settings with team panel open: team member panel remains visible; chat/status/swap/agent-settings panels do not cover Settings.
- Settings already open, then new chat/status/swap panel: Settings remains front unless the team panel is explicitly opened.
- Team/personal chat input: progress bubble appears within 300ms.
- Natural work routing: first visible feedback appears within 300ms.
- Artifact detail open: normal artifact within 500ms; long artifact must not freeze UI.
- External lookup: progress state appears immediately; timeout/partial failure is explicit.

## 3. Release Tag Gate

Run:

```bash
python3 scripts/validate_launch_readiness.py --release-tag
```

Release live provider cases must be `PASS` or `DISABLED`.

Default policy is fail-closed:

- If a live provider has not passed QA, keep its Release surface disabled.
- If a provider is enabled, its matching `ReleaseLiveProviderGate` boolean must be true and the matching rows in `docs/qa/LiveProviderQAMatrix.md` must be PASS.
- Do not enable Worker-backed public lookup tools until `python3 scripts/validate_worker_production_health.py` passes against production.

## 4. Worker Production Gate

Current production endpoint:

```bash
python3 scripts/validate_worker_production_health.py
```

PASS requires:

- `ok: true`
- `service: myteam-basic-lookup-api`
- `version: 0.3.0`
- `build: public-lookup-0.3.0`
- `userRoutes` present
- `diagnosticContract` present
- no `/dart/*` route in `userRoutes`
- `/dart/*` absent from `userRoutes`; diagnostic route names are not exposed in public `/health`
- no-token and wrong-token `/dart/*` requests return exactly `404`

Source validation is not deploy proof. If production `/health` does not match this contract, public lookup Release surfaces stay disabled. A release tag can proceed only if those surfaces remain `DISABLED`; enabling them requires this Worker gate to pass first.

## 5. Product Truth Copy

Allowed launch copy:

> MyTeam은 회의록, 문서 초안, 업무 브리핑, 공공 조회 결과를 하나의 업무 산출물로 정리해주는 로컬 업무 보조 앱입니다. 일부 외부 조회 기능은 연결 상태와 공공데이터 응답에 따라 제한될 수 있으며, 주식/금융 정보는 실시간 시세나 투자 조언이 아닙니다. 표/엑셀 관련 기능은 현재 실제 파일 수정이 아니라 붙여넣은 자료 기반 점검 초안 생성 중심입니다.

Forbidden unless directly negated as a disclaimer:

- 실시간 현재가
- 현재가
- 매수 추천
- 매도 추천
- 투자 추천
- 기사 전문 요약
- 공시 전문 분석 완료
- 수정 완료
- 검산 완료
- 연결 완료 without live validation evidence

## 6. Enablement Rule

To enable a Release live provider:

1. Run the matching live QA rows.
2. Update `docs/qa/LiveProviderQAMatrix.md` from DISABLED to PASS with concrete evidence.
3. Flip the matching `ReleaseLiveProviderGate` boolean.
4. Re-run static gate, `--release-tag`, Debug build, and Release build.

Do not flip a gate first and plan to test later.
