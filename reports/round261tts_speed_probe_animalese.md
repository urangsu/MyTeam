# Round 261TTS Speed Probe and Animalese QA Report

**날짜:** 2026-05-23
**브랜치:** cloud/round252-supertonic-license-lock
**기준 커밋:** 8589b8f (Round 260B 후속)

---

## Purpose

1. Supertonic3 speed 파라미터가 합성 duration에 실제로 반영되는지 계측.
2. Supertonic TTS와 완전히 분리된 절차적(procedural) Animalese blip speech 엔진 추가.

---

## Speed Probe

### 계측 방식

`probeSpeedApplication(text:preset:)` — testSpeeds `[0.70, 1.00, 1.30, 2.00]`에 대해 각각 합성을 실행하고 durationSec/sampleCount/elapsedMs/realtimeFactor를 기록. 재생 없음. WAV 저장 없음.

### 기대 결과

```
S 0.70 durationSec > S 1.00 durationSec > S 1.30 durationSec > S 2.00 durationSec
```

이 순서가 유지되면 "✅ Speed 적용됨", 깨지면 "⚠️ Speed 의심" 판정.

### 구현

| 파일 | 변경 |
|------|------|
| `SupertonicSpeedProbe.swift` (신규) | `SupertonicSpeedProbeResult` + `verifyOrdering()` + `verdictSummary()` |
| `SpeechManager.probeSpeedApplication()` (추가) | 4개 speed 순차 합성, AppLog 기록 |
| `TTSLabView.speedProbeSection` (추가) | 문장 입력, 계측 버튼, 결과 표(Speed/Duration/Samples/RTF/비교) |

---

## Animalese Synthesizer

### 설계 원칙

- Nintendo/Animal Crossing 원본 사운드 샘플 사용 **금지**.
- YouTube 오디오 추출 **금지**.
- 자체 sine/triangle/squareSoft/noiseBlend 파형만 사용 (procedural).
- `Supertonic3ONNXRunner` 완전 독립. 모델 없어도 동작.
- TTS Lab 테스트 전용. 기본 채팅 발화에 사용하지 않음.

### 엔진 구조

```
AnimaleseSynthesizer.synthesize(text:config:) -> [Float]
  ├── isVoicedChar(): 한글/영문/숫자 → blip 1개
  ├── isPunctuation(): 공백/구두점 → gap
  ├── frequency(for:config:index:): Unicode scalar → major scale degree → freq + jitter
  └── generateBlip(frequency:duration:attack:release:sampleRate:waveform:): ADSR envelope
```

### 프로필 5종

| Profile | base freq | charDuration | waveform |
|---------|-----------|--------------|----------|
| Cute 🌸 | 620 Hz | 40ms | Triangle |
| Calm 🌊 | 430 Hz | 55ms | Triangle |
| Deep 🌲 | 300 Hz | 60ms | Triangle |
| Robot 🤖 | 520 Hz | 40ms | SquareSoft |
| Tiny ✨ | 760 Hz | 35ms | Sine |

### 구현

| 파일 | 변경 |
|------|------|
| `AnimaleseSynthesizer.swift` (신규) | `AnimaleseWaveform` + `AnimaleseVoiceProfile` + `AnimaleseConfig` + `AnimaleseSynthesizer` |
| `SpeechManager.previewAnimalese()` (추가) | `AnimaleseSynthesizer.synthesize` → `AudioPlaybackService.playFloatSamples` |
| `TTSLabView.animaleseSection` (추가) | 문장/Profile/Speed/PitchOffset 슬라이더 + 재생 버튼 |

---

## 빌드 검증

```
Debug:   ✅ BUILD SUCCEEDED
Release: ✅ BUILD SUCCEEDED
```

빌드 수정:
- `ForEach(Array(speedProbeResults.enumerated()), ...)` — SwiftUI 타입추론 실패 → `ForEach(speedProbeResults) { r in speedProbeRow(r, results:) }` helper 분리

---

## Preflight 결과

| 스크립트 | 결과 |
|---------|------|
| `preflight_round258tts_character_voice_system.sh` | ✅ 38/38 PASS |
| `preflight_round259tts_voice_tuner.sh` | ✅ 22/22 PASS |
| `preflight_round260btts_official_speed_range.sh` | ✅ 18/18 PASS |
| `preflight_round261tts_speed_probe_animalese.sh` | ✅ 22/22 PASS |

---

## 불변 규칙 준수

- ✅ 치코 role "UX 디자이너 & 온보딩 도우미" 보존
- ✅ Nintendo/AC 원본 샘플 없음
- ✅ AnimaleseSynthesizer — 외부 파일 로드 없음 (Bundle/AudioFile 호출 없음)
- ✅ previewAnimalese — Supertonic3ONNXRunner 호출 없음
- ✅ Apple TTS / fallback TTS 없음
- ✅ auto speak 기본 OFF 유지
- ✅ ONNX/WAV 파일 커밋 없음

---

## Manual QA 체크리스트

- [ ] TTS Lab → "Speed 적용 계측" — 계측 버튼 클릭 후 결과 표 확인
  - [ ] durationSec 순서: S 0.70 > 1.00 > 1.30 > 2.00 인지 확인
  - [ ] "✅ Speed 적용됨" 판정 표시 확인
- [ ] TTS Lab → "Animalese" — 프로필 5종 청감 비교
  - [ ] Cute: 높고 빠른 blip
  - [ ] Calm: 낮고 느린 blip
  - [ ] Deep: 가장 낮은 톤
  - [ ] Robot: 사각파 질감
  - [ ] Tiny: 가장 높고 짧은 blip
- [ ] Speed 슬라이더 0.5~2.0 범위 조작 시 발화 속도 변화 확인
- [ ] PitchOffset 슬라이더 조작 시 전체 pitch 이동 확인
- [ ] 기본 채팅 발화에 Animalese 미사용 확인
