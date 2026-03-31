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
- **감정-스프라이트 동적 연결**:
  - AI 응답 텍스트에 포함된 감정을 파싱해 즉각 에이전트 뷰의 모션을 `.joy`, `.agree` 등으로 변경
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
