# Supertonic Use Restriction Policy

## Round 254TTS-NOTICE Update (2026-05-22)

TTS Lab notice gate implemented. Key additions:

- `SupertonicTTSNoticePolicy.swift`: centralizes notice version, UserDefaults keys, accept/reset
- `SupertonicNoticeCardView.swift`: license notice + use restriction card shown in TTSLabView
- ONNX synthesis disabled until notice accepted (`!noticeAccepted` in disabled condition)
- Notice version `round254-2026-05` — version bump triggers re-acceptance
- Release user-facing TTS remains locked (`TTSProductPolicy.userFacingTTSEnabled = false`)
- `scripts/preflight_round254tts_notice.sh`: 18/18 checks pass

---

## Purpose

This document defines the product guardrails required before Supertonic TTS can become a user-facing MyTeam feature.

Supertonic is the only TTS candidate. The model license allows product planning under license conditions, but the app must implement safe-use notice and release guardrails before enabling TTS outside TTS Lab.

## Product Scope

Allowed intended use:

- MyTeam assistant voice feedback.
- User-owned workflow narration.
- Local workroom assistant responses.
- Non-deceptive AI character voice within the app.
- Optional productivity feedback when the user intentionally enables TTS.

Not allowed:

- Impersonating a real person without consent.
- Generating deceptive audio that misrepresents identity, affiliation, or events.
- Harassment, threats, or abusive targeting.
- Unlawful use, fraud, or evasion.
- Extracting, disclosing, or weaponizing personal information.
- Using TTS to conceal that output is machine generated where disclosure is necessary.

## Required UX Before Release

Before release exposure, MyTeam must provide:

1. A TTS settings notice explaining that the voice is AI-generated.
2. A license and attribution screen mentioning Supertonic / Supertone Inc. and the applicable model license.
3. A short prohibited-use notice near the enable toggle or first-use flow.
4. No default auto-enable.
5. No launch-time model load.
6. A clear off switch.
7. Local model storage/distribution explanation.

## Required Technical Guards

- TTS is disabled by default.
- Supertonic does not auto-initialize on app launch.
- TTS cannot become a fallback for failed text output.
- TTS is not exposed in release UI until all release gates pass.
- Model files are not committed to git without an explicit distribution decision.
- Generated audio stays local unless the user explicitly exports or shares it.

## Release Gate

The following must be true before release exposure:

- Korean quality accepted.
- Local runtime benchmark documented.
- Bundle or user-selected model policy approved.
- License notice and attribution implemented.
- Use-restriction notice implemented.
- Release UX approved.

## Product Decision

Supertonic or no TTS.

MyTeam must not add another low-quality TTS fallback. If Supertonic fails release gates, MyTeam v1 ships without TTS.
