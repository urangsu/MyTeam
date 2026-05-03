# MyTeam 개발 로그

> 위치: `/Users/su/Desktop/MyTeam/DEVLOG.md`
> 목적: 현재 앱 방향, 최근 결정, 완료 이력만 남기는 단일 개발 로그.
> 세부 TODO와 남은 로드맵은 `TASK.md`에 기록한다.

---

## 프로젝트 기준

MyTeam은 macOS 데스크톱에 4명의 캐릭터 AI 에이전트가 상주하는 SwiftUI/AppKit 앱이다.
목표는 Mac App Store 배포 가능한 퍼스트파티급 네이티브 앱이다.

### 현재 기술 스택

| 영역 | 현재 기준 |
| --- | --- |
| 앱 | Swift 6, SwiftUI, AppKit `NSPanel`, SpriteKit |
| 상태 관리 | `AgentWindowManager` + `ChatRoom` / `ChatLog` |
| LLM | `AIService` 직접 호출: Gemini, OpenAI, Claude, OpenRouter |
| API 키 | `KeychainManager` |
| TTS | `Qwen3TTSService` + `ModelCatalog` + Qwen3-TTS MLX |
| 음성 재생 | `SpeechManager` + `AudioPlaybackService` |
| 팀 대화 | `TeamOrchestrator` + `IntentRouter` + `ToolPolicy` |
| 웹/금융 자료 | `ToolEvidenceService`, 출처 칩 `SourceReference` |

### 현재 고정 결정

- 런타임 TTS는 `Qwen3TTSService` 기준이다.
- Apple TTS/AVSpeechSynthesizer는 폴백으로도 사용하지 않는다.
- Python TTS 서버, ONNX Chatterbox, MLXInferenceService 기반 실험은 아카이브다.
- 캐릭터 음성은 pitch/rate 보정이 아니라 레퍼런스 음성 자산 품질로 관리한다.
- LLM 모델명은 가능한 동적 발견/설정 기반으로 둔다. `gemini-1.5`, `gpt-4o` 같은 특정 모델 하드코딩은 지양한다.
- Mac App Store 배포를 막는 절대경로, 외부 프로세스, 평문 API 키 저장은 블로커로 본다.

---

## 핵심 파일

| 파일 | 역할 |
| --- | --- |
| `MyTeam/AgentWindowManager.swift` | 앱 전역 상태, 방/메시지/창/스케줄 업무 관리 |
| `MyTeam/AgentConfig.swift` | 캐릭터 설정, LLM provider, 데스크 라우팅 |
| `MyTeam/ChatModels.swift` | `ChatRoom`, `ChatLog`, `SourceReference`, `AutomationTask` |
| `MyTeam/AgentChatView.swift` | 개인 채팅창 |
| `MyTeam/TeamStatusView.swift` | 팀 채팅/스케줄 업무 UI |
| `MyTeam/TeamTableView.swift` | 메인 플로팅 팀 창 |
| `MyTeam/TeamOrchestrator.swift` | 팀 대화 진행, 리더/멘션 우선순위 |
| `MyTeam/IntentRouter.swift` | 업무/잡담/도구 필요 판단 |
| `MyTeam/AIService.swift` | LLM 호출, 모델 발견, API 키 검증 |
| `MyTeam/AgentToolKit.swift` | 도구 정책, 웹/금융/URL 자료 수집 |
| `MyTeam/ConversationMemory.swift` | 첨부 컨텍스트, `/clear`, `/compact`, `/schedule` 등 명령어 |
| `MyTeam/Qwen3TTSService.swift` | Qwen3 TTS 런타임, 캐릭터 레퍼런스 voice clone |
| `MyTeam/ModelCatalog.swift` | TTS 모델 ID 기본값 |
| `MyTeam/SpeechManager.swift` | STT, TTS 스트림 연결, barge-in |
| `MyTeam/FloatingPanel.swift` | 위치/크기 저장 복원, 패널 드래그 |
| `MyTeam/SettingsView.swift` | API 키, provider, 데스크 라우팅, 사용자/팀 설정 |

---

## 작업 규칙

- 메시지 추가는 `AgentWindowManager.addChatLog()`를 사용한다.
- 팀 대화는 `TeamOrchestrator.runTeamDiscussion()`로 보낸다.
- 개인 대화는 개인창 응답 정책과 `ToolPolicy`를 거친다.
- 최신 정보/금융/URL 질문은 도구 자료와 출처 칩을 붙인다.
- 금융/투자 답변은 “최종 선택과 책임은 사용자 본인에게 있고 AI/외부 데이터는 틀릴 수 있다”는 고지를 유지한다.
- 스케줄 업무는 앱이 켜져 있을 때만 실행한다. 파일 삭제/결제/외부 글쓰기 같은 destructive action은 금지한다.

---

## 최근 완료 이력

### 2026-05-01

#### P0 품질 기준 정리

- `xcodebuild -quiet -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Debug -destination 'platform=macOS' build` 성공.
- `xcodebuild -quiet -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Release -destination 'platform=macOS' build` 성공.
- MyTeam 타겟 Swift 경고는 quiet Debug/Release 기준 0건. 남은 출력은 Xcode destination 선택 안내뿐이며, 일반 Release 빌드에서 보였던 `mlx-swift` Metal C++17 경고는 외부 패키지 경고로 분리.
- `ToolPolicyDecision`, `ToolEvidenceResult`에 `Sendable`을 붙이고 automation timer의 불필요한 `Task { @MainActor ... }` 캡처를 줄임.
- `IntentRouter.classify()`의 `toolPolicy` 기본값을 메시지 기반 평가로 바꿔 도구 판단이 빈 문자열에 묶이지 않게 수정.
- P0 상주 문제를 `TASK.md`에 별도 섹션으로 고정. TTS/캐시/로그/창/대화 fallback을 한 번에 보이도록 정리.
- 앱 로그는 `AppLog` 래퍼를 기준으로 점진 전환. legacy TTS/WebSocket/OnDevice 로그는 기본 비활성화할 수 있는 구조로 이동.
- 팀 대화 selector 실패 시 랜덤 fallback을 deterministic fallback으로 교체하고, TTS 첫 발화 대기 때문에 텍스트 진행이 막히는 구조를 제거.
- `FloatingPanel`의 window restoration을 명시적으로 끄고 패널별 크기 저장 정책을 함수로 분리.
- Qwen3 모델 캐시가 앱 컨테이너에 없으면 자동 다운로드로 조용히 빠지지 않고 명확한 오류를 내도록 preflight를 추가.

#### TTS 측정과 보류 결정

- 앱 런타임 전용 `MYTEAM_TTS_PROBE=1` 측정 경로를 추가. 결과는 앱 컨테이너 `Application Support/MyTeam/TTSBench/`에 JSON/WAV로 저장.
- voice clone 기본값은 OFF로 고정. `UserDefaults("MyTeam.TTS.useQwenVoiceClone") == true`일 때만 개발 검증 모드로 사용.
- 앱스토어 샌드박스 기준에서는 기존 비샌드박스 HuggingFace 캐시를 자동 공유하지 못해 앱 컨테이너 캐시/초기 다운로드/ODR 정책이 별도 P0임을 확인.
- 2026-05-01 부분 측정: 루나 base는 모델 준비 3.84s, 합성 6.67s, 오디오 5.56s, RTF 1.20. 11캐릭터 base 부분 측정도 RTF 1.04~1.32 범위로 즉각 반응 목표와 거리가 있음.
- 결론: TTS는 “감상”이 아니라 측정 기반으로 관리하되, 현 Qwen3 경로는 출시 품질 블로커다. 당장은 다른 P0 앱 품질 작업을 우선하고 TTS는 별도 게이트로 재평가한다.

#### TTS 후처리와 스케줄 UX 정리

- `동물의숲 효과`를 고객용 음성 토글과 분리된 TTS 후처리 기능으로 복원.
- 캐릭터별 pitch/rate 값을 `VoiceStyleCatalog`로 분리하고 안전 범위로 clamp.
- 스케줄 패널에서 담당 캐릭터 지정 추가. 현재 팀에 없는 캐릭터는 메뉴/칩에 `없음`으로 표시.
- 담당 캐릭터가 팀에 없으면 대체 화자가 짧은 대신 수행 메시지를 남긴 뒤 실행.
- OpenAI/OpenRouter 모델 ID는 고급 설정으로 유지하고, 비워두면 자동 선택 경로를 사용.

### 2026-05-02

#### 레거시 코드 완전 제거 (P4)

- 활성 코드에서 참조 없음을 확인 후 17개 dead code 파일 삭제:
  - Chatterbox/ONNX 파이프라인 클러스터: `MLXInferenceService`, `MLXModelManager`, `T3MLXModel`, `T3Model`, `LlamaModel`, `T3CondEnc`, `HiFTGenerator`, `VoiceEncoder`, `BPETokenizer`, `KanaDecomposer`, `ChatterboxPipeline`, `ChatterboxConfig`
  - 외부 Python WebSocket 클러스터: `WebSocketClient`, `WebSocketStreamManager`, `LiveAudioManager`
  - On-device TTS 관리자: `OnDeviceTTSManager`, `TTSServiceManager`
- project.pbxproj에서 총 68줄 제거 (파일 참조 4위치 × 17파일).
- `/Users/su/` 하드코딩된 절대경로(`MLXModelManager`, `BPETokenizer`)가 이 삭제로 해소됨 → P0 샌드박스 블로커 해제.
- Debug/Release clean build 성공. 외부 패키지(mlx-swift C++17) 경고 외 앱 코드 경고 0건.

#### [BUG FIX] 캐릭터 음성 일관성 (P0 TTS)

- **원인**: `SamplingConfig`에 seed 파라미터 없음. 내부 `MLXRandom.gumbel()` 매 호출마다 새 랜덤 시퀀스 생성 → 같은 캐릭터도 청크마다 다른 음성 토큰 경로.
- **해결**: `Qwen3TTSService`에 `import MLX` 추가, `characterSeed(for:)` (FNV-1a 해시) 함수 추가, 합성 직전 `MLXRandom.seed(characterSeed(for: characterName))` 고정.
- 결과: 동일 캐릭터 → 동일 seed → 동일 gumbel noise → 일관된 토큰 경로 → 일관된 음성.

#### Reference Audio 자산 정리 (P4)

- `voices-audit.md` 작성: 11개 파일 모두 존재(216~340KB, 추정 13~21s), clipping 적용 중. 실청 검수 미완.
- `POLICY.md` 작성: 4~7초, 24kHz mono, -20 LUFS ±2, 앞뒤 무음 <0.2s, fade out 0.1s 기준 문서화.

#### [BUG FIX] 앱 종료 크래시 + 캐릭터 음성 일관성 2차 수정 (2026-05-02 추가)

**종료 크래시 (EXC_BAD_ACCESS in __hash__)**
- 증상: 앱 종료 시 Task 154 `com.apple.root.user-initiated-qos.cooperative` 에서 `__hash__()` 크래시
- 원인: MLX Metal 셰이더 캐시(C++ `unordered_map`)를 백그라운드 스레드가 접근 중에 Swift 래퍼 객체 해제
- 해결: `applicationWillTerminate`에 `Task.detached(@Qwen3TTSActor) { cancelCurrentInference() }` + `Thread.sleep(1.0)` drain 대기 추가

**음성 일관성 2차 수정 — 세션 앵커**
- 1차 seed 고정은 "동일 텍스트 재현성"만 보장. 다른 텍스트는 여전히 다른 speaker zone → 다른 목소리
- 해결: `sessionVoiceAnchors: [String: [Float]]` — 캐릭터 첫 합성 출력을 앵커 저장, 이후 발화는 `synthesizeWithVoiceClone(anchor)` 호출 (temperature 0.30, topK 20으로 낮춰 안정성 확보)
- 경로: 파일 voice clone(ON) > 세션 앵커 clone > 첫 base 합성+앵커 저장
- `clearSessionAnchors()` / `clearSessionAnchor(for:)` 세션 리셋 API 추가

#### Debug/Release clean build 검증 (P0)

- Debug + Release 모두 `BUILD SUCCEEDED` 재확인.

---

### 2026-05-03

#### [BUG FIX] 앱 종료 크래시 #2 — ObjC EXC_BAD_ACCESS in objc_msgSend

**증상**: 앱 종료 시 Task 272 `com.apple.root.user-initiated-qos.cooperative` 에서 `(*pProc)(pObj, selector, args...)` — `objc_msgSend` 에서 EXC_BAD_ACCESS(code=1)

**원인**: `applicationWillTerminate`가 `Thread.sleep(1.0)`으로 대기하는 동안 AVAudioEngine의 CoreAudio 렌더 스레드(실시간 OS 스레드)가 계속 동작. 이 상태에서 Swift가 AVAudioNode(ObjC 객체)를 해제하면 렌더 콜백이 이미 해제된 포인터에 ObjC 메시지를 보내 크래시 발생. voice clone 합성은 최대 11초인데 sleep(1.0)은 부족.

**해결**:
- `AudioPlaybackService.stopEngineForTermination()` 추가: `playerNode.stop()` → `engine.stop()` 명시 호출 → 노드 분리. CoreAudio 렌더 스레드를 즉시 정지시켜 in-flight 콜백 차단.
- `applicationWillTerminate`를 `DispatchSemaphore` 방식으로 전면 교체:
  1. `stopEngineForTermination()` 비동기 호출 + 50ms 드레인
  2. `Task.detached(@Qwen3TTSActor)` → `cancelCurrentInference()` 호출 후 `sem.signal()`
  3. `sem.wait(timeout: .now() + 5.0)` — 최대 5초 대기 (actor 확인 보장)
  4. Metal command queue drain용 `Thread.sleep(0.5)`

#### [QUALITY] TTS 앵커 패딩 — 짧은 앵커 반복 오디오 방지

**증상**: 세션 앵커가 1.88초(≈22 codec tokens)처럼 짧으면 voice clone 합성이 75-token safety limit에 걸려 6초짜리 반복 오디오 생성 → quality gate 실패 → base fallback → 루프

**해결** (`Qwen3TTSService.swift`):
- `paddedClippedReferenceAudio(_:)` 추가: 앵커가 3초(72,000 samples) 미만이면 루프 패딩으로 3초 채운 뒤 7초(168,000 samples) 상한 적용
- `isQualityGateFailed()` 에 `isVoiceClone: Bool = false` 파라미터 추가: voice clone 경로는 per-char 상한 배율을 0.8x → 1.5x로 완화 (prosody 확장 고려)
- voice clone 경로(3-b)에서 `clippedReferenceAudio(anchor)` → `paddedClippedReferenceAudio(anchor)`로 교체

#### P1: 팀장 배지 + 컨텍스트 메뉴

- `AgentMenuPopupView`: `isTeamLeader: Bool`, `onSetLeader: (() -> Void)?` 파라미터 추가
- `TeamTableView`: 에이전트 셀에서 `AgentWindowManager.shared.teamLeader()?.id == agent.id` 조건으로 팀장 여부 전달, "팀장 설정/해제" 메뉴 항목 (`crown.fill`/`crown` SF Symbol) 연결
- 팀장 지정: `AgentWindowManager.shared.setTeamLeader(agentID:)` 호출

#### P1: 장기 기억 Scope V2 분리 (global / room / character)

- **저장 구조 변경**: `@AppStorage("MyTeam.keyFacts")` 전역 배열 → `MyTeam.keyFactsV2` 키 딕셔너리 `[String: [String]]`
  - `"global"` — 수석님(사용자) 관련 기기 공유 사실
  - `"room_{UUID}"` — 방별 컨텍스트
  - `"char_{name}"` — 캐릭터별 기억
- `/remember` 문법 확장: `/remember @루나 텍스트` → character scope, `/remember :global 텍스트` → global scope, 기본 → room scope
- `/memory` — 현재 방 + 현재 캐릭터 + global 3개 scope 전체 표시
- `/forget` — scoped + legacy V1 양쪽 검색/삭제
- `buildMemoryContext()` → `scopedMemoryContext(agentName:roomID:)` — 3 scope 병합 → 시스템 프롬프트 주입

#### P1: /compact LLM 요약

- `AIService.quickSummary(prompt:)` 추가: Gemini → Claude → OpenAI 순서로 single-turn 요약 호출. API 키 없으면 정적 요약으로 폴백.
- `/compact` 핸들러 업데이트: `quickSummary()` 호출 후 `"[LLM 요약됨] ..."` 단일 메시지로 교체. 응답 없으면 기존 static 요약 사용.

#### P2: /edit-task, /approve, /skip 명령어

- `AgentWindowManager.editAutomationTask(idPrefix:option:)`:
  - `HH:MM` 형식 → 다음 실행 시간 변경
  - `--disable` / `--enable` → 활성화 토글
  - `--approval on/off` → 승인 요청 토글
- `ChatModels.AutomationTask`에 `requiresApproval: Bool = false` 필드 추가
- `runDueAutomationTasks()`: `requiresApproval == true`이면 채팅창에 승인 요청 메시지 표시, 2분 타임아웃 후 자동 실행. `pendingApprovalTaskIDs: Set<UUID>` 관리.
- `ConversationMemory`: `/edit-task`, `/approve`, `/skip` 핸들러 추가. `/tasks` 표시에 상태 이모지(✅/⏸), 승인 플래그, 짧은 ID prefix 추가.

#### P2: 금융 API — NAVER 금융 추가

- `AgentToolKit.fetchNaverFinanceQuote(symbol:)` 추가: `https://m.stock.naver.com/api/stock/{code}/basic` (한국 주식 6자리 코드 또는 .KS/.KQ)
- `fetchYahooFinanceQuote(symbol:)`: Yahoo Finance v8 `/v8/finance/chart/` + User-Agent 헤더로 안정성 강화
- 라우팅 로직: 6자리 숫자 코드나 `.KS`/`.KQ` suffix → NAVER 우선, 실패 시 Yahoo fallback. 해외 주식은 Yahoo 직접.

#### P3: LLMConfigCatalog — 신규 파일

- `LLMConfigCatalog.swift` 신규 생성:
  - `LLMCapability` enum: `.webSearch`, `.toolUse`, `.longContext`, `.vision`
  - `LLMProviderConfig: Codable`: selectedModelId, supportsToolUse, supportsWebSearch, discoveredModels, lastDiscoveryDate
  - `@MainActor LLMConfigCatalog`: UserDefaults 캐시, TTL 1시간 discovery 갱신, `bestProvider(for:)`, `routeOrDefault(_:fallback:)`
  - `extension AIService`: `discoverModel(for:apiKey:)` 브릿지, discovery 함수 internal 노출

#### P3: Tool-capable 라우팅

- `AgentChatView`: ToolPolicy 평가 후 `.needsFinance || .needsWeb` → `.webSearch` capability, 나머지 → `.toolUse`. `LLMConfigCatalog.routeOrDefault()` 로 최적 provider 결정 후 `agentConfig.withProvider(best)` 임시 오버라이드.
- `AgentConfig.withProvider(_:)` 추가: 원본 불변, 오버라이드 복사본 반환.
- `AgentWindowManager.handleWake()`: `LLMConfigCatalog.shared.refreshAllIfNeeded()` 호출로 포그라운드 복귀 시 TTL 체크.

#### Debug/Release clean build 검증

- Debug + Release 모두 `BUILD SUCCEEDED`. 앱 코드 Swift 경고 0건.
- TASK.md 크래시/P1/P2/P3 체크박스 9개 ✅ 업데이트.

#### P1: 없는 캐릭터 대체 발화 톤 + 개인창 전문성 연결

- `TeamOrchestrator.unavailableNoticeText(speaker:unavailableName:)` 추가: 11캐릭터 각각 성격에 맞는 부재 안내 문구로 교체 (레오 — 절제된 분석, 루나 — 밝고 에너지, 렉스 — 느긋하고 꼼꼼, 몽몽 — 친절 공감 등).
- `ConversationMemory.buildPersonalResponsePolicy()` 강화: `agentPersonas` 에서 `specialty`/`role` 읽어 개인창 시스템 프롬프트에 "핵심 전문 분야 '\(specialty)'에서 특히 깊이 있는 답변을" 힌트 주입.

#### P2: Gemini Grounding + OpenAI web_search 연동 PoC

- `ToolEvidenceService.fetchWebEvidence()` 3단계 폴백 구조:
  1. `fetchGeminiGrounding()`: `tools: [{"google_search": {}}]` — Google 실시간 검색, `groundingChunks` 출처 추출
  2. `fetchOpenAIWebSearch()`: Responses API `web_search_preview` 도구 — gpt-4o-mini 기반 웹 검색
  3. `fetchDuckDuckGo()`: 기존 DuckDuckGo Instant Answer 폴백
- API 키가 없으면 자동으로 다음 단계로 fall through. 출처 칩에 "Google 검색" / "OpenAI" 표시.

#### P2: /schedule 파서 확장

- `parseSchedule()` 전면 개편:
  - `내일/tomorrow HH:MM 내용` → 내일 해당 시간 1회 실행
  - `매일/daily/every day HH:MM 내용` → 매일 반복 (repeatInterval = 86400s)
  - `매주 {요일} HH:MM 내용` / `every {weekday} HH:MM 내용` → 매주 반복 (604800s)
  - `N시 [M분] 내용` → 한국어 시간 표기 지원
  - `every 30m/2h 내용` 기존 interval 방식 유지
- `/schedule` 도움말 메시지 multi-line으로 개선.

#### P2: URL fetch HTML 본문 추출 품질 개선

- `extractMainContent()` 추가: `<article>` → `<main>` → content class/id div → `<p>` 단락 집합 → 전체 스트립 순서로 본문 추출. 200자 미만이면 다음 전략으로 fall through.
- `extractMetaDescription()` 추가: `og:description`, `name=description` meta 태그 추출, URL 본문 앞에 "요약:" 으로 표시.
- `cleanHTML()` 강화: `<nav>`, `<header>`, `<footer>`, `<aside>`, HTML 주석(`<!-- -->`) 제거 추가. HTML 숫자 엔티티 (`&#NNNN;`) 디코딩 추가.

#### P2: 금융 alias 확대

- `extractFinanceSymbols()` 한국 대형주 15종목 추가: SK하이닉스, 카카오, 네이버, 현대차/기아, 셀트리온, LG에너지솔루션, 삼성바이오로직스, 크래프톤 등.
- 가상자산: 솔라나(SOL-USD), 리플(XRP-USD) 추가.
- 미국: ARM, AVGO(브로드컴), 팔란티어(PLTR), QCOM(퀄컴) 추가.

#### P3: 설정창 모델 목록 UI

- `SettingsView.apiSettingsTab` 고급 모델 설정 섹션 개선:
  - `LLMConfigCatalog.shared.configs[selectedProvider]?.discoveredModels` 목록 표시
  - 모델 탭하면 `openAIModelId` / `openRouterModelId` 자동 입력
  - 선택된 모델 체크마크 표시
  - 갱신(↺) 버튼 → `LLMConfigCatalog.refreshIfNeeded()` 호출
  - 모델 없으면 "자동 선택 (검증 후 갱신)" 안내 텍스트

#### Debug/Release clean build 검증 (2차)

- Debug + Release `BUILD SUCCEEDED`. 경고: 기존 3건 (await 없는 await, NSOrderedSet cast, var→let) 유지, 신규 없음.

---

### 2026-04-30

#### 팀/개인 대화 구조 개선

- 팀방에 `leaderAgentID` 추가.
- 팀 리더 지정 UI 추가.
- 캐릭터 이름을 부르면 해당 캐릭터가 우선 응답.
- 팀에 없는 캐릭터를 부르면 리더/대체 화자가 대신 응답.
- 팀 대화 TTS는 첫 발화만 나오도록 정리.

#### 페르소나/직업 설정 연결

- `AgentSettingsView`의 직업/성격 설정이 `AIService.buildSystemPrompt()`에 반영되도록 수정.
- 커스텀 persona가 기본 캐릭터 persona를 덮어쓰지 않고 보조 설정으로 붙도록 변경.

#### 도구 정책, 출처, 금융 정보

- `ToolPolicy` 추가.
- 최신/뉴스/검색/URL/금융 질문 감지.
- `ToolEvidenceService` 추가.
- Yahoo Finance 기반 주식/코인 시세 컨텍스트 추가.
- DuckDuckGo Instant Answer 기반 웹 자료 수집 추가.
- URL 직접 읽기 `/fetch` 지원.
- 답변 아래 출처 칩 표시 및 클릭 열기 지원.

#### 명령어와 장기 기억

- `/help`, `/clear`, `/compact`, `/remember`, `/memory`, `/forget`, `/silent`, `/voice` 추가.
- `/open`, `/fetch`, `/search`, `/schedule`, `/tasks`, `/cancel` 추가.
- `keyFacts` 장기 기억을 개인창 응답 컨텍스트에 연결.

#### 스케줄 업무

- `AutomationTask` 모델 추가.
- 앱 내부 timer 기반 스케줄 업무 실행.
- 팀 채팅창 하단에 “스케줄 업무” 스트립 추가 후, 시선 방해가 커서 입력창 왼쪽 아이콘 호출형 패널로 변경.
- 스케줄 패널에서 등록 업무 확인/삭제 가능.

#### 설정/API/창 구조

- API 키 검증을 provider별 실제 models list 호출로 교체.
- 기본 LLM provider와 데스크별 provider/model routing 연결.
- 설정창 X 버튼이 `hideSettingsWindow()`를 호출하도록 정리.
- 패널 위치/크기 저장 복원 개선.
- 개인창 열 때 저장된 크기를 덮어쓰지 않도록 수정.
- 상태창 크기 변경 API를 폭/높이 통합으로 정리.

#### TTS

- 런타임 TTS를 `Qwen3TTSService`로 고정.
- 긴 reference audio 기반 voice clone에서 음질 붕괴와 과도한 생성 시간이 확인되어 기본 런타임은 한국어 기본 합성으로 임시 전환.
- voice clone은 `UserDefaults("MyTeam.TTS.useQwenVoiceClone") == true`인 개발 검증 모드에서만 사용.
- voice clone 검증 시 reference audio는 최대 7초로 잘라 사용.
- `!` 같은 의미 없는 punctuation-only 청크가 TTS로 들어가지 않도록 필터링.
- TTS 청크 길이를 90자로 제한해 safety limit 폭주 가능성을 낮춤.
- `SpeechManager.speak()`가 `agentID`로 캐릭터 이름을 역추적해 루나 fallback 남발을 줄이도록 수정.
- 샘플링 temperature/topK를 낮춰 같은 캐릭터가 매번 다른 목소리처럼 흔들리는 현상을 완화.
- 단발성 TTS 경로의 pitch 값을 원본 유지값 `0.0`으로 수정.

#### App Store 샌드박스

- Debug 앱 target의 `ENABLE_APP_SANDBOX`를 Release와 동일하게 `YES`로 변경.
- outgoing network, audio input, user-selected readonly 파일 접근 설정은 유지.

#### 검증

- `xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Debug -destination 'platform=macOS' build`
- 결과: `BUILD SUCCEEDED`
- Debug sandbox enabled 상태에서 build 성공.

#### Push

- `8461f0a feat: add chat commands and scheduled tasks`
- `20ff8b4 feat: improve LLM settings and window behavior`
- `3e669f1 fix: pin character TTS to reference voices`
- `origin/main` push 완료.

---

## 아카이브 요약

과거 ONNX/Chatterbox/MLXInferenceService 기반 TTS 실험은 다음 이유로 현행 개발 기준에서 제외한다.

- ONNX Chatterbox는 속도, 음질, 모델 입출력 복원 비용 문제로 출시 경로가 아니다.
- Python/FastAPI/WebSocket TTS 서버는 Mac App Store 배포 경로가 아니다.
- Apple TTS는 캐릭터성/음질 요구를 만족하지 못해 폴백으로도 쓰지 않는다.
- 기존 레거시 파일은 삭제 전 `TASK.md`의 P2 단계에서 사용처 0 확인 후 정리한다.

상세 과거 로그가 필요하면 git history에서 이전 `DEVLOG.md`를 확인한다.
