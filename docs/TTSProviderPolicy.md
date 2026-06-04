# TTS Provider Policy

**Current MyTeam TTS Rule** — Supertonic3 is the main generated voice engine. BubbleSpeech / `뽀글뽀글 말하기` is the protected procedural syllable speech effect layer that must be enhanced, not deleted.

## Protected Runtime Contract (2026-06-03)

- **Main TTS engine:** Supertonic3 only.
- **Protected effect layer:** BubbleSpeech / `뽀글뽀글 말하기`. It is not a competing TTS model, not a fallback provider, and not a fake success path.
- BubbleSpeech exists to shape, stylize, or test the character voice experience with app-generated syllable blips.
- Do not delete `BubbleSpeechSynthesizer.swift`, `SpeechManager.previewBubbleSpeech`, BubbleSpeech profile logic, TTS Lab BubbleSpeech controls, or future Supertonic3→BubbleSpeech overlay code.
- Do not delete or "legacy-cleanup" Supertonic3 runtime files, ONNX integration, model locator, voice tuning, routing, or playback paths.
- Do not "simplify" voice by removing BubbleSpeech. The correct direction is overlay quality, controllability, character mapping, QA metrics, and truthful UI labels.
- If Supertonic3 runtime is broken, fix Supertonic3. Do not replace it with Apple TTS, ElevenLabs, Chatterbox, Qwen, MLX TTS, or any other TTS model.
- If BubbleSpeech output quality is weak, improve the effect layer. Do not delete it.
- BubbleSpeech v1.2 uses a single Supertonic3 synthesis pass, then cuts the generated character voice into short syllable rhythm chunks. Per-syllable Supertonic3 multi-call synthesis is intentionally out of scope for this add-on effect.
- BubbleSpeech guide generation failure is a failure, not passthrough success.
- Returning original Supertonic3 voice samples without effect is forbidden in BubbleSpeech preview.
- BubbleSpeech preview may only report success when Supertonic3 synthesis succeeds and BubbleSpeech effect rendering produces non-empty modified samples.
- The TTS input wording must match the visible chat bubble wording. Character style must come from Supertonic3 pitch/rate/speed/timbre tuning and BubbleSpeech audio effects, not from hidden text rewrites such as changing endings, adding punctuation, summarizing, or substituting different phrases.

Target architecture:

```text
LLM response
  -> Supertonic3 character voice synthesis
  -> CharacterVoiceProfile prosody/tuning
  -> BubbleSpeech single-pass syllable chopper + quiet guide support
  -> AudioPlaybackService
```

---

**Round 262TTS-BUBBLESPEECH-SPEECHLIKE-ENGINE** — melody-like blip을 음절형 procedural speech effect로 재작성.

## Round 262TTS-BUBBLESPEECH-SPEECHLIKE-ENGINE (2026-05-23)

### BubbleSpeech Speech Effect 정책

BubbleSpeech / 뽀글뽀글 말하기는 Supertonic 대체 TTS가 아니다. fallback TTS도 아니다. MyTeam 캐릭터 보이스를 앱 내부 procedural 음절 말소리로 보정/고도화하기 위한 보호된 speech effect layer다.

Round 261 구현은 글자마다 장음계 pitch를 부여하는 blip engine이라 음표처럼 들리는 문제가 있었다. Round 262는 다음 구조로 바꾼다.

- 한글 음절 분해: 초성 / 중성 / 종성
- 음절 생성: consonant transient + vowel-colored body + final tail
- pitch: major scale 금지, profile base 주변 speech contour만 사용
- phrase pause: 공백, 쉼표, 마침표, 물음표, 느낌표에 pause와 ending contour 적용
- profile: speech profile과 effect profile 분리
- QA: duration, peak, zero crossing rate, estimated click count snapshot 표시

### QA 기준

- 음표처럼 들리는가?
- 말소리처럼 이어지는가?
- phrase pause가 자연스러운가?
- 클릭/깨짐이 있는가?
- speech profile과 effect profile이 명확히 구분되는가?

### Safety

- 타사 원본 샘플 사용 금지
- YouTube 오디오 추출 금지
- 외부 sample file 로드 금지
- Apple TTS/fallback TTS 추가 금지
- launch auto-init 금지

---

**Round 261TTS-SPEED-PROBE-AND-BUBBLESPEECH** — speed 계측 + procedural BubbleSpeech blip speech 엔진.

## Round 261TTS-SPEED-PROBE-AND-BUBBLESPEECH (2026-05-23)

### Speed Probe 정책

`probeSpeedApplication(text:preset:)` — Supertonic3 합성 duration이 speed에 따라 실제로 변하는지 계측.
재생 없음. WAV 저장 없음. AppLog에 speed/duration/RTF 기록.

기대: `S 0.70 > S 1.00 > S 1.30 > S 2.00` (durationSec 감소). 깨지면 의심 표시.

### BubbleSpeech 정책

- **Supertonic3 대체 금지** — Supertonic3가 메인 TTS 엔진이다.
- **Fallback TTS 아님** — Supertonic3 실패를 성공처럼 포장하지 않는다.
- **삭제 금지** — BubbleSpeech는 캐릭터 보이스 효과 레이어로 유지하고 고도화한다.
- **Overlay 목표** — 생성된 Supertonic3 캐릭터 보이스 위에 BubbleSpeech 말하기 질감을 얹는 방향으로 발전시킨다.
- **procedural audio only** — 타사 원본 샘플, YouTube 추출 금지. 자체 sine/triangle/squareSoft/noiseBlend 파형.
- **provider 아님** — BubbleSpeechSynthesizer는 순수 DSP 효과 레이어지만, 제품 preview 성공은 Supertonic3 합성 성공과 non-empty modified render가 모두 있어야 한다.
- AudioPlaybackService.playFloatSamples 재사용 (pitch/rate 오프셋 지원).

BubbleSpeech 프로필 5종: cute(620Hz/triangle), calm(430Hz/triangle), deep(300Hz/triangle), robot(520Hz/squareSoft), tiny(760Hz/sine).

변경 파일:
1. `SupertonicSpeedProbe.swift` (신규) — probe result + ordering 검증
2. `BubbleSpeechSynthesizer.swift` (신규) — BubbleSpeechWaveform + BubbleSpeechVoiceProfile + BubbleSpeechConfig + synthesize
3. `SpeechManager.probeSpeedApplication()` — speed 4종 계측 API
4. `SpeechManager.previewBubbleSpeech()` — Supertonic3 캐릭터 음성 기반 effect preview API
5. `TTSLabView.speedProbeSection` — 계측 UI + 결과 표
6. `TTSLabView.bubbleSpeechSection` — profile/speed/pitchOffset + 재생 버튼
7. `scripts/preflight_round261tts_speed_probe_bubbleSpeech.sh` — 22/22 PASS

---

**Round 260B-TTS-OFFICIAL-SPEED-RANGE** — 공식 speed 범위 0.70~2.00 적용 + Expression Tag A/B 인프라.

## Round 260B-TTS-OFFICIAL-SPEED-RANGE (2026-05-23)

### Speed Zone 정책

Supertonic3 공식 speed 범위: 0.70(slow) ~ 2.00(fast). GitHub/HuggingFace 문서 기준.

| Zone | 범위 | UI 배지 | 경고 |
|------|------|---------|------|
| 권장 | 0.90~1.30 | 🟢 "권장" | 없음 |
| 실험 | 1.30~1.60 | 🟠 "실험" | ⚠️ 효과음 느낌 |
| 특수효과 | 1.60~2.00 | 🔴 "특수효과" | 🚨 일반 캐릭터 비권장 |
| 하한 경고 | <0.80 | — | ⚠️ 발음 흐려짐 |

기본 캐릭터 발화(`speakOnce`, `dispatchToInferencePipeline`)의 speed는 `baseSpeed`(0.96~1.06) 유지.  
슬라이더 전체 범위 0.70~2.00는 TTS Lab 튜닝 전용.

### Expression Tags 정책

Supertonic3 공식 expression tag: `<laugh>`, `<breath>`, `<sigh>`.

- **기본 발화에는 적용하지 않음** — TTS Lab A/B 테스트 전용.
- `SupertonicExpressionTagPolicy.apply(emotion:to:)`: 감정→권장 태그 자동 매핑.
- formal/numeric 텍스트(숫자 밀도 15% 초과, 법률/회계 키워드)에는 적용 금지.
- 태그는 텍스트 앞에 접두사로 삽입, 말풍선 원문에는 절대 표시 안 함.

| 감정 | 권장 태그 |
|------|-----------|
| neutral | 없음 |
| friendly | `<breath>` |
| confident | 없음 |
| careful | `<breath>` |
| excited | `<laugh>` |
| bubbleSpeech | `<laugh>` |

### BubbleSpeech 재튜닝 (Round 260B)

speed-first 전략으로 재정의. pitch 과도 상승 제거.

| | Round 259 | Round 260B |
|---|---|---|
| pitch M | +140 | +120 |
| pitch F | +180 | +160 |
| rate | 1.12 | 1.08 |
| speed | base+0.35 (max 1.60) | min(1.60, max(1.35, base+0.35)) |

변경 파일:
1. `SupertonicExpressionTagPolicy.swift` (신규) — tag 3종 + 감정→tag 매핑
2. `VoiceTuningState.swift` — speedRange 0.70~2.00, zone/warning 상수
3. `Supertonic3ONNXRunner.swift` — safeSpeed clamp min(2.00, max(0.70, speed))
4. `SupertonicProsodyTextProcessor.swift` — useExpressionTags 파라미터 추가
5. `SpeechManager.previewWithTuning` — useExpressionTags 파라미터 추가
6. `SupertonicVoicePresetPolicy.bubbleSpeechTuning` — speed-first 재정의
7. `TTSLabView` — S 슬라이더 존 배지+경고, Expression Tags A/B 섹션
8. `scripts/preflight_round260btts_official_speed_range.sh` — 18/18 PASS

---

**Round 259TTS-VOICE-TUNER** — 임시 P/R/S 튜닝 컨트롤 + pitch 재조정 + BubbleSpeech 모드 분리.

## Round 259TTS-VOICE-TUNER (2026-05-23)

### P/R/S 파라미터 정책

| 파라미터 | 설명 | UI 범위 | artifact 경고 |
|---------|------|---------|--------------|
| P / Pitch | 음높이 (cents, AVAudioUnitTimePitch) | -180~+180 | ±100 초과 시 금속성/비프음 가능 |
| R / Rate | 재생 후처리 속도 배율 | 0.92~1.12 | - |
| S / Speed | Supertonic3 합성 duration predictor | 0.90~1.20 | - |

> 목소리 개성은 preset, 말의 빠르기는 S, 최종 보정은 P/R.

### CharacterVoiceProfile basePitch 재조정 (Round 259TTS)

사용자 청감 피드백(pitch 100 이상 금속성/비프음)에 따라 basePitch를 ±100 이하로 재조정.  
이전 최대값: 핀 +320, 몽몽 +340, 치코 +260 → 모두 +90으로 낮춤.  
모코/올리버는 안정적으로 평가되어 ±60 이내 유지.

### BubbleSpeech 모드 재정의 (Round 259TTS)

- **이전:** `basePitch + bubbleSpeechPitchBoost` (누적 방식) → 기존 설정과 체감 차이 없음
- **이후:** `bubbleSpeechTuning(for:)` — 독립 cartoon target (M:+140, F:+180, rate:1.12)
- BubbleSpeech은 테스트 전용. 기본 캐릭터 발화에는 사용되지 않음.

### VoiceTuningState (신규)

`VoiceTuningValues` — P/R/S 임시 튜닝값 컨테이너 (Codable, Sendable, Equatable).  
`VoiceTuningDefaults` — UI 슬라이더 범위 + artifact 경고 임계값 (pitchArtifactThreshold: 100).

변경 파일:
1. `VoiceTuningState.swift` (신규)
2. `CharacterVoiceProfile.swift` — basePitch 재조정 + bubbleSpeechBoost 필드 비활성화
3. `SupertonicVoicePresetPolicy.swift` — bubbleSpeechTuning(for:) 추가, BubbleSpeech case 재정의
4. `SpeechManager.previewWithTuning(text:preset:pitch:rate:speed:)` 추가
5. `TTSLabView` — prsDescriptionBox + prsTuningSection + 3개 섹션 tuning override 지원
6. `scripts/preflight_round259tts_voice_tuner.sh` — 22/22 PASS

---

**Round 258B-TTS-EMOTION-AUDIT** — 감정 표현 감사 + 보이스 디렉터 분리 + 팀 슬롯 동기화 강화.

## Round 258B-TTS-EMOTION-AUDIT (2026-05-23)

캐릭터별 기본 감정 스타일 적용, emotion-aware pitch/rate/speed API, 보이스 디렉터 원본 preset 분리.

변경 사항:
1. `CharacterVoiceProfile.emotionSpeedBoost` — 감정 speed 부스트 필드 추가
2. `SupertonicVoicePresetPolicy.emotionStyle(for:)` — 캐릭터 기본 감정 반환
3. `SupertonicVoicePresetPolicy.pitch/rate/speed(for:emotion:)` — emotion-aware API 추가
   - neutral: base 값 그대로
   - careful: base + min(0, boost) — 음수 boost만 적용
   - friendly/confident/excited: base + boost 전체 적용
   - bubbleSpeech: base + bubbleSpeechBoost (강한 모드, 기본 미사용)
4. `SpeechManager` — dispatch/speakOnce에서 emotionStyle 조회 후 emotion-aware API 사용
5. `SpeechManager.previewPreset(text:preset:)` — 원본 preset 미리듣기 (pitch=0, rate=1, neutral)
6. `SpeechManager.previewCharacterEmotion(text:agentID:emotion:)` — 캐릭터+감정 미리듣기
7. `TTSLabView` — "원본 Preset 테스트"(previewPreset 사용) + "감정 표현 테스트"(Picker+6 감정 버튼)
8. `AgentWindowManager.swapAgent()` → `syncSelectedTeamWorkroomAgents()` 추가 (팀 슬롯 동기화)
9. `AgentSwapView` → `replaceTeamAgent(at:with:)` 사용
10. `scripts/preflight_round258tts_character_voice_system.sh` — 22 → 38 checks, 38/38 PASS

기본 감정 스타일:
- 레오: confident, 루나: excited, 모코: careful, 핀: friendly, 치코: friendly
- 렉스: careful, 케이: neutral, 래키: confident, 폴라: confident, 몽몽: friendly, 올리버: careful

치코 role "UX 디자이너 & 온보딩 도우미" — 이번 라운드 수정 없음 (Round 258TTS에서 설정됨).

---

## Round 258TTS-CHARACTER-VOICE-SYSTEM (2026-05-23)

캐릭터별 pitch/rate/speed 아이덴티티 적용, 텍스트 전처리(prosody), TTS Lab 보이스 디렉터 UI.

변경 사항:
1. `CharacterVoiceProfile.swift` — 11개 캐릭터 보이스 프로필 (pitch/rate/speed/emotionStyle)
2. `SupertonicProsodyTextProcessor.swift` — 텍스트 전처리 (prosody, neutral 보호)
3. `Supertonic3ONNXRunner.synthesize(speed:)` — speed 파라미터화 (기존 하드코딩 1.05 제거)
4. `SupertonicVoicePresetPolicy` — CharacterVoiceProfileCatalog 기반, pitch/rate/speed API 추가
5. `AudioPlaybackService.playFloatSamples(pitch:rate:)` — pitch/rate 파라미터 추가
6. `SpeechManager` — prosody 전처리 + pitch/rate/speed 적용
7. `TTSLabView` — 보이스 디렉터 섹션 (preset 10개 버튼 + 캐릭터 11개 샘플)
8. `AgentWindowManager` — 치코 role "UX 디자이너 & 온보딩 도우미", replaceTeamAgent 래퍼
9. `TeamTableView` — 팀원 교체 슬롯 서브메뉴 (슬롯 0 고정 버그 수정)
10. `scripts/preflight_round258tts_character_voice_system.sh` — 22/22 PASS

캐릭터 보이스 정책:
- basePitch/baseRate: VoiceStyleCatalog 기존값 계승 (cents 기준)
- baseSpeed: Supertonic3 duration predictor 속도 스케일 (0.85~1.25 clamp)
- BubbleSpeech mode: bubbleSpeechPitchBoost/RateBoost로 분리, 기본 OFF
- 법률/회계/숫자 텍스트 → neutral 처리 (변환 스킵)
- 말풍선 원문은 절대 변경 안 함

---

**Round 256TTS-OFFICIAL-ENGINE** — Supertonic3 공식 MyTeam TTS 엔진 승격.

## Round 257TTS-PLAYBACK (2026-05-23)

Supertonic3 합성 결과를 실제 스피커로 재생 연결.

변경 사항:
1. `AudioPlaybackService.playFloatSamples(samples:sampleRate:streamId:characterName:onPlaybackStarted:)` 추가
2. `SpeechManager.speakOnce(text:agentID:)` 신규 — 합성 + 재생 단일 API
3. `SpeechManager.dispatchToInferencePipeline` supertonic3 경로: `playFloatSamples` 호출
4. `SpeakButtonView` — `speakOnce` 호출, 성공 시 `speaker.wave.2.fill`
5. `scripts/preflight_round257tts_playback.sh` — 12/12 PASS

자동 재생 기본 OFF, 폴백 없음, Apple TTS 없음 정책 유지.

---

## Round 256TTS-OFFICIAL-ENGINE (2026-05-23)

Supertonic3를 실험용 후보에서 공식 MyTeam TTS 엔진으로 승격.

변경 사항:
1. `TTSProductPolicy.officialEngineEnabled = true`, `officialEngine = .supertonic3`
2. `SupertonicVoicePresetPolicy.swift` — 11개 캐릭터 → 보이스 프리셋 매핑
3. `SpeechManager.synthesize(text:agentID:)` — 공개 API, ONNXRunner 직접 호출
4. `AgentChatView` — `SpeakButtonView` 추가 (말하기 버튼, 기본 OFF)
5. `TTSRoutingPolicy.isSupertonic3Available` — computed property 추가
6. `RuntimeDiagnosticsSnapshot` 10개 필드 추가
7. `ToolContractValidator` 6개 validators 추가
8. `scripts/preflight_round256tts_official_engine.sh` — 18/18 PASS

핵심 정책:
- 자동 재생 기본 OFF (`autoSpeakDefaultEnabled = false`)
- 폴백 TTS 없음 (`fallbackTTSAvailable = false`)
- Apple TTS 절대 금지 (폴백 포함)
- 앱 launch auto-init 금지
- ONNX 파일 bundle 여부는 다음 gate에서 결정

---

**Round 254TTS-NOTICE** — Supertonic license notice + use restriction UX gate.

## Round 254TTS-NOTICE (2026-05-22)

TTS Lab ONNX synthesis now gated behind notice acceptance:

1. `SupertonicTTSNoticePolicy.swift` — notice version management, UserDefaults keys, accept/reset
2. `SupertonicNoticeCardView.swift` — SwiftUI card shown in TTSLabView with license + use restrictions
3. TTSLabView: `noticeAccepted` state, ONNX synth button `.disabled(...|| !noticeAccepted)`
4. `TTSProductPolicy.licenseNoticeRequired = true`, `useRestrictionNoticeRequired = true`, `userNoticeAcceptanceRequired = true`
5. `RuntimeDiagnosticsSnapshot` fields: 6 notice gate diagnostics
6. `ToolContractValidator`: 4 Round 254 validators
7. `scripts/preflight_round254tts_notice.sh`: 18/18 pass

Release user-facing TTS remains locked (`userFacingTTSEnabled = false`).

---

**Round 253TTS** — Supertonic adoption gate.

---

## Product Decision

Supertonic is the only TTS candidate.

MyTeam has no default user-facing TTS yet.

There is no fallback TTS.

Supertonic is allowed for product planning under the upstream OpenRAIL-M model license and MIT sample-code license, subject to license notice, attribution, and use-restriction compliance.

If Supertonic fails quality, runtime, bundle, or release UX gates, MyTeam v1 ships without TTS.

---

## Official Engine (Round 256TTS~)

| Item | Value |
|---|---|
| Provider | Supertonic3 |
| Scope now | 공식 MyTeam TTS 엔진 (사용자 활성화 필요) |
| Scope next | bundle/release gate 통과 시 기본 활성화 |
| Release default | disabled until release UX is approved |
| Model bundle | allowed only with license notice and distribution policy |
| Launch auto-init | prohibited |
| Commercial product use | allowed under license conditions |
| Model redistribution | allowed under license conditions |
| Release product exposure | blocked until runtime, quality, bundle, and release UX gates pass |

---

## Gate (canShipAsProductFeature)

All release gates must be `true` before shipping as a product feature:

1. `koreanQualityAccepted` — Korean quality accepted by product owner
2. `localRuntimeVerified` — local Mac runtime verified with benchmark results
3. `bundlePolicyAccepted` — model bundle or user-selected model policy approved
4. `releaseIntegrationApproved` — release UX, compliance notices, and App Store path approved

License evidence is now sufficient for planning, but release exposure remains blocked until implementation gates pass.

---

## Routing

```swift
// TTSRoutingPolicy.selectedProvider()
// Supertonic3 (enabled && modelAvailable && releaseGateApproved) → .supertonic3
// nil → silent
```

---

## Not Allowed

- Fallback TTS
- Product TTS exposure before release gates pass
- ONNX files committed to git without explicit distribution decision
- Supertonic launch auto-init
- Claiming production readiness, App Store readiness, or verified runtime status before all release gates pass

---

## Compliance Review

See `docs/SupertonicCommercialLicenseReview.md` before considering any release exposure.

The upstream license text and model terms permit product planning, but MyTeam must still implement attribution, license notice, restricted-use notice, model distribution policy, and release UX before enabling a user-facing product feature.
