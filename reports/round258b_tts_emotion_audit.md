# Round 258B-TTS-EMOTION-AUDIT — QA Report

**Branch:** `cloud/round252-supertonic-license-lock`  
**Date:** 2026-05-23  
**Status:** ✅ Implementation Complete

---

## Summary

Round 258B adds emotion-aware prosody to the Supertonic3 TTS pipeline. Each character
now has a `defaultEmotionStyle`, and pitch/rate/speed are adjusted per emotion at synthesis time.
The Voice Director UI separates raw preset preview from character+emotion preview.

---

## Changes Delivered

| # | Item | Status |
|---|------|--------|
| 1 | `CharacterVoiceProfile.emotionSpeedBoost` 필드 추가 | ✅ |
| 2 | `SupertonicVoicePresetPolicy.emotionStyle(for:)` 추가 | ✅ |
| 3 | `pitch/rate/speed(for:emotion:)` emotion-aware API 추가 | ✅ |
| 4 | `SpeechManager` → emotion-aware API 적용 (dispatch + speakOnce) | ✅ |
| 5 | `SpeechManager.previewPreset()` — 원본 preset, pitch=0/rate=1/neutral | ✅ |
| 6 | `SpeechManager.previewCharacterEmotion()` — 캐릭터+감정 full preview | ✅ |
| 7 | `TTSLabView` 보이스 디렉터: "원본 Preset 테스트" + "감정 표현 테스트" | ✅ |
| 8 | `AgentWindowManager.swapAgent()` → `syncSelectedTeamWorkroomAgents()` 추가 | ✅ |
| 9 | `AgentSwapView` → `replaceTeamAgent(at:with:)` 사용 | ✅ |
| 10 | 치코 role 유지 ("UX 디자이너 & 온보딩 도우미") — 이번 라운드 수정 없음 | ✅ |
| 11 | Preflight 22 → 38 checks 확장 | ✅ |

---

## Emotion-Aware Prosody Matrix

### Pitch Delta (cents) per Emotion Style

| 캐릭터 | base | neutral | careful | friendly | confident | excited | AC mode |
|--------|------|---------|---------|----------|-----------|---------|---------|
| 레오 (M1) | -180 | -180 | -200 | -160 | -160 | -160 | +20 |
| 루나 (F1) | +180 | +180 | +160 | +220 | +220 | +220 | +460 |
| 모코 (F3) | +90 | +90 | +70 | +110 | +110 | +110 | +310 |
| 핀 (F4) | +320 | +320 | +290 | +370 | +370 | +370 | +580 |
| 치코 (F2) | +260 | +260 | +230 | +310 | +310 | +310 | +520 |
| 렉스 (M3) | -260 | -260 | -290 | -230 | -230 | -230 | -40 |
| 케이 (M2) | -120 | -120 | -120 | -120 | -120 | -120 | +100 |
| 래키 (M4) | +120 | +120 | +100 | +150 | +150 | +150 | +360 |
| 폴라 (F5) | -180 | -180 | -190 | -170 | -170 | -170 | +60 |
| 몽몽 (F3) | +340 | +340 | +310 | +390 | +390 | +390 | +600 |
| 올리버 (M5) | -80 | -80 | -80 | -80 | -80 | -80 | +140 |

> ⚠️ Animal Crossing (AC) mode는 기본 미사용. 강한 부스트 — 테스트 전용.
> ⚠️ 클램프: pitch -300 ~ +360 cents 적용됨.

### Rate Delta per Emotion Style

| 캐릭터 | base | neutral | careful | friendly | confident | excited |
|--------|------|---------|---------|----------|-----------|---------|
| 레오 | 0.94 | 0.94 | 0.94 | 0.97 | 0.97 | 0.97 |
| 루나 | 1.03 | 1.03 | 0.99 | 1.07 | 1.07 | 1.07 |
| 모코 | 0.97 | 0.97 | 0.97 | 0.97 | 0.97 | 0.97 |
| 핀 | 1.10 | 1.10 | 1.06 | 1.14 | 1.14 | 1.14 |
| 치코 | 1.08 | 1.08 | 1.04 | 1.12 | 1.12 | 1.12 |
| 렉스 | 0.92 | 0.92 | 0.91 | 0.93 | 0.93 | 0.93 |
| 케이 | 0.98 | 0.98 | 0.98 | 0.98 | 0.98 | 0.98 |
| 래키 | 1.06 | 1.06 | 1.04 | 1.09 | 1.09 | 1.09 |
| 폴라 | 0.94 | 0.94 | 0.93 | 0.95 | 0.95 | 0.95 |
| 몽몽 | 1.12 | 1.12 | 1.08 | 1.14 | 1.14 | 1.14 |
| 올리버 | 0.96 | 0.96 | 0.96 | 0.96 | 0.96 | 0.96 |

> ⚠️ 클램프: rate 0.90 ~ 1.14 적용됨. 핀/몽몽/치코 excited/friendly는 1.14에 클램프됨.

### Speed Delta per Emotion Style

| 캐릭터 | base | neutral | careful | friendly | confident | excited |
|--------|------|---------|---------|----------|-----------|---------|
| 레오 | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 |
| 루나 | 1.05 | 1.05 | 1.02 | 1.08 | 1.08 | 1.08 |
| 모코 | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 |
| 핀 | 1.08 | 1.08 | 1.05 | 1.11 | 1.11 | 1.11 |
| 치코 | 1.05 | 1.05 | 1.02 | 1.08 | 1.08 | 1.08 |
| 렉스 | 0.95 | 0.95 | 0.94 | 0.95 | 0.95 | 0.95 |
| 케이 | 1.02 | 1.02 | 1.02 | 1.02 | 1.02 | 1.02 |
| 래키 | 1.05 | 1.05 | 1.03 | 1.07 | 1.07 | 1.07 |
| 폴라 | 1.03 | 1.03 | 1.02 | 1.04 | 1.04 | 1.04 |
| 몽몽 | 1.00 | 1.00 | 0.97 | 1.03 | 1.03 | 1.03 |
| 올리버 | 0.98 | 0.98 | 0.98 | 0.98 | 0.98 | 0.98 |

> ⚠️ 클램프: speed 0.85 ~ 1.25 적용됨.

---

## Safety Checks

| 항목 | 결과 |
|------|------|
| Apple TTS (AVSpeechSynthesizer) | ❌ 사용 없음 |
| fallbackTTSAvailable | false |
| autoSpeakDefaultEnabled | false |
| 치코 role 수정 여부 | 수정 없음 (UX 디자이너 & 온보딩 도우미 유지) |
| tracked .onnx 파일 | 0건 |
| main 직접 커밋 | 없음 |

---

## Build Results

| 구성 | 결과 |
|------|------|
| Debug | BUILD SUCCEEDED |
| Release | BUILD SUCCEEDED |

---

## Manual QA Checklist

- [ ] TTS Lab → 보이스 디렉터 → "원본 Preset 테스트": M1~F5 각 버튼 재생 — 캐릭터 보정 없이 원음
- [ ] TTS Lab → 보이스 디렉터 → "감정 표현 테스트": 캐릭터 Picker → 6개 감정 버튼 각각 재생
- [ ] 감정별 청감: neutral vs excited vs careful 차이 청취 확인
- [ ] 팀원 교체: "팀원 교체하기" 메뉴 → 1~4번 슬롯 서브메뉴 → 각 교체 정상 동작
- [ ] 교체 후 워크룸 agentIDs 동기화 확인 (swapAgent → syncSelectedTeamWorkroomAgents)
- [ ] 중복 방지: 이미 활성화된 에이전트 선택 시 무시
- [ ] 치코 역할 표시: "UX 디자이너 & 온보딩 도우미" 확인

---

*Generated: Round 258B-TTS-EMOTION-AUDIT completion — 2026-05-23*
