# TTS Provider Policy

**Round 251TTS** — Supertonic3 단독 후보. 이전 후보 모두 제거.

---

## Product Decision

MyTeam은 기본 TTS를 제공하지 않는다.

Supertonic3가 유일한 TTS 후보다.

Supertonic3가 품질/라이선스/런타임/번들/릴리즈 gate를 통과하지 못하면
**MyTeam v1은 TTS 없이 출시한다.**

---

## Candidate

| 항목 | 값 |
|---|---|
| Provider | Supertonic3 |
| Scope | TTS Lab / experimental 전용 |
| Release 기본값 | 비활성 |
| 모델 번들 | 금지 |
| launch 자동 init | 금지 |
| 상업 라이선스 | pending |
| 모델 재배포 | pending |

---

## Gate (canShipAsProductFeature)

다음 5개가 모두 true여야 제품 기능으로 제공 가능:

1. `koreanQualityAccepted` — 한국어 품질 검증 통과
2. `licenseVerified` — 공식 LICENSE / model card 확인
3. `localRuntimeVerified` — 로컬 Mac 런타임 검증
4. `bundlePolicyAccepted` — 모델 번들 재배포 정책 확인
5. `releaseIntegrationApproved` — 릴리즈 통합 승인

현재: 모두 `false`. 제품 기능 제공 불가.

---

## Routing

```swift
// TTSRoutingPolicy.selectedProvider()
// Supertonic3(isEnabled && modelAvailable) → .supertonic3
// nil → 무음
// Apple TTS: 영원히 금지
```

---

## Not Allowed

- fallback TTS
- Apple TTS / AVSpeechSynthesizer (폴백 포함 영원히 금지)
- 라이선스 검증 전 제품 TTS 노출
- 모델 번들 (재배포 정책 확인 전)
- ONNX 파일 git commit
- Supertonic launch 자동 init
- 상업 출시 준비 완료 / 런타임 검증 완료 표현 (제품 준비 완료 주장 금지)
