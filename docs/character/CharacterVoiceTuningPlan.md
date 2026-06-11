# Character Voice Tuning Plan

Date: 2026-06-10

Purpose: record the current Supertonic3 character voice settings before changing them, and define the next tuning pass for a warmer, softer, more character-like speech experience.

## Non-Negotiable Rules

- Supertonic3 remains the main TTS engine.
- BubbleSpeech / "뽀글뽀글 말하기" remains an effect layer on top of generated Supertonic3 character voice.
- Do not add Apple TTS, ElevenLabs, Chatterbox, Qwen TTS, or MLX TTS fallback.
- TTS must speak the same wording shown in the chat bubble. Do not rewrite endings, summarize, or substitute words in the TTS path.
- Pauses should be implemented through chunking, timing, or prosody-safe spacing policy, not by changing the visible message text.
- Any profile change needs live audio QA before it is called final.

## Current Baseline

| Character | Agent | Preset | Pitch | Rate | Speed | Emotion | Current Issue |
|---|---:|---:|---:|---:|---:|---|---|
| Leo | agent_1 | M1 | -80 | 0.96 | 1.00 | confident | User wants Kay voice swapped with Leo |
| Luna | agent_2 | F1 | 80 | 1.03 | 1.04 | excited | Acceptable baseline |
| Pin | agent_4 | F4 | 90 | 1.06 | 1.06 | friendly | Too fast |
| Chiko | agent_5 | F2 | 90 | 1.05 | 1.06 | friendly | Starts okay, later phrases feel too fast |
| Rex | agent_6 | M3 | -110 | 0.94 | 0.96 | careful | User requests 0.5x speed |
| Kay | agent_7 | M2 | -60 | 0.99 | 1.02 | neutral | Swap voice identity with Leo |
| Lacky | agent_8 | M4 | 40 | 1.04 | 1.05 | confident | Needs more excited feeling |
| Mongmong | agent_10 | F3 | 90 | 1.06 | 1.04 | friendly | Too calm; should feel more buoyant |
| Oliver | agent_11 | M5 | -50 | 0.97 | 0.99 | careful | Too calm and stiff; should be much brighter |

## Proposed Tuning Pass

| Character | Proposed Change | Rationale |
|---|---|---|
| Leo | Use Kay's M2 preset; keep stable pitch/rate around `-60 / 0.98 / 1.00` | User asked to bring Kay's voice to Leo. Keep Leo strategic, but less heavy than current M1. |
| Kay | Use Leo's M1 preset; set around `-80 / 0.97 / 1.00` | Completes the swap without changing persona text. |
| Pin | Lower to around `pitch 75`, `rate 1.00`, `speed 0.99`; reduce emotion speed boost | Pin is perceived as too fast. Slow the synthesis first, not only playback. |
| Chiko | Lower to around `pitch 80`, `rate 1.00`, `speed 1.00`; add phrase-level pause chunking after commas/short greetings | The first phrase sounds fine, later text accelerates. Chunking is safer than rewriting text. |
| Rex | Safe target: `speed 0.70`, `rate 0.90`, pitch around `-100`; true 0.5x requires lowering playback clamp | Current code clamps synthesis speed at 0.70 and playback rate at 0.90. Actual 0.5x is a policy/runtime change, not a simple profile edit. |
| Lacky | Increase energy with `pitch 55`, `rate 1.05`, `speed 1.06`, default emotion `.excited` | More excited without pushing pitch past artifact-prone range. |
| Mongmong | Use buoyant profile around `pitch 105`, `rate 1.04`, `speed 1.03`, emotion `.excited`; test end-of-phrase artifact | Needs more animated character feel, but high pitch may worsen end artifacts. |
| Oliver | Brighten with `pitch 10...20`, `rate 1.01`, `speed 1.02`, emotion `.friendly` | Move away from stiff QA voice while keeping clarity. |

## Prosody Plan

Current product speech keeps the visible text unchanged and normalizes whitespace only. That protects trust, but gives no extra breathing room for Korean phrases.

Next safe change:

- Keep chat bubble text unchanged.
- Split TTS synthesis chunks at stronger phrase boundaries: `.`, `?`, `!`, newline, and selected comma/short interjection boundaries.
- Do not insert different words, endings, or hidden punctuation.
- For examples like `어머, 안녕. 오늘 ...`, synthesize `어머, 안녕.` as one short chunk, then use smaller phrase chunks after that instead of one long fast remainder.

## Bug Fixes To Keep

- Single-shot `SpeechManager.speak(...)` should cancel any previous TTS task before starting a new one.
- SpriteKit character views should not receive hover scale on top of internal scene scaling.
- `SpriteAgentView` scene size should track the actual SwiftUI view size.

## QA Checklist

- Compare before/after samples for Luna, Pin, Chiko, Rex, Kay, Leo, Lacky, Mongmong, Oliver.
- Use the same sentence for all: `어머, 안녕. 오늘은 작업 흐름을 조금 더 부드럽게 맞춰볼게요.`
- Record whether the voice is too fast, too metallic at phrase endings, too stiff, or too synthetic.
- Do not mark tuning complete until live audio confirms the result.
