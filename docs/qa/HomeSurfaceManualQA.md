# Home Surface Manual QA

This document verifies that Home and Settings expose only defensible product surfaces. Static policy exists, but manual UI inspection is still required.

## Evidence Metadata

- tested_commit: `837276699a11268112a09c78bc1bb60bb954c781`
- tested_build: `not run for manual QA in this pass`
- tested_at: `2026-07-06 00:08:59 KST`
- tester: `pending manual QA`
- profile: `Developer, Release Candidate, and App Store profile expectations must be checked separately`
- configuration: `pending manual QA`
- architecture: `pending manual QA`
- xcode_version: `pending manual QA`
- artifact_sha256: `pending manual QA`

| Case ID | Scenario | Input / Action | Expected result | Forbidden result | Actual result | PASS / FAIL / BLOCKED | Evidence | Notes |
|---|---|---|---|---|---|---|---|---|
| HOME-001 | Home primary tools by profile | Open Home dashboard in Developer, Release Candidate, and App Store-equivalent profile | Developer may expose QA-enabled read-only tools. Release Candidate/App Store may show only local/draft tools plus live-QA PASS providers; fail-closed providers may be hidden or shown as unavailable/connection-needed, not ready. | One profile-invariant expectation; disabled provider shown as ready; Finance statement, DART, Weather, Calendar, Google Sheets, spreadsheet, voice preview, developer diagnostics in primary grid | Not run in this pass | BLOCKED | Pending profile-specific Home UI screenshots | Reason: requires app UI inspection by profile. Next: capture Home per profile and compare against ProductSurfacePolicy plus ReleaseLiveProviderGate. |
| HOME-002 | Hidden spreadsheet surfaces | Inspect Home and user-facing tool cards | Google Sheets read, spreadsheet postprocess, spreadsheet merge are not ordinary primary product cards | Spreadsheet/Excel tools shown as ready primary actions | Not run in this pass | BLOCKED | Pending Home UI screenshot | Reason: requires app UI inspection. Next: verify Home and tool list. |
| HOME-003 | Natural-only tools lowered | Inspect Home and connection/secondary sections | DART, Weather, Calendar, company statement are not primary Home cards; they appear only where policy allows | Natural-only tools exposed as primary standalone promises | Not run in this pass | BLOCKED | Pending Home UI screenshot | Reason: requires app UI inspection. Next: compare against ProductSurfacePolicy. |
| HOME-004 | Settings surface and window layering | Open Settings from menu/Cmd+, reopen when minimized, open Settings while team/chat/status panels exist, then create a new chat/status panel while Settings is open | No developer diagnostics, MCP, Playwright, subprocess, model cache internals in ordinary surface; Settings opens in front; team member panel remains visible; chat/status/swap/agent-settings do not cover Settings | ConnectorStatusView/PlaywrightMCPStatusView/developer diagnostics visible in Release-like surface; duplicate Settings window; Settings hidden behind floating panels; detail sheet cannot be closed | Not run in this pass | BLOCKED | Pending Settings UI screenshot and timing note | Reason: requires settings UI inspection. Next: open Settings in Release profile and record layering/timing. |
| HOME-005 | ProductSurfacePolicy consistency | Compare ProductSurfacePolicy tiers with rendered Home | Rendered surfaces follow `ProductSurfacePolicy.tier` and `shouldShow...` decisions | Hard-coded Home quick tools bypass policy | Static check only in this pass | PASS | `python3 scripts/audit_product_completeness.py` expected PASS | Manual UI still recommended. |
| HOME-006 | DLC/Pro exposure | Inspect character/DLC/Pro surfaces | Disabled Pro/DLC surfaces are absent or clearly not available; no fake unlock/completed commerce | Character store/DLC/Pro shown as completed purchasable feature without real unlock flow | Not run in this pass | BLOCKED | Pending Settings/Home UI inspection | Reason: requires release surface walkthrough. Next: inspect monetization surfaces. |

## Static Evidence

- `python3 scripts/audit_product_completeness.py`: expected to pass.

## Completion Rule

HOME-001 through HOME-006 must be PASS before Home/Product Surface QA can support a Release Candidate recommendation.
