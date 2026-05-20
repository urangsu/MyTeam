# Supertonic-3 TTS Assessment

**Status:** PoC Skeleton 완료 (Round 247TTS) — 실제 inference는 248TTS  
**Date:** 2026-05-21 (업데이트)  
**Authored:** Round 241B → 247TTS 업데이트

---

## 확인된 사항 (Round 247TTS 조사, 신뢰도 높음)

| 항목 | 확인된 정보 |
|---|---|
| 파라미터 수 | ~99M |
| 런타임 | ONNX Runtime (onnxruntime-swift-package-manager, Microsoft) |
| RTF (Apple Silicon) | **0.012–0.015× on M4 Pro** (실측, native Swift 예제 기준) |
| RTF (공개 벤치 구버전) | ~0.3x (iReader CPU 기준 — 구식) |
| 음성 수 | **10 preset voices: M1-M5 (남성), F1-F5 (여성)** |
| 오디오 품질 | 44.1kHz, 16-bit WAV |
| 모델 파일 | **4개 ONNX (총 ~398 MB)**: text_encoder(~36MB), duration_predictor(~4MB), vector_estimator(~257MB), vocoder(~101MB) |
| Swift 지원 | **Native Swift 예제 존재 (production-grade, iOS MVVM 앱 포함)** |
| 라이선스 | **MIT (코드) + OpenRAIL-M (모델)** — 상업적 사용 허용 |
| App Store 배포 | **미검증** (248TTS에서 법무 검토 필요) |
| 플랫폼 | macOS 13.0+, Apple Silicon CPU inference |
| 실배포 사례 | **PageEcho (iOS App Store)** 등 |
| 모델 경로 | `~/.cache/supertonic3/` (Python SDK 기본값) |
| HuggingFace | Supertone/supertonic-3 |

---

## 미검증 항목 (248TTS에서 해소 예정)

- [ ] OpenRAIL-M 라이선스 App Store 배포 가능 여부 법무 검토
- [ ] ONNX Runtime v1.16.0+ macOS arm64 SPM 빌드 검증 (248TTS에서 Package.swift 추가)
- [ ] 44.1kHz WAV → 24kHz PCM 변환 (AudioPlaybackService 연결)
- [ ] Supertonic3 실 디바이스 RTF 측정 (M1/M2/M3 — M4 Pro만 확인됨)
- [ ] Voice preset 음성 품질 주관 평가 — MyTeam 캐릭터(Chiko 등) 매핑 적합성
- [ ] App Store 번들 허용 여부 (~398 MB 모델 번들 vs 사용자 다운로드)
- 지연(latency): 첫 토큰 생성까지 체감 시간

---

## 결정: PoC 라운드 별도 진행 전까지 미통합

**이유:**
1. 위 미검증 항목 없이 통합하면 App Store 제출 또는 번들 크기 문제로 다시 제거해야 할 위험
2. RTF가 공개 벤치 기준이므로 Apple Silicon 실측치 없이 UX 약속 불가
3. OpenRAIL-M 상업 조건 미확인 → 법무 검토 필요

**PoC 라운드에서 할 일:**
- macOS M-series 환경에서 ONNX 빌드 + RTF 실측
- 번들 크기 측정 → 50MB 이하 여부 확인
- 10개 프리셋 실청 → Chiko 1~2개 매핑 후보 선정
- OpenRAIL-M 조항 검토

---

## 참고: Apple TTS 사용 금지

프로젝트 정책상 Apple TTS(AVSpeechSynthesizer)는 기계음으로 사용자가 강력 거부.  
폴백으로도 포함 금지. (`docs/character/` + `MEMORY.md` 참고)

현재 대안: Qwen3TTSService (별도 로컬 서버) 또는 무음.

---

*이 문서는 PoC 결과가 나오면 업데이트할 것.*
