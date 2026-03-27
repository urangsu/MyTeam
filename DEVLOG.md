# MyTeam 개발 로그 (공유 작업 지시서)

> **위치**: `/Users/su/Desktop/MyTeam/DEVLOG.md`
> **규칙**: 작업 전 반드시 이 파일을 읽고, 작업 완료 후 하단 로그에 추가하세요.
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

```
MyTeam/MyTeam/MyTeam/
├── AgentWindowManager.swift   ← 전체 상태 관리 (@EnvironmentObject, ChatRoom, rooms, 이벤트)
├── AIService.swift            ← 로컬 AI 통신 (Gemini/Claude/OpenAI 직접 호출, 서버 불필요)
├── WebSocketClient.swift      ← 레거시 백엔드 통신 (점진적 제거 예정)
├── AgentChatView.swift        ← 개별 채팅창 (iMessage 스타일, isPersonalChat)
├── TeamStatusView.swift       ← 팀 채팅창 (iMessage 사이드바 + 방 삭제 모드)
├── TeamTableView.swift        ← 메인 플로팅 팀 창 (에이전트 4명 + 팀명 배지)
├── FloatingPanel.swift        ← NSPanel 래퍼 (드래그 이동, 이벤트 알림)
├── SpriteAgentView.swift      ← SwiftUI-SpriteKit 브릿지 (건드리지 말 것)
├── CharacterSpriteScene.swift ← SpriteKit 씬, AnimationState enum (건드리지 말 것)
├── SpeechManager.swift        ← STT 녹음 관리, recognizedText, sttError
├── SettingsView.swift         ← 전역 설정창 (API키, userTitle, teamName, 응원받기)
├── AgentSettingsView.swift    ← 에이전트별 커스텀 성격 설정
├── AgentSwapView.swift        ← 에이전트 교체 UI
└── AnimalTTSManager.swift     ← 동물의 숲 TTS 엔진 (절대 수정 금지)
    HangulDecomposer.swift     ← 한글 음소 분해 (절대 수정 금지)
    KeychainManager.swift      ← API키 보안 저장 (절대 수정 금지)
    LiveAudioManager.swift     ← 실시간 오디오 (절대 수정 금지)
    Resources/Phonemes/*.wav   ← 71개 음소 WAV (절대 수정 금지)
    tools/                     ← 쉘 스크립트 (절대 수정 금지)
```

---

## 🏗️ 핵심 아키텍처 원칙 (작업 전 반드시 숙지)

### 1. 데이터 흐름
- `AgentWindowManager.shared` 가 단일 진실 공급원 (Single Source of Truth)
- `rooms: [ChatRoom]` → `currentRoomID` → `teamChatLogs` (computed) 순으로 데이터 흐름
- 메시지 추가는 반드시 `manager.addChatLog()` 사용 — `teamChatLogs.append()` 직접 호출 금지

### 2. 채팅방(ChatRoom) 모델
```swift
struct ChatRoom: Identifiable, Codable {
    let id: UUID
    var name: String
    var messages: [ChatLog]
    var agentIDs: [String]
    let createdAt: Date
}
```
- 영속화: `UserDefaults("myteam_rooms")` — `saveRooms()` / `loadRooms()` 자동 호출
- 방 관리: `createRoom()`, `renameRoom()`, `deleteRoom()`, `showProjectChat()`

### 3. SpriteName (캐릭터 애니메이션)
- `AgentConfig.spriteName: String?` — nil이면 이모지 폴백
- 현재 완성된 캐릭터: `"sloth"` (루나), `"dog"` (맥스)
- `AnimationState`: `.idle`, `.speaking`, `.thinking`, `.joy`, `.sad`, `.dragging`, `.landing`, `.greeting`, `.thumbsUp`
- `SpriteAgentView(characterID:fallbackEmoji:state:)` — 이 시그니처 사용

### 4. 시스템 이벤트
```swift
WebSocketClient.shared.sendSystemEvent(eventType: "wake"/"idle"/"startup"/"greeting"/"cheer", baseGreeting: "...")
```
- `idle`: 15분 무활동 후 자동 트리거
- `wake`: macOS 잠금 해제 / 잠자기 해제
- `startup`: 앱 시작 2초 후

### 5. 하이브리드 TTS
- `UserDefaults("useCloudVoice")` = true → 백엔드 Base64 audio_base64 재생
- false → `SpeechManager.shared.speak(text:)` 네이티브 TTS

### 6. 중요 AppStorage 키
| 키 | 타입 | 용도 |
|----|------|------|
| `userTitle` | String | 에이전트가 사용자 호칭으로 사용 |
| `teamName` | String | 메인 창 상단 배지 이름 |
| `showTeamName` | Bool | 팀명 배지 표시 여부 |
| `useCloudVoice` | Bool | 클라우드 TTS 사용 여부 |
| `isDarkMode` | Bool | 다크모드 |
| `isSilentMode` | Bool | 무음 모드 |
| `custom_persona_{agentID}` | String | 에이전트별 커스텀 성격 |

---

## 🎨 UI 설계 원칙

### 채팅창 스타일
- **iMessage 스타일**: 사용자 메시지 우측(파란 버블), 에이전트 메시지 좌측(회색 버블)
- 에이전트 아바타(이모지) + 이름 표시, 타임스탬프, 날짜 구분선
- `IMMessageBubble` 구조체 사용 (`AgentChatView.swift` 하단에 정의됨)
- `DateSeparator` 구조체: 날짜 구분선 (같은 파일에 정의됨)

### 창 크기 정책
- 메인 팀 창: 460 × 280
- 채팅창: 자유 리사이즈 (`frame(maxWidth: .infinity, maxHeight: .infinity)`)
- 설정창: 440 × 700
- 팀 협업현황창: 620 × 480

### 구성 요소 색상
- 컴파일러 타임아웃 방지: 복잡한 삼항 연산자를 헬퍼 프로퍼티로 분리
- 다크모드: `manager.isDarkMode`

---

## 🔴 절대 금지 사항

1. `teamChatLogs.append()` 직접 호출 — `addChatLog()` 사용
2. `AnimalTTSManager`, `HangulDecomposer`, `SpriteAgentView`, `CharacterSpriteScene`, `KeychainManager`, `LiveAudioManager`, `Resources/Phonemes/`, `tools/` 수정
3. `AgentConfig`에서 `spriteName` 없이 새 에이전트 추가 (nil 가능하지만 파라미터 누락 금지)
4. Swift onChange 단일 파라미터 클로저 사용 — `{ _, newValue in }` 두 파라미터 형식 사용

---

## 📋 작업 이력

### [2026-03-25] Antigravity
- 초기 AgentWindowManager, FloatingPanel, TeamTableView, AgentChatView 구축
- 드래그 이동, 에이전트 팝업 메뉴, 교체 창 구현

### [2026-03-26] Antigravity
- Master Spec 문서 작성 `/Users/su/.gemini/antigravity/brain/ec9f3552-91ef-4d61-8d9e-a9cd7e3c9cd1/master_spec.md`
- ChatRoom 아키텍처 최초 구현 (후에 외부 작업으로 롤백됨)
- TeamStatusView iMessage 스타일 최초 구현

### [2026-03-27] Antigravity — 전체 기능 복원
**복원 항목:**
- `AgentConfig.spriteName` (PNG 시퀀스 캐릭터용)
- `ChatRoom` 모델 + `rooms` 영속화 + `currentRoomID`
- `teamRepresentative` 정적 config (팀 전체 채팅용)
- `teamPanelWindow` 노출 (드래그 이동용)
- 아이들 타이머(15분) + 기상/시작 시스템 이벤트
- `addChatLog`, `createRoom`, `renameRoom`, `deleteRoom`, `showProjectChat`, `saveRooms/loadRooms`
- `showChat(isPersonalChat:)` 파라미터
- `WebSocketClient`: `audio_base64`, `is_system`, `sendSystemEvent`, `messageQueue`, `flushQueue`, 하이브리드 TTS, `updateInteractionTime`, `use_cloud_voice`/`user_title` 페이로드
- `AgentChatView`: `isPersonalChat`, `SpeechManager` 연동, 방별 메시지 필터링, `DateSeparator`, STT 에러
- `TeamStatusView`: iMessage 사이드바(방 목록) + 채팅 패널 + 날짜 구분선
- `TeamTableView`: 팀명 배지 + 드래그, 마이크 버튼, 종료 메뉴, SpriteKit 캐릭터 분기, 더블탭 인사말
- `SpriteAgentView` 호출 시그니처 수정: `characterID:fallbackEmoji:state:`

- `SettingsView` 복원: `userTitle`(사용자 호칭), `teamName`+`showTeamName`(팀명), `useCloudVoice`(클라우드 TTS), 응원받기 버튼

### [2026-03-27] Antigravity — UI 버그 수정 및 사용성 개선
- `TeamStatusView`: 삭제 모드(`−`) 버튼 디자인 개선 (다크모드 시 흰색 배경 + 검정 아이콘으로 시인성 확보)
- `TeamStatusView`: 팀 채팅방 하단에 누락되었던 채팅 입력창(`TextField`) 추가
- `FloatingPanel`: "최소화 락" 해제를 위해 표준 최소화 버튼(`miniaturizeButton`) 활성화 → (로그 수정) 사용자 요청으로 다시 비활성화 및 최소 크기 제한으로 해결
- `AgentChatView`: 외곽 컨테이너에 `.frame(maxWidth: .infinity, maxHeight: .infinity)` 추가하여 창 리사이즈 시 공백 문제 해결

- `FloatingPanel`: 창 상단에 나타나던 네이티브 신호등 버튼(닫기, 최소화, 확대) 완전 숨김 (커스텀 UI와 중복 방지)
- `AgentWindowManager`: 개별 채팅창에 최소 크기(`minSize`) 제한 제거 (사용자 요청에 따라 자유 조절 허용)

### [2026-03-27] Antigravity — iMessage 레이아웃 고도화 및 동적 리사이즈
- **동적 창 확장**: 채팅방 선택 시 창 너비가 300px에서 600px로 자동 확장 (아이메세지 스타일)
- **사이드바 최적화**: `TeamStatusView` 및 `AgentChatView` 사이드바 너비를 85px로 축소하여 공간 효율성 증대
- **기능 통합**: 개별 채팅창에도 에이전트 목록 사이드바를 추가하여 팀 채팅과 일관된 UX 제공
- **UI 정리**: 팀 채팅 사이드바 하단의 불필요한 설정 버튼 제거
- `AgentWindowManager`: `updateStatusWindowWidth`, `updateChatWindowWidth` 함수 구현으로 SwiftUI-AppKit 간 창 크기 동기화

### [2026-03-27] Antigravity — 백엔드 연결성 및 UI 개선
- **`backend/main.py`**: Gemini 모델명 `gemini-1.5-flash-latest`로 업데이트하여 404 오류 해결
- **`WebSocketClient.swift`**: 하드코딩된 URL을 `UserDefaults`의 `customBackendURL`을 사용하도록 동적화
- **`TeamStatusView.swift`**: 팀 채팅방 레이아웃 수정 (입력창을 대화 로그 하단으로 이동)
- 백엔드 서버 재시작 및 API 통신 검증 완료

### [2026-03-27] Claude Code — 로컬 아키텍처 전환 (Python 백엔드 제거)
**핵심 변경: 서버 없이 앱만으로 동작하도록 전환**

**새 파일:**
- `AIService.swift` — Gemini/Claude/OpenAI REST API 직접 호출 (URLSession)
  - 에이전트 페르소나 8명 정의 (main.py에서 이식)
  - 라운드 로빈 프로바이더 선택
  - `getResponse(text:agentID:chatHistory:)` → AI 응답
  - `validateKey(provider:apiKey:)` → 설정창 API 검증
  - 시스템 프롬프트, 커스텀 페르소나, userTitle 모두 지원

**수정 파일:**
- `AgentChatView.swift` — `sendMessage()`가 WebSocket 대신 AIService 직접 호출
- `TeamStatusView.swift` — `sendTeamMessage()`가 WebSocket 대신 AIService 직접 호출
- `SettingsView.swift` — API 검증이 백엔드 경유 대신 AIService.validateKey() 직접 호출
- `AnimalTTSManager.swift` — `loadPhonemeCache()` 백그라운드 스레드로 이동 (설정창 멈춤 해결)
  - WAV 로드를 `DispatchQueue.global(qos: .userInitiated)`에서 실행
  - 음소 미로드 시 가드 추가
- `SpeechManager.swift` — `useAnimalTTS` 기본값 true 보장
- `backend/main.py` — Gemini 모델 `gemini-2.0-flash` 교체

**아키텍처 변경 요약:**
```
이전: Swift → WebSocket → Python FastAPI → AI API
현재: Swift → AIService.swift → AI API 직접 호출 (서버 불필요!)
```

**주의: WebSocketClient.swift는 아직 삭제하지 않음** (호환성 유지)
Antigravity가 WebSocket 관련 코드를 참조하고 있을 수 있으므로,
완전 삭제는 협의 후 진행. 현재는 채팅에서 사용하지 않음.

### [2026-03-27] Claude Code — 버그 수정 2건
- **`SpeechManager.swift`**: `bool(forKey:)` → `object(forKey:) as? Bool ?? true` 로 변경
  - 원인: 설정창 미오픈 상태에서 `useAnimalTTS` 키가 UserDefaults에 없어 false 반환 → Apple TTS 폴백
  - 수정: 키 없을 때 기본값 true 보장 → 앱 최초 실행부터 AnimalTTS 동작
- **`backend/main.py`**: Gemini 모델명 `gemini-1.5-flash` → `gemini-2.0-flash` (2곳)
  - 원인: v1beta API에서 1.5-flash 404 삭제됨
  - 수정: validate_key + set_api_keys 모두 교체

### [2026-03-27] Claude Code — 동물의 숲 TTS + SpriteKit 파이프라인 추가
**새로 추가한 파일 (절대 수정 금지):**
- `AnimalTTSManager.swift` — espeak-ng 기반 음소 재생 엔진, AVAudioEngine + 피치/리버브, 캐릭터별 VoiceProfile
- `HangulDecomposer.swift` — 한글 유니코드 → 초성/중성 분해 → 음소 키 변환
- `CharacterSpriteScene.swift` — SpriteKit SKSpriteNode, AnimationState enum, PNG 시퀀스 자동 탐지, 이모지 폴백
- `SpriteAgentView.swift` — SwiftUI SpriteView 래퍼, `characterID:fallbackEmoji:state:` 시그니처
- `KeychainManager.swift` — API 키 Keychain 보안 저장
- `LiveAudioManager.swift` — 실시간 오디오 스트림 관리
- `Resources/Phonemes/*.wav` — 71개 한국어 음소 WAV (espeak-ng 생성, 16kHz 모노, ~100ms)
- `tools/generate_phonemes.sh` — 음소 WAV 재생성 스크립트
- `tools/extract_frames.sh` — MP4 → PNG 시퀀스 추출 (fps=12 + rembg 배경제거)

**주의사항:**
- `AgentWindowManager.AgentConfig`에 `spriteName: String?` 필드가 있어야 SpriteKit 연동 가능
  - 현재 Antigravity 복원 작업으로 재추가된 상태 (2026-03-27 Antigravity 로그 참조)
- `SpeechManager.speak(text:animalTTS:)` — `animalTTS: true`면 AnimalTTSManager 사용
- Phonemes 폴더는 Xcode 프로젝트에 수동 추가 필요 (Copy Bundle Resources 타겟 포함)

---

## 🚧 미완성 / 향후 작업 (TODO)

- [ ] FloatingPanel 드래그 이벤트 WebSocket 연동 복원 (`drag_start`, `dragging`, `drop` — 현재 주석 처리됨)
- [ ] 영상통화 기능 (장기 로드맵)
- [ ] StoreKit 2 캐릭터 스킨 인앱결제
- [ ] 팀 채팅 개별 채팅 프로젝트 연결 (채팅방 선택 후 1:1 대화)
- [ ] 에이전트 추가 스프라이트: 슬로스(완성), 개(완성) → 나머지 6개 미완성
- [ ] `AgentSettingsView`: role/job 필드 복원 (현재 persona만 있음)
- [ ] 백엔드 `cheer` 이벤트 타입 처리 추가

---

## 📝 다음 작업 시 이 파일에 아래 형식으로 추가

```
### [YYYY-MM-DD] [Antigravity / Claude Code]
- 작업한 내용 요약
- 수정 파일 목록
```
