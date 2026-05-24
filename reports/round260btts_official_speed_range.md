# Round 260B-TTS-OFFICIAL-SPEED-RANGE QA Report

**날짜:** 2026-05-23  
**브랜치:** cloud/round252-supertonic-license-lock  
**기준 커밋:** cb8cc20 (Round 259TTS)

---

## 구현 요약

Supertonic3 공식 speed 범위(0.70~2.00) 적용 및 Expression Tag A/B 테스트 인프라 구축.

| 항목 | 내용 |
|------|------|
| speed 범위 | 0.70~2.00 (기존 0.90~1.20 → 공식 범위로 확장) |
| speed 존 | 권장 0.90~1.30 / 실험 1.30~1.60 / 특수효과 1.60~2.00 |
| Expression Tags | `<laugh>` / `<breath>` / `<sigh>` A/B 테스트 섹션 |
| Animal Crossing | speed-first 재정의 (1.35~1.60, pitch M:+120/F:+160) |
| 수정 파일 | 6개 기존 파일 + 1개 신규 파일 |

---

## 신규/수정 파일

### 신규
- `MyTeam/SupertonicExpressionTagPolicy.swift` — expression tag 3종 + 감정→tag 매핑 정책

### 수정
| 파일 | 변경 내용 |
|------|-----------|
| `MyTeam/VoiceTuningState.swift` | speedRange 0.70~2.00, 존/경고 상수 추가 |
| `MyTeam/Supertonic3ONNXRunner.swift` | safeSpeed clamp → min(2.00, max(0.70, speed)) |
| `MyTeam/SupertonicProsodyTextProcessor.swift` | useExpressionTags: Bool 파라미터 추가 |
| `MyTeam/SpeechManager.swift` | previewWithTuning useExpressionTags 파라미터 추가 |
| `MyTeam/SupertonicVoicePresetPolicy.swift` | animalCrossingTuning speed-first (1.35~1.60) 재정의 |
| `MyTeam/TTSLabView.swift` | S 슬라이더 존 배지+경고 3종, Expression Tags A/B 섹션 추가 |

---

## Speed Zone 정책

| Zone | 범위 | UI 표시 | 경고 |
|------|------|---------|------|
| 권장 | 0.90~1.30 | 🟢 초록 "권장" | 없음 |
| 실험 | 1.30~1.60 | 🟠 주황 "실험" | ⚠️ "효과음 느낌" |
| 특수효과 | 1.60~2.00 | 🔴 빨강 "특수효과" | 🚨 "일반 캐릭터 비권장" |
| 하한 경고 | <0.80 | — | ⚠️ "발음 흐려짐" |

---

## Expression Tags A/B 테스트

| 감정 | 권장 태그 | 적용 조건 |
|------|-----------|-----------|
| friendly | `<breath>` | formal/numeric 아닐 때 |
| careful | `<breath>` | formal/numeric 아닐 때 |
| excited | `<laugh>` | formal/numeric 아닐 때 |
| animalCrossing | `<laugh>` | formal/numeric 아닐 때 |
| neutral, confident | 없음 | 항상 |

TTS Lab에서 각 감정에 대해 "없음" / "태그 있음" 두 버튼으로 A/B 비교 가능.  
**기본 발화(speakOnce, dispatchToInferencePipeline)에는 태그 미적용.**

---

## Animal Crossing 재튜닝

| 파라미터 | Round 259 | Round 260B |
|----------|-----------|------------|
| pitch (M) | +140 | +120 |
| pitch (F) | +180 | +160 |
| rate | 1.12 | 1.08 |
| speed | baseSpeed + 0.35 (max 1.60) | min(1.60, max(1.35, base+0.35)) |
| 전략 | pitch+rate 중심 | speed 중심 (1.35~1.60 안정 범위) |

---

## 빌드 검증

```
xcodebuild Debug:   ✅ BUILD SUCCEEDED
xcodebuild Release: ✅ BUILD SUCCEEDED
```

빌드 수정 사항:
- `TTSLabView.swift:832`: `.font(.system(size:design:weight:))` → `.font(.system(size:weight:design:))` 인수 순서 수정
- `scripts/preflight_round259tts_voice_tuner.sh` check [1]: `grep -A 20` → `grep -A 30` (윈도우 확장)

---

## Preflight 결과

| 스크립트 | 결과 |
|---------|------|
| `preflight_round258tts_character_voice_system.sh` | ✅ 38/38 PASS |
| `preflight_round259tts_voice_tuner.sh` | ✅ 22/22 PASS |
| `preflight_round260btts_official_speed_range.sh` | ✅ 18/18 PASS |

---

## 불변 규칙 준수

- ✅ 치코 role "UX 디자이너 & 온보딩 도우미" 보존 (수정 없음)
- ✅ Apple TTS 없음
- ✅ fallback TTS 없음
- ✅ auto speak 기본 OFF 유지
- ✅ Expression Tags는 TTS Lab 전용, 기본 발화 미적용
- ✅ ONNX/WAV 파일 commit 없음
