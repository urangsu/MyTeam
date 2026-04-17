# MyTeam Task Tracker

> **위치**: `/Users/su/Desktop/MyTeam/TASK.md`
> **담당**: Antigravity (Claude Sonnet) + Claude Code 공동 관리
> **규칙**: 추가할 기능, 수정할 버그, 리팩토링 계획 등은 모두 이 파일에 관리합니다. 작업이 완료되면 `[x]` 표시를 하고, 그 내역을 루트의 `DEVLOG.md`에 추가해 주세요!

---

## 🎯 프로젝트 목표 (모든 작업자 반드시 숙지)

> **Mac App Store(macOS)를 통해 정식 출시할 데스크톱 어플리케이션을 만든다.**  
> 기한은 아직 많이 남아있으므로 완성도가 매우 중요하다.
> **목표 완성도: 애플 퍼스트파티(First-party) 제품 수준.** 로직을 바꾸든, 새로운 라이브러리를 도입하든, 뭐든 좋다. 최상의 결과만 낸다.

### 작업 전 항상 스스로에게 질문할 것

1. **"이게 Mac App Store 샌드박스 환경에서 배포 가능한 형태인가?"** — Python 서버, 외부 프로세스(`Process()`), `/Users/...` 계열의 절대경로 하드코딩은 모두 **심사 거절(Rejection)** 사유이자 배포 블로커.
2. **"애플 퍼스트파티 앱처럼 느껴지는가?"** — 버벅임, 끊김, 로딩 인디케이터 없이 즉각 반응해야 함
3. **"더 빠르게, 더 작게, 더 우아하게 만들 수 없는가?"** — 항상 개선 여지를 고민

### 앱스토어 배포를 위한 현재 구조적 블로커

| 블로커 | 내용 | 해결 방향 |
| 🟢 Python TTS 서버 | `mlx_tts_server.py`를 앱에서 실행 불가 (샌드박스 위반) | MLX-Swift 네이티브 전환 (진행 중) |
| [x] 절대경로 하드코딩 | `/Users/su/Desktop/...` 경로 다수 존재 | `FileManager` 컨테이너 내부 경로로 전면 교체 완료 |
| 🟡 AI API 키 | 현재 UserDefaults 저장 (보안 취약) | `KeychainManager` 연동 완료 (일부 잔존 로직 마이그레이션 중) |
| 🟡 모델 파일 크기 | MLX 가중치 1.95GB | On-Demand Resources 또는 4-bit 양자화 모델 배포 예정 |
| [x] 통합된 거대 클래스 | `SpeechManager`, `AgentChatView` 등 비대화 | 오디오 엔진(`AudioPlaybackService`) 등 역할 분리 완료 |

---

## 💎 macOS 네이티브 앱을 위한 고도화/최적화 과제 (심층 분석)

우리가 "애플 제품 같은" 수준으로 가기 위해 당장 눈에 보이는 버그 외에 구조적으로 뜯어고쳐야 할 기술적 부채와 최적화 포인트들입니다.

### [x] [우선순위 1] Mac App Store 샌드박스 완벽 대응 및 보안 (완료)
- **이슈**: 현재 코드 베이스 어딘가에 바탕화면이나 문서 폴더를 직접 찌르는 경로가 있다면 샌드박스 활성화 시 앱이 그 즉시 크래시 납니다. 통신용 API 키 저장 방식도 취약합니다.
- **해결 방안 및 결과**: 모든 파일 I/O(TTS 캐시, 모델 파일 로딩, 로그 저장)를 `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)` 샌드박스 컨테이너 내부로 캡슐화 완료했습니다. API 키 등 민감 정보는 기존 UserDefaults 평문 방식에서 자체 구축한 **KeychainManager**를 통한 암호화 저장으로 모두 마이그레이션 및 적용 완료했습니다 (블로커 해소).

### [x] [우선순위 2] 구조적 아키텍처 개선 (오디오 엔진 분리 완료)
- **이슈**: `SpeechManager.swift` 하나가 오디오 엔진 관리, 네트워크 통신, 파일 캐싱 등을 모조리 관리하던 문제.
- **결과**: 오디오 재생 전담(`AudioPlaybackService`), 세션 관리(`WebSocketStreamManager`), 캐시 적재(`AnimalTTSCacheManager`)로 분리 완료. 의존성 주입(DI) 기반 아키텍처로 체계화. (2026-04-07)

### [우선순위 3] Unified Memory 환경에서의 온디바이스 AI 최적화 (MLX-Swift)
- **이슈**: Mac은 8GB 모델부터 존재합니다. 현재 TTS 모델만 1.95GB를 차지하며, Python 브릿지를 타기 때문에 시스템 모니터링 시 거슬립니다. 다른 온디바이스 모델(LLM) 구동 시 OOM이 매우 쉽게 일어납니다.
- **고도화 방향**: 
  - `apple/mlx-swift` 네이티브 이식을 완료하고, 가중치 로딩 시 **4-bit / 8-bit Quantization(양자화)** 모델을 채택. 
  - 음성 합성이 끝난 후 일정 시간(예: 30초) 동안 호출이 없으면 GPU 메모리에서 가중치를 Unload 하는 **Dynamic Memory Management** 로직 구축.

### [우선순위 4] 대화 기록 및 상태 관리의 무결성 보장 (SwiftData)
- **이슈**: 대화 기록이 단순히 메모리상의 배열에 의존하거나 일반 텍스트 포맷으로 관리되면 데이터 손실, 성능 저하, 검색 불가 문제가 발생합니다.
- **고도화 방향**: 최신 애플 표준인 **SwiftData**를 도입하여 대화 로그, 캐릭터별 볼륨/피치 선호도, 사전합성 캐시 메타데이터 등을 관계형 트랜잭션으로 구축해 앱의 뼈대와 데이터 무결성을 보장합니다.

### [우선순위 5] macOS 데스크톱 네이티브 최고 수준의 UX/UI 폴리싱
- **이슈**: 단순 윈도우가 아니라 화면 귀퉁이에 떠있는 상주형 에이전트라면 네이티브 디자인 인터페이스 규칙(HIG)을 완벽하게 지켜야 합니다.
- **고도화 방향**: `NSPanel`을 활용해 타 앱 위로 자연스럽게 컴패니언으로 떠다니고, 배경에 `NSVisualEffectView` (유리 질감 블러)를 시스템 모드(다크/라이트)에 즉각 반응하게 적용하며, 화면 엣지 스냅핑(Edge snapping) 애니메이션 등을 60프레임으로 제공합니다.

---

# 🆕 ACTIVE PLAN — 2026-04-15 Chatterbox Multilingual 전면 피벗

> **이 블록이 현재 유일한 유효 실행 계획입니다.**
> 아래 "🚀 TTS 고도화 로드맵" ~ "온디바이스 TTS CoreML/MLX 전환" 섹션은 **모두 레거시/실패 이력**으로 보존만 합니다.
> 새 에이전트는 이 블록 끝까지 읽고, 실패 이력은 `DEVLOG.md` 2026-04-10 / 2026-04-15 항목으로 맥락 파악하시기 바랍니다.

## 🎯 최상위 목표

**ONNX 역공학 폐기** → **mlx-audio + Chatterbox Multilingual** 로 전면 전환.

- 13개 캐릭터 각자 다른 목소리 (zero-shot voice cloning)
- 한국어 정식 지원 (Resemble AI 공식 학습, 7~8/10 품질)
- 감정 표현 (happy/sad/thinking)
- macOS Apple Silicon 네이티브 (MLX)
- MIT 라이선스 (상업 배포 OK, App Store 안전)
- 3~4초 지연, 사용자 추가 설치 없음

## 🚫 절대 하지 말 것 (Dead Ends — 2026-04 검증 완료)

1. **ONNX Chatterbox 역공학 재개** — `MLXInferenceService.swift` + S3Gen CFM의 `spks`/`cond` 생성 로직은 원본 Python 소스 없이 복원 불가. 20초 지연 + "치지직" 한 번으로 검증 끝.
2. **Kokoro-82M** — Apache 2.0이지만 **한국어 미지원** (지원 언어: EN/JA/ZH/ES/FR/HI/IT/PT). VOICES.md 직접 확인 완료.
3. **F5-TTS** — 한국어 지원 문서 없음, 사실상 영어 전용.
4. **Fish-Speech / IndexTTS2** — 라이선스 지뢰 (CC-BY-NC-SA / commercial 조건 불명). App Store 심사 실격 리스크.
5. **Apple TTS / AVSpeechSynthesizer** — 수석님이 기계음으로 강력 거부. 폴백으로도 금지.
6. **AnimalTTSService 음절 WAV** — 기계음 동일 취급, 사용 금지.
7. **Python mlx_tts_server.py + 자체 T3 Llama** — 샌드박스 위반으로 App Store 배포 불가.

## 📚 반드시 읽어야 하는 자료

| # | 파일 / URL | 용도 |
|---|---|---|
| 1 | `/Users/su/Desktop/MyTeam/DEVLOG.md` | 2026-04-10/15 실패/피벗 사유 |
| 2 | `~/.claude/projects/-Users-su-Desktop-MyTeam/memory/DEVLOG.md` | 역공학 실패 상세 |
| 3 | `~/.claude/projects/-Users-su-Desktop-MyTeam/memory/feedback_no_apple_tts.md` | Apple TTS 절대 금지 사유 |
| 4 | `~/.claude/projects/-Users-su-Desktop-MyTeam/memory/feedback_honorifics.md` | "수석님" 호칭 + 존댓말 규칙 |
| 5 | https://github.com/Blaizzy/mlx-audio | mlx-audio 저장소 (MIT) — Chatterbox 포함 |
| 6 | https://github.com/resemble-ai/chatterbox | Chatterbox 본가 (MIT) — Multilingual 브랜치 |
| 7 | https://www.resemble.ai/introducing-chatterbox-multilingual-open-source-tts-for-23-languages/ | Multilingual 한국어 지원 공식 발표 |

---

## 🗂️ Phase 0 — 사전 검증 (20분 컷, 소리 한 번 들으면 끝)

> **목적:** Chatterbox Multilingual이 실제로 Apple Silicon에서 한국어를 읽는지 스모크 테스트. 이게 안 되면 Phase 1 이후는 전부 의미 없음.

### - [ ] TASK-0.1: mlx-audio Python PoC
- **작업자:** 단독 (Python/Mac 지식 필요)
- **출력:** 한국어 샘플 WAV 1개 ("안녕하세요 수석님, 반갑습니다")
- **단계:**
  1. 새 디렉토리 `/Users/su/Desktop/TTS맨/mlx-audio-poc/` 생성
  2. `python3 -m venv .venv && source .venv/bin/activate`
  3. `pip install mlx-audio` (MIT 라이선스 확인)
  4. `/Users/su/Desktop/TTS맨/chatterbox/ref_voices/` 에서 기존 WAV 1개 복사해서 레퍼런스로 사용
  5. mlx-audio README의 Chatterbox 예시 코드 그대로 실행
  6. 생성된 output.wav 재생 → 사람 소리인지 확인
- **성공 기준:**
  - [ ] import 성공, 모델 다운로드 완료
  - [ ] 한국어 텍스트 → 알아들을 수 있는 한국어 음성 출력
  - [ ] 생성 시간 < 10초 (M-시리즈 기준)
- **실패 대응:** mlx-audio가 Chatterbox Multilingual 미포팅이면 → TASK-0.2 즉시 전환
- **기록:** `/Users/su/Desktop/MyTeam/DEVLOG.md` 에 결과 추가

### - [ ] TASK-0.2: (Fallback) Chatterbox 본가 Python MPS PoC
- **선행:** TASK-0.1 실패 시에만
- **단계:**
  1. `pip install chatterbox-tts` (resemble-ai 공식)
  2. `ChatterboxMultilingualTTS.from_pretrained(device="mps")`
  3. 동일 한국어 샘플 생성
- **성공 기준:** MPS에서 10초 이내 한국어 WAV 생성
- **실패 대응:** Phase 0을 CosyVoice 2 로 재시도 (별도 Task 추가)

### - [ ] TASK-0.3: 성능 프로파일링
- **선행:** TASK-0.1 또는 TASK-0.2 성공
- **측정:**
  - 콜드 스타트 / 핫 생성 (5/25/50/100자)
  - RAM, 온도, CPU/GPU 활용률
- **성공 기준:** 25자 < 3초, RAM < 6GB, 온도 < 70°C
- **결과:** `mlx-audio-poc/benchmark.md` + `DEVLOG.md`

---

## 🗂️ Phase 1 — 레퍼런스 음성 자산 준비

> Chatterbox zero-shot cloning은 레퍼런스 WAV 품질이 결과 품질의 거의 전부.

### - [ ] TASK-1.1: 13 캐릭터 명단 확정
- **입력:** `AnimalTTSManager.swift`, `AgentPersona.swift`, `CharacterDialogues.swift`
- **단계:** Grep으로 13개 캐릭터 이름 추출 + 성별/연령/톤/감정 메타데이터 정리
- **출력:** `/Users/su/Desktop/MyTeam/MyTeam/CharacterRoster.md`

### - [ ] TASK-1.2: 기존 레퍼런스 WAV 감사
- **선행:** TASK-1.1
- **확인 경로:**
  - `/Users/su/Desktop/TTS맨/chatterbox/ref_voices/`
  - `/Users/su/Desktop/MyTeam/MyTeam/Resources/ReferenceAudio/` (현 .mp3)
  - `/Users/su/Desktop/MyTeam/MyTeam/PrecomputedVoice/`
- **출력:** `voices-audit.md` (있음/없음/품질 평가)

### - [ ] TASK-1.3: 누락/저품질 레퍼런스 보완
- **선행:** TASK-1.2
- **옵션:**
  - A. 기존 고품질 WAV에서 3~5초 구간 `ffmpeg`로 컷
  - B. 수석님 직접 녹음 요청 — **마지막 수단**
- **품질 기준:** 3~5초, 배경 잡음 -40dB 이하, 중립 톤, 24kHz mono 16-bit
- **출력:** `Resources/ReferenceVoices/{character}.wav`

### - [ ] TASK-1.4: 레퍼런스 임베딩 사전 계산
- **선행:** TASK-0.1 + TASK-1.3
- **단계:**
  1. Chatterbox `PrepareConditionals` API로 WAV → 임베딩 추출
  2. `.safetensors` 로 저장
  3. 런타임에 임베딩만 로드하도록 구조 설계 (WAV 파싱 단계 제거)
- **출력:** `Resources/ReferenceEmbeddings/{character}.safetensors`
- **이유:** 콜드 스타트 단축 + 앱 번들 크기 감소

---

## 🗂️ Phase 2 — TTS 서버 전면 교체 (Python, 임시)

> **주의:** 이 서버는 **개발용 과도기** 입니다. App Store 배포 버전에서는 Phase 5에서 PyInstaller 번들 또는 Swift 네이티브로 재이식합니다.

### - [ ] TASK-2.1: 기존 서버 계약 분석
- **입력:** `/Users/su/Desktop/TTS맨/chatterbox/mlx_tts_server.py`, `OnDeviceTTSManager.swift`
- **출력:** `api-contract.md` (엔드포인트/요청·응답 스키마/캐시 키 정책)
- **핵심 확인:** `SpeechCacheManager` 캐시 키와 호환되는지

### - [ ] TASK-2.2: 새 서버 `chatterbox_ml_server.py` 구현
- **선행:** TASK-2.1 + Phase 1 완료 + TASK-0.1 성공
- **위치:** `/Users/su/Desktop/TTS맨/chatterbox/chatterbox_ml_server.py`
- **요구사항:**
  - FastAPI/Flask (기존과 동일), 포트 **9998 유지**
  - 요청 스키마 100% 호환 → Swift 클라이언트 무수정
  - 콜드 스타트 시 13 캐릭터 임베딩 preload
  - 응답: 24kHz mono WAV
  - 감정 태그 실험 (`[happy]` prefix or API param)
- **출력:** 동작 서버 + `README.md`

### - [ ] TASK-2.3: 서버 벤치마크
- **테스트:** 5/25/50/100자 × 13 캐릭터 순환, 각 10회
- **성공 기준:** 25자 P95 < 3초
- **출력:** `benchmark.md`

### - [ ] TASK-2.4: 구 서버 보존 + 전환
- **단계:**
  1. `mlx_tts_server.py` → `mlx_tts_server.py.legacy` (삭제 금지, 롤백용)
  2. `chatterbox_ml_server.py` 기본 실행으로 승격
  3. `run_tts.sh` / launchd plist 업데이트

---

## 🗂️ Phase 3 — Swift 클라이언트 정리

> ONNX 경로 완전 제거 + HTTP 클라이언트 재점검. 이상적으로는 `OnDeviceTTSManager.swift` 한 파일만 건드려서 마무리.

### - [ ] TASK-3.1: ONNX 파이프라인 데드코드 삭제
- **삭제 대상:**
  - `/Users/su/Desktop/MyTeam/MyTeam/MLXInferenceService.swift` (전체)
  - `/Users/su/Desktop/MyTeam/MyTeam/T3MLXModel.swift` (전체)
  - `/Users/su/Desktop/MyTeam/MyTeam/MLXModelManager.swift` (Phase 2 이후 호출부 없으면)
  - `/Users/su/Desktop/MyTeam/MyTeam/PrecomputedVoice/*.json` (Phase 1.4의 .safetensors로 대체)
  - `/Users/su/Desktop/MyTeam/MyTeam/Resources/onnx_models/*.onnx` 전체
  - `BPETokenizer.swift` (사용처 확인 후)
- **단계:**
  1. `Grep` 으로 각 클래스 사용처 전수조사
  2. 호출부 선(先)차단 → 빌드 에러로 경로 확인
  3. 파일 삭제 + `project.pbxproj` 참조 제거
  4. 클린 빌드 성공 확인
- **성공 기준:** TTS 경로가 HTTP 서버 1개로 귀결, 빌드 성공

### - [ ] TASK-3.2: `OnDeviceTTSManager.swift` 재검증
- **선행:** TASK-3.1 + TASK-2.4
- **단계:**
  1. `synthesizeOnly()` → `http://127.0.0.1:9998/synthesize` 호출 확인
  2. 24kHz mono WAV 응답 파싱 경로 검증
  3. 서버 미가동 시 무음 폴백 (Apple TTS 금지)
- **성공 기준:** 앱에서 말 걸면 3초 내 한국어 음성 재생

### - [ ] TASK-3.3: `SpeechCacheManager` 무효화
- **단계:**
  1. 캐시 키 접두사 `cm_v1_` 추가
  2. 기존 캐시 디렉토리 `~/Library/Application Support/MyTeam/SpeechCache/` 이름 변경(삭제 금지)
- **이유:** 모델 교체로 구 캐시 음색 불일치

### - [ ] TASK-3.4: `AnimalTTSManager` 단순화
- **현재:** AVAudioEngine 피치 조작 (실패 이력 — DEVLOG 2026-04-06)
- **변경 후:** 캐릭터 → 레퍼런스 임베딩 파일명 매핑 테이블만 유지 (20~30 LOC)

### - [ ] TASK-3.5: `AudioPlaybackService` 이펙트 노드 제거
- **단계:**
  1. `AVAudioUnitTimePitch` 분리
  2. `PlaybackCommand.pitch` deprecated
  3. 24kHz mono → 44.1kHz Stereo 변환 그래프만 유지
- **성공 기준:** 재생 코드 LOC 30% 이상 감소, 품질 정상

---

## 🗂️ Phase 4 — 캐릭터 보이스 매핑 & 감정

### - [ ] TASK-4.1: 13 캐릭터 × 보이스 프리셋 QA
- **단계:** 캐릭터별로 1~3회 생성 테스트 → 사람 귀로 이미지 일치 여부 평가 → 불일치 시 레퍼런스 재선정
- **출력:** `character-voice-mapping.md`

### - [ ] TASK-4.2: 감정 태그 스키마 확정
- **옵션:**
  - A. 텍스트 prefix `[happy]`
  - B. API 파라미터 `emotion`
  - C. 레퍼런스 자체를 감정별로 다중 보관
- **결정 기준:** Chatterbox 실제 동작 확인 후
- **출력:** `emotion-schema.md`

### - [ ] TASK-4.3: LLM 응답 감정 메타데이터 주입
- **단계:**
  1. `AIService.swift` 시스템 프롬프트에 `[감정]` 태그 규칙 추가
  2. 응답 파싱 → TTS 요청에 포함
  3. 태그 없으면 neutral
- **성공 기준:** "기뻐서 말해봐" → 실제 밝은 톤

---

## 🗂️ Phase 5 — App Store 대응 & 배포

> **최중요:** Python 서버는 App Store 샌드박스 위반. 이 Phase에서 해결하지 않으면 출시 불가.

### - [ ] TASK-5.1: 배포 아키텍처 결정
- **옵션 비교 필수:**
  - A. **PyInstaller 번들 + XPC** — Python 서버를 단일 바이너리화 후 XPC 서비스로 실행 (샌드박스 승인 가능성 확인 필요)
  - B. **Swift 네이티브 재이식** — mlx-audio의 Chatterbox 추론 경로를 MLX-Swift 로 포팅 (최선이나 난이도 높음)
  - C. **On-Demand Resources** — 모델 가중치만 ODR, 추론은 Swift
- **출력:** `deployment-architecture-decision.md` + 수석님 결재

### - [ ] TASK-5.2: E2E 시나리오 테스트
- **시나리오:**
  - [ ] 13 캐릭터 순차 발화 — 모두 다른 목소리
  - [ ] Barge-in 즉시 중단
  - [ ] 동시 요청 큐잉
  - [ ] 무음 모드
  - [ ] 25자 청크 순차 스트리밍 (말풍선 동기화)
  - [ ] 100자+ 끊김 없음
  - [ ] 감정 변화 구분
- **출력:** `integration-test-results.md`

### - [ ] TASK-5.3: 30분 안정성 테스트
- **측정:** RAM 증가, GPU 온도, 크래시 여부
- **성공 기준:** RAM 증가 < 200MB, 온도 < 75°C, 크래시 0

### - [ ] TASK-5.4: .dmg 배포 아티팩트
- **단계:**
  1. TASK-5.1 결정에 따라 번들 구성
  2. 라이선스 통합 (`LICENSES.md` + About 창)
  3. 코드 사이닝 + notarization
  4. 신규 Mac 설치 → 추가 설치 없이 동작 확인

### - [ ] TASK-5.5: App Store 심사 체크리스트
- [ ] 라이선스 전수조사 (Chatterbox MIT, mlx-audio MIT, MLX Apache 2.0)
- [ ] 개인정보/마이크 사용 설명 문자열
- [ ] 번들 크기 확인 (모델 포함 시 2GB 예상)
- [ ] 샌드박스 엔타이틀먼트 (로컬 127.0.0.1:9998 허용 가능 여부)
- [ ] notarization 통과

---

## 🗂️ Phase 6 — 문서 & 로그 규칙 (상시)

### TASK-6.1: Task 완료 시 `/Users/su/Desktop/MyTeam/DEVLOG.md` 갱신 포맷
```
## 2026-04-XX — TASK-X.Y 완료 (@작업자)
- 변경 파일: ...
- 결과: ...
- 발견 이슈: ...
- 해제된 의존성: TASK-A.B, TASK-C.D
```

### TASK-6.2: 실패 시 DEVLOG 필수 기록
- 시도한 접근법 + 실패 원인 → 다른 에이전트 중복 삽질 방지

### TASK-6.3: 아래 레거시 섹션은 삭제 금지
- 원인 분석과 되돌아갈 근거가 되므로 **보존만** 함
- 더 이상 수정하지 말 것

---

## 🏷️ Task 의존성 그래프

```
TASK-0.1 ─┬─> TASK-0.3 ─> G0
          └─> TASK-1.4

TASK-1.1 → TASK-1.2 → TASK-1.3 → TASK-1.4
TASK-2.1  (TASK-0.1과 병렬 가능)

G0 + TASK-1.4 + TASK-2.1 → TASK-2.2 → TASK-2.3 → TASK-2.4

TASK-2.4 + TASK-3.1 → TASK-3.2 → TASK-3.3
                                └→ TASK-3.4 → TASK-3.5

Phase 4: TASK-3.2 이후 병렬
Phase 5: Phase 4 이후 순차
```

**동시 작업 가능 에이전트 최대 3명:**
- A. Python 서버 (Phase 0 → 2)
- B. 자산 준비 (Phase 1)
- C. Swift 클라이언트 (Phase 3)

---

## 🚦 Go/No-Go 게이트

| 게이트 | 조건 | 통과 시 | 실패 시 |
|---|---|---|---|
| **G0** | TASK-0.1/0.2 성공 + 0.3 벤치 25자 < 3초 | Phase 1 | CosyVoice 2 재조사 |
| **G1** | 13 레퍼런스 임베딩 확보 | Phase 2 | 재녹음 |
| **G2** | P95 < 3초 | Phase 3 | 경량화 |
| **G3** | 앱에서 한국어 재생 정상 | Phase 4 | 클라이언트 재점검 |
| **G4** | 13 캐릭터 구분 가능 | Phase 5 | 레퍼런스 재선정 |
| **G5** | 샌드박스/배포 통과 | 출시 | TASK-5.1 재결정 |

---

## 📌 에이전트 작업 규칙 (필수)

1. **Task 시작 전:** `DEVLOG.md` 최신 항목 + 선행 Task 완료 여부 검증
2. **작업 중:** 범위 벗어나면 즉시 중단 → 이 파일에 sub-task 추가
3. **완료 후:** DEVLOG 기록 + 본 파일 체크박스 `[ ]` → `[x]`
4. **실패 시:** 원인 + 시도한 접근법 DEVLOG 기록 (중복 방지)
5. **호칭:** 모든 응답 "수석님" + 존댓말
6. **Apple TTS / 음절 WAV 유혹:** `feedback_no_apple_tts.md` 재독
7. **경로 규칙:** `/Users/su/Desktop/MyTeam/MyTeam/MyTeam/` 외 Swift 파일 건드리지 말 것

---

---

# 📜 LEGACY — 2026-04-15 이전 TTS 시도 기록 (보존용)

> ⚠️ 아래 섹션들은 **모두 실패** 또는 **피벗으로 무효화** 되었습니다.
> 수정 금지. 원인 분석·재발 방지 용도로만 존재합니다.
> 현재 유효한 계획은 위의 "ACTIVE PLAN" 블록입니다.

---

## 🚀 TTS 고도화 로드맵 (우선순위 순) — LEGACY

> **핵심 원칙**: 온디바이스, 서버 없음, 한국어 고품질, App Store 배포 가능

### 현재 TTS 구조 및 속도

```
[AI 응답] → splitIntoMessageChunks(25자) → speakChunk()
              ↓                                    ↓
    [prefetchChunk]              캐시 히트: <50ms (NSSound)
    URLSession → Python HTTP     캐시 미스: 1.5~5s (MLX 합성)
                 mlx_tts_server.py (포트 9998)
                      ↓
             T3 LlamaModel(30L, 1.95GB, MLX GPU)
             S3Gen CFM (ONNX, 5 euler steps)
             HiFiGAN Full (ONNX)
             → WAV → NSSound
```

**병목 지점**: T3 AR decode (1~3초) + HTTP 왕복 (100~200ms) + Python 프로세스 오버헤드

---

### 📍 Phase 1 (즉시 적용 가능) — 캐시 히트율 극대화

**원리**: MLX가 느린 건 어쩔 수 없으니, 캐시를 최대한 활용해서 사용자가 기다리는 시간을 0으로 만든다.

- [x] 사전 합성 캐시 시스템 (`SpeechCacheManager`, `pregenerate_dialogues.py`)
- [ ] **AI 응답 패턴 캐시** — 자주 쓰는 짧은 대사(인사, 감탄사, 리액션) 300개 사전 합성
  - "알겠어요!", "맞아요!", "흥미롭네요!" 등 공통 리액션을 캐릭터별 WAV로 빌드 타임에 포함
  - 앱 번들에 `Resources/SpeechCache/` 포함 → 설치 즉시 캐시 히트
- [ ] **AI 응답 길이 제어 강화** — 일상 대화 1문장(10자 이내) 목표, TTS 합성 0.8초 이내로
  - `splitIntoMessageChunks` maxChars=15로 축소 검토 (현재 25자)
  - AI 프롬프트: "일상 대화는 반드시 10자 이내 단문으로"
- [ ] **이벤트 대사 WAV 번들 포함** — pregenerate 완료 후 Xcode에 포함

---

### 📍 Phase 2 (1~2주) — MLX-Swift 네이티브 전환 【App Store 필수】

**원리**: Python HTTP 서버를 완전히 제거하고 Swift에서 직접 MLX 추론.  
`apple/mlx-swift` 패키지가 LlamaModel을 공식 지원함.

```
[현재] Swift → HTTP → Python mlx_tts_server.py → MLX GPU → HTTP → Swift
[목표] Swift → MLX-Swift (T3 LlamaModel) → MLX GPU → Swift (직접)
```

**구현 계획:**
- [ ] `apple/mlx-swift` Swift Package 추가 (`mlx`, `mlx-nn`, `mlx-optimizers`)
  - GitHub: `https://github.com/ml-explore/mlx-swift`
  - `mlx-swift-examples`의 LLM 구현 참고
- [ ] `MLXTTSEngine.swift` 신규 파일 — T3 LlamaModel Swift 구현
  - 가중치: 이미 `t3_mlx_weights.npz` 존재 (1.95GB, MLX 포맷)
  - KV Cache, CFG (2회 forward), BPE 토크나이저 Swift 이식
- [ ] S3Gen + HiFiGAN: ONNX → MLX 변환 또는 CoreML 재시도
  - S3Gen(26MB), HiFiGAN(80MB) → CoreML 변환은 이미 일부 성공
- [ ] `OnDeviceTTSManager` HTTP 클라이언트 경로를 MLX-Swift 경로로 교체
- [ ] Python 서버 의존성 완전 제거

**기대 효과:**
- HTTP 오버헤드 200ms 제거
- Python 프로세스 메모리/CPU 절약
- 앱스토어 배포 가능

---

### 📍 Phase 3 (장기) — 경량 한국어 TTS 모델 교체

**문제**: 현 T3+S3Gen+HiFiGAN 파이프라인은 총 1.95GB + 처리 시간 ~2초.  
**목표**: <200MB, <0.5초, 한국어 고품질

**검토 대상:**

| 모델 | 크기 | 속도 | 한국어 | 라이선스 | 배포 가능 |
|------|------|------|--------|----------|-----------|
| **VITS2-Korean** | ~100MB | <300ms | ✅ 네이티브 | Apache 2.0 | ✅ |
| **Kokoro-82M** | 82MB | <100ms | ⚠️ 현재 영어 중심 | MIT | ✅ |
| **Piper TTS** | 50~200MB | <100ms | ✅ 한국어 모델 있음 | MIT | ✅ |
| **StyleTTS2-Korean** | ~200MB | <500ms | ✅ | MIT | ✅ |
| **현재 Chatterbox** | 1.95GB | 1.5~5s | ✅ 제로샷 | Apache 2.0 | ❌ (Python) |

**우선 검토**: VITS2-Korean (CoreML 변환 → App Store 배포 가능, 한국어 품질 검증 필요)

---

### 📍 즉각적인 속도 개선 아이디어 (개발 오버헤드 낮음)

- [ ] **T3 maxTokens 동적 설정** — 입력 텍스트 길이에 비례 (15자→30토큰, 5자→10토큰)
  - 현재 고정값 → 짧은 대사가 불필요하게 오래 기다림
- [ ] **CFM 스텝 A/B 테스트** — 현재 5스텝. 3스텝에서도 품질 차이 청취 테스트
- [ ] **S3Gen + HiFiGAN CoreML EP 재확인** — 현재 설정됨, 실제 ANE 가속 여부 확인
- [ ] **speakChunk 타임아웃** — MLX 합성 5초 초과 시 텍스트만 표시하고 다음 청크로 넘어감
  ```swift
  // speakChunk 내부에 타임아웃 추가
  let result = await withTimeout(seconds: 5) {
      await SpeechManager.shared.synthesizeOnly(...)
  }
  ```

---

## ⚠️ 작업 경로 규칙 (반드시 준수)

**Antigravity와 Claude Code 모두 아래 단일 경로에서만 작업할 것:**

```
✅ 유일한 작업 경로: /Users/su/Desktop/MyTeam/MyTeam/MyTeam/
✅ task 파일:        /Users/su/Desktop/MyTeam/TASK.md  (이 파일)
✅ 개발 일지:        /Users/su/Desktop/MyTeam/DEVLOG.md
```

**절대 금지:**
- ❌ `/Users/su/Desktop/MyTeam/MyTeam/*.swift` 직접 수정 (Xcode 외부 경로)
- ❌ Claude Code worktree (`.claude/worktrees/`) 안에서 Swift 파일 수정
- ❌ 별도 task/devlog 파일 생성 (`.claude/DEVLOG.md` 등)

**이유**: 과거에 Antigravity는 `MyTeam/MyTeam/`에서, Claude Code는 `.claude/worktrees/`에서 각각 작업하면서 파일이 분기됨. 지금은 `MyTeam/MyTeam/MyTeam/`으로 통일됨.

## ✅ 완료된 작업 (2026-04-05 최종 세션)

- [x] **음절 반복 ("오늘 텐션 오늘 텐션")** — T3 decode에 CFG 복원 완료 (`CFG_DECODE_W=0.3`, 2회 forward pass)
- [x] **abort 파일 잔존 → 204 에러** — `abort_target_id` 변수 도입, 해당 요청만 취소하도록 수정
- [x] **CoreML EP 적용** — S3Gen/HiFiGAN ONNX에 `CoreMLExecutionProvider` 적용 (일부 ANE 가속)
- [x] **사전 합성 캐시 시스템** — `SpeechCacheManager.swift` + `pregenerate_dialogues.py` 구현, 이벤트 대사 <50ms 재생
- [x] **refHash 정수 불일치 버그** — Python `str(int(mtime))` / Swift `"\(Int(mtime))"` 통일
- [x] **Thinking Character UX** — `onAudioStarted` 콜백으로 텍스트·음성 동시 출력, 캐시 미스 시 typing... 유지 (2026-04-06)

## ✅ 완료된 작업 (2026-04-07 오디오 엔진 리팩토링)

- [x] **True Real-Time AVAudioEngine 리팩토링** — `NSSound` 및 파일 I/O 기반 레거시를 전면 교체하여 고성능 60fps급 오디오 파이프라인 구축
- [x] **WebSocket PCM 스트리밍 및 세션 멀티플렉싱** — `stream_id` 기반 컨트롤 프레임 처리 및 실시간 Raw PCM 스트리밍 연동
- [x] **안정화 및 최적화 (Robustness)** — Jitter Buffer(100ms), Silence Padding, Node Detach(Teardown) 구현으로 팝핑 노이즈 및 메모리 누수 방지
- [x] **AnimalTTS In-Memory 캐싱** — `AnimalTTSCacheManager (actor)` 기반 비동기 Pre-loading으로 수백 개 음절의 I/O 딜레이 제거
- [x] **Perfect Lip-Sync (오디오 팝업 동기화)** — `scheduleBuffer` 후킹 및 콜백 배관(`SpeechManager.shared.processRealtimeSSEStream`)을 통해 스피커 첫 발성 찰나에 UI 텍스트 출력 완벽 연동 (AgentChatView 레거시 로직 전면 파괴)

---

## 🚀 2026-04-07 완료 및 다음 작업

### ✅ 2026-04-07 완료: Mock → Real TTS 파이프라인 + ModelRouter
- [x] `MLXModelManager.swift` — WAV + Zero-Copy Memory Mapping 구현
- [x] `T3MLXModel.swift` (신규) — Llama AR 추론 + RoPE + KV Cache + BPE 토크나이저 연동
- [x] `MLXInferenceService.swift` — CoreML EP 강제, 파이프라인 (ve → s3gen_enc → s3gen_cfm → hifigan), `@autoreleasepool` 메모리 릭 차단
- [x] `AgentConfig.swift` — LLMProvider enum + openRouterModelId 필드 추가
- [x] `AIService.swift` — ModelRouter (Gemini/Claude/OpenRouter SSE) 및 Claude `3-5-sonnet` 업데이트

### ✅ 2026-04-07 완료: Phase 6 (보안/UI 조종석 및 네이티브 전환 완수)
- [x] **`KeychainManager.swift`** — 군사급 API 키 암호화 및 보관 로직
- [x] **`SettingsView.swift`** — API 키 등록 및 OpenRouter 모델 스위칭 UI
- [x] **`BPETokenizer.swift`** — 100% Swift 네이티브 자소 분리(Jamo split) 기반 BPE 텍스트 로더

---

## 🚧 다음 세션에서 해야 할 작업 (2026-04-08~)

### 🔴 1순위: 레퍼런스 오디오 WAV 변환 + ONNX 모델 파일 번들 배치

**상황**: MLXInferenceService.swift가 완성됐으나, 실행 환경 준비 필요

- [ ] **ReferenceAudio MP3 → WAV 변환** (24kHz, 16-bit mono PCM)
  - 현재: `Resources/ReferenceAudio/{char}_reference.mp3` (11개)
  - 필수: `Resources/ReferenceAudio/{char}_reference.wav`
  - 변환 명령: `ffmpeg -i 루나_reference.mp3 -ar 24000 -ac 1 -sample_fmt s16 루나_reference.wav`
  - 적용 범위: 루나, 레오, 렉스, 래키, 모코, 몽몽, 올리버, 치코, 케이, 폴라, 핀 (11개)

- [ ] **ONNX 모델 파일 앱 번들 확인**
  - 앱 번들에 필수 파일:
    - ✅ `Resources/onnx_models/ve.onnx` — Voice Encoder (화자 임베딩)
    - ✅ `Resources/onnx_models/s3gen_enc.onnx` — S3Gen Encoder
    - ❌ `Resources/onnx_models/s3gen_cfm.onnx` — S3Gen CFM (TTS맨에서 복사 필요)
    - ❌ `Resources/onnx_models/hifigan_full.onnx` — HiFiGAN (TTS맨에서 복사 필요)
    - ✅ `Resources/onnx_models/grapheme_mtl_merged_expanded_v1.json` — BPE 토크나이저
  - 복사 명령:
    ```bash
    cp /Users/su/Desktop/TTS맨/chatterbox/onnx_models/s3gen_cfm.onnx ~/Desktop/MyTeam/MyTeam/Resources/onnx_models/
    cp /Users/su/Desktop/TTS맨/chatterbox/onnx_models/hifigan_full.onnx ~/Desktop/MyTeam/MyTeam/Resources/onnx_models/
    ```

- [ ] **T3 FP16 가중치 파일 번들/Dev 폴백 확인**
  - 앱 번들 경로: `Resources/onnx_models/t3_mlx_weights_fp16.npz` (선호)
  - Dev 폴백: `/Users/su/Desktop/TTS맨/chatterbox/onnx_models/t3_mlx_weights_fp16.npz` (배포 빌드에선 ODR 필요)

### 🔴 2순위: 빌드 검증 + 첫 실행 테스트

- [ ] **Xcode 빌드 성공 확인**
  - `MLXModelManager.swift` (MLX, AVFoundation import)
  - `T3MLXModel.swift` (MLX.loadArrays, NPY 로드)
  - `MLXInferenceService.swift` (OnnxRuntimeSwift, CoreML EP)
  - `AgentConfig.swift` + `AIService.swift` 통합 확인

- [ ] **런타임 에러 확인 및 수정**
  - WAV 파일 없음 → "MP3 사용 불가" 오류 메시지 확인 (의도된 동작)
  - ONNX 파일 없음 → "[OrtSessionPool] ❌ 세션 초기화 실패" 로그 확인
  - 첫 token → T3 AR 디코딩 시작 → PCM 청크 yield 확인

### 🟡 3순위: 성능 측정 + 최적화

- [ ] **Token-to-Audio 레이턴시 프로파일링**
  - BPE 토크나이징 시간
  - T3 AR 디코딩 시간 (maxTokens 동적 설정 테스트)
  - ONNX CoreML EP 추론 시간 (ve → s3gen_enc → s3gen_cfm → hifigan)
  - PCM 청크 yield 오버헤드
  - 목표: 짧은 대사 (<20자) 1초 이내 출력 시작

- [ ] **메모리 사용량 모니터링**
  - MLX 가중치 메모리 (FP16, 약 950MB)
  - KV Cache 최대치 (AR 디코딩 중)
  - ONNX 세션 메모리 (CoreML EP)
  - 목표: 총 메모리 < 2GB (8GB Mac 최소 사양 고려)

### 🟡 4순위: 기존 미해결 과제

- [ ] [긴급 버그] AIService.swift 대화 품질 개선 (단답형 제거, 대화기록 절삭 완화)
- [ ] [UX] 채팅창 스크롤과 창 이동 충돌 해결
- [ ] [기능] CharacterDialogues 대사 추가 및 부자연스러운 대사 수정
- [x] [긴급] 에이전트(팀원)창: 말할 때 가로 크기 늘어났다 줄어드는 애니메이션 제거 — 팀원창 크기 항상 고정
- [ ] [긴급 버그] AIService.swift 대화 품질 개선 (단답형 제거, 대화기록 절삭 완화)
- [] [UX] 채팅창 스크롤과 창 이동 충돌 해결 — isMovableByWindowBackground=true 유지하되 ScrollView 영역에서는 스크롤 우선-해결 -> 팀채팅방 크기 조절 기능 추가 필요
- [ ] [기능] CharacterDialogues 대사 추가 및 부자연스러운 대사 수정 (끊김, 시간, 시기 부적절 등)

### 🔴 온디바이스 TTS — CoreML/MLX 전환 (ONNX 폐기)
> 캐시/서버 금지. 100% 동적 생성만.

**완료된 것**:
- [x] BPE 토크나이저 수정 완료 (unicodeScalars 기반 자모 분해)
- [x] ISTFT 수정 완료 (periodic Hann window — `nFFT`로 나누기)
- [x] KV Cache export + 42배 속도 향상
- [x] HiFiGAN Full ONNX (F0+Source+Decode 통합)
- [x] t3_cond_embeds pre-compute (perceiver 포함 34토큰 conditioning)
- [x] HiFiGAN F0 CoreML 변환 성공 (`f0_predictor.mlpackage`)
- [x] HiFiGAN Decode CoreML 변환 성공 (`hifigan_decode.mlpackage`)

**ONNX 실패 원인 (기록)**:
- CFG (Classifier-Free Guidance): batch=2 실행은 되지만 cond≈uncond로 효과 없음
- ONNX export 시 CFG 로직이 소실됨
- Python에서 2회 호출 CFG는 동작 확인 (첫 토큰 1763 → Python 원본 1761과 일치)

**다음 단계 (경로 선택 필요)**:

경로 A: **ONNX + 2회 호출 CFG + CoreML EP**
- ONNX 모델 유지, CFG를 모델 2번 호출로 구현
- CoreML EP(`CPUAndGPU`)로 GPU 가속
- 예상: 2-3시간, 3-5초/문장

경로 B: **CoreML 직접 변환** (현재 시도 중)
- `torch.diff`, `new_ones`, `fill` 등 미지원 op 계속 패치 필요
- coremltools 9.0 + transformers 5.2.0 호환성 문제
- 예상: 수일, 성공 보장 없음

경로 C (채택): **MLX** (Apple Silicon 네이티브) ✅ 동작 확인
- `pip install mlx mlx-lm` → 설치 완료
- T3 가중치 MLX 변환 완료 (`t3_mlx_weights.npz`, 1952MB)
- **MLX M4 GPU 벤치마크**: Prefill 279ms, Decode 29ms/step
- LlamaModel MLX 네이티브 구현 완료 (`mlx_t3_inference.py`)
- **✅ 전체 파이프라인 성공**: MLX T3 + CFG + ONNX S3Gen + HiFiGAN → "안녕하세요" 음성 출력 확인!
- T3 MLX GPU: 1.86초, 전체: 6.95초
- 스크립트: `/Users/su/Desktop/TTS맨/chatterbox/mlx_t3_inference.py`

**달성:**
  - [x] Swift 앱 연결 완료 (MLX TTS 서버 port 9998 → OnDeviceTTSManager)
  - [x] 앱에서 한국어 음성 출력 성공 ("반갑습니다", "안녕하세요" 등)
  - [x] Prompt 부분 트리밍 (깨진 레퍼런스 재구성 제거)
  - [x] 반복 패턴 감지 (3연속, ABAB, 최근10개 중 5회)

**현재 속도** (2026-04-06 기준):
| 대사 | 시간 | 비고 |
|------|------|------|
| "착지!" (4자) | 1.5초 | ✅ 가장 빠름 |
| "안녕하세요" (5자) | 1.7초 | ✅ 깨끗한 음성 |
| "안녕하세요 팀장님" (9자) | 3.5초 | ⚠️ 약간 느림 |
| 15자 이상 | 4~7초 | ❌ 반복/깨짐 발생 |

**속도 최적화 히스토리** (참고용):
| 최적화 | 속도 변화 |
|--------|----------|
| ONNX KV cache 없음 | 60초+ |
| ONNX KV cache | 3초 |
| ONNX INT8 | 0.46초 (Python) |
| MLX GPU | 1.86초 |
| + KV warm-up | 1.7초 |
| + CFG prefill only | 1.2초 |
| + CFM 2→1 step | 0.9초 (품질↓) |
| **현재 (CFM 5, CFG prefill)** | **1.5~3.5초** |

**다음 단계 (속도/품질 개선)**:
  1. **T3 decode에 CFG 복원** — 반복 문제 근본 해결 (속도↓ 품질↑)
  2. **S3Gen + HiFiGAN MLX 변환** — ONNX CPU(0.8~1.5초) → MLX GPU
  3. **MLX-Swift 네이티브** — HTTP 오버헤드 제거, Swift에서 직접 추론
  4. **스트리밍 재생** — 첫 청크 즉시 재생
  5. **서버 아키텍처 개선** — 싱글스레드 → 비동기 (abort 동시 처리)

경로 D: **transformers 다운그레이드** (4.44) 후 CoreML 변환
- Chatterbox가 5.2 전용이라 호환 안 될 수 있음

### 🟡 3순위: UI 개선
- [ ] [UI] 설정창 "사용자 설정" 개편: 사용자 이름 + 사용자 호칭 한 줄 배치, 맥락에 따라 두 호칭 유기적 사용
- [ ] [UI] 설정창 "팀원창" 섹션: 에이전트창 배경 투명도 조절 슬라이더
- [ ] [UI] 설정창 "현재 위치" → GPS 기반 자동 (CoreLocation)
- [ ] [정리] 구실만 갖춘 빈 파일 → 정상 작동하게 내용 채우기
- [ ] [정리] 불필요한 중복 파일 삭제

### 📋 이전 세션에서 완료한 것 (2026-04-05)
- [x] ONNXTTSManager.swift 전체 파이프라인 구현 (T3/S3Gen/HiFiGAN + 임베딩 룩업)
- [x] precompute_embeddings.py: 11캐릭터 speaker embedding pre-compute
- [x] T3 임베딩 가중치 6개 + spkr_enc 추출 (.npy)
- [x] SpeechManager: ONNX 우선 + NSSound 폴백
- [x] 이름 태그 정규식 버그 수정 (첫 글자 잘림)
- [x] 에이전트창 크기변동 버그 (updateStatusWindowWidth → statusPanel)
- [x] 말풍선 30초 타임아웃 안전장치
- [x] OnDeviceTTSManager 스트리밍 실패 시 false 반환
- [x] 카톡 스타일 채팅 (문장 분리 + 타이핑 딜레이 + ... 인디케이터)
- [x] FloatingPanel 모든 창 이동 가능
- [x] 설정창 .clipped() + isMovableByWindowBackground
- [x] 대사 시간 인식 + AI 시간 컨텍스트 주입
- [x] NSSound 중복 재생 방지
- [x] Mac mini 오디오 호환성: AVAudioEngine/AVAudioPlayer 무음 → NSSound 통일
- [x] [프롬프트] "본캐+부캐" 마스터 프롬프트 템플릿 적용 및 탈옥 방어 (AIService.swift)
- [x] [버그/최적화] AI 답변 이름 태그 정규식 제거 도입 (`[캐릭터이름] 어쩌고...`)
- [x] [채팅 UX] 개별대화방 대화 삭제 시 흔들림(Jiggle) 속도를 1/2로 느리게 조정
- [x] [채팅 UX] 편집 모드 전환 시 안 흔들리는 뷰 누락 버그 해결 (onAppear)
- [x] [채팅 UX] 대화 삭제(x버튼) 위치를 모두 화면 우측으로 동일하게 정렬하여 편의성 향상
- [x] [채팅 UX] 대화 삭제 시 가장 아래로 강제 스크롤되는 자동 다운 버그 수정
- [x] [UI/문구] AgentSettingsView 내부 타이틀 "직업 프리셋" 등 -> "보조 업무"로 변경
- [x] [창 관리] SettingsView에 "대화창 정돈" 버튼 추가 및 AgentWindowManager에 윈도우 우측/하단 정렬 로직 구현
- [x] [다중 연결] 팀 채팅방 "team_all" 멀티 에이전트 유기적 답변 체계(티키타카 오케스트레이션) 구축
- [x] [음성/UX] TTS SpeechManager단에서 이모티콘 낭독 방지를 위한 정규식(Regex) 절삭 로직 추가
- [x] [UI/문구] SettingsView 대화창 정돈 섹션을 더 깔끔한 디자인(작은 버튼 하나)으로 변경

### [최우선] ONNX 온디바이스 TTS — 진행 중 (2026-04-05~)

> ⚠️ AnimalTTSManager.swift는 절대 수정 금지.
> ONNXTTSManager.swift가 완전 온디바이스 추론 담당 (서버 불필요)

**현재 상태 (2026-04-05 업데이트)**:
- [x] ONNXTTSManager.swift 전체 파이프라인 구현 (7개 ONNX 모델)
- [x] precompute_embeddings.py: 11캐릭터 speaker embedding pre-compute 완료
- [x] T3 임베딩 가중치 6개 + spkr_enc 추출 (.npy)
- [x] SpeechManager 연동 구조 (ONNX → 음절 WAV → 레퍼런스 오디오 폴백)
- [x] T3 ONNX 모델 Gather OOB 버그 수정 (fix_gather_oob.py)
- [x] S3Gen mel_mask bool→float 변환 수정 (extractBoolsAsFloats)
- [x] **Python E2E 검증 완료** (T3→S3Gen→CFM→HiFiGAN→ISTFT→WAV 재생 확인)
- [ ] **Swift에서 실제 호출 안됨** — SpeechManager.speak()에서 useAnimalTTS=true이면 ONNX 스킵 (1순위에서 수정할 것)
- [ ] **main thread 블로킹** — ONNX 세션 로딩이 CoreML EP와 함께 main thread에서 실행 (1순위에서 수정할 것)
- [ ] cond_enc emotion 연동 (나중에)

**ONNX 파이프라인 요약** (다음 작업자 참고):
```
T3 prefill (inputs_embeds:[1,seq,1024] → logits:[1,seq,8194])
  ↓ AR decode loop (prefillSession 재사용, KV cache 미사용)
S3Gen encoder (token+prompt+xvector → mu/mask/conds/spks)
  ↓
CFM ODE 10 Euler steps (x + dt*dxdt)
  ↓
HiFiGAN F0 (speech_feat → f0)
  ↓ f0→sin wave source (T_mel × 480 samples)
HiFiGAN backbone (mel+source → magnitude+phase STFT)
  ↓
ISTFT (n_fft=16, hop=4, vDSP) → PCM float32 → WAV → NSSound
```

---

#### 📁 신규 생성할 파일 3개

**1. `TTSEngine.swift`** — 프로토콜 (엔진 교체 가능한 추상화 레이어)
```swift
protocol TTSEngine {
    func speak(text: String, profile: VoiceProfile) async
    func stop()
    var isSpeaking: Bool { get }
}
```

**2. `VoiceProfile.swift`** — 11개 캐릭터 × 감정별 Pitch/Rate 프로필 매트릭스
```swift
struct VoiceProfile {
    let voiceIdentifier: String  // AVSpeechSynthesisVoice
    let pitch: Float             // 0.5 ~ 2.0
    let rate: Float
    let volume: Float

    static func profile(for agentID: String, emotion: EmotionState) -> VoiceProfile
}
```
- 감정은 기존 `detectEmotion()` 결과값 그대로 활용
- 캐릭터별 기본 음색 방향 예시:
  - 치코: Pitch 높음, Rate 빠름 / joy: Pitch +0.2 / sad: Rate -0.2
  - 레오: Pitch 낮음, Rate 느림 / angry: Pitch +0.1
  - 루나: Pitch 중간, 부드럽게 / sad: Rate -0.3

**3. `TTSAudioSession.swift`** — AVAudioSession 관리 (플로팅 앱 충돌 방지 핵심)
```swift
// 다른 앱(Zoom, 음악 등)과 충돌 방지 — 이 설정 필수
try AVAudioSession.sharedInstance().setCategory(
    .playback,
    options: [.mixWithOthers, .duckOthers]
)
```
- `AVAudioSessionInterruptionNotification` 인터럽트 처리 포함할 것

---

#### 🔗 기존 파일 연동 포인트

**`AgentWindowManager.swift`**
- `detectEmotion()` 결과 → `NativeTTSEngine.speak(text, emotion, agentID)` 호출 추가
- TTS 시작 시 `speakingAgentID = agentID` 설정 → 말하는 중 스프라이트 모션 자동 연결
- TTS 종료 시 `speakingAgentID = nil` 복원

**`AIService.swift`**
- AI 응답 수신 후 기존 AnimalTTS 호출부를 NativeTTSEngine 호출로 교체

---

#### ✅ 작업 순서

1. `TTSEngine` 프로토콜 + `VoiceProfile` 설계 및 파일 생성
2. `NativeTTSEngine: TTSEngine` 구현 (AVSpeechSynthesizer)
3. `TTSAudioSession` 완성 (인터럽트 처리 포함)
4. `AgentWindowManager.detectEmotion()` → TTS 파이프라인 연결
5. AnimalTTSManager 호출부 NativeTTSEngine으로 교체 → 동작 확인 후 AnimalTTSManager 폐기 처리

---

#### 🔮 장기 확장 (지금 건드리지 말 것)
- `ChatterboxTTSEngine: TTSEngine` 으로 나중에 교체 예정
- 위 프로토콜 구조가 잡혀있으면 엔진만 갈아끼우면 됨

## 🔵 Claude Code 담당 — 5대 기능 로드맵

> ⚠️ Antigravity 작업과 충돌 방지: `MyTeam/MyTeam/` 경로에서만 작업. 신규 파일은 이 경로에 추가.

### [최우선 과제] 감정-스프라이트 연결 (현재 오작동/미구현)
- [ ] AI가 자신을 AI로 인식하여 표정을 지을 수 없다고 답변하는 문제 해결 (시스템 프롬프트 강화 및 자기 객관화 방지)
- [ ] 실제 AI 응답 감정과 UI 스프라이트 액션(.joy, .agree 등)이 완벽하게 연계되어 작동하도록 로직 재구현
- [ ] `AgentWindowManager`의 `detectEmotion()` 로직 재점검 및 뷰 계층 전달 오류 수정

### [최우선 과제] 멀티에이전트 대화 엔진 재구축 (AutoGen+CrewAI 하이브리드)

> **현재 문제**: 팀 채팅에서 랜덤 2~3명이 각각 독립적으로 대답 → 서로 참조 없는 병렬 독백
> **목표**: 에이전트들이 서로의 발언을 참조하며 자연스럽게 토의하는 유기적 대화
> **참고**: AutoGen SelectorGroupChat 패턴 + CrewAI Scoped Memory 패턴

#### 📁 신규 생성할 파일

**1. `TeamOrchestrator.swift`** — 팀 대화 오케스트레이터 (핵심)
```swift
class TeamOrchestrator {
    /// LLM Selector: 대화 맥락을 읽고 다음 화자를 선택 (AutoGen 패턴)
    func selectNextSpeaker(
        conversationThread: [ChatLog],
        agents: [AgentConfig],
        lastSpeaker: String?
    ) async -> String?  // agentID or nil(종료)

    /// 팀 대화 실행: 사용자 메시지 → 시스템 팀장이 작업 지시서(Work Order) 생성 → 에이전트 순차 수행
    func runTeamDiscussion(
        userMessage: String,
        roomID: UUID,
        maxTurns: Int = 3
    ) async

    /// 에이전트별 역할 프롬프트 (전략가=리드/종합, 디자이너=시각적제안, 보안=리스크지적)
    func buildAgentPrompt(agentID: String, role: DiscussionRole, previousTurns: [ChatLog]) -> String
}

enum DiscussionRole {
    case leader      // 토의 리드, 종합
    case contributor // 전문 의견 제시
    case critic      // 반론/리스크 제기
    case supporter   // 동의/보충
    case summarizer  // 마무리 정리
}
```

**2. `ConversationMemory.swift`** — 범위별 대화 기억 (CrewAI 패턴)
```swift
struct ConversationMemory {
    var teamContext: String       // 팀 전체 공유 맥락 (자동 요약)
    var agentMemories: [String: [String]]  // 에이전트별 사적 기억
    var currentTopic: String      // 현재 토의 주제

    /// 30개 초과 시 오래된 메시지를 AI로 요약 (토큰 관리)
    mutating func compactIfNeeded(messages: [ChatLog]) async -> String
}
```

#### 🔗 기존 파일 수정 포인트

**`AIService.swift`** — 시스템 프롬프트 분화
- 개별 대화용 프롬프트 vs 팀 토의용 프롬프트 분리
- 팀 토의 프롬프트에 포함: 이전 화자의 발언 요약, 현재 에이전트의 역할(leader/critic/etc), 대화 종료 조건
- Selector LLM 호출용 경량 프롬프트 추가 (다음 화자 선택 전용)

**`AgentChatView.swift`** — 팀 채팅 로직 교체
- 현재: `agents.shuffled().prefix(2...3)` + 순차 독립 응답
- 수정: `TeamOrchestrator.runTeamDiscussion()` 호출 → 자동 턴 진행
- 각 턴에서 이전 에이전트의 응답을 다음 에이전트의 컨텍스트로 주입

**`AgentPersona.swift`** — 에이전트 설명문 추가
- Selector가 "누가 이 주제에 답해야 하나"를 판단하려면 각 에이전트의 전문 분야 설명 필요
- 예: `레오: 비즈니스 전략 전문. 프로젝트 방향성, 의사결정, 리소스 배분에 강점`

#### ✅ 구현 순서
1. `TeamOrchestrator.swift` 생성 — Selector LLM 호출 + 턴 루프
2. `ConversationMemory.swift` 생성 — 맥락 요약 + 범위별 기억
3. `AgentPersona.swift` — 에이전트별 1줄 설명 추가 (Selector용)
4. `AIService.swift` — 팀 토의용 프롬프트 + Selector 프롬프트 추가
5. `AgentChatView.swift` — 팀 채팅 `team_all` 분기를 Orchestrator로 교체
6. 테스트: "취득세 검토해줘" → 레오(리드) → 렉스(법률) → 케이(리스크) → 레오(종합)

#### Selector 프롬프트 설계 (핵심)
```
당신은 팀 대화의 진행자입니다. 아래 대화를 읽고, 다음에 발언할 에이전트를 선택하세요.

[참가자]
- 레오(agent_1): 비즈니스 전략, 프로젝트 리드
- 루나(agent_2): 마케팅, 크리에이티브
- 렉스(agent_6): 법률, 규정 분석
- 케이(agent_7): 보안, 리스크 평가

[대화 기록]
{conversation_history}

[규칙]
- 직전 화자는 연속 선택 불가
- 주제와 무관한 에이전트는 선택하지 말 것
- 충분히 논의되었으면 "DONE"을 출력
- 에이전트 이름만 출력 (예: "렉스")
```

### [P1 진행중] TTS 교체
> Antigravity TASK.md의 TTSEngine 프로토콜 방식 사용. 아래 수치를 VoiceProfile에 추가할 것.
- 11개 캐릭터 pitch/rate: 치코(+400c/1.15x), 레오(-200c/0.9x), 루나(+300c/1.1x), 렉스(-400c/0.75x), 핀(+500c/1.2x), 모코(+100c/0.95x), 케이(-200c/0.9x), 래키(+100c/1.1x), 폴라(-300c/0.85x), 몽몽(+500c/1.2x), 올리버(-150c/0.95x)
- `speak(text:agentID:)` — agentID로 speakingAgentID 연동

### [P2] 대화 축약 전달 (ConversationHandoff)
- [ ] `ConversationSummarizer.swift` — AI로 대화 축약 (맥락+미션+결론+남은과제)
- [ ] `ConversationHandoffView.swift` — 편집 가능한 축약본 + 목적지 선택 UI
- [ ] `ChatModels.swift` 확장 — isHandoff 플래그, 시스템 프롬프트 주입 (받는쪽 맥락 인식)
- [ ] `AgentChatView.swift` — 공유 버튼에 HandoffView 연결

### [P3] 외부 서비스 연동 (Function Calling)
- [ ] `ToolExecutor.swift` — AgentTool 프로토콜 + 실행 엔진 (Gemini/Claude/OpenAI 각 포맷)
- [ ] `AIService.swift` — Function Calling 3사 지원 + tool call 루프 (최대 3회)
- [ ] `GoogleOAuthManager.swift` — OAuth 2.0 PKCE (토큰 → KeychainManager 저장)
- [ ] `Tools/GoogleCalendarTool.swift` — 일정 조회/생성
- [ ] `Tools/GoogleSheetsTool.swift` — 시트 생성/수정
- [ ] `Tools/GoogleSlidesTool.swift` — 장표/PPT 자동 생성 (1순위 디자인 도구)
- [ ] `Tools/GmailTool.swift` — 메일 검색/초안
- [ ] `Tools/FigmaTool.swift` — 디자인 조회 (2순위)
- [ ] `Tools/WebSearchTool.swift` — Gemini Grounding
- [ ] `SettingsView.swift` — Google 연동 섹션 추가

### [P4] 다단계 워크플로우 + 자율 토의
- [ ] `WorkflowModels.swift` — Workflow, WorkflowStep, DiscussionTurn, CrossCheckConfig
- [ ] `WorkflowEngine.swift` — 단계별 실행, 의존성 추적
- [ ] `DiscussionEngine.swift` — 에이전트 라운드 로빈 자율 토의 (역할 미지정시도 자동 배정)
- [ ] `AgentOrchestrator.swift` — 자연어→Workflow 변환, 크로스체크, [DELEGATE] 파싱
- [ ] `WorkflowView.swift` — 타임라인 UI + 실시간 토의 표시
- [ ] 작업 완료 알림: 최소화 패널 위글 + 뱃지

---

## 📌 나중에 다시 고민할 과제 (Deferred / Recorded)

### 1. 개별 에이전트 공간 확장 (꼬리 짤림 해결)
- **현상**: 에이전트 꼬리 등이 창 크기(100x140)에 비해 커서 9:16 영상 삽입 시 짤리는 문제.
- **아이디어**: 가로 폭을 130~140px로 확장하여 여백 확보 검토. (팀 테이블 전체 너비 증가 동반됨)

### 2. 멀티에이전트 유기적 대화 엔진 (TeamOrchestrator)
- **현상**: 현재 빌드 에러 및 로직 정교화 필요로 인해 잠시 중단.
- **기록된 에러**:
  - `nil' requires a contextual type`
  - `Cannot find type 'AgentConfig' in scope`
  - `Cannot infer contextual base in reference to member 'whitespacesAndNewlines' / 'regularExpression'`
- **목표**: AutoGen SelectorGroupChat + CrewAI Scoped Memory 패턴 도입하여 병렬 독백이 아닌 유기적 토론 구현.

---

## 📝 향후 작업 (Backlog & TODO)

**🛠️ 기능 고도화**
- [ ] 에이전트 고도화 (OpenClo Lite): `AgentOrchestrator`를 통한 에이전트 간 위임, `SharedWorkspace` 연동
- [ ] 외부 서비스 연동 (Tool Use/Function Calling): `ToolExecutor.swift` 신규 구현 (Google Calendar, Gmail, Web Search 등 기능 확장)
- [ ] 에이전트 추가 스프라이트 제작 및 적용: 슬로스(루나), 개(올리버/몽몽 등)에 이어 나머지 캐릭터 적용
- [ ] 화면(플로팅 창) 드래그 이벤트 로컬 처리 고도화 (`drag_start`, `dragging`, `drop` 개선)

**🗣️ 음성 및 통신 인터페이스 개선**
- [x] 기존 음소 합성 TTS 엔진(AnimalTTS) 완전 폐기 및 Apple Native AVAudioEngine DSP 파이프라인으로 전환 완료 (2026-04-07)
- [ ] 백엔드 `cheer` 시스템 이벤트 타입 등 부가 처리
- [ ] 장기 로드맵: Chatterbox CoreML 기반 제로샷 음성 복제
- [ ] 장기 로드맵: 에이전트 팀 영상 통화 기능 구현

**💰 UI 및 비즈니스 로직**
- [ ] `AgentSettingsView`: 이전 구현체에 있던 role/job 필드 복원
- [ ] 팀 채팅 뷰에서 특정 에이전트와 나눈 대화를 기준으로 한 개별 프로젝트 대화(1:1 채팅) 분기 기능
- [ ] StoreKit 2 기반 캐릭터 스킨 / 프리미엄 캐릭터 등 인앱결제 연동

---

## 🏗 리팩토링 로드맵 (Refactoring Phases)

- [ ] **Phase 2: Service Layer Refactoring**
  - AI Provider (Gemini, OpenAI, Claude) 프로토콜 기반 구현체로 추출
  - `AgentWindowManager`의 과부하를 줄이기 위한 `ChatRoomManager` 분리
  - 복잡한 데스크탑 창 제어 로직을 전담할 `WindowManager` 분리

- [ ] **Phase 3: View Layer Refactoring**
  - `AgentChatView` 내부 구성을 분리: `ChatHeaderView`, `ChatLogView`, `ChatInputView`
  - 프로젝트 리스트 사이드바 `ProjectSidebarView` 컴포넌트로 추출
  - 재사용 가능한 `ProjectListItem` 컴포넌트 생성

- [ ] **Phase 4: Model Organization**
  - 별도의 `Models/` 구성 폴더 생성하여 관리 집중
  - 파편화된 에러 타입을 통합하여 `Error.swift` 생성
  - 데이터 흐름 패턴(예능 방향 모델 변경 등) 표준화 작업

---

## ✅ 완료된 작업 (Done)

- [x] 크래시 해결: `AgentChatView` 창 최소화-복원 시 애니메이션 충돌 해결 (2026-03-28)
- [x] Phase 1 리팩토링: `AgentWindowManager` 분할(config, 모델, 뷰 분리) (2026-03-28)
- [x] 개별 대화창 UI 구조 개편 및 크기 충돌(SwiftUI vs AppKit) 해결 (2026-03-29)
- [x] 치코 스프라이트 23종 완벽 적용 및 오류 상태 체인(Fallback Chain) 구축 (2026-03-29)
- [x] 캐릭터 프로필 이미지 시스템(11인) Fallback 구축 완료 (2026-03-29)
