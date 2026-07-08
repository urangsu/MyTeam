# MyTeam P0/P1 Stabilization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the remaining launch blockers by proving runtime behavior, deploy provenance, release capability state, and multi-room workflow integrity without marking untested paths as ready.

**Architecture:** Keep `main` as integration and treat `release/*` as the strict RC gate. Runtime capability decisions must be made by one release manifest and enforced at every execution boundary, not only in Home/Settings UI. Manual QA evidence must identify the exact commit, build artifact, configuration, architecture, Xcode version, and artifact hash.

**Tech Stack:** Swift/macOS, SwiftUI, Cloudflare Worker JavaScript, Python validators, Markdown QA evidence, Xcode Debug/Release builds.

---

## Current State Snapshot

- Branch: `/Users/su/Desktop/MyTeam`, `main...origin/main [ahead 11]`.
- Latest local commit: `626f2fa fix(worker): require deploy provenance and diagnostic schema`.
- Static validators pass for current source, but strict manual QA still fails by design.
- Production Worker still returns old `/health` contract with `routes`, not `userRoutes`, `diagnosticContract`, `contractVersion`, `gitSha`, and `deployedAt`.
- `ReleaseLiveProviderGate` still uses hardcoded booleans and unknown tools default to enabled. This is the highest remaining code-level P0 after Worker deployment.
- Source control must contain only a release capability manifest template. A generated PASS manifest is produced during an RC build from durable QA evidence and a clean HEAD, and must not be committed.

---

## File Map

### Release Capability and Runtime Gate

- Modify: `/Users/su/Desktop/MyTeam/MyTeam/ProductSurfacePolicy.swift`
  - Replace hardcoded provider booleans with a manifest-backed gate.
- Create: `/Users/su/Desktop/MyTeam/MyTeam/ReleaseCapabilityManifest.swift`
  - Load and validate bundled release capability manifest.
- Create: `/Users/su/Desktop/MyTeam/MyTeam/Resources/ReleaseCapabilityManifest.template.json`
  - Schema/template only. It is not release evidence and must stay fail-closed.
- Generate during RC only: `ReleaseCapabilityManifest.generated.json`
  - Generated from durable QA evidence and a clean HEAD. This file must not be committed.
- Modify: `/Users/su/Desktop/MyTeam/MyTeam/MyTeam.xcodeproj/project.pbxproj`
  - Add the manifest resource if Xcode does not auto-include resources.
- Modify: `/Users/su/Desktop/MyTeam/scripts/validate_myteam_release.py`
  - Fail if the generated manifest is tracked or release gates allow unknown external capabilities by default.
- Modify: `/Users/su/Desktop/MyTeam/scripts/audit_product_completeness.py`
  - Fail if provider booleans are reintroduced as the release source of truth.

### Worker Deployment and Provider Safety

- Modify: `/Users/su/Desktop/MyTeam/workers/basic-lookup-api/worker.js`
  - Already has baseline `contractVersion/gitSha/deployedAt`, diagnostic schema, local rate limit, timeout, and response-size guards. P0 execution is deploy proof and any missing hardening found by validator.
- Modify: `/Users/su/Desktop/MyTeam/scripts/validate_worker_production_health.py`
  - Already checks current HEAD and diagnostic JSON schema. Keep as production proof gate.
- Modify: `/Users/su/Desktop/MyTeam/workers/basic-lookup-api/README.md`
  - Keep exact deploy order: push commit, set Worker vars, deploy, validate.
- Modify: `/Users/su/Desktop/MyTeam/docs/qa/LiveProviderQAMatrix.md`
  - Record Worker PASS only after live production proof.

### Workflow Concurrency

- Modify: `/Users/su/Desktop/MyTeam/MyTeam/AgentWindowManager.swift`
  - Ensure room-scoped workflow state changes do not clear global compatibility fields while another room is active.
- Modify: `/Users/su/Desktop/MyTeam/MyTeam/WorkflowOrchestrator.swift`
  - Keep dispatch delegated, but audit global state cleanup.
- Modify: `/Users/su/Desktop/MyTeam/MyTeam/CompositeArtifactRecorder.swift`
  - Verify artifact room/workflow ID is captured from initiating room, not active room at completion.
- Modify: `/Users/su/Desktop/MyTeam/docs/qa/NaturalWorkE2EManualQA.md`
  - Fill `NW-CONC-001` through `NW-CONC-006` only after runtime evidence.
- Modify: `/Users/su/Desktop/MyTeam/scripts/validate_release_qa_evidence.py`
  - Already includes new concurrency case IDs. Keep strict.

### Tool Result State and Persistence

- Modify: `/Users/su/Desktop/MyTeam/MyTeam/ToolExecutionState.swift`
  - Confirm `checkedEmpty` and `partial` are first-class states.
- Modify: `/Users/su/Desktop/MyTeam/MyTeam/ToolExecutionLog.swift`
  - Add backward-compatible decode for unknown future states and old succeeded-empty records.
- Modify: `/Users/su/Desktop/MyTeam/MyTeam/ToolExecutionLogView.swift`
  - Show old/unknown/empty states honestly.
- Modify: `/Users/su/Desktop/MyTeam/MyTeam/NaturalWorkRouting.swift`
  - Confirm `checkedEmpty` never enters confirmed result sections.
- Create: `/Users/su/Desktop/MyTeam/tests/fixtures/tool_execution_log_legacy.json`
  - Fixture for legacy log decode.
- Create: `/Users/su/Desktop/MyTeam/scripts/validate_tool_state_migration.py`
  - Decode fixture and statically verify migration paths.

### Artifact Integrity and Reopen

- Modify: `/Users/su/Desktop/MyTeam/MyTeam/ArtifactStore.swift`
  - Add missing-file and hash-mismatch status if not already present.
- Modify: `/Users/su/Desktop/MyTeam/MyTeam/WorkArtifactDetailView.swift`
  - Render recovery states for missing file, missing index, and hash mismatch.
- Modify: `/Users/su/Desktop/MyTeam/docs/qa/ArtifactReopenManualQA.md`
  - Fill `ART-005` through `ART-009` only after runtime/fixture proof.
- Create: `/Users/su/Desktop/MyTeam/scripts/smoke_artifact_integrity.py`
  - Generate temporary artifact/index corruption fixtures and verify detail/recovery logic statically where possible.

### App Termination and Window QA

- Modify only if runtime QA reproduces a defect:
  - `/Users/su/Desktop/MyTeam/MyTeam/AppTerminationCoordinator.swift`
  - `/Users/su/Desktop/MyTeam/MyTeam/AgentWindowManager.swift`
  - `/Users/su/Desktop/MyTeam/MyTeam/FloatingPanel.swift`
  - `/Users/su/Desktop/MyTeam/MyTeam/TeamStatusView.swift`
- Update evidence:
  - `/Users/su/Desktop/MyTeam/docs/qa/AppTerminationManualQA.md`
  - `/Users/su/Desktop/MyTeam/docs/qa/HomeSurfaceManualQA.md`

### Launch Value Gate

- Modify: `/Users/su/Desktop/MyTeam/scripts/validate_release_qa_evidence.py`
  - Keep `--release-strict` as safety gate.
- Create: `/Users/su/Desktop/MyTeam/scripts/validate_launch_value_gate.py`
  - Require minimum product value capabilities to be live PASS before marketing/launch readiness claims.
- Modify: `/Users/su/Desktop/MyTeam/docs/qa/LaunchReadinessRunbook.md`
  - Separate `Release Safety Gate` from `Launch Value Gate`.

---

## P0 Execution Plan

### P0-1: Push and Prove Worker Production Contract

**Purpose:** Stop treating local Worker source as deployment proof.

**Files:**
- Modify after live proof: `/Users/su/Desktop/MyTeam/docs/qa/LiveProviderQAMatrix.md`
- Modify after live proof: `/Users/su/Desktop/MyTeam/docs/qa/FullProductDefectAudit.md`

- [ ] **Step 1: Push current integration commits**

Run:

```bash
cd /Users/su/Desktop/MyTeam
git status --short --branch
git push origin main
```

Expected:

```text
main is pushed to origin with commit 626f2fa... or newer.
```

- [ ] **Step 2: Set Cloudflare production variables**

Set these Worker variables/secrets in Cloudflare Dashboard:

```text
MYTEAM_WORKER_GIT_SHA=<exact pushed commit SHA>
MYTEAM_WORKER_DEPLOYED_AT=<UTC timestamp such as 2026-07-08T12:34:56Z>
DIAGNOSTIC_ROUTE_TOKEN=<secret value, never pasted into repo/docs/chat>
```

Expected:

```text
The values exist in Cloudflare Variables and Secrets.
The diagnostic token value is not written to files or logs.
```

- [ ] **Step 3: Deploy Worker source**

Deploy:

```text
/Users/su/Desktop/MyTeam/workers/basic-lookup-api/worker.js
```

Expected:

```text
Cloudflare production deploy completes.
```

- [ ] **Step 4: Verify public health contract**

Run:

```bash
cd /Users/su/Desktop/MyTeam
python3 scripts/validate_worker_production_health.py
```

Expected:

```text
PASS: Worker production /health validation
```

- [ ] **Step 5: Verify diagnostic positive auth schema**

Run with local env var only:

```bash
cd /Users/su/Desktop/MyTeam
MYTEAM_DIAGNOSTIC_TOKEN='<local secret>' python3 scripts/validate_worker_production_health.py --validate-diagnostic-auth
```

Expected:

```text
PASS: Worker production /health validation
```

Failure examples that must block release:

```text
HTTP 500
non-JSON response
provider != dart
error == not_found
missing route-specific handler marker
```

- [ ] **Step 6: Update evidence docs after live proof**

Update only after Steps 4 and 5 pass:

```markdown
| WORKER-002 | Worker production health | ... | ... | ... | PASS | `python3 scripts/validate_worker_production_health.py`; `MYTEAM_DIAGNOSTIC_TOKEN=... python3 scripts/validate_worker_production_health.py --validate-diagnostic-auth` | Production `/health` matched commit `<sha>`. |
```

Commit:

```bash
git add docs/qa/LiveProviderQAMatrix.md docs/qa/FullProductDefectAudit.md
git commit -m "docs(qa): record worker production health evidence"
```

---

### P0-2: Replace Hardcoded ReleaseLiveProviderGate with Generated ReleaseCapabilityManifest

**Purpose:** Prevent QA on commit A and release enabling on commit B, without committing a self-asserted PASS file.

**Files:**
- Create: `/Users/su/Desktop/MyTeam/MyTeam/ReleaseCapabilityManifest.swift`
- Create: `/Users/su/Desktop/MyTeam/MyTeam/Resources/ReleaseCapabilityManifest.template.json`
- Modify: `/Users/su/Desktop/MyTeam/MyTeam/ProductSurfacePolicy.swift`
- Modify: `/Users/su/Desktop/MyTeam/scripts/validate_myteam_release.py`
- Modify: `/Users/su/Desktop/MyTeam/scripts/audit_product_completeness.py`
- Modify if needed: `/Users/su/Desktop/MyTeam/MyTeam/MyTeam.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add fail-closed manifest template**

Create `/Users/su/Desktop/MyTeam/MyTeam/Resources/ReleaseCapabilityManifest.template.json`:

```json
{
  "schema_version": 1,
  "tested_commit": "UNTESTED",
  "profile": "releaseCandidate",
  "worker": {
    "contract_version": 2,
    "production_health": "DISABLED",
    "git_sha": null,
    "deployed_at": null
  },
  "providers": {
    "google": "DISABLED",
    "finance": "DISABLED",
    "dart": "DISABLED",
    "kma": "DISABLED",
    "news": "DISABLED",
    "law": "DISABLED"
  }
}
```

`ReleaseCapabilityManifest.generated.json` is produced later during the RC build from durable QA evidence and a clean HEAD. Manifest generation must not change the source commit and the generated file must not be tracked.

- [ ] **Step 2: Add manifest loader**

Create `/Users/su/Desktop/MyTeam/MyTeam/ReleaseCapabilityManifest.swift`:

```swift
import Foundation

enum ReleaseCapabilityStatus: String, Codable, Sendable {
    case pass = "PASS"
    case passBYOK = "PASS_BYOK"
    case disabled = "DISABLED"
}

struct ReleaseCapabilityManifest: Codable, Sendable {
    struct Worker: Codable, Sendable {
        let contractVersion: Int
        let productionHealth: ReleaseCapabilityStatus

        enum CodingKeys: String, CodingKey {
            case contractVersion = "contract_version"
            case productionHealth = "production_health"
        }
    }

    let schemaVersion: Int
    let testedCommit: String
    let profile: String
    let worker: Worker
    let providers: [String: ReleaseCapabilityStatus]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case testedCommit = "tested_commit"
        case profile
        case worker
        case providers
    }
}

enum ReleaseCapabilityManifestStore: Sendable {
    nonisolated static let bundled: ReleaseCapabilityManifest = {
        guard let url = Bundle.main.url(forResource: "ReleaseCapabilityManifest.generated", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(ReleaseCapabilityManifest.self, from: data)
        else {
            return ReleaseCapabilityManifest(
                schemaVersion: 1,
                testedCommit: "UNTESTED",
                profile: "releaseCandidate",
                worker: .init(contractVersion: 2, productionHealth: .disabled),
                providers: [
                    "google": .disabled,
                    "finance": .disabled,
                    "dart": .disabled,
                    "kma": .disabled,
                    "news": .disabled,
                    "law": .disabled
                ]
            )
        }
        return manifest
    }()

    nonisolated static func status(for provider: String) -> ReleaseCapabilityStatus {
        bundled.providers[provider] ?? .disabled
    }
}
```

- [ ] **Step 3: Separate approval, runtime compatibility, and user connection**

Do not collapse these three states:

```text
releaseApproved      = generated manifest provider state
runtimeCompatible    = Worker /health contract and deploy metadata compatibility
userConnectionReady  = Keychain/OAuth/local credential/readiness state
```

Runtime allow condition:

```text
releaseApproved && runtimeCompatible && requiredCredentialStateSatisfied
```

The release surface gate handles release approval and runtime compatibility. User connection remains in `ToolExecutionRouter.readiness`.

- [ ] **Step 4: Replace hardcoded booleans in ProductSurfacePolicy**

Modify `ReleaseLiveProviderGate` in `/Users/su/Desktop/MyTeam/MyTeam/ProductSurfacePolicy.swift` so release decisions call manifest state:

```swift
enum ReleaseLiveProviderGate: Sendable {
    nonisolated static func isEnabledInCurrentReleaseSurface(toolID: String) -> Bool {
        guard FeatureGate.current != .developer else { return true }
        return isApprovedForRelease(toolID: toolID)
    }

    nonisolated static func isApprovedForRelease(toolID: String) -> Bool {
        switch toolID {
        case "news.search":
            return workerIsLive && providerIsPass("news")
        case "law.search":
            return workerIsLive && providerIsPass("law")
        case "finance.krx.stockPrice", "finance.krx.index", "finance.company.statement":
            return workerIsLive && providerIsPass("finance")
        case "weather.current":
            return workerIsLive && providerIsPass("kma")
        case "dart.disclosures.search":
            return providerIsPass("dart") || ReleaseCapabilityManifestStore.status(for: "dart") == .passBYOK
        case "calendar.events.today", "spreadsheet.googleSheets.read":
            return providerIsPass("google")
        default:
            return allowOnlyKnownLocalSafeTool(toolID)
        }
    }

    private nonisolated static var workerIsLive: Bool {
        ReleaseCapabilityManifestStore.bundled.worker.productionHealth == .pass
    }

    private nonisolated static func providerIsPass(_ provider: String) -> Bool {
        ReleaseCapabilityManifestStore.status(for: provider) == .pass
    }
}
```

Unknown external capability must default deny. Only known local/draft tools without external credentials may be allowed by default.

- [ ] **Step 5: Add validator checks**

In `/Users/su/Desktop/MyTeam/scripts/validate_myteam_release.py`, add:

```python
def validate_release_capability_manifest() -> None:
    template_path = ROOT / "MyTeam" / "Resources" / "ReleaseCapabilityManifest.template.json"
    generated_path = ROOT / "MyTeam" / "Resources" / "ReleaseCapabilityManifest.generated.json"
    if not template_path.exists():
        raise SystemExit("FAIL: ReleaseCapabilityManifest.template.json missing")
    if is_git_tracked(generated_path):
        raise SystemExit("FAIL: generated release capability manifest must not be tracked")
    data = json.loads(template_path.read_text())
    if data.get("schema_version") != 1:
        raise SystemExit("FAIL: ReleaseCapabilityManifest template schema_version must be 1")
    providers = data.get("providers")
    if not isinstance(providers, dict):
        raise SystemExit("FAIL: ReleaseCapabilityManifest providers must be an object")
    for key in ["google", "finance", "dart", "kma", "news", "law"]:
        if providers.get(key) != "DISABLED":
            raise SystemExit(f"FAIL: ReleaseCapabilityManifest template must be fail-closed: {key}")
```

Call it from `main()`.

- [ ] **Step 6: Fail hardcoded provider booleans and default allow**

In `/Users/su/Desktop/MyTeam/scripts/audit_product_completeness.py`, fail on:

```python
for token in [
    "workerProductionHealthPassed",
    "googleLiveQAPassed",
    "financeLiveQAPassed",
    "dartLiveQAPassed",
    "kmaLiveQAPassed",
    "newsLiveQAPassed",
    "lawLiveQAPassed",
    "default:\n            return true",
]:
    if token in surface_policy:
        failures.append(f"ReleaseLiveProviderGate must use ReleaseCapabilityManifest, not hardcoded boolean: {token}")
```

- [ ] **Step 7: Verify**

Run:

```bash
cd /Users/su/Desktop/MyTeam
git diff --check
python3 scripts/validate_myteam_release.py
python3 scripts/audit_product_completeness.py
xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Debug -destination 'platform=OS X,arch=arm64' build
xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Release -destination 'platform=OS X,arch=arm64' build
```

Expected:

```text
All commands exit 0.
Release external surfaces remain fail-closed because the generated manifest is absent and the template is DISABLED.
```

- [ ] **Step 8: Commit**

```bash
git add MyTeam/ReleaseCapabilityManifest.swift MyTeam/Resources/ReleaseCapabilityManifest.template.json MyTeam/ProductSurfacePolicy.swift scripts/validate_myteam_release.py scripts/audit_product_completeness.py MyTeam/MyTeam.xcodeproj/project.pbxproj .gitignore
git commit -m "fix(release): gate providers with capability manifest"
```

---

### P0-3: Prove Runtime Capability Gate Across All Execution Paths

**Purpose:** Ensure hidden/disabled tools cannot run through natural language, saved actions, retry, resume, direct dispatch, or old artifacts.

**Files:**
- Modify: `/Users/su/Desktop/MyTeam/scripts/smoke_natural_work_e2e.py`
- Modify: `/Users/su/Desktop/MyTeam/scripts/validate_architecture_boundaries.py`
- Modify: `/Users/su/Desktop/MyTeam/docs/qa/FullProductDefectAuditRunbook.md`
- Modify if runtime bypass is found:
  - `/Users/su/Desktop/MyTeam/MyTeam/ToolExecutionRouter.swift`
  - `/Users/su/Desktop/MyTeam/MyTeam/NaturalWorkRouting.swift`
  - `/Users/su/Desktop/MyTeam/MyTeam/WorkflowInputCoordinator.swift`

- [ ] **Step 1: Add static gate assertions**

Ensure the validators require:

```text
NaturalWorkPlanExecutor -> ToolExecutionRouter.readiness -> ProductSurfacePolicy
NaturalWorkPlanExecutor -> ToolExecutionRouter.run
ToolExecutionRouter.run -> readiness(for:bypassApproval:)
StarterActionDispatcher -> WorkflowOrchestrator.dispatch
BriefingActionDispatcher -> WorkflowOrchestrator.dispatch
```

- [ ] **Step 2: Add runtime QA rows**

Add to `docs/qa/NaturalWorkE2EManualQA.md` if absent:

```markdown
| NW-GATE-001 | Release disabled news through natural language | In Release profile, submit `삼성전자 뉴스` while news is DISABLED | Shows unavailable/connection-needed section; no network request | `news.search` executes | Not run in this pass | BLOCKED | Pending Release-profile runtime log | Requires Release profile run. |
| NW-GATE-002 | Release disabled finance through saved action | Trigger old/saved finance action while finance is DISABLED | Action re-checks gate and blocks | Finance runner executes | Not run in this pass | BLOCKED | Pending saved-action runtime log | Requires saved action fixture. |
| NW-GATE-003 | Retry disabled provider | From a disabled provider failure card, tap retry | Retry re-checks gate and remains blocked | Retry bypasses Release gate | Not run in this pass | BLOCKED | Pending retry runtime log | Requires disabled provider card. |
```

- [ ] **Step 3: Add IDs to validator**

Add `NW-GATE-001`, `NW-GATE-002`, and `NW-GATE-003` to `/Users/su/Desktop/MyTeam/scripts/validate_release_qa_evidence.py`.

- [ ] **Step 4: Verify**

Run:

```bash
python3 scripts/validate_release_qa_evidence.py --strict || true
python3 scripts/smoke_natural_work_e2e.py
python3 scripts/validate_architecture_boundaries.py
```

Expected:

```text
strict fails because new rows are BLOCKED.
smoke and architecture validators pass.
```

- [ ] **Step 5: Commit**

```bash
git add docs/qa/NaturalWorkE2EManualQA.md scripts/validate_release_qa_evidence.py scripts/smoke_natural_work_e2e.py scripts/validate_architecture_boundaries.py docs/qa/FullProductDefectAuditRunbook.md
git commit -m "test(release): require runtime capability gate evidence"
```

---

### P0-4: Workflow Concurrency Runtime QA and Fixes

**Purpose:** Prevent multi-room global state races.

**Files:**
- Modify if defect is reproduced: `/Users/su/Desktop/MyTeam/MyTeam/AgentWindowManager.swift`
- Modify if defect is reproduced: `/Users/su/Desktop/MyTeam/MyTeam/WorkflowOrchestrator.swift`
- Modify if defect is reproduced: `/Users/su/Desktop/MyTeam/MyTeam/CompositeArtifactRecorder.swift`
- Update: `/Users/su/Desktop/MyTeam/docs/qa/NaturalWorkE2EManualQA.md`

- [ ] **Step 1: Run two-room concurrent QA**

Manual app steps:

```text
1. Open team workroom room A.
2. Submit `삼성전자 알려줘`.
3. Switch to room B before A finishes.
4. Submit `광양 출장 날씨 알려줘`.
5. Return to room A after both finish.
```

Expected:

```text
Room A has only A progress/final artifact.
Room B has only B progress/final artifact.
Neither run clears the other room status.
```

- [ ] **Step 2: If global state clears another room, patch AgentWindowManager**

Patch principle:

```swift
// When clearing a room-scoped workflow, only clear legacy global fields
// if the cleared room owns the current global workflow ID.
if currentWorkflowID == removedWorkflowID {
    currentWorkflowID = currentWorkflowIDByRoom.values.first
    workflowStatusText = currentWorkflowID.flatMap { id in
        workflowStatusTextByRoom.first(where: { currentWorkflowIDByRoom[$0.key] == id })?.value
    }
}
```

- [ ] **Step 3: Run cancellation QA**

Manual app steps:

```text
1. Start room A natural work.
2. Start room B natural work.
3. Cancel only room A.
4. Observe room B until completion.
```

Expected:

```text
Room B remains running and completes.
Room A records cancellation only for room A.
```

- [ ] **Step 4: Run double-submit QA**

Manual app steps:

```text
1. In one workroom, submit `삼성전자 알려줘` twice rapidly.
2. Observe progress and artifact list.
```

Expected:

```text
Either two separate runs are clearly represented, or de-duplication is explicit.
No stuck status, duplicate artifact ID, or cross-linked artifact.
```

- [ ] **Step 5: Record evidence**

Update `NW-CONC-001` through `NW-CONC-006` with:

```text
tested_commit
tested_build
configuration
architecture
xcode_version
artifact_sha256
runtime log or screenshot path
```

- [ ] **Step 6: Verify**

Run:

```bash
python3 scripts/validate_release_qa_evidence.py --strict || true
```

Expected:

```text
Concurrency rows no longer fail if all six are PASS.
Other manual rows may still fail.
```

- [ ] **Step 7: Commit**

```bash
git add MyTeam/AgentWindowManager.swift MyTeam/WorkflowOrchestrator.swift MyTeam/CompositeArtifactRecorder.swift docs/qa/NaturalWorkE2EManualQA.md
git commit -m "fix(workflow): preserve room-scoped concurrent state"
```

---

### P0-5: Tool State Migration and Empty Result Integrity

**Purpose:** Stop old `.succeeded + empty body` and unknown future states from reopening as fake success.

**Files:**
- Modify: `/Users/su/Desktop/MyTeam/MyTeam/ToolExecutionLog.swift`
- Modify: `/Users/su/Desktop/MyTeam/MyTeam/ToolExecutionLogView.swift`
- Modify: `/Users/su/Desktop/MyTeam/MyTeam/NaturalWorkRouting.swift`
- Create: `/Users/su/Desktop/MyTeam/tests/fixtures/tool_execution_log_legacy.json`
- Create: `/Users/su/Desktop/MyTeam/scripts/validate_tool_state_migration.py`
- Modify: `/Users/su/Desktop/MyTeam/scripts/validate_myteam_release.py`

- [ ] **Step 1: Add legacy fixture**

Create `/Users/su/Desktop/MyTeam/tests/fixtures/tool_execution_log_legacy.json`:

```json
[
  {
    "id": "11111111-1111-1111-1111-111111111111",
    "toolID": "news.search",
    "displayName": "뉴스 검색",
    "startedAt": "2026-07-08T00:00:00Z",
    "finishedAt": "2026-07-08T00:00:01Z",
    "state": "succeeded",
    "path": "toolCard",
    "durationMs": 1000,
    "summary": "",
    "failureMessage": null,
    "artifactID": null,
    "artifactFilename": null,
    "timedOut": false
  },
  {
    "id": "22222222-2222-2222-2222-222222222222",
    "toolID": "law.search",
    "displayName": "법령 검색",
    "startedAt": "2026-07-08T00:00:00Z",
    "finishedAt": "2026-07-08T00:00:01Z",
    "state": "futureState",
    "path": "toolCard",
    "durationMs": 1000,
    "summary": "unknown state fixture",
    "failureMessage": null,
    "artifactID": null,
    "artifactFilename": null,
    "timedOut": false
  }
]
```

- [ ] **Step 2: Add migration script**

Create `/Users/su/Desktop/MyTeam/scripts/validate_tool_state_migration.py`:

```python
#!/usr/bin/env python3
from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[1]
fixture = ROOT / "tests" / "fixtures" / "tool_execution_log_legacy.json"
tool_log = (ROOT / "MyTeam" / "ToolExecutionLog.swift").read_text()
tool_view = (ROOT / "MyTeam" / "ToolExecutionLogView.swift").read_text()

failures = []
data = json.loads(fixture.read_text())
if len(data) != 2:
    failures.append("legacy fixture must contain exactly two entries")
for token in ["case checkedEmpty", "case partial", "case unknown", "init(from decoder"]:
    if token not in tool_log:
        failures.append(f"ToolExecutionLog.swift missing migration token: {token}")
for token in ["결과 없음", "알 수 없는 상태", "checkedEmpty"]:
    if token not in tool_view:
        failures.append(f"ToolExecutionLogView missing honest state wording: {token}")

if failures:
    print("FAIL: tool state migration validation")
    for failure in failures:
        print(f"- {failure}")
    sys.exit(1)

print("PASS: tool state migration validation")
```

- [ ] **Step 3: Add unknown state support**

Modify `ToolExecutionLogState`:

```swift
enum ToolExecutionLogState: String, Codable, Sendable, Equatable {
    case running
    case succeeded
    case checkedEmpty
    case partial
    case failed
    case unavailable
    case timedOut
    case unknown
}
```

In custom decode, map unknown string to `.unknown`.

- [ ] **Step 4: Verify**

Run:

```bash
python3 scripts/validate_tool_state_migration.py
python3 scripts/validate_myteam_release.py
xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Debug -destination 'platform=OS X,arch=arm64' build
xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Release -destination 'platform=OS X,arch=arm64' build
```

Expected:

```text
All commands exit 0.
Old/unknown states do not render as verified success.
```

- [ ] **Step 5: Commit**

```bash
git add MyTeam/ToolExecutionLog.swift MyTeam/ToolExecutionLogView.swift MyTeam/NaturalWorkRouting.swift tests/fixtures/tool_execution_log_legacy.json scripts/validate_tool_state_migration.py scripts/validate_myteam_release.py
git commit -m "fix(tools): preserve empty and unknown execution states"
```

---

### P0-6: Artifact Integrity Runtime Gate

**Purpose:** Make artifact reopen reliable enough for RC review.

**Files:**
- Modify: `/Users/su/Desktop/MyTeam/MyTeam/ArtifactStore.swift`
- Modify: `/Users/su/Desktop/MyTeam/MyTeam/WorkArtifactDetailView.swift`
- Create: `/Users/su/Desktop/MyTeam/scripts/smoke_artifact_integrity.py`
- Modify: `/Users/su/Desktop/MyTeam/docs/qa/ArtifactReopenManualQA.md`

- [ ] **Step 1: Add fixture smoke script**

Create `/Users/su/Desktop/MyTeam/scripts/smoke_artifact_integrity.py`:

```python
#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
store = (ROOT / "MyTeam" / "ArtifactStore.swift").read_text()
detail = (ROOT / "MyTeam" / "WorkArtifactDetailView.swift").read_text()

failures = []
for token in ["contentHash", "fileSizeBytes", "missing", "hash"]:
    if token not in store + detail:
        failures.append(f"artifact integrity path missing token: {token}")
for phrase in ["파일을 찾을 수 없습니다", "내용이 변경되었을 수 있습니다", "다시 생성"]:
    if phrase not in detail:
        failures.append(f"WorkArtifactDetailView missing recovery phrase: {phrase}")

if failures:
    print("FAIL: artifact integrity smoke")
    for failure in failures:
        print(f"- {failure}")
    sys.exit(1)

print("PASS: artifact integrity smoke")
```

- [ ] **Step 2: Implement missing-file and hash-mismatch UI**

`WorkArtifactDetailView` must render:

```text
산출물 파일을 찾을 수 없습니다.
최근 실행 기록은 남아 있지만 원본 파일이 이동되었거나 삭제되었습니다.
다시 생성하거나 원본 위치를 확인하세요.
```

For hash mismatch:

```text
산출물 내용이 생성 당시와 다를 수 있습니다.
파일이 수정되었을 가능성이 있어 검증된 결과로 표시하지 않습니다.
```

- [ ] **Step 3: Verify**

Run:

```bash
python3 scripts/smoke_artifact_integrity.py
python3 scripts/validate_myteam_release.py
xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Debug -destination 'platform=OS X,arch=arm64' build
xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Release -destination 'platform=OS X,arch=arm64' build
```

- [ ] **Step 4: Manual QA**

Run `ART-005` through `ART-009` and record evidence.

- [ ] **Step 5: Commit**

```bash
git add MyTeam/ArtifactStore.swift MyTeam/WorkArtifactDetailView.swift scripts/smoke_artifact_integrity.py docs/qa/ArtifactReopenManualQA.md
git commit -m "fix(artifact): show integrity recovery states"
```

---

## P1 Execution Plan

### P1-1: Durable Worker Abuse Controls

**Purpose:** Move from isolate-local rate limiting to durable, production-grade quota protection.

**Files:**
- Modify: `/Users/su/Desktop/MyTeam/workers/basic-lookup-api/worker.js`
- Modify: `/Users/su/Desktop/MyTeam/workers/basic-lookup-api/README.md`

- [ ] Add Cloudflare KV/R2/Durable Object decision.
- [ ] Implement durable per-IP and per-route rate limit if Cloudflare plan allows it.
- [ ] Add cache for safe public-data routes with conservative TTL:
  - finance/index: 10 minutes
  - KMA forecast: 10 minutes
  - news: no cache or 60 seconds maximum
  - diagnostic: always no-store
- [ ] Verify with `python3 scripts/validate_worker_production_health.py`.
- [ ] Commit: `fix(worker): add durable lookup quota protection`.

### P1-2: Launch Value Gate

**Purpose:** Separate "safe to release disabled" from "valuable enough to launch".

**Files:**
- Create: `/Users/su/Desktop/MyTeam/scripts/validate_launch_value_gate.py`
- Modify: `/Users/su/Desktop/MyTeam/docs/qa/LaunchReadinessRunbook.md`

Rules:

```text
Safety gate: PASS or DISABLED is acceptable.
Value gate: at least 3 core capabilities must be PASS.
Suggested core capabilities:
- APPTERM manual suite
- Natural Work local document/draft path
- Artifact reopen
- At least one live public lookup provider or DART BYOK
```

Commit:

```bash
git add scripts/validate_launch_value_gate.py docs/qa/LaunchReadinessRunbook.md
git commit -m "test(release): add launch value gate"
```

### P1-3: Clean Install and Upgrade QA

**Files:**
- Create: `/Users/su/Desktop/MyTeam/docs/qa/InstallUpgradeManualQA.md`
- Modify: `/Users/su/Desktop/MyTeam/scripts/validate_release_qa_evidence.py`

Cases:

```text
UPG-001 clean install
UPG-002 previous version upgrade
UPG-003 stale panel coordinates
UPG-004 old credential migration
UPG-005 old execution state
UPG-006 old artifact index
```

Commit:

```bash
git add docs/qa/InstallUpgradeManualQA.md scripts/validate_release_qa_evidence.py
git commit -m "test(qa): add install and upgrade gate"
```

### P1-4: Credential Lifecycle QA

**Files:**
- Create: `/Users/su/Desktop/MyTeam/docs/qa/CredentialLifecycleManualQA.md`
- Modify: `/Users/su/Desktop/MyTeam/scripts/validate_release_qa_evidence.py`

Cases:

```text
CRED-001 save key
CRED-002 replace key
CRED-003 delete key
CRED-004 revoked key
CRED-005 Keychain read failure
CRED-006 offline read
CRED-007 app relaunch does not show stale connected state
```

Commit:

```bash
git add docs/qa/CredentialLifecycleManualQA.md scripts/validate_release_qa_evidence.py
git commit -m "test(qa): add credential lifecycle gate"
```

### P1-5: Provider Enablement Runs

**Purpose:** Turn disabled providers into PASS only with real evidence.

Order:

```text
1. Worker production health
2. NEWS
3. LAW
4. KMA
5. FIN
6. DART BYOK
7. GOOGLE
```

For each provider:

```bash
python3 scripts/validate_release_qa_evidence.py --release-strict
```

Expected:

```text
Provider stays DISABLED until PASS evidence is written.
No provider is enabled by code boolean flip alone.
```

---

## Verification Matrix

Run after each P0 commit:

```bash
cd /Users/su/Desktop/MyTeam
git diff --check
node --check workers/basic-lookup-api/worker.js
python3 scripts/validate_myteam_release.py
python3 scripts/validate_architecture_boundaries.py
python3 scripts/smoke_natural_work_e2e.py
python3 scripts/validate_release_qa_evidence.py
python3 scripts/validate_release_qa_evidence.py --release-strict
python3 scripts/precommit_safety_check.py
python3 scripts/report_character_dialogues.py --check-only
```

Run before RC claim:

```bash
python3 scripts/validate_release_qa_evidence.py --strict
python3 scripts/validate_worker_production_health.py
MYTEAM_DIAGNOSTIC_TOKEN='<local secret>' python3 scripts/validate_worker_production_health.py --validate-diagnostic-auth
xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Debug -destination 'platform=OS X,arch=arm64' build
xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Release -destination 'platform=OS X,arch=arm64' build
```

---

## Commit Order

1. `fix(worker): prove production deploy identity`
2. `fix(release): gate providers with capability manifest`
3. `test(release): require runtime capability gate evidence`
4. `fix(workflow): preserve room-scoped concurrent state`
5. `fix(tools): preserve empty and unknown execution states`
6. `fix(artifact): show integrity recovery states`
7. `test(release): add launch value gate`
8. `test(qa): add install and credential lifecycle gates`

---

## Remaining Risk Rules

- Do not mark `APPTERM`, `NW`, `ART`, or `HOME` rows PASS without runtime evidence.
- Do not mark Worker PASS until production `/health` matches the current commit SHA.
- Do not write `DIAGNOSTIC_ROUTE_TOKEN` or token values to Swift, plist, JSON resources, docs, logs, screenshots, or URLs.
- Do not flip provider capability to PASS unless evidence was gathered on the same commit/build that will be shipped.
- Do not call `main` release-ready. Use `release/*` plus strict gates for RC language.
