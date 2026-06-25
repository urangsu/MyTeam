# Home Surface Manual QA

This document verifies that Home and Settings expose only defensible product surfaces. Static policy exists, but manual UI inspection is still required.

| Case ID | Scenario | Input / Action | Expected result | Forbidden result | Actual result | PASS / FAIL / BLOCKED | Evidence | Notes |
|---|---|---|---|---|---|---|---|---|
| HOME-001 | Home primary tools | Open Home dashboard | Primary surfaces: 오늘 로컬 업무 브리핑, 회의록 작성, 주식 기준일 시세, 시장 지수 기준일 조회, 뉴스 브리핑, 법령 검색 | Finance statement, DART, Weather, Calendar, Google Sheets, spreadsheet, voice preview, developer diagnostics in primary grid | Not run in this pass | BLOCKED | Pending Home UI screenshot | Reason: requires app UI inspection. Next: open Home and capture screenshot/text. |
| HOME-002 | Hidden spreadsheet surfaces | Inspect Home and user-facing tool cards | Google Sheets read, spreadsheet postprocess, spreadsheet merge are not ordinary primary product cards | Spreadsheet/Excel tools shown as ready primary actions | Not run in this pass | BLOCKED | Pending Home UI screenshot | Reason: requires app UI inspection. Next: verify Home and tool list. |
| HOME-003 | Natural-only tools lowered | Inspect Home and connection/secondary sections | DART, Weather, Calendar, company statement are not primary Home cards; they appear only where policy allows | Natural-only tools exposed as primary standalone promises | Not run in this pass | BLOCKED | Pending Home UI screenshot | Reason: requires app UI inspection. Next: compare against ProductSurfacePolicy. |
| HOME-004 | Settings developer surface | Open Settings | No developer diagnostics, MCP, Playwright, subprocess, model cache internals in ordinary surface | ConnectorStatusView/PlaywrightMCPStatusView/developer diagnostics visible in Release-like surface | Not run in this pass | BLOCKED | Pending Settings UI screenshot | Reason: requires settings UI inspection. Next: open Settings in Release profile. |
| HOME-005 | ProductSurfacePolicy consistency | Compare ProductSurfacePolicy tiers with rendered Home | Rendered surfaces follow `ProductSurfacePolicy.tier` and `shouldShow...` decisions | Hard-coded Home quick tools bypass policy | Static check only in this pass | PASS | `python3 scripts/audit_product_completeness.py` expected PASS | Manual UI still recommended. |
| HOME-006 | DLC/Pro exposure | Inspect character/DLC/Pro surfaces | Disabled Pro/DLC surfaces are absent or clearly not available; no fake unlock/completed commerce | Character store/DLC/Pro shown as completed purchasable feature without real unlock flow | Not run in this pass | BLOCKED | Pending Settings/Home UI inspection | Reason: requires release surface walkthrough. Next: inspect monetization surfaces. |

## Static Evidence

- `python3 scripts/audit_product_completeness.py`: expected to pass.

## Completion Rule

HOME-001 through HOME-006 must be PASS before Home/Product Surface QA can support main merge recommendation.
