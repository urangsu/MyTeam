# TTS Provider Policy

**Round 251TTS** — Supertonic3 is the only TTS candidate.

---

## Product Decision

Supertonic is the only TTS candidate.

MyTeam has no default user-facing TTS.

There is no fallback TTS.

If Supertonic fails product gates, MyTeam v1 ships without TTS.

---

## Candidate

| Item | Value |
|---|---|
| Provider | Supertonic3 |
| Scope | TTS Lab / experimental only |
| Release default | disabled |
| Model bundle | prohibited |
| Launch auto-init | prohibited |
| Commercial license | pending |
| Model redistribution | pending |
| Release product exposure | blocked until all gates pass |

---

## Gate (canShipAsProductFeature)

All 5 must be `true` before shipping as a product feature:

1. `koreanQualityAccepted` — Korean quality verified
2. `licenseVerified` — Official LICENSE / model card confirmed
3. `localRuntimeVerified` — Local Mac runtime verified
4. `bundlePolicyAccepted` — Model bundle redistribution policy confirmed
5. `releaseIntegrationApproved` — Release integration approved

Current: all `false`. Release product exposure is blocked until all gates pass.

---

## Routing

```swift
// TTSRoutingPolicy.selectedProvider()
// Supertonic3 (isEnabled && modelAvailable) → .supertonic3
// nil → silent
// Apple TTS: permanently forbidden
```

---

## Not Allowed

- Fallback TTS
- Apple TTS / AVSpeechSynthesizer (permanently forbidden, including as fallback)
- Product TTS exposure before license verification
- Model bundle before redistribution policy is confirmed
- ONNX files committed to git
- Supertonic launch auto-init
- Claiming production readiness or verified runtime status before all gates pass
