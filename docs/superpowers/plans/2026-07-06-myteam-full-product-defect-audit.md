# MyTeam Full Product Defect Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Identify every known, recorded, untested, weak, or ambiguous MyTeam product surface before Release Candidate work continues.

**Architecture:** This is an audit-first plan. It does not enable hidden features or mark QA as PASS; it builds a single source of truth from static validators, manual QA docs, live provider gates, runtime screenshots, and product-surface policies. Findings are written as evidence-backed rows with owner, risk, reproduction path, and next action.

**Tech Stack:** Swift/macOS app, SwiftUI/AppKit windows, Cloudflare Worker, Python validators, Xcode Debug/Release builds, Markdown QA matrices.

---

## Current Known State

- Current branch: `main`, locally ahead of `origin/main` by 7 commits at the time of planning.
- Latest local commit observed: `67d3c76 fix(ui): prevent team panel clipping`.
- Release Candidate strict manual QA is blocked because APPTERM/NW/ART/HOME rows remain `BLOCKED`.
- Release tag live provider gate is fail-closed. Provider rows are `DISABLED`, not product-value PASS.
- Production Worker `/health` currently fails contract because production returns `routes` only, not `userRoutes` and `diagnosticRoutes`.
- QA evidence docs still reference an older `tested_commit` in several places and must be refreshed only after actual runtime QA.
- Recent runtime UI fixes for Settings/team status/onboarding clipping need manual retest before being treated as stable.

---

## Defect Inventory Categories

Use these statuses exactly:

- `P0-blocker`: blocks Release Candidate or can create fake success/user trust damage.
- `P0-qa-blocked`: implemented or guarded statically but not proven in runtime manual QA.
- `P1-product-gap`: feature works partially but is not complete enough for normal users.
- `P1-live-disabled`: intentionally fail-closed until live provider QA passes.
- `P2-polish`: quality improvement after RC blockers are closed.
- `invalid`: suspected issue disproven by evidence.

Use these evidence types exactly:

- `static-validator`
- `debug-build`
- `release-build`
- `manual-screenshot`
- `manual-video`
- `runtime-log`
- `provider-response`
- `worker-health`
- `code-reference`

---

## Files

### Create

- `docs/qa/FullProductDefectAudit.md`
  - Main defect inventory table.
  - One row per issue, including source evidence and next action.

- `docs/qa/FullProductDefectAuditRunbook.md`
  - Step-by-step QA commands and manual scenarios.
  - This is the operator guide for repeating the audit.

- `scripts/audit_full_product_defects.py`
  - Aggregates existing QA docs and reports unresolved BLOCKED/DISABLED/stale evidence rows.
  - Does not mark PASS.

### Modify

- `docs/qa/AppTerminationManualQA.md`
  - Refresh metadata only after actual QA run.

- `docs/qa/NaturalWorkE2EManualQA.md`
  - Refresh metadata only after actual QA run.

- `docs/qa/ArtifactReopenManualQA.md`
  - Refresh metadata only after actual QA run.

- `docs/qa/HomeSurfaceManualQA.md`
  - Add recent Settings/team panel/onboarding clipping checks if missing.

- `docs/qa/LiveProviderQAMatrix.md`
  - Keep providers `DISABLED` until live QA proves them.

- `scripts/validate_release_qa_evidence.py`
  - Only update if audit shows it allows stale evidence or missing metadata.

---

## Task 1: Create the Full Defect Inventory Document

**Files:**
- Create: `docs/qa/FullProductDefectAudit.md`

- [ ] **Step 1: Create the audit table with mandatory columns**

Write this exact document skeleton:

```markdown
# Full Product Defect Audit

Last updated: YYYY-MM-DD HH:mm KST
Audited branch: main
Audited commit: <git-sha>
Audited build: <Debug/Release build path or not run>

## Summary

| Severity | Count | Meaning |
| --- | ---: | --- |
| P0-blocker | 0 | Blocks RC or risks fake success/user trust |
| P0-qa-blocked | 0 | Needs runtime/manual proof |
| P1-product-gap | 0 | Partial feature or incomplete user value |
| P1-live-disabled | 0 | Intentionally hidden/disabled until provider QA |
| P2-polish | 0 | Quality improvement after RC |

## Inventory

| ID | Severity | Area | Symptom / Risk | Evidence | Current Status | Required Fix or QA | Owner Action | Verification |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| APPTERM-MANUAL-001 | P0-qa-blocked | App termination | APPTERM-001~006 are still BLOCKED. Process-level quit is not proven. | docs/qa/AppTerminationManualQA.md | BLOCKED | Run Cmd+Q, menu quit, AppleScript quit, TTS quit, tool quit, artifact detail quit in Debug and Release. | Manual QA | `python3 scripts/validate_release_qa_evidence.py --strict` |
| NW-MANUAL-001 | P0-qa-blocked | Natural work routing | NW-001~013 are still BLOCKED. One-bubble composite routing is not proven in runtime. | docs/qa/NaturalWorkE2EManualQA.md | BLOCKED | Run all personal chat and team workroom scenarios. | Manual QA | Runtime screenshots/logs plus strict validator |
| ART-MANUAL-001 | P0-qa-blocked | Artifact reopen | ART-001~004 are still BLOCKED. Internal artifact detail reopen is not proven. | docs/qa/ArtifactReopenManualQA.md | BLOCKED | Generate composite artifact, reopen recent artifact, test artifactID-only and long body. | Manual QA | Runtime screenshots/logs plus strict validator |
| HOME-MANUAL-001 | P0-qa-blocked | Home/Settings surface | HOME-001~004 and HOME-006 are still BLOCKED. Product surface is not manually proven. | docs/qa/HomeSurfaceManualQA.md | BLOCKED | Inspect Home, Settings, DLC/Pro, developer diagnostics, Settings layering, team panel. | Manual QA | Runtime screenshots plus strict validator |
| WORKER-PROD-001 | P0-blocker | Cloudflare Worker | Production /health returns routes only; missing userRoutes/diagnosticRoutes. | `python3 scripts/validate_worker_production_health.py` | FAIL | Redeploy repository Worker source to Cloudflare production. | Cloudflare deploy | `python3 scripts/validate_worker_production_health.py` |
| LIVE-PROVIDER-001 | P1-live-disabled | Public lookup providers | FIN/DART/KMA/NEWS/LAW/GOOGLE are disabled or unproven. | docs/qa/LiveProviderQAMatrix.md | DISABLED | Keep disabled or run live provider QA before enabling. | Provider QA | `python3 scripts/validate_release_qa_evidence.py --release-strict` plus provider screenshots/logs |
| QA-METADATA-001 | P0-qa-blocked | QA evidence | Manual QA docs reference stale tested_commit/build metadata. | docs/qa/*ManualQA.md | STALE | Refresh only after actual runtime QA on current HEAD/build. | QA doc update | `python3 scripts/validate_release_qa_evidence.py --strict` |
| SETTINGS-RUNTIME-001 | P0-qa-blocked | Settings/windowing | Recent Settings/team panel fixes are build-verified but need manual repeat QA. | commits dac334d, c4b8869, 67d3c76 | PARTIAL | Open Settings from Cmd+, menu, status item; test minimized, behind panels, new panels while Settings open. | Manual QA | Screenshot/video and HOME-004 PASS |
| TEAM-PANEL-001 | P0-qa-blocked | Team status panel | Recent clipping/drag fixes are build-verified but need manual repeat QA across display positions. | commits c4b8869, 67d3c76 | PARTIAL | Test onboarding, team list, workroom tab, bottom controls, drag/tuck behavior. | Manual QA | Screenshot/video and HOME-004 PASS |
| TTS-MANUAL-001 | P0-qa-blocked | Supertonic3/BubbleSpeech | Voice path is protected but live audio QA is not fully recorded for RC. | docs/qa/ProductCompletenessInventory.md | liveButNeedsManualQA | Run preview/playback/failure cases; verify no Apple TTS fallback and no BubbleSpeech passthrough success. | Audio QA | Runtime log + audio QA notes |
| OFFICE-PARTIAL-001 | P1-product-gap | File/office review | File/office features are partialTextOnly; not real Excel/PDF deep analysis. | docs/qa/ProductCompletenessInventory.md | PARTIAL | Keep copy modest or implement real parsing/evidence links. | Product decision | Home/manual QA plus fixture docs |
```

- [ ] **Step 2: Fill counts from the table**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
text = Path('docs/qa/FullProductDefectAudit.md').read_text()
inventory = text.split('## Inventory', 1)[1].split('## Rules', 1)[0]
for sev in ['P0-blocker','P0-qa-blocked','P1-product-gap','P1-live-disabled','P2-polish']:
    print(sev, inventory.count(f'| {sev} |'))
PY
```

Expected: printed counts match the Summary table after manual update.

- [ ] **Step 3: Commit**

```bash
git add docs/qa/FullProductDefectAudit.md
git commit -m "docs(qa): inventory unresolved product defects"
```

---

## Task 2: Add the Audit Runbook

**Files:**
- Create: `docs/qa/FullProductDefectAuditRunbook.md`

- [ ] **Step 1: Write static gate commands**

Use this content:

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add docs/qa/FullProductDefectAuditRunbook.md
git commit -m "docs(qa): add full product audit runbook"
```

---

## Task 3: Add Static Aggregator for Unresolved Product Defects

**Files:**
- Create: `scripts/audit_full_product_defects.py`

- [ ] **Step 1: Write the script**

```python
#!/usr/bin/env python3
from __future__ import annotations

import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
QA_DOCS = [
    ROOT / 'docs/qa/AppTerminationManualQA.md',
    ROOT / 'docs/qa/NaturalWorkE2EManualQA.md',
    ROOT / 'docs/qa/ArtifactReopenManualQA.md',
    ROOT / 'docs/qa/HomeSurfaceManualQA.md',
    ROOT / 'docs/qa/LiveProviderQAMatrix.md',
    ROOT / 'docs/qa/MainProductStabilizationMergeGate.md',
    ROOT / 'docs/qa/ProductCompletenessInventory.md',
]

STALE_COMMIT_DOCS = [
    ROOT / 'docs/qa/AppTerminationManualQA.md',
    ROOT / 'docs/qa/NaturalWorkE2EManualQA.md',
    ROOT / 'docs/qa/ArtifactReopenManualQA.md',
    ROOT / 'docs/qa/HomeSurfaceManualQA.md',
]


def current_head() -> str:
    return subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()


def table_rows(text: str) -> list[list[str]]:
    rows: list[list[str]] = []
    for line in text.splitlines():
        if not line.startswith('|'):
            continue
        cells = [cell.strip() for cell in line.strip().strip('|').split('|')]
        if cells and re.match(r'^[A-Z]+[-A-Z0-9]*-\d+', cells[0]):
            rows.append(cells)
    return rows


def main() -> int:
    head = current_head()
    unresolved: list[str] = []
    stale: list[str] = []

    for path in QA_DOCS:
        if not path.exists():
            unresolved.append(f'MISSING_DOC {path.relative_to(ROOT)}')
            continue
        text = path.read_text(encoding='utf-8')
        for row in table_rows(text):
            status = next((cell for cell in row if cell in {'FAIL', 'BLOCKED', 'DISABLED'}), None)
            if status:
                unresolved.append(f'{status} {path.relative_to(ROOT)} {row[0]} {row[1] if len(row) > 1 else ""}')

    for path in STALE_COMMIT_DOCS:
        text = path.read_text(encoding='utf-8') if path.exists() else ''
        match = re.search(r'tested_commit:\s*`([^`]+)`', text)
        if match and match.group(1) != head:
            stale.append(f'STALE_COMMIT {path.relative_to(ROOT)} tested_commit={match.group(1)} head={head}')

    worker = subprocess.run(
        ['python3', 'scripts/validate_worker_production_health.py'],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    if worker.returncode != 0:
        unresolved.append('FAIL docs/qa/LiveProviderQAMatrix.md WORKER-002 production /health contract')

    print('Full product defect audit')
    print(f'HEAD {head}')
    print('\nUnresolved rows:')
    for item in unresolved:
        print(f'- {item}')
    print('\nStale evidence:')
    for item in stale:
        print(f'- {item}')

    if stale:
        print('\nNOTE: stale evidence is expected until manual QA is rerun on current HEAD.')
    if unresolved:
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x scripts/audit_full_product_defects.py
```

- [ ] **Step 3: Run and verify current expected failure**

```bash
python3 scripts/audit_full_product_defects.py || true
```

Expected: lists BLOCKED manual QA rows, DISABLED live provider rows, stale manual QA commit metadata, and Worker production health failure.

- [ ] **Step 4: Commit**

```bash
git add scripts/audit_full_product_defects.py
git commit -m "test(qa): aggregate unresolved product defects"
```

---

## Task 4: Manual QA Pass 1 - Windowing and Team Panel

**Files:**
- Modify: `docs/qa/HomeSurfaceManualQA.md`
- Modify: `docs/qa/FullProductDefectAudit.md`

- [ ] **Step 1: Run current Release app**

```bash
open -n /Users/su/Library/Developer/Xcode/DerivedData/MyTeam-evpptvfqtronmdfbvmwvfqxzoimq/Build/Products/Release/MyTeam.app
```

Expected: MyTeam process appears in `pgrep -fl MyTeam`.

- [ ] **Step 2: Run Settings QA**

Manual cases:

1. Open Settings through menu/Cmd+,.
2. Minimize Settings and reopen through menu/Cmd+,.
3. Open Settings while team panel is visible.
4. Open Settings while personal chat is visible.
5. Open a new chat/status/swap panel while Settings is already visible.
6. Open Settings detail sheet and close it with visible button.

Expected:

- Settings is normal window, not draggable/tuckable panel.
- Team member panel remains visible.
- Chat/status/swap/agent-settings do not cover Settings.
- Detail sheet is closable.

Forbidden:

- Settings hidden behind panels.
- duplicate Settings windows.
- detail sheet without close action.
- settings_window in FloatingPanel behavior.

- [ ] **Step 3: Run team panel QA**

Manual cases:

1. Force first-launch onboarding if needed.
2. Verify onboarding panel bottom CTA is visible.
3. Click `선택 없이 계속`.
4. Verify room template step bottom CTA is visible.
5. Switch to normal team list.
6. Confirm bottom controls are visible.
7. Click rows and scroll inside the panel.
8. Confirm panel does not edge-tuck or move vertically from internal clicks.

Expected:

- No clipping at top or bottom.
- No hidden CTA.
- No internal-click drag behavior.

- [ ] **Step 4: Record evidence**

Update HOME-004 in `docs/qa/HomeSurfaceManualQA.md` with:

- tested_commit: current HEAD.
- tested_build: Release app path.
- screenshot paths.
- PASS only if all listed cases passed.

- [ ] **Step 5: Commit evidence only if PASS was actually observed**

```bash
git add docs/qa/HomeSurfaceManualQA.md docs/qa/FullProductDefectAudit.md
git commit -m "docs(qa): record settings and team panel evidence"
```

---

## Task 5: Manual QA Pass 2 - Termination

**Files:**
- Modify: `docs/qa/AppTerminationManualQA.md`
- Modify: `docs/qa/FullProductDefectAudit.md`

- [ ] **Step 1: Run APPTERM-001 idle Cmd+Q**

```bash
open -n /Users/su/Library/Developer/Xcode/DerivedData/MyTeam-evpptvfqtronmdfbvmwvfqxzoimq/Build/Products/Release/MyTeam.app
# Press Cmd+Q manually, wait 6 seconds.
pgrep -fl MyTeam || true
```

Expected: no MyTeam process remains.

- [ ] **Step 2: Run APPTERM-003 AppleScript quit**

```bash
open -n /Users/su/Library/Developer/Xcode/DerivedData/MyTeam-evpptvfqtronmdfbvmwvfqxzoimq/Build/Products/Release/MyTeam.app
sleep 3
osascript -e 'tell application "MyTeam" to quit'
sleep 6
pgrep -fl MyTeam || true
```

Expected: no MyTeam process remains.

- [ ] **Step 3: Run remaining manual cases**

Run APPTERM-002, APPTERM-004, APPTERM-005, APPTERM-006 exactly as described in `docs/qa/AppTerminationManualQA.md`.

- [ ] **Step 4: Record evidence**

Update `docs/qa/AppTerminationManualQA.md` rows to PASS only with command output or screenshot/video evidence.

- [ ] **Step 5: Commit**

```bash
git add docs/qa/AppTerminationManualQA.md docs/qa/FullProductDefectAudit.md
git commit -m "docs(qa): record app termination manual evidence"
```

---

## Task 6: Manual QA Pass 3 - Natural Work and Artifact Reopen

**Files:**
- Modify: `docs/qa/NaturalWorkE2EManualQA.md`
- Modify: `docs/qa/ArtifactReopenManualQA.md`
- Modify: `docs/qa/FullProductDefectAudit.md`

- [ ] **Step 1: Run personal chat natural work cases**

Inputs:

```text
삼성전자 알려줘
삼성전자 주가 알려줘
회의록 만들어줘
뉴스 기사처럼 써줘
법적으로 자연스럽게 써줘
날씨 알려줘
광양 출장 날씨 알려줘
근로기준법 연차 조문 찾아줘
```

Expected:

- One progress bubble.
- One final composite answer.
- No internal terms: Tool, FastPath, proxy, provider, scope.
- No fake current price, investment advice, legal advice, article full-text summary.
- Missing input asks a question.
- Disabled provider appears as unavailable or connection needed, not success.

- [ ] **Step 2: Run team workroom natural work cases**

Inputs:

```text
삼성전자 알려줘
삼성전자 주가랑 공시랑 재무상황 알려줘
```

Expected:

- Same routing result class as personal chat.
- Room-scoped artifact.
- No duplicate tool-bubble spray.

- [ ] **Step 3: Run artifact reopen cases**

1. Create composite artifact from a successful or partial natural work result.
2. Open recent artifact from app internal UI.
3. Verify `WorkArtifactDetailView` opens.
4. Verify long artifact does not freeze UI.

- [ ] **Step 4: Record evidence**

Update `docs/qa/NaturalWorkE2EManualQA.md` and `docs/qa/ArtifactReopenManualQA.md` only for cases actually observed.

- [ ] **Step 5: Commit**

```bash
git add docs/qa/NaturalWorkE2EManualQA.md docs/qa/ArtifactReopenManualQA.md docs/qa/FullProductDefectAudit.md
git commit -m "docs(qa): record natural work and artifact evidence"
```

---

## Task 7: Worker Production and Live Provider Audit

**Files:**
- Modify: `docs/qa/LiveProviderQAMatrix.md`
- Modify: `docs/qa/FullProductDefectAudit.md`

- [ ] **Step 1: Validate production Worker**

```bash
python3 scripts/validate_worker_production_health.py
```

Expected before Cloudflare redeploy: FAIL because production currently lacks `userRoutes` and `diagnosticRoutes`.

- [ ] **Step 2: Redeploy Worker from repository source outside this plan**

Use Cloudflare deployment flow and then rerun:

```bash
python3 scripts/validate_worker_production_health.py
```

Expected after redeploy: PASS.

- [ ] **Step 3: Keep providers disabled until live QA**

Do not flip any `ReleaseLiveProviderGate` boolean until these rows have PASS evidence:

- GOOGLE-001~006
- FIN-001~005
- DART-001~004
- KMA-001~003
- NEWS-001~003
- LAW-001~003
- WORKER-002

- [ ] **Step 4: Commit evidence only**

```bash
git add docs/qa/LiveProviderQAMatrix.md docs/qa/FullProductDefectAudit.md
git commit -m "docs(qa): record live provider audit evidence"
```

---

## Task 8: Final RC Gate Review

**Files:**
- Modify: `docs/qa/MainProductStabilizationMergeGate.md`
- Modify: `docs/qa/FullProductDefectAudit.md`

- [ ] **Step 1: Run full static gate**

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
python3 scripts/validate_result_presentation.py
python3 scripts/validate_release_checklist.py
python3 scripts/validate_skill_packages.py
python3 scripts/precommit_safety_check.py
python3 scripts/report_character_dialogues.py --check-only
```

Expected: PASS.

- [ ] **Step 2: Run builds**

```bash
xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Debug -destination 'platform=OS X,arch=arm64' build
xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Release -destination 'platform=OS X,arch=arm64' build
```

Expected: both end with `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Run RC strict gate**

```bash
python3 scripts/validate_release_qa_evidence.py --strict
```

Expected before manual QA completion: FAIL.
Expected after manual QA completion: PASS.

- [ ] **Step 4: Run release live gate**

```bash
python3 scripts/validate_release_qa_evidence.py --release-strict
python3 scripts/validate_worker_production_health.py
```

Expected:

- `--release-strict` passes if providers are PASS or DISABLED.
- Worker production health passes only after redeploy.

- [ ] **Step 5: Update decision**

Only if all required gates pass, update `docs/qa/MainProductStabilizationMergeGate.md` Release Candidate decision.

- [ ] **Step 6: Commit**

```bash
git add docs/qa/MainProductStabilizationMergeGate.md docs/qa/FullProductDefectAudit.md
git commit -m "docs(qa): finalize release candidate gate evidence"
```

---

## Self-Review

- Spec coverage: The plan covers recorded-but-unfixed issues, QA-blocked issues, possible runtime issues, function gaps, Worker/provider gaps, Settings/windowing regressions, TTS manual QA, file/office partial support, and stale QA metadata.
- Placeholder scan: No task uses TBD/TODO/fill-in language. Each task has concrete files, commands, expected results, and commit command.
- Type consistency: The plan uses existing file names and existing validator command names from the current repo.
