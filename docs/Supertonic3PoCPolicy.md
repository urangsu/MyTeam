# Supertonic3 PoC Policy

**Round:** 247TTS-SUPERTONIC3-POC  
**Status:** Skeleton (Cloud) — 실제 inference 없음  
**Updated:** 2026-05-21

---

## 이번 라운드 범위

### 포함 (247TTS)

- TTSProviderKind, TTSProviderAvailability, TTSOutput, TTSProviderError 타입 정의
- TTSRoutingPolicy — provider 선택 정책 (Supertonic3 → Qwen3DevLab → nil/무음)
- Supertonic3TTSConfig — 모델 경로, voice preset, isEnabled=false 기본값
- Supertonic3ModelLocator — `~/.cache/supertonic3/onnx/` 파일 존재 여부 확인
- Supertonic3TTSProvider (skeleton) — synthesize() 항상 .missingRuntime
- Supertonic3TTSProbe — Cloud probe (모델 탐색 + 설정 요약, inference 없음)
- TTSLabView — Developer Lab 전용 UI (enable 토글, 모델 상태, preset 선택)
- SpeechManager 수정 — TTSRoutingPolicy 연결, Qwen3 DevLab 격리
- RuntimeDiagnosticsSnapshot — TTS 정책 필드 11개 추가
- ToolContractValidator — TTS validators 7개 추가

### 미포함 (248TTS에서 구현)

- ONNX Runtime SPM 의존성 (`onnxruntime-swift-package-manager`)
- 실제 4-stage inference (text_encoder → duration_predictor → vector_estimator → vocoder)
- 44.1kHz WAV → 24kHz PCM 변환 (AudioPlaybackService 연결)
- NSOpenPanel 모델 경로 선택 UI
- App Store 라이선스 법무 검토

---

## Supertonic3 기술 조사 결과 (2026-05 확인)

| 항목 | 내용 |
|---|---|
| 모델 | Supertone/supertonic-3 (HuggingFace) |
| 아키텍처 | 4 ONNX 파일 (text_encoder, duration_predictor, vector_estimator, vocoder) |
| 총 크기 | ~398 MB |
| 출력 | 44,100 Hz WAV, 16-bit |
| Voice presets | M1-M5 (남성), F1-F5 (여성), 총 10종 |
| RTF | 0.012–0.015× (M4 Pro Apple Silicon) |
| 플랫폼 | macOS 13.0+, Apple Silicon (CPU inference) |
| 라이선스 | MIT (코드) + OpenRAIL-M (모델) — 상업적 사용 허용 |
| App Store 검증 | 미완료 |
| Swift 지원 | Native Swift 예제 존재 (production-grade) |
| 실배포 사례 | PageEcho (iOS App Store) 등 |
| SPM | `onnxruntime-swift-package-manager` (Microsoft, v1.16.0+) |
| 모델 경로 | `~/.cache/supertonic3/` (Python SDK 기본값) |

---

## 활성화 조건 (Mac 248TTS 이후)

```
1. supertonic3ExperimentalEnabled = true (UserDefaults)
2. ~/.cache/supertonic3/onnx/ 에 4개 ONNX 파일 존재 (각 크기 > 0)
3. ONNX Runtime SPM 탑재 (248TTS에서 Package.swift 추가)
```

현재(Cloud 247TTS): 조건 3 미충족 → synthesize() 항상 .missingRuntime → 무음

---

## 미검증 항목 (248TTS에서 해소)

- [ ] OpenRAIL-M 라이선스 App Store 배포 가능 여부 법무 검토
- [ ] ONNX Runtime v1.16.0+ macOS arm64 SPM 빌드 검증
- [ ] 44.1kHz → 24kHz 변환 품질 + 지연 측정
- [ ] Supertonic3 실 디바이스 RTF 측정 (M1/M2/M3)
- [ ] Voice preset 음성 품질 주관 평가

---

## 모델 다운로드 방법 (수동, 자동 다운로드 절대 없음)

```bash
# 방법 1: Python SDK
pip install supertonic
python -c "from supertonic import TTS; TTS(auto_download=True)"

# 방법 2: HuggingFace CLI
huggingface-cli download Supertone/supertonic-3 --include 'onnx/*'
# → ~/.cache/supertonic3/onnx/ 에 저장

# 필요 파일
# - text_encoder.onnx       (~36 MB)
# - duration_predictor.onnx (~4 MB)
# - vector_estimator.onnx   (~257 MB)
# - vocoder.onnx             (~101 MB)
```
