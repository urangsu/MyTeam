# TTS Provider Policy

**Round 252TTS** — Supertonic is the only TTS candidate.

---

## Product Decision

Supertonic is the only TTS candidate.

MyTeam has no default user-facing TTS.

There is no fallback TTS.

If Supertonic fails quality, runtime, license, bundle, or release gates, MyTeam v1 ships without TTS.

---

## Candidate

| Item | Value |
|---|---|
| Provider | Supertonic3 |
| Scope | TTS Lab / experimental only |
| Release default | disabled |
| Model bundle | prohibited until approved |
| Launch auto-init | prohibited |
| Commercial product use | pending compliance review |
| Model redistribution | pending compliance review |
| Release product exposure | blocked until all gates pass |

---

## Gate (canShipAsProductFeature)

All 5 must be `true` before shipping as a product feature:

1. `koreanQualityAccepted` — Korean quality accepted by product owner
2. `licenseVerified` — exact upstream LICENSE / model card / terms reviewed
3. `localRuntimeVerified` — local Mac runtime verified with benchmark results
4. `bundlePolicyAccepted` — model bundle or user-selected model policy approved
5. `releaseIntegrationApproved` — release UX, compliance, and App Store path approved

Current: all `false`. Release product exposure is blocked until all gates pass.

---

## Routing

```swift
// TTSRoutingPolicy.selectedProvider()
// Supertonic3 (isEnabled && modelAvailable) → .supertonic3 for TTS Lab only
// nil → silent
```

---

## Not Allowed

- Fallback TTS
- Product TTS exposure before license verification
- Model bundle before redistribution policy is confirmed
- ONNX files committed to git
- Supertonic launch auto-init
- Claiming production readiness, commercial readiness, App Store readiness, or verified runtime status before all gates pass

---

## Compliance Review

See `docs/SupertonicCommercialLicenseReview.md` before considering any release exposure.

The upstream license text and model terms are compliance inputs, not automatic product approval. MyTeam must still verify commercial use, model redistribution, App Store bundle compatibility, attribution, and restricted-use obligations before enabling any release feature.