# BubbleSpeech Character Language QA

Last updated: 2026-07-12
Branch: `codex/tts-runtime-hardening-p0`

## Scope

BubbleSpeech remains an optional effect over one Supertonic3 synthesis pass. It must preserve the visible wording, use no external game audio, and fail rather than report an unmodified passthrough as a successful effect render.

The automatic policy is:

- Short character lines: strong effect.
- Medium dialogue: medium effect.
- Numeric or business-data lines: light effect.
- Long or structured business answers: normal Supertonic3 voice.

## Listening Matrix

Do not change `BLOCKED` to `PASS` without listening to the current build and recording the tester, commit, and date.

| Character | Short statement | Short question | Numeric line | Long-answer bypass | Identity distinct | Status |
| --- | --- | --- | --- | --- | --- | --- |
| Leo | Not run | Not run | Not run | Not run | Not run | BLOCKED |
| Luna | Not run | Not run | Not run | Not run | Not run | BLOCKED |
| Moko | Not run | Not run | Not run | Not run | Not run | BLOCKED |
| Pin | Not run | Not run | Not run | Not run | Not run | BLOCKED |
| Chiko | Not run | Not run | Not run | Not run | Not run | BLOCKED |
| Agent 6 | Not run | Not run | Not run | Not run | Not run | BLOCKED |
| Agent 7 | Not run | Not run | Not run | Not run | Not run | BLOCKED |
| Agent 8 | Not run | Not run | Not run | Not run | Not run | BLOCKED |
| Agent 9 | Not run | Not run | Not run | Not run | Not run | BLOCKED |
| Agent 10 | Not run | Not run | Not run | Not run | Not run | BLOCKED |
| Agent 11 | Not run | Not run | Not run | Not run | Not run | BLOCKED |

## Pass Criteria

1. The effect sounds like a compact character language while retaining roughly 20-40% lexical intelligibility for short lines.
2. Questions have a perceptibly different contour from statements.
3. Characters are distinguishable by rhythm and color, not pitch alone.
4. Numeric and business-data lines remain understandable.
5. Long answers use normal Supertonic3 voice without a sudden failure or fake effect-success message.
6. No clicks, non-finite samples, unsafe peaks, or unexplained silence occur.
7. The spoken wording matches the visible bubble.

## Current Evidence

- Granular renderer and policy XCTest: 20 tests passed on 2026-07-12.
- `validate_tts_runtime_truth.py`: passed on 2026-07-12.
- Debug build: passed on 2026-07-12.
- Manual listening: not run.
