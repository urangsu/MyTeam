# Supertonic Commercial License Review

## Status

| Item | Status |
|---|---|
| TTS candidate | Supertonic only |
| Model license | OpenRAIL-M |
| Sample code license | MIT |
| Commercial use | Allowed under license conditions |
| Model redistribution | Allowed under license conditions |
| App bundle distribution | Allowed with license notice and use-restriction compliance |
| Release user-facing exposure | Blocked until runtime, quality, and release UX gates pass |
| Default TTS | None |
| Fallback TTS | None |

## Current Decision

Supertonic remains the only TTS candidate for MyTeam.

The license gate is now treated as passable for product planning because the upstream model card states that the model uses OpenRAIL-M and the sample code uses MIT. The release gate remains locked until MyTeam implements the required license notice, use-restriction policy, local runtime benchmark, and product quality approval.

If Supertonic fails quality, runtime, bundle implementation, or release UX gates, MyTeam v1 ships without TTS.

## Verified Upstream Facts

The public Hugging Face model page for `Supertone/supertonic-3` states the following facts:

- The model page license badge is `openrail`.
- The project sample code is released under the MIT License.
- The accompanying model is released under the OpenRAIL-M License.
- The model is designed for local ONNX Runtime inference without cloud synthesis calls.
- The model card lists Korean among the supported languages.

The OpenRAIL-M license grants broad rights to use, reproduce, sublicense, and distribute the model and derivatives, including commercial product use, subject to the license conditions and use-based restrictions.

## Conditions MyTeam Must Implement

Before Supertonic can become a release feature, MyTeam must implement and document:

1. Bundled copy or accessible copy of the OpenRAIL-M license.
2. Copyright and attribution notice for Supertone Inc.
3. Notice that generated audio must not violate the license restrictions.
4. Use-restriction guardrails for impersonation, harmful deception, unlawful use, harassment, and harmful disclosure of personal information.
5. A product disclaimer that TTS output is machine generated where required by context.
6. A model-bundle or user-selected-model distribution plan.
7. Korean quality acceptance by the product owner.
8. Local Mac runtime benchmark results.
9. Release UX approval.

## Product Gate

Supertonic can ship only when all release gates are true:

- `koreanQualityAccepted`
- `localRuntimeVerified`
- `bundlePolicyAccepted`
- `releaseIntegrationApproved`

License evidence is now sufficient for product planning, but release remains blocked until the implementation gates above are complete.

## Not Allowed Until Release Gates Pass

- Release user-facing TTS controls.
- Default TTS provider.
- Fallback TTS provider.
- Model files committed to git without an explicit distribution decision.
- Launch-time Supertonic initialization.
- Product readiness or App Store readiness claims.

## Allowed Scope Now

- TTS Lab / experimental validation.
- Local user-selected model directory.
- Runtime and quality measurement.
- License evidence collection.
- Implementation planning for license notice and use restrictions.

## Final Policy

Supertonic or no TTS.

MyTeam does not add another low-quality Korean TTS fallback. If Supertonic does not pass the release gates, the correct product decision is to remove TTS from MyTeam v1.
