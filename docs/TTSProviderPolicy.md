# TTS Provider Policy

**Round:** 247TTS-SUPERTONIC3-POC  
**Status:** 확정  
**Updated:** 2026-05-21

---

## 핵심 원칙

### 1. Apple TTS (AVSpeechSynthesizer): 영원히 금지

- **폴백 포함 절대 사용 금지**
- AVSpeechSynthesizer 코드가 앱 어디에도 존재하지 않아야 함
- TTSProviderKind enum에 `appleSystem` case 없음
- TTSRoutingPolicy.selectedProvider()에서 절대 반환하지 않음
- 근거: 사용자 명시적 요구 (기계음 강력 거부, 245라운드 이전부터 정책화)

### 2. 무음 (Silent): 허용

- provider가 없을 때 무음은 정상 동작
- `TTSRoutingPolicy.selectedProvider() == nil` → SpeechManager 무음 처리
- 말풍선(onPlaybackStarted 콜백)은 즉시 발화하여 텍스트는 표시됨

### 3. Provider 우선순위

```
1. Supertonic3 (isEnabled && modelAvailable) → .supertonic3
2. Qwen3 (ttsDevLabQwen3Override && enableExperimentalQwenTTS) → .qwen3MLX
3. 없음 → nil (무음)
```

---

## Provider별 정책

### Supertonic3 (실험용)

| 항목 | 값 |
|---|---|
| 기본 활성화 | false |
| 활성화 방법 | Developer Lab에서 수동 토글 |
| 모델 위치 | `~/.cache/supertonic3/onnx/` (로컬, 자동 다운로드 없음) |
| 라이선스 | MIT (code) + OpenRAIL-M (model) |
| App Store 배포 | 미검증 (248TTS에서 법무 검토 필요) |
| 출력 샘플레이트 | 44,100 Hz WAV (24kHz 변환은 248TTS에서 구현) |
| Cloud 환경 | synthesize() 항상 .missingRuntime |

### Qwen3-TTS (기본 비활성)

| 항목 | 값 |
|---|---|
| 기본 활성화 | false |
| 활성화 방법 | Developer Lab → ttsDevLabQwen3Override + enableExperimentalQwenTTS |
| 재활성화 제한 | DevLab override 없이는 enableExperimentalQwenTTS 단독으로 활성화 불가 |
| 모델 | MLX 4bit, 로컬 |

---

## 구현 위치

| 역할 | 파일 |
|---|---|
| Provider kind 정의 | `TTSProviderModels.swift` |
| 선택 정책 | `TTSRoutingPolicy.swift` |
| SpeechManager 연결 | `SpeechManager.swift` (dispatchToInferencePipeline) |
| Supertonic3 설정 | `Supertonic3TTSConfig.swift` |
| 모델 탐색 | `Supertonic3ModelLocator.swift` |
| Skeleton provider | `Supertonic3TTSProvider.swift` |
| Developer Lab UI | `TTSLabView.swift` |

---

## 금지 항목 (이 파일이 존재하는 한 영원히)

- `AVSpeechSynthesizer` 임포트/사용
- `NSSpeechSynthesizer` 사용
- `TTSProviderKind.appleSystem` case 추가
- `TTSRoutingPolicy`에서 Apple TTS 반환
- Supertonic3 모델 자동 다운로드
- Supertonic3 라이선스 미검증 상태에서 production 기본 활성화
