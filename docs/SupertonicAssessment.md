# Supertonic-3 TTS Assessment

**Status:** Investigation / PoC Pending  
**Date:** 2026-05-19  
**Authored:** Round 241B

---

## What we know (public sources only)

| 항목 | 공개 정보 |
|---|---|
| 파라미터 수 | ~99M |
| 런타임 | ONNX Runtime |
| RTF (공개 벤치) | ~0.3x (iReader CPU 기준) |
| 음성 수 | 10 preset voices |
| 파라미터 | speed 조절 지원 |
| 오디오 품질 | 44.1kHz, 16-bit |
| Swift binding | README에서 언급됨 (미검증) |
| 라이선스 | OpenRAIL-M (상업적 조건 미확인) |

---

## 미검증 항목

- macOS Apple Silicon (M-series) 실측 RTF
- ONNX 모델 파일 실제 크기 (App Store 번들 허용 여부)
- Swift / macOS 빌드 실제 동작 확인
- OpenRAIL-M 상업적 배포 허용 범위 (재배포 조건 포함)
- 10개 프리셋 음성 실청 — MyTeam 캐릭터(Chiko 등) 매핑 적합성
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
