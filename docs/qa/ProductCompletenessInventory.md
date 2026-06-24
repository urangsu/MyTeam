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

| Area | Current status | Required product truth |
| --- | --- | --- |
| Natural work routing | `liveButNeedsManualQA` | Personal chat and team workroom must use the same entrypoint. Legacy fast-path remains only as fallback. |
| Public lookup tools: news/weather/law/finance | `liveButNeedsManualQA` | Must not run empty input with default topics. Basic lookup outages must show failure or connection guidance. |
| DART disclosures | `liveButNeedsManualQA` | Direct BYOK only. Missing or invalid key must be shown as connection/key issue, not empty success. |
| Google Calendar / Google Sheets read | `liveButNeedsManualQA` | Token presence and real read capability must stay separate. Write actions remain hidden. |
| File intake | `partialTextOnly` | Supported files mean text extraction/card creation. Table parsing and evidence links are not guaranteed. |
| Office review: budget/accounting/tax/vendor/contract | `partialTextOnly` | Label as draft/checklist generation unless table parsing and evidence links are implemented. |
| Demo mode | `plannedHidden` | Do not expose as real demo mode until sample seeding and clear labeling exist. |
| Character store / paid unlock | `plannedHidden` | StoreKit/unlock not implemented; do not present purchasable cards as usable. |
| Observation / screen / Finder selection | `partialTextOnly` | User-confirmed, non-continuous capture only. Screen/Finder gaps must show fallback guidance. |
| Supertonic3 / BubbleSpeech | `liveButNeedsManualQA` | Main TTS path must not fall back to Apple TTS or passthrough BubbleSpeech success. Manual audio QA remains required. |

P0 guardrails:

- No silent default query for external lookups.
- No unimplemented user-facing tool.
- No prepared/coming-soon connector shown as connectable.
- No skeleton commerce/demo surface shown as complete product.
- No file support message that implies full analysis when only extraction is available.
