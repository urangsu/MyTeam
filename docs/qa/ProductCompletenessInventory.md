# Product Completeness Inventory

This inventory tracks user-facing surfaces that can look like finished product
but still have manual QA, live-route, or implementation gaps.

Status levels:

- `productionReady`: implemented, validated, and safe to expose.
- `liveButNeedsManualQA`: implemented but still needs valid-key/live UI QA.
- `partialTextOnly`: can create text or draft output, but not full analysis.
- `plannedHidden`: not ready for normal user-facing execution.
- `developerOnly`: allowed only in Developer profile or lab surfaces.
- `blocked`: must not be exposed as usable.

Recommended surface levels:

- `primary`: visible in the first work dashboard surface.
- `secondary`: available in lower-priority work or advanced sections.
- `naturalOnly`: available through natural-language work routing, not as a primary card.
- `connectionOnly`: shown only as a connection or credential task.
- `developerOnly`: hidden from normal users.
- `hidden`: not exposed until productized.

| Area | Current status | Recommended surface | Code policy | Required product truth | Next action |
| --- | --- | --- | --- | --- | --- |
| Natural work routing | `liveButNeedsManualQA` | `primary` | `ProductSurfacePolicy.primary` for core work entry cards | Personal chat and team workroom must use the same entrypoint. Legacy fast-path remains only as fallback. | Keep as main entry and expand manual QA. |
| Public lookup tools: news/law/finance stock and index | `blocked` until live QA | `hidden` in Release, enabled in Developer QA | `ReleaseLiveProviderGate.workerProductionHealthPassed`, `newsLiveQAPassed`, `lawLiveQAPassed`, `financeLiveQAPassed` are false | Must not run empty input with default topics. Basic lookup outages must show failure or connection guidance. | Keep hidden from Release until Worker `/health` and provider live QA pass. |
| Weather lookup | `blocked` until live QA | `hidden` in Release, enabled in Developer QA | `ReleaseLiveProviderGate.workerProductionHealthPassed` and `kmaLiveQAPassed` are false | Requires explicit region and valid KMA readiness. No silent Seoul fallback. | Keep hidden from Release until KMA live QA passes. |
| DART disclosures | `blocked` until BYOK QA | `hidden` in Release, enabled in Developer QA | `ReleaseLiveProviderGate.dartLiveQAPassed` is false | Direct BYOK only. Missing or invalid key must be shown as connection/key issue, not empty success. | Keep hidden from Release until direct DART valid/no-key/failure QA passes. |
| Finance company statement | `blocked` until live QA | `hidden` in Release, enabled in Developer QA | `ReleaseLiveProviderGate.workerProductionHealthPassed` and `financeLiveQAPassed` are false | Company identity and selected reporting period must be explicit in output. No hard-coded Samsung/2024 default. | Keep hidden from Release until company finance live QA passes. |
| Google Calendar read | `blocked` until OAuth QA | `hidden` in Release, enabled in Developer QA | `ReleaseLiveProviderGate.googleLiveQAPassed` is false | Token presence and real read capability must stay separate. Write actions remain hidden. | Keep hidden from Release until Calendar no-token/success/failure QA passes. |
| Google Sheets read | `blocked` until OAuth QA | `hidden` | `spreadsheet.googleSheets.read` is `ProductSurfacePolicy.hidden`; `ReleaseLiveProviderGate.googleLiveQAPassed` is false | Read-only implementation exists, but normal surface is hidden until live QA and input UX are stronger. | Re-enable only after URL/range QA and result artifact QA. |
| Spreadsheet/table cleanup plan | `partialTextOnly` | `hidden` | `spreadsheet.postprocess` and `spreadsheet.merge` are `ProductSurfacePolicy.hidden` | Generates only a cleanup/check plan from pasted table text. It does not edit Excel files. | Keep code path available for later, but hide from normal tool surfaces. |
| File intake | `partialTextOnly` | `secondary` | File intake is not a primary tool card | Supported files mean text extraction/card creation. Table parsing and evidence links are not guaranteed. | Keep copy modest. |
| Office review: budget/accounting/tax/vendor/contract | `partialTextOnly` | `naturalOnly` | Routed through natural work, not primary direct cards | Label as draft/checklist generation unless table parsing and evidence links are implemented. | Route through clarification and draft/checklist output only. |
| Demo mode | `plannedHidden` | `hidden` | Demo surfaces stay hidden | Do not expose as real demo mode until sample seeding and clear labeling exist. | Keep out of normal settings. |
| Character store / paid unlock | `plannedHidden` | `hidden` | Store skeleton stays hidden | StoreKit/unlock not implemented; do not present purchasable cards as usable. | Keep skeleton out of normal settings. |
| Observation / screen / Finder selection | `partialTextOnly` | `developerOnly` | Observation surfaces stay `developerOnly` | User-confirmed, non-continuous capture only. Screen/Finder gaps must show fallback guidance. | Keep behind developer/lab policy. |
| Supertonic3 / BubbleSpeech | `liveButNeedsManualQA` | `secondary` | Voice preview tools are `ProductSurfacePolicy.developerOnly` as work tools | Main TTS path must not fall back to Apple TTS or passthrough BubbleSpeech success. Manual audio QA remains required. | Keep as voice settings/lab, not work dashboard primary action. |

P0 guardrails:

- No silent default query for external lookups.
- No unimplemented user-facing tool.
- No prepared/coming-soon connector shown as connectable.
- No skeleton commerce/demo surface shown as complete product.
- No file support message that implies full analysis when only extraction is available.
