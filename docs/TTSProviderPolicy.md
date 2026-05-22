# TTS Provider Policy

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