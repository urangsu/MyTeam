# Round 262TTS Animalese Speech-like Engine

**날짜:** 2026-05-23
**브랜치:** cloud/round252-supertonic-license-lock

---

## Problem

Round 261 Animalese sounded like melody/Tetris blips because each character was mapped to a major-scale blip.

## Change

- Removed major-scale pitch mapping.
- Added Korean syllable decomposition.
- Added consonant transient, vowel color, final tail.
- Added speech-like contour and phrase pause.
- Added speech/effect profile split.
- Added audio feature snapshot for click/ZCR QA.

## Manual QA

- Does it still sound like notes?
- Does it feel more like speech-like syllables?
- Are pauses natural?
- Are clicks reduced?
- Which profile is most usable?

## Safety

- No Nintendo samples.
- No YouTube audio extraction.
- Procedural synthesis only.
- No fallback TTS.
- Auto speak remains OFF.
- Chiko role preserved.

