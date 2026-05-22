# TTS Provider Policy

**Round 253TTS** — Supertonic adoption gate.

---

## Product Decision

Supertonic is the only TTS candidate.

MyTeam has no default user-facing TTS yet.

There is no fallback TTS.

Supertonic is allowed for product planning under the upstream OpenRAIL-M model license and MIT sample-code license, subject to license notice, attribution, and use-restriction compliance.

If Supertonic fails quality, runtime, bundle, or release UX gates, MyTeam v1 ships without TTS.

---

## Candidate

| Item | Value |
|---|---|
| Provider | Supertonic3 |
| Scope now | TTS Lab / experimental validation |
| Scope next | Product adoption candidate |
| Release default | disabled until release UX is approved |
| Model bundle | allowed only with license notice and distribution policy |
| Launch auto-init | prohibited |
| Commercial product use | allowed under license conditions |
| Model redistribution | allowed under license conditions |
| Release product exposure | blocked until runtime, quality, bundle, and release UX gates pass |

---

## Gate (canShipAsProductFeature)

All release gates must be `true` before shipping as a product feature:

1. `koreanQualityAccepted` — Korean quality accepted by product owner
2. `localRuntimeVerified` — local Mac runtime verified with benchmark results
3. `bundlePolicyAccepted` — model bundle or user-selected model policy approved
4. `releaseIntegrationApproved` — release UX, compliance notices, and App Store path approved

License evidence is now sufficient for planning, but release exposure remains blocked until implementation gates pass.

---

## Routing

```swift
// TTSRoutingPolicy.selectedProvider()
// Supertonic3 (enabled && modelAvailable && releaseGateApproved) → .supertonic3
// nil → silent
```

---

## Not Allowed

- Fallback TTS
- Product TTS exposure before release gates pass
- ONNX files committed to git without explicit distribution decision
- Supertonic launch auto-init
- Claiming production readiness, App Store readiness, or verified runtime status before all release gates pass

---

## Compliance Review

See `docs/SupertonicCommercialLicenseReview.md` before considering any release exposure.

The upstream license text and model terms permit product planning, but MyTeam must still implement attribution, license notice, restricted-use notice, model distribution policy, and release UX before enabling a user-facing product feature.