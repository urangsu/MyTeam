# TTS Runtime Quality Audit

Last updated: 2026-07-11
Branch: `codex/tts-runtime-hardening-p0`

## Product Contract

- The spoken text must match the visible chat text.
- Normal speech must not create files on the user's Desktop.
- Playback success means the buffer reached `dataPlayedBack`, not merely that it was scheduled.
- Supertonic3 remains the only MyTeam TTS engine. BubbleSpeech remains an effect over one Supertonic3 synthesis pass.
- Build success is not audio-quality proof. Listening QA remains required.

## P0 Findings And Status

| ID | Finding | Status | Evidence or next action |
| --- | --- | --- | --- |
| TTS-P0-001 | Product preprocessing collapsed whitespace and truncated visible text after 200 characters. | Code fixed, XCTest passed | Exact-text XCTest fixtures and `validate_tts_runtime_truth.py` |
| TTS-P0-002 | Streaming chunk validation rewrote repeated punctuation and whitespace. | Code fixed, XCTest passed | Exact streaming-chunk fixture |
| TTS-P0-003 | `playFloatSamples` returned after scheduling instead of actual playback completion. | Code fixed, manual QA required | Await `dataPlayedBack` with bounded timeout |
| TTS-P0-004 | Normal TTS wrote every synthesis result to Desktop. | Code fixed | Normal paths no longer call `S3WavWriter`; explicit lab artifacts use app cache |
| TTS-P0-005 | A new speech session reset the currently playing session. | Code fixed, manual QA required | Normal lines use FIFO queue; swap/barge-in/stop use ordered interruption; busy-drop is explicit |
| TTS-P0-006 | Supertonic bundle validation checked presence but not support files or hashes. | Code fixed, inference QA required | Bundled support files and SHA-256 manifest are enforced; release-equivalent inference smoke remains open |
| TTS-P0-007 | Speaking sprite state used a 30-second fallback instead of playback lifecycle. | Code fixed, manual QA required | SpeechManager exclusively starts and clears speaking state at playback boundaries |
| TTS-P0-008 | BubbleSpeech used uniform source slicing and was only connected to TTS Lab. | Code fixed, listening QA required | Voice-derived grain bank, character rhythm signatures, adaptive strength, and product playback integration; see `BubbleSpeechCharacterLanguageQA.md` |

## P1 Findings

- ONNX environment, sessions, Unicode index, and voice styles are now actor-isolated and reused across utterances.
- ONNX text encoder output now uses a typed missing-output failure instead of force unwrap.
- Normal PCM now rejects empty, invalid-rate, non-finite, silent, and unsafe-peak output before engine setup.
- Tune Chiko only after removing duplicated synthesis-speed and playback-rate/pitch transforms.
- Remove or merge the unused second character voice configuration source.
- Isolate mutable SpeechManager and audio capture state instead of relying on unchecked sendability.
- Add echo-cancellation and barge-in policy before enabling continuous voice interaction.

## P2 And Product-Wide Risks

- Reduce character-by-character LLM calls to one planning/answer call plus local character presentation.
- Remove duplicate skill-result and team-discussion execution.
- Fix FloatingPanel key swallowing and double drag handling.
- Make team panel layout responsive to available screen size and accessibility text size.
- Artifact Markdown and indexes now use atomic writes, and primary artifact writers fail closed on index registration errors. Corruption recovery and concurrent-save QA remain open.
- Confirm whether macOS 26.2 is an intentional minimum deployment target.

## Additional Code-Only Hardening

- Floating panels now forward keyboard events through the AppKit responder chain.
- Manual background movement no longer invokes AppKit movement a second time.
- Team drag/drop sounds only run after actual pointer movement, not a click.
- Manual panel interaction QA remains required on small displays and with text fields focused.

## Verification Boundary

The app-hosted XCTest runner now suppresses product windows and TTS prewarm during tests. The full local suite executed 68 tests successfully on 2026-07-11. This does not replace listening QA; do not mark TTS manual QA complete until these cases are exercised in the app:

1. Long Korean speech over 200 characters matches the bubble.
2. Two team-member lines do not unexpectedly cut each other off.
3. Speaking animation starts and ends with audible playback.
4. Chiko normal, careful, and excited samples pass listening comparison.
5. Cancellation, app termination, and missing output device do not hang.
6. No normal conversation creates a WAV file on Desktop.
7. BubbleSpeech short, question, numeric, and long-bypass cases pass the 11-character listening matrix.

## Speech Request Policy

- `queue`: default for character dialogue and system lines. Requests are played in FIFO order.
- `interruptCurrent`: reserved for explicit context switches such as character swap.
- `dropIfBusy`: available for nonessential reactions that must not delay active work.
- Barge-in, user stop, and app termination clear pending speech and stop current playback.
- Call sites must not set speaking animation before audible playback starts.
