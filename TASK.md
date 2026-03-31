# MyTeam Task Tracker

> **위치**: `/Users/su/Desktop/MyTeam/TASK.md`
> **담당**: Antigravity (Claude Sonnet) + Claude Code 공동 관리
> **규칙**: 추가할 기능, 수정할 버그, 리팩토링 계획 등은 모두 이 파일에 관리합니다. 작업이 완료되면 `[x]` 표시를 하고, 그 내역을 루트의 `DEVLOG.md`에 추가해 주세요!

## 🚧 현재 진행 중인 작업 (In Progress)
- [ ] [긴급 버그] AIService.swift 대화 품질 개선 (단답형 제거, 대화기록 절삭 완화, Messages Array 적용)
## 🚧 현재 진행 중인 작업 (In Progress)

### [최우선] Native TTS 파이프라인 구축 — AnimalTTSManager 교체

> ⚠️ AnimalTTSManager.swift는 절대 수정 금지. 신규 파일로 대체하고 호출부만 교체할 것.
> ⚠️ AVAudioEngine 조작은 반드시 DispatchQueue.main.async로 메인스레드 분리 (기존 크래시 패턴 동일)

**목표**: AVSpeechSynthesizer + AVAudioEngine 기반 완전 오프라인 TTS로 전환.
나중에 Chatterbox CoreML 엔진으로 교체 가능한 구조로 설계할 것.

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

### [P1 완료] 감정-스프라이트 연결 ✅
- [x] `AgentWindowManager`: `speakingAgentID`, `agentEmotions`, `detectEmotion()`, `setAgentSpeaking()` 구현
- [x] `TeamTableView`: `isSpeaking: manager.speakingAgentID == agent.id` (하드코딩 해제)
- [x] `AgentChatView`: AI 응답 후 `setAgentSpeaking()` 호출
- [x] `AgentSeatView`: `agentEmotions[config.id]` → SpriteAgentView 전달

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

## 📝 향후 작업 (Backlog & TODO)

**🛠️ 기능 고도화**
- [ ] 에이전트 고도화 (OpenClo Lite): `AgentOrchestrator`를 통한 에이전트 간 위임, `SharedWorkspace` 연동
- [ ] 외부 서비스 연동 (Tool Use/Function Calling): `ToolExecutor.swift` 신규 구현 (Google Calendar, Gmail, Web Search 등 기능 확장)
- [ ] 에이전트 추가 스프라이트 제작 및 적용: 슬로스(루나), 개(올리버/몽몽 등)에 이어 나머지 캐릭터 적용
- [ ] 화면(플로팅 창) 드래그 이벤트 로컬 처리 고도화 (`drag_start`, `dragging`, `drop` 개선)

**🗣️ 음성 및 통신 인터페이스 개선**
- [ ] 기존 음소 합성 TTS 엔진(AnimalTTS) 완전 폐기 및 Apple Native AVSpeechSynthesizer + AVAudioEngine DSP 파이프라인으로 전환 (완전 오프라인 대응, 캐릭터별 Pitch/Rate Profile 유지)
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
- [x] AI 응답 기반 캐릭터 감정-스프라이트 동적 전환 추가 (2026-03-29)
