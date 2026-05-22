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

## Verified Upstream Facts

The public Hugging Face model page for `Supertone/supertonic-3` states the following facts:

- The model page license badge is `openrail`.
- The project sample code is released under the MIT License.
- The accompanying model is released under the OpenRAIL-M License.
- The model is designed for local ONNX Runtime inference without cloud synthesis calls.
- The model card describes supported Korean output and lists Korean among the supported languages.

These facts are evidence inputs for review. They do not automatically approve MyTeam product release, App Store distribution, model bundling, attribution handling, or restricted-use compliance.

## Required Before Product Use

Before Supertonic can become a release feature, all of the following must be documented:

1. Exact official LICENSE file or model card revision used by MyTeam.
2. Commercial use interpretation for MyTeam's intended app use case.
3. Weight/model redistribution permission.
4. App bundle distribution permission.
5. Attribution requirements.
6. Prohibited-use or acceptable-use restrictions.
7. Generated-audio restrictions, if any.
8. App Store distribution compatibility.
9. Internal approval that MyTeam can satisfy the license obligations in product UX/docs.
10. Korean quality acceptance by the product owner.
11. Local Mac runtime benchmark results.

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
- License evidence collection.

## Final Policy

Supertonic or no TTS.

MyTeam does not add another low-quality Korean TTS fallback. If Supertonic does not pass the product gates, the correct product decision is to remove TTS from MyTeam v1.
