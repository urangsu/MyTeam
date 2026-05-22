# Round 256TTS-OFFICIAL-ENGINE QA Report

**날짜:** 2026-05-23  
**브랜치:** cloud/round252-supertonic-license-lock  
**라운드:** 256TTS-OFFICIAL-ENGINE — Supertonic3 공식 MyTeam TTS 엔진 승격

---

## 요약

Supertonic3를 실험용(experimental) 후보에서 MyTeam 공식 TTS 엔진으로 승격.  
SpeechManager가 TTSRoutingPolicy를 통해 Supertonic3ONNXRunner를 직접 호출하도록 배선.  
AgentChatView에 말하기(🔊) 버튼 추가, 11개 캐릭터별 보이스 프리셋 매핑.

---

## 정책 확인 (TTSProductPolicy)

| 항목 | 값 | 기준 |
|------|-----|------|
| officialEngine | supertonic3 | ✅ |
| officialEngineEnabled | true | ✅ |
| autoSpeakDefaultEnabled | false | ✅ 자동 재생 기본 OFF |
| fallbackTTSAvailable | false | ✅ 폴백 TTS 없음 |
| characterVoiceEnabled | true | ✅ |
| agentVoiceEnabled | true | ✅ |
| licenseVerified | true | ✅ OpenRAIL-M 확인 |
| commercialUseAllowed | true | ✅ |
| modelBundled | false | ✅ ONNX 파일 미포함 |
| supertonicAutoInitOnLaunch | false | ✅ launch auto-init 없음 |
| bundlePolicyAccepted | false | ⬜ 다음 gate에서 결정 |
| releaseIntegrationApproved | false | ⬜ 다음 gate에서 결정 |
| canShipAsProductFeature | false | ⬜ bundle/release gate 전 |

---

## 구현 항목

### 신규 파일
- `MyTeam/SupertonicVoicePresetPolicy.swift` — 11개 에이전트 ID → 프리셋 매핑

### 수정 파일
- `MyTeam/TTSProductPolicy.swift` — officialEngineEnabled=true, 정책 상수 업데이트
- `MyTeam/TTSRoutingPolicy.swift` — isSupertonic3Available 추가
- `MyTeam/SpeechManager.swift` — synthesize(text:agentID:) 공개 API 추가, ONNXRunner 직접 호출
- `MyTeam/AgentChatView.swift` — SpeakButtonView 추가 (말하기 버튼)
- `MyTeam/TTSLabView.swift` — officialEngineStatusSection 추가
- `MyTeam/RuntimeDiagnosticsService.swift` — 256TTS 필드 10개 추가
- `MyTeam/ToolContractValidator.swift` — 256TTS validators 6개 추가 (호출 + 구현)

### 신규 스크립트
- `scripts/preflight_round256tts_official_engine.sh` — 18/18 PASS

---

## Preflight 결과

```
scripts/preflight_round256tts_official_engine.sh: 18/18 PASS ✅
```

---

## 보이스 프리셋 매핑

| 에이전트 | ID | 프리셋 | 성별 |
|----------|-----|--------|------|
| 레오 | agent_1 | M1 | 남 |
| 루나 | agent_2 | F1 | 여 |
| 모코 | agent_3 | F3 | 여 |
| 핀 | agent_4 | F4 | 여 |
| 치코 | agent_5 | F2 | 여 |
| 렉스 | agent_6 | M3 | 남 |
| 케이 | agent_7 | M2 | 남 |
| 래키 | agent_8 | M4 | 남 |
| 폴라 | agent_9 | F5 | 여 |
| 몽몽 | agent_10 | F3 | 여 |
| 올리버 | agent_11 | M5 | 남 |

---

## Apple TTS 차단 확인

```bash
grep -rn "AVSpeechSynthesizer" MyTeam/ --include="*.swift" \
  | grep -v '//.*AVSpeechSynthesizer' \
  | grep -v '".*AVSpeechSynthesizer'
# → 0건 ✅
```

---

## 금지 항목 확인

| 금지 항목 | 상태 |
|-----------|------|
| Apple TTS (폴백 포함) | ✅ 없음 |
| 모든 메시지 자동 재생 기본 ON | ✅ false |
| 앱 launch 자동 init | ✅ 없음 |
| ONNX 파일 git commit | ✅ 없음 |
| 모델 자동 다운로드 | ✅ 없음 |
| Qwen3 복구 | ✅ 없음 |

---

## 미결 항목 (다음 Gate)

- 모델 번들 정책 결정 (`bundlePolicyAccepted`)
- 릴리즈 통합 승인 (`releaseIntegrationApproved`)
- 실기기 한국어 품질 QA
- canShipAsProductFeature → true 조건 달성
