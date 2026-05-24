# Round 257TTS-PLAYBACK QA Report

**날짜:** 2026-05-23  
**브랜치:** cloud/round252-supertonic-license-lock  
**라운드:** 257TTS-PLAYBACK — Supertonic3 합성 결과 AudioPlaybackService 재생 연결

---

## 요약

Round 256TTS에서 WAV 저장 + `onPlaybackStarted()` 직접 호출만 수행하던 경로를,
`AudioPlaybackService.playFloatSamples(...)` 호출을 통해 실제 스피커 재생으로 연결.  
`SpeakButtonView`는 `speakOnce`를 호출해 합성 + 재생을 한 번에 수행.

---

## 구현 항목

### 수정 파일

#### `MyTeam/AudioPlaybackService.swift`
- `playFloatSamples(samples:sampleRate:streamId:characterName:onPlaybackStarted:)` 추가
  - `AVAudioFormat(standardFormatWithSampleRate:channels:1)` 소스 포맷 생성
  - `AVAudioPCMBuffer` 생성 + `floatChannelData[0]`에 `[Float]` 직접 복사
  - `prepareSession(...)` 호출 (노드 재연결 + `currentActiveStreamId` 설정)
  - `convertBuffer(...)` 으로 engine 포맷(보통 44.1kHz stereo)으로 변환
  - `playerNode.scheduleBuffer(...)` → engine 기동 → `playerNode.play()`
  - `playerNode.play()` **이후** `onPlaybackStarted` 콜백 (립싱크 원칙 준수)

#### `MyTeam/SpeechManager.swift`
- `dispatchToInferencePipeline` supertonic3 경로 수정:
  - 기존: S3WavWriter.write 후 `onPlaybackStarted()` 직접 호출
  - 변경: S3WavWriter.write(debug용) + `await playback.playFloatSamples(..., onPlaybackStarted:)` 호출
  - `onPlaybackStarted`는 `playerNode.play()` 이후 AudioPlaybackService가 호출
- `speakOnce(text:agentID:) async -> TTSOutput?` 신규 메서드
  - 합성 → `playback.playFloatSamples(...)` → WAV 저장(debug) → `TTSOutput` 반환
  - 실패 시 `nil` 반환

#### `MyTeam/AgentChatView.swift`
- `SpeakButtonView` 업데이트 (Round 257TTS-PLAYBACK):
  - `synthesize()` → `speakOnce()` 로 교체
  - `SpeechManager.shared.speakOnce(text:agentID:)` 호출
  - 성공: `hasPlayed = true` → `speaker.wave.2.fill` 아이콘
  - 실패: `errorMessage` 설정 → 아이콘 빨간색 + help 텍스트 변경
  - 오류 상태를 `help()` modifier로 표시

### 신규 스크립트

- `scripts/preflight_round257tts_playback.sh` — 12/12 PASS

---

## 재생 흐름 (완전)

```
SpeakButtonView.speakOnce()
  → SpeechManager.shared.speakOnce(text:agentID:)
    → TTSRoutingPolicy.selectedProvider() == .supertonic3 (gate)
    → Supertonic3ONNXRunner.shared.synthesize(...)   ← 합성
    → AudioPlaybackService.shared.playFloatSamples(  ← 재생
        samples: result.wavSamples,
        sampleRate: result.sampleRate,
        onPlaybackStarted: nil
      )
        → AVAudioPCMBuffer 생성 + floatChannelData 복사
        → convertBuffer (44.1kHz mono → engineFormat)
        → playerNode.scheduleBuffer
        → playerNode.play()                          ← 스피커 출력
    → S3WavWriter.write(tag:"speakonce_F1")          ← Desktop WAV (debug)
    → TTSOutput 반환
  → hasPlayed = true → speaker.wave.2.fill 아이콘
```

---

## onPlaybackStarted 타이밍

| 경로 | 호출 시점 |
|------|-----------|
| `dispatchToInferencePipeline` (SSE/speak 경로) | `playerNode.play()` 이후 AudioPlaybackService가 콜백 |
| `speakOnce` (SpeakButtonView 경로) | `playFloatSamples` 완료 후 (onPlaybackStarted=nil, UI는 반환값으로 처리) |

---

## Preflight 결과

```
scripts/preflight_round257tts_playback.sh:    12/12 PASS ✅
scripts/preflight_round256tts_official_engine.sh: 18/18 PASS ✅
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

---

## Runtime Manual QA (로컬 기기 필요)

- [ ] TTS Lab — 공식 엔진 활성화 후 말하기 버튼 표시 확인
- [ ] 말하기 버튼 클릭 → 스피커 출력 확인
- [ ] 메시지 내용과 음성 일치 확인
- [ ] 다른 에이전트 메시지 → 다른 프리셋 보이스 확인 (M1/F1/F2/M3 등)
- [ ] 합성 중 버튼 비활성(isSynthesizing) 확인
- [ ] 재생 성공 후 아이콘 변경(speaker.wave.2.fill) 확인
- [ ] crash 없음 확인
- [ ] 앱 재시작 시 자동 재생 없음 확인
