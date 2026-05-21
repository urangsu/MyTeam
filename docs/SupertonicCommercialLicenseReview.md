# Supertonic Commercial License Review

## Status

| Item | Status |
|---|---|
| TTS candidate | Supertonic only |
| Commercial product use | Pending compliance review |
| Model redistribution | Pending compliance review |
| App bundle distribution | Blocked until approved |
| Release user-facing exposure | Blocked until all product gates pass |
| Default TTS | None |
| Fallback TTS | None |

## Current Decision

Supertonic remains the only TTS candidate for MyTeam.

MyTeam must not claim product readiness, commercial readiness, App Store readiness, or model redistribution approval until the required license and distribution checks are complete.

If Supertonic fails quality, runtime, license, bundle, or release gates, MyTeam v1 ships without TTS.

## Verified Inputs To Review

The upstream public materials indicate that SupertonicTTS is a research/demo TTS system and that the local integration uses the Supertonic3 ONNX model files. The MyTeam repository must treat upstream license details as compliance inputs, not as automatic product approval.

## Required Before Product Use

Before Supertonic can become a release feature, all of the following must be documented:

1. Official LICENSE file or model card terms for the exact model files used by MyTeam.
2. Commercial use permission.
3. Weight/model redistribution permission.
4. App bundle distribution permission.
5. Attribution requirements.
6. Prohibited-use or acceptable-use restrictions.
7. Any generated-audio restrictions.
8. App Store distribution compatibility.
9. Internal approval that MyTeam can satisfy the license obligations in product UX/docs.

## Product Gate

Supertonic can ship only when all gates are true:

- `koreanQualityAccepted`
- `licenseVerified`
- `localRuntimeVerified`
- `bundlePolicyAccepted`
- `releaseIntegrationApproved`

Current state: all product gates remain false.

## Not Allowed Until Gate Passes

- Release user-facing TTS controls.
- Default TTS provider.
- Fallback TTS provider.
- Model files committed to git.
- Model files bundled into the app.
- Launch-time Supertonic initialization.
- Product or App Store readiness claims.
- Commercial readiness claims.

## Allowed Scope

- TTS Lab / experimental validation.
- Local user-selected model directory.
- Runtime and quality measurement.
- Documentation of benchmark results.

## Final Policy

Supertonic or no TTS.

MyTeam does not add another low-quality Korean TTS fallback. If Supertonic does not pass the product gates, the correct product decision is to remove TTS from MyTeam v1.