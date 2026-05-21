# SupertonicONNXSpike — Round 249TTS-SPIKE

## 목적

Supertonic3 ONNX 모델을 Swift에서 직접 실행하는 것이 실현 가능한지 검증하는 스파이크.

**스파이크 범위**: Developer Lab 전용. 프로덕션 TTS 경로(SpeechManager)에 연결하지 않음.

---

## 구현 파일 (Round 249TTS-SPIKE)

| 파일 | 역할 |
|---|---|
| `Supertonic3ONNXModelPaths.swift` | 4개 ONNX 파일 경로 해석 |
| `Supertonic3UnicodeIndexer.swift` | unicode_indexer.json 로드, 텍스트 → token ids |
| `Supertonic3VoiceStyle.swift` | voice preset JSON 로드, style_ttl / style_dp 텐서 추출 |
| `Supertonic3ONNXRunner.swift` | 4단계 ONNX 파이프라인 (실제 onnxruntime_objc 호출) |
| `Supertonic3ONNXSpike.swift` | 프로덕션 준비 게이트 (모든 플래그 false) |

---

## ONNX 파이프라인 (4단계)

Python SDK 소스(`supertonic/core.py`)에서 역엔지니어링한 Swift 구현.

### 1. Duration Predictor
- 입력: `text_ids` [1, T] int64, `style_dp` [1, 8, 16] float32, `text_mask` [1, 1, T] float32
- 출력: `dur_onnx` [1, T] float32

### 2. Text Encoder
- 입력: `text_ids` [1, T] int64, `style_ttl` [1, 50, 256] float32, `text_mask` [1, 1, T] float32
- 출력: `text_emb` [1, T, 256] float32

### 3. Vector Estimator (×N steps, default 8)
Flow Matching ODE (CFM). 초기 노이즈는 Box-Muller 변환으로 Gaussian 샘플링.

- 입력: `noisy_latent` [1, 144, L], `text_emb`, `style_ttl`, `text_mask`, `latent_mask` [1, 1, L], `current_step` [1], `total_step` [1]
- 출력: `xt` [1, 144, L]

latent_dim = ldim(24) × chunk_compress_factor(6) = 144

### 4. Vocoder
- 입력: `latent` [1, 144, L] float32
- 출력: `wav` [1, N] float32 (44.1kHz PCM)

### 텍스트 전처리
1. NFKD 정규화 (Swift: `decomposedStringWithCompatibilityMapping`)
2. 마침표 추가 (없을 경우)
3. 언어 토큰 래핑: `<ko>안녕하세요.</ko>`
4. unicode_indexer 룩업: codepoint → model index (-1 = 지원 안 함, 스킵)

---

## 설정값 (tts.json 기준)

| 항목 | 값 |
|---|---|
| sample_rate | 44100 Hz |
| base_chunk_size | 512 |
| chunk_compress_factor | 6 |
| latent_dim (ldim) | 24 |
| effective latent_dim | 144 (= 24 × 6) |
| flow-matching steps | 8 (기본) |

---

## 모델 경로

```
~/.cache/supertonic3/
├── onnx/
│   ├── text_encoder.onnx       (~35 MB)
│   ├── duration_predictor.onnx (~3.5 MB)
│   ├── vector_estimator.onnx   (~245 MB)
│   ├── vocoder.onnx            (~97 MB)
│   ├── unicode_indexer.json
│   └── tts.json
└── voice_styles/
    ├── F1.json .. F5.json
    └── M1.json .. M5.json
```

앱 번들에 포함하지 않음. 자동 다운로드 없음.

---

## 프로덕션 준비 게이트

`SupertonicProductReadiness` 모든 플래그가 true여야 프로덕션 사용 가능:

| 게이트 | 상태 |
|---|---|
| Swift 빌드 검증 | ⬜ Mac 로컬 빌드 필요 |
| 합성 실행 성공 | ⬜ Mac 로컬 실행 필요 |
| RTF 허용 범위 | ⬜ 미측정 (목표: < 0.05x) |
| 오디오 품질 검증 | ⬜ 청취 테스트 필요 |
| App Store 라이선스 | ⬜ OpenRAIL-M 법무 검토 필요 |
| 배포 전략 결정 | ⬜ 다운로드 방식 미결정 |

→ **현재: 프로덕션 사용 불가. Developer Lab 스파이크만.**

---

## 정책 제약

- main product surface TTS 노출 금지
- SpeechManager에 ONNXRunner 직접 연결 금지
- SystemTTS/Apple TTS fallback 금지
- 앱 launch 시 자동 초기화 금지
- 모델 파일 app target resource 포함 금지
- 대용량 모델 git commit 금지
- production-ready 표현 금지 (readiness gate 미통과 시)

---

## Mac 로컬 QA 체크리스트

Round 249TTS-SPIKE 완료 후 Mac 로컬에서 수행:

- [ ] `xcodebuild ... Debug build` → BUILD SUCCEEDED, 0 warnings
- [ ] `xcodebuild ... Release build` → BUILD SUCCEEDED, 0 warnings
- [ ] TTSLabView > ONNX Spike 섹션 표시 확인
- [ ] "ONNX 합성 실행" 버튼 누름 → 에러 없이 결과 표시
- [ ] RTF 수치 확인 (< 0.5x 목표)
- [ ] 생성된 WAV 파일 `afplay`로 재생 → 음질 확인
- [ ] `bash scripts/preflight_round249tts.sh` → 17/17 통과

---

## 다음 단계 (스파이크 성공 후)

1. Mac 로컬 빌드 + 합성 검증 완료
2. `SupertonicProductReadiness` 플래그 업데이트
3. 오디오 재생 경로 연결 (44100Hz → AudioPlaybackService)
4. SpeechManager TTSRoutingPolicy 연결 (적절한 시점)
5. App Store 라이선스 검토
6. 모델 배포 전략 결정

**Last updated**: 2026-05-21 Round 249TTS-SPIKE
