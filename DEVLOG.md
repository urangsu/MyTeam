# MyTeam 개발 로그 (공유 작업 지시서)

> **위치**: `/Users/su/Desktop/MyTeam/DEVLOG.md`
> **규칙**: 작업 전 반드시 이 파일을 읽고, 작업 완료 후 하단 로그에 추가하세요. 
> **중요**: (Claude Code에게 알림) 본 프로젝트에서는 이제부터 루트 디렉토리의 `DEVLOG.md`를 **유일한 개발 로그(Single Source of Truth)**로 사용합니다. `.claude/DEVLOG.md` 등 개별 로그 작성은 중단하시고, 작업 완료 이력은 이곳에, 남은 할 일(TODO)과 로드맵은 루트의 `TASK.md` 파일에 기록하세요.
> **담당**: Antigravity (Claude Sonnet) + Claude Code — 두 개발자 공동 관리

---

## 📐 프로젝트 개요

macOS 투명 플로팅 윈도우에 동물 캐릭터 AI 에이전트 4명이 상주하는 데스크탑 앱.
에이전트들이 팀원처럼 사용자와 채팅·음성으로 소통하고 서로 협업하는 것이 핵심.

### 기술 스택
| 레이어 | 기술 |
|--------|------|
| 클라이언트 | Swift 6 + SwiftUI + AppKit (NSPanel) + SpriteKit |
| AI 통신 | AIService.swift (URLSession 직접 호출, 서버 불필요) |
| 백엔드 (레거시) | Python + FastAPI + WebSocket (점진적 제거 예정) |
| 수익화 | StoreKit 2 (캐릭터 스킨 인앱결제) |

---

## 🗂️ 핵심 파일 구조 및 역할

Phase 1 리팩토링(2026-03-28)으로 비대했던 파일들이 분리되었습니다. 
모든 추출 타입은 `extension AgentWindowManager { struct Name... }` 패턴으로 기존 코드들의 참조 변경 없는 호환성을 유지합니다.

```
MyTeam/MyTeam/MyTeam/
├── AgentWindowManager.swift   ← 전체 상태 관리 (@EnvironmentObject, ChatRoom, rooms, 이벤트)
├── AgentConfig.swift          ← 요원 설정(프로퍼티: id, name, role, emoji, color, 상태, sprite/fallback 이미지)
├── ChatModels.swift           ← ChatRoom, ChatLog 모델 (Codable)
├── ChatComponents.swift       ← JiggleEffect, IMMessageBubble, DateSeparator, ChatBubble
├── AgentSeatView.swift        ← 개별 요원 카드(말풍선, 스프라이트, 상태 컴포넌트)
├── AgentMenuPopupView.swift   ← 팝업 메뉴 버튼 분리 (Chat/Voice/Settings/Swap)
├── AIService.swift            ← 로컬 AI 통신 (Gemini/Claude/OpenAI 직접 호출)
├── AgentPersona.swift         ← 8명 요원 페르소나 정의 및 에러 처리 (AIService에서 분리됨)
├── WebSocketClient.swift      ← 레거시 백엔드 통신 (점진적 제거 예정)
├── AgentChatView.swift        ← 개별 채팅창 (iMessage 스타일, isPersonalChat)
├── TeamStatusView.swift       ← 팀 채팅창 (iMessage 사이드바 + 방 삭제 모드)
├── TeamTableView.swift        ← 메인 플로팅 팀 창 (에이전트 4명 + 팀명 배지)
├── FloatingPanel.swift        ← NSPanel 래퍼 (드래그 이동, 이벤트 알림)
├── SpriteAgentView.swift      ← SwiftUI-SpriteKit 브릿지 (건드리지 말 것)
├── CharacterSpriteScene.swift ← SpriteKit 씬, AnimationState enum (건드리지 말 것)
├── CharacterDialogues.swift   ← 캐릭터별 15가지 감정 상태 대사 (구글 시트 연동)
├── SpeechManager.swift        ← STT 녹음 관리, recognizedText, sttError
├── SettingsView.swift         ← 전역 설정창 (API키, userTitle, 팀명 명패색 커스텀 등)
├── Color+Hex.swift            ← SwiftUI Color ↔ HEX 문자열 변환, 배경색 명도 보정
├── AgentSettingsView.swift    ← 에이전트별 커스텀 성격 설정 및 직업 프리셋
├── AgentSwapView.swift        ← 에이전트 교체 UI
└── AnimalTTSManager.swift     ← (폐기 예정/교체 대상) 동물의 숲 TTS 엔진 (절대 수정 금지)
```

---

## 🏗️ 핵심 아키텍처 원칙 (작업 전 반드시 숙지)

### 1. 데이터 흐름
- `AgentWindowManager.shared` 가 단일 진실 공급원 (Single Source of Truth)
- `rooms: [ChatRoom]` → `currentRoomID` → `teamChatLogs` (computed) 순으로 데이터 흐름
- 메시지 추가는 반드시 `manager.addChatLog()` 사용 — `teamChatLogs.append()` 직접 호출 금지

### 2. 채팅방(ChatRoom) 모델
- 영속화: `UserDefaults("myteam_rooms")` — `saveRooms()` / `loadRooms()` 자동 호출
- 방 관리: `createRoom()`, `renameRoom()`, `deleteRoom()`, `showProjectChat()`

### 3. 스프라이트 및 프로필 (SpriteName & Fallback Image)
- `AgentConfig.fallbackImageName`: 스프라이트가 없는 경우 노출될 기본 원형 프로필 이미지 (필수)
- `AgentConfig.spriteName: String?`: PNG 시퀀스 캐릭터 애니메이션 (nil이면 `fallbackImageName` 표시됨)
- `AnimationState`: 체인에 의한 fallback 지원 (.idle, .typing, .greeting 등) 기본 복귀 상태는 `.typing`

### 4. 시스템 이벤트 및 감정 연동 시스템
- `WebSocketClient.shared.sendSystemEvent` 및 로컬 이벤트의 통합
- AI가 응답한 텍스트에서 감정을 추출해 `manager.detectEmotion()` → `speakingAgentID`와 `agentEmotions`에 즉시 반영 → **표정 자동 전환**

### 5. 애니메이션 및 UI 혼합 제어 규칙 (Technical Notes)
- **Animation Context Isolation**: AppKit 크기(NSPanel Frame) 조절 시 SwiftUI `withAnimation(.spring...)` 트랜잭션이 충돌하면 `EXC_BREAKPOINT` 크래시가 납니다. AppKit 업데이트는 반드시 `DispatchQueue.main.async`로 분리하세요.
- SwiftUI `idealWidth`보다는 전체 컨테이너 `.frame(maxWidth: .infinity)` 방식을 선호하여 AppKit이 창 크기를 지배하게 해야 충돌이 방지됩니다.

---

## 🎨 UI 설계 원칙

### 채팅창 스타일
- **iMessage 스타일**: 사용자 메시지 우측(파란 버블), 에이전트 메시지 좌측(회색 버블)
- 에이전트 프로필 이미지 둥근 배경, 타임스탬프, 날짜 구분선 (`ChatComponents.swift` 활용)

### 창 크기 정책
- 메인 팀 창: 460 × 280
- 채팅창: 가로 700px, 세로 620px (고정이 아닌 조절 가능 영역, `minSize` 준수)
- 설정창: 440 × 700
- 팀 협업현황창: 620 × 480

---

## 🔴 절대 금지 사항

1. `teamChatLogs.append()` 직접 호출 — `addChatLog()` 사용
2. `AnimalTTSManager`, `SpriteAgentView`, `CharacterSpriteScene`, `KeychainManager` 수정 (단, 향후 Native TTS 마이그레이션이 있을 때 제외)
3. Swift onChange 단일 파라미터 클로저 사용 — `{ _, newValue in }` 두 파라미터 형식 사용

---

## 📋 작업 이력

### 2026-04-01: [Antigravity] Phase 2/3 - 의도 기반 협업 및 지능형 기억 시스템 (진행 중)
- **[아키텍처] 시스템-팀장 (App-as-Leader) 모델 도입**
  - 에이전트들이 스스로 조율하는 대신, 앱(SwiftUI)이 중앙 지휘자가 되어 작업을 분배하는 'Orchestrator-Worker' 패턴 확립.
  - 이를 통해 캐릭터의 페르소나 오염을 방지하고 토큰 비용 및 대기 시간(Latency)을 획기적으로 단축.
- **[핵심기능] 의도 기반 투트랙 라우터 (IntentRouter.swift)**
  - 사용자 입력을 '수다(Chitchat)'와 '업무(Task)'로 분류하고 적임자(Task Leader)를 추천하는 로직 구현.
  - JSON 파싱 실패 시 수다 모드로 자동 폴백(Fallback)되는 안정적 구조 구축.
- **[핵심기능] 지능형 기억 보호 (Key Fact Buffer)**
  - `AgentWindowManager`에 `keyFacts` 영구 저장소 신설.
  - 대화 종료 후 핵심 정보(사용자 이름, 프로젝트명 등)를 자동 추출하여 모든 프롬프트 상단에 박제함으로써 슬라이딩 윈도우로 인한 기억 상실 방지.
- **[버그 수정] 대규모 구문 오류(125개) 및 타입 추론 해결**
  - `AgentWindowManager`의 `init()` 메서드 중괄호 누락 및 `AIService` 메서드 오버로드 누락으로 발생한 빌드 에러 완벽 복구.
- **[프롬프트] 강력한 결과 도출 규칙 (No Weak Results)**
  - 업무 모드 한정으로 "절대 모호한 결과를 내지 말 것"이라는 가이드라인 추가하여 답변의 전문성 강화.

### 2026-04-01: [Antigravity] 마스터 프롬프트 고도화 및 대규모 채팅 UX 개편 (완료)
- **[핵심기능] 유기적 팀 채팅방(멀티 에이전트 오케스트레이션) 구현**
  - 팀 대화방에 남긴 사용자 메시지를 기반으로, 2~3명의 에이전트가 무작위로 추첨되어 순차적으로 각자의 맥락을 인지하고 릴레이로 답변하는 구조 도입
- **[UX 개선] TTS 사운드 이모티콘 낭독 차단 (`SpeechManager.swift`)**
  - `sanitizeForSpeech` 정규식 필터링을 추가하여 TTS 엔진이 출력 텍스트 중 이모지만 무시하고 읽는 로직 반영
- **[핵심기능] 캐릭터 몰입/탈옥 방어 정규화 (`AIService.swift`)**
  - `<Core_Identity>` 및 `<Auxiliary_Task>` 템플릿 기반으로 모든 에이전트의 프롬프트 정규화
  - "보조 업무" 시스템을 도입하여 본캐의 성격을 잃지 않고 두 번째 직무를 수행하도록 지시
  - 출력 필터링용 정규식(Regex)을 도입하여, 답변 앞단에 붙어나오는 이름 태그(`[루나]`, `치코:` 등)를 UI 출력 전에 강제 절삭
- **[UX 개선] 채팅 삭제 및 스크롤 경험 최적화 (`AgentChatView.swift`, `ChatComponents.swift`)**
  - 뷰 재사용 시 Jiggle 효과가 무시되는 버그(`onAppear` 수명주기 누락) 수정
  - Jiggle 효과 속도를 기존 대비 1/2로 낮춰 어지러움 완화
  - 대화 삭제 X 버튼을 마우스 이동이 용이하도록 리스트 맨 우측으로 통일(Agent/User 상관없이)
  - 대화를 지울 때마다 무조건 하단 스크롤이 트리거되던 버그를 `onChange` 카운트 비교 시 증가할 때만 트리거되도록 수정 완료
- **[UX 개선] 화면 정돈 기능 도입 (`AgentWindowManager.swift`)**
  - 설정 화면에서 "대화창 한 번에 정돈하기" 버튼 클릭 시, 에이전트 화면은 Dock 위 중앙으로, 상태창과 채팅창은 우측 맨 끝 모서리를 따라 가지런히 Cascading 되도록 위치 자동 재배치 로직 구현
- **[UI 텍스트 개선]**
  - 직업 프리셋을 "보조 업무"로 명칭 통일하여 사용자가 캐릭터 롤플레잉 방식("본캐+부캐")을 정확히 인지하도록 유도 (`AgentSettingsView.swift`)

### 2026-03-31: 에이전트 정체성 혼선 및 메타인지 제어 시스템 보완
- 초기 창 모델 및 SwiftUI 뷰(단일/팀 채팅) 구현 및 WebSocket 연동에서 완전히 `AIService.swift` 기반의 로컬 연결 아키텍처로 변환 (서버 불필요). 백엔드 Python 서버 의존성 점진적 제거. AnimalTTS 첫 적용.

### [2026-03-25 ~ 2026-03-27] 초기 구축 및 로컬 환경 전환
- 초기 창 모델 및 SwiftUI 뷰(단일/팀 채팅) 구현 및 WebSocket 연동에서 완전히 `AIService.swift` 기반의 로컬 연결 아키텍처로 변환 (서버 불필요). 백엔드 Python 서버 의존성 점진적 제거. AnimalTTS 첫 적용.

### [2026-03-28] Claude Code & Antigravity 합동 리팩토링 및 기능 고도화
- **Phase 1 리팩토링 (파일 분할)**: 
  - 비대한 파일에서 `AgentConfig`, `ChatModels`, `ChatComponents`, `AgentMenuPopupView`, `AgentSeatView`, `AgentPersona` 분할 추출. (`PBXFileSystemSynchronizedRootGroup` 사용 환경이라 파일 직접 복사로 프로젝트 병합)
- **버그 수정**:
  - `AgentChatView` 창 최소화 후 복원 시 발생하는 크래시(`EXC_BREAKPOINT`)를 `DispatchQueue.main.async`와 AppKit/SwiftUI 렌더링 분리로 완벽 해결.
- **사양 추가**: 
  - WebSocket 완전 제거 (TeamTableView 등에서 로컬 addChatLog로 대체)
  - 14개 직업 프리셋과 캐릭터 감정 대사 시스템(`CharacterDialogues.swift`) + Apple 고유 목소리 폴백(에이전트별 피치 조절) 적용

### [2026-03-29] Claude & Antigravity — 스프라이트 최적화, 이미지 폴백 적용, 채팅창 UI 개편
- **채팅창 크기 및 버그 해결**: 
  - 개별 대화창(`AgentChatView`) 가로 길이를 700px로 조정하고, SwiftUI/AppKit 크기 계산 충돌을 방지하여 처음 캘 때 이상한 크기로 나오는 버그 수정.
- **치코 스프라이트 완전 연동**: 
  - 23개 모션 파일 연결. 스프라이트 화면 위 잘림 버그 수정(100x140 씬 확대), 폴백 체인(대체 상태 자동 맵핑) 도입, 1회 애니메이션 후 기본 상태를 `.idle`에서 `.typing`(업무 중)으로 변경.
- **프로필 이미지 시스템**:
  - 스프라이트가 렌더링되지 않는 레오, 루나 등의 캐릭터에게 이모지 대신 고퀄리티 `.png` 원형 이미지가 표시되도록 `fallbackImageName` 통일 및 `Assets.xcassets` 구성

---

## 📝 다음 작업 시 이 파일에 아래 형식으로 추가

```markdown
### [YYYY-MM-DD] [Antigravity / Claude Code]
- 작업한 내용 요약
- 수정 파일 목록
```
