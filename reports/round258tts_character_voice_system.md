# Round 258TTS-CHARACTER-VOICE-SYSTEM QA Report

**날짜:** 2026-05-23  
**브랜치:** cloud/round252-supertonic-license-lock  
**라운드:** 258TTS-CHARACTER-VOICE-SYSTEM — 캐릭터 보이스 아이덴티티 + 감정 운율 + 팀원 교체 버그 수정

---

## 요약

Round 257TTS에서 연결된 재생 파이프라인 위에, 캐릭터별 pitch/rate/speed 아이덴티티,  
경량 텍스트 전처리(prosody), 팀원 교체 슬롯 버그 수정, TTS Lab 보이스 디렉터 UI를 추가.

---

## 구현 항목

### 신규 파일

#### `MyTeam/CharacterVoiceProfile.swift`
- `CharacterVoiceProfile` struct: id, agentID, displayName, preset, basePitch, baseRate, baseSpeed,
  emotionPitchBoost, emotionRateBoost, animalCrossingPitchBoost, animalCrossingRateBoost,
  defaultEmotionStyle, styleNote, sampleLine
- `CharacterVoiceProfileCatalog` enum: 11개 캐릭터 profiles
  - `profile(for agentID:)` — agentID lookup, 루나(F1) fallback
  - `profile(forPreset:)` — preset lookup (TTS Lab 전체 테스트용)
- pitch/rate 값: VoiceStyleCatalog 기존값 계승 (cents 기준)
- Animal Crossing boost: 기본 미사용, 별도 boost 값으로 분리
- defaultEmotionStyle: 캐릭터별 기본 감정 스타일 정의

#### `MyTeam/SupertonicProsodyTextProcessor.swift`
- `SupertonicEmotionStyle`: neutral / friendly / confident / careful / excited / animalCrossing
- `SupertonicProsodyTextProcessor.preprocess(_:agentID:style:)`:
  - 법률/회계/숫자 감지 → neutral 처리 (변환 스킵)
  - 개행→공백, 연속공백 정리
  - friendly + 80자 이하: 공식 표현 소프트 변환
  - 연결어 쉼표 보완 (먼저, 그럼, 그리고 등)
  - 200자 초과 → 200자 + "..." 처리
  - 말풍선 원문은 절대 변경 안 함 — TTS 입력만 처리

### 수정 파일

#### `MyTeam/Supertonic3ONNXRunner.swift`
- `synthesize(...)` 에 `speed: Float = 1.05` 파라미터 추가
- 내부: `let safeSpeed = min(1.25, max(0.85, speed))` clamp 적용
- `durOnnx.map { $0 / safeSpeed }` — 기존 하드코딩 1.05 제거

#### `MyTeam/SupertonicVoicePresetPolicy.swift`
- 기존 switch 제거, `CharacterVoiceProfileCatalog` 기반으로 교체
- `preset(for:)` / `pitch(for:)` / `rate(for:)` / `speed(for:)` / `styleNote(for:)` / `sampleLine(for:)` API 추가

#### `MyTeam/AudioPlaybackService.swift`
- `playFloatSamples(...)` 시그니처에 `pitch: Float = 0.0, rate: Float = 1.0` 추가
- `prepareSession` 호출 시 `clampedPitch(pitch)`, `clampedRate(rate)` 전달
- private `clampedPitch` / `clampedRate` helpers 추가 (범위: pitch -300~+360, rate 0.90~1.14)

#### `MyTeam/SpeechManager.swift`
- `dispatchToInferencePipeline` supertonic3 경로:
  - `SupertonicProsodyTextProcessor.preprocess(text, agentID:)` 적용
  - `SupertonicVoicePresetPolicy.pitch/rate/speed(for:)` 조회
  - `Supertonic3ONNXRunner.synthesize(..., speed:)` 호출
  - `playback.playFloatSamples(..., pitch:, rate:)` 전달
- `speakOnce(text:agentID:)` 동일하게 전처리 + pitch/rate/speed 적용

#### `MyTeam/AgentWindowManager.swift`
- 치코 role: `"문서·할일 정리 팀원"` → `"UX 디자이너 & 온보딩 도우미"`
- 치코 status: `"문서와 할 일을 정리하는 중"` → `"UX와 온보딩을 도와주는 중"`
- `replaceTeamAgent(at:with:)` 추가 — `swapAgent(at:with:)` 기반 래퍼
- `syncSelectedTeamWorkroomAgents()` 추가 — selectedTeamWorkroomID 기준 agentIDs 동기화

#### `MyTeam/TeamTableView.swift`
- **버그 수정:** line ~197 `showSwapWindow()` → 4개 슬롯 서브메뉴
  - 기존: `Button(action: { manager.showSwapWindow() })` — 항상 슬롯 0 교체
  - 수정: `Menu { ForEach(activeAgents.enumerated()) }` — 각 슬롯별 교체 선택

#### `MyTeam/TTSLabView.swift`
- `voiceDirectorSection` 추가 (보이스 디렉터):
  - **Preset 전체 테스트:** M1~M5, F1~F5 10개 버튼, 각 preset speakOnce 호출
  - **캐릭터 목소리 매핑:** 11개 캐릭터 행, 각 행 sampleLine speakOnce 버튼
  - pitch/rate/speed 값 표시 (p±xxx r0.xx s0.xx 형식)
  - 모델 없음 / notice 미수락 시 버튼 비활성
  - 진행 중 `voiceDirectorSpeakingID` 추적으로 동시 재생 방지

### pbxproj 등록
- `CharacterVoiceProfile.swift` — PBXFileReference + PBXBuildFile 등록
- `SupertonicProsodyTextProcessor.swift` — PBXFileReference + PBXBuildFile 등록

### 신규 스크립트
- `scripts/preflight_round258tts_character_voice_system.sh` — 22/22 PASS

---

## 캐릭터 보이스 프로필 요약

| 캐릭터 | agentID | preset | basePitch | baseRate | baseSpeed | defaultEmotion |
|--------|---------|--------|-----------|----------|-----------|----------------|
| 레오 | agent_1 | M1 | -180 | 0.94 | 1.00 | confident |
| 루나 | agent_2 | F1 | +180 | 1.03 | 1.05 | excited |
| 모코 | agent_3 | F3 | +90 | 0.97 | 1.00 | careful |
| 핀 | agent_4 | F4 | +320 | 1.10 | 1.08 | friendly |
| 치코 | agent_5 | F2 | +260 | 1.08 | 1.05 | friendly |
| 렉스 | agent_6 | M3 | -260 | 0.92 | 0.95 | careful |
| 케이 | agent_7 | M2 | -120 | 0.98 | 1.02 | neutral |
| 래키 | agent_8 | M4 | +120 | 1.06 | 1.05 | confident |
| 폴라 | agent_9 | F5 | -180 | 0.94 | 1.03 | confident |
| 몽몽 | agent_10 | F3 | +340 | 1.12 | 1.00 | friendly |
| 올리버 | agent_11 | M5 | -80 | 0.96 | 0.98 | careful |

---

## Preflight 결과

```
scripts/preflight_round258tts_character_voice_system.sh:  22/22 PASS ✅
scripts/preflight_round257tts_playback.sh:               12/12 PASS ✅
scripts/preflight_round256tts_official_engine.sh:        18/18 PASS ✅
```

## 빌드 결과

```
Debug:   BUILD SUCCEEDED ✅ (0 errors, 0 warnings)
Release: BUILD SUCCEEDED ✅ (0 errors, 0 warnings)
```

---

## 금지 항목 확인

| 항목 | 상태 |
|------|------|
| Apple TTS (폴백 포함) | ✅ 없음 |
| 자동 재생 기본 ON | ✅ false |
| 앱 launch auto-init | ✅ 없음 |
| 폴백 TTS | ✅ 없음 |
| ONNX 파일 git commit | ✅ 없음 |
| 말풍선 원문 변경 | ✅ 없음 (TTS 입력만 전처리) |

---

## Runtime Manual QA (로컬 기기 필요)

- [ ] TTS Lab → 보이스 디렉터 섹션 표시 확인
- [ ] Preset 전체 테스트 버튼 (M1~M5, F1~F5) 10개 클릭 → 각 preset 발화 확인
- [ ] 캐릭터 목소리 매핑 11개 행 샘플 말하기 → 캐릭터별 pitch/rate 차이 청감
- [ ] 말하기 버튼: 캐릭터별 pitch/rate 차이 청감 (레오 vs 핀 등)
- [ ] 팀원 교체하기 서브메뉴: 1~4번 슬롯 각각 선택 가능 확인
- [ ] 슬롯 1번 교체 → 실제 슬롯 1번만 교체 (슬롯 0 고정 버그 수정 확인)
- [ ] 치코 역할 표시: "UX 디자이너 & 온보딩 도우미" 확인
- [ ] 긴 문장 (200자 초과) 발화 → 앞 200자만 재생 확인
- [ ] 숫자/법률 문장 → neutral 처리 (변환 없음) 확인
- [ ] 앱 재시작 시 자동 재생 없음 확인
- [ ] crash 없음 확인
