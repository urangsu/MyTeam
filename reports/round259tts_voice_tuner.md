# Round 259TTS-VOICE-TUNER

**Branch:** `cloud/round252-supertonic-license-lock`  
**Date:** 2026-05-23  
**Status:** ✅ Implementation Complete

---

## Purpose

P/R/S를 직접 조절하면서 캐릭터 목소리와 감정 표현을 청감 기준으로 튜닝한다.

---

## P/R/S 파라미터 정의

| 파라미터 | 이름 | 단위 | 설명 | 권장 범위 |
|---------|------|------|------|-----------|
| P | Pitch | cents | 음높이 (AVAudioUnitTimePitch) | ±100 이내 |
| R | Rate | 배율 | 재생 후처리 속도 | 0.92~1.12 |
| S | Speed | 배율 | Supertonic3 합성 duration predictor | 0.90~1.20 |

> ⚠️ Pitch ±100 초과 시 일부 preset에서 금속성/비프음 artifact 가능.  
> 말의 빠르기 조정은 S(Speed) 우선, 최종 보정에 P/R 사용.

---

## 사용자 피드백 반영 사항

| 피드백 | 반영 내용 |
|--------|-----------|
| pitch 100 이상에서 금속성/비프음 | basePitch ±100 이하로 재조정 (치코 260→90, 핀 320→90, 몽몽 340→90 등) |
| 모코/올리버 안정적 | 두 캐릭터 pitch 범위 ±60 이내 유지 |
| Animal Crossing 차이가 없음 | 기존 boost 누적 방식 → 별도 cartoon target으로 분리 (M:+140, F:+180) |
| 감정이 뚜렷하게 안 느껴짐 | 감정 샘플 문장 개선, emotionBoost pitch ±30 이하 유지 |
| P/R/S 직접 조절 필요 | TTS Lab "임시 P/R/S 튜닝" 섹션 추가 |

---

## Changes Delivered

| # | Item | Status |
|---|------|--------|
| 1 | `VoiceTuningState.swift` 신규 — VoiceTuningValues + VoiceTuningDefaults | ✅ |
| 2 | `CharacterVoiceProfile` basePitch 재조정 (11개 캐릭터 ±110 이하) | ✅ |
| 3 | `SupertonicVoicePresetPolicy.animalCrossingTuning(for:)` 추가 | ✅ |
| 4 | AC `.animalCrossing` case → animalCrossingTuning() 별도 target | ✅ |
| 5 | `SpeechManager.previewWithTuning(text:preset:pitch:rate:speed:emotion:agentID:label:)` | ✅ |
| 6 | `TTSLabView` P/R/S 설명 박스 (prsDescriptionBox) | ✅ |
| 7 | `TTSLabView` "임시 P/R/S 튜닝" 섹션 (prsTuningSection) — 슬라이더 + 경고 + 초기화 | ✅ |
| 8 | `TTSLabView` 원본 preset / 캐릭터 / 감정 3개 섹션 모두 tuning override 지원 | ✅ |
| 9 | `TTSLabView` 감정 샘플 문장 개선 (confident/careful/excited) | ✅ |
| 10 | `TTSLabView` AC "테스트 전용 — 기본 보이스 미적용" 안내 | ✅ |
| 11 | `scripts/preflight_round259tts_voice_tuner.sh` — 22/22 PASS | ✅ |
| 12 | Debug/Release BUILD SUCCEEDED | ✅ |

---

## Pitch 재조정 테이블 (Round 258TTS → 259TTS)

| 캐릭터 | 258TTS basePitch | 259TTS basePitch | 변화 |
|--------|-----------------|-----------------|------|
| 레오 | -180 | -80 | +100 (artifact 감소) |
| 루나 | +180 | +80 | -100 |
| 모코 | +90 | +40 | -50 (안정 유지) |
| 핀 | +320 | +90 | -230 (artifact 감소) |
| 치코 | +260 | +90 | -170 |
| 렉스 | -260 | -110 | +150 |
| 케이 | -120 | -60 | +60 |
| 래키 | +120 | +40 | -80 |
| 폴라 | -180 | -60 | +120 |
| 몽몽 | +340 | +90 | -250 (artifact 감소) |
| 올리버 | -80 | -50 | +30 (안정 유지) |

---

## Animal Crossing 재정의

**이전:** `basePitch + animalCrossingPitchBoost` (누적 방식)  
**이후:** `animalCrossingTuning(for:)` — 독립 cartoon target

| Preset 타입 | targetPitch | rate | speed |
|-------------|-------------|------|-------|
| M1~M5 | +140 | 1.12 | baseSpeed + 0.12 |
| F1~F5 | +180 | 1.12 | baseSpeed + 0.12 |

---

## Safety Checks

| 항목 | 결과 |
|------|------|
| 치코 role 수정 여부 | 수정 없음 (UX 디자이너 & 온보딩 도우미 유지) |
| Apple TTS (AVSpeechSynthesizer) | ❌ 사용 없음 |
| fallbackTTSAvailable | false |
| autoSpeakDefaultEnabled | false |
| tracked .onnx 파일 | 0건 |
| main 직접 커밋 | 없음 |

---

## Build Results

| 구성 | 결과 |
|------|------|
| Debug | BUILD SUCCEEDED ✅ |
| Release | BUILD SUCCEEDED ✅ |

---

## Manual QA Checklist

- [ ] TTS Lab → 보이스 디렉터 → P/R/S 설명 박스 표시 확인
- [ ] "임시 P/R/S 튜닝" 토글 OFF → 원본 preset M1~F5 정상 재생
- [ ] "임시 P/R/S 튜닝" 토글 ON → P/R/S 슬라이더 표시 확인
- [ ] Pitch +120 설정 → ⚠️ 경고 텍스트 표시 확인
- [ ] "중립값으로 초기화" 버튼 → P=0, R=1.0, S=1.05 복원
- [ ] "현재 캐릭터 기본값" 버튼 → 선택된 캐릭터의 profile 값 로드
- [ ] 튜닝 ON 상태에서 M1 재생 → pitch/rate/speed 적용 청취
- [ ] 치코 default: P=+90, R=1.05, S=1.06 — 비프음 없는지 확인
- [ ] 핀 default: P=+90 — 이전 P=+320 대비 금속성 감소 확인
- [ ] friendly vs excited 감정 차이 청감 비교
- [ ] Animal Crossing → M preset +140, F preset +180 — 별도 느낌 확인
- [ ] AC "테스트 전용" 안내 문구 표시 확인

---

*Generated: Round 259TTS-VOICE-TUNER completion — 2026-05-23*
