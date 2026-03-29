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

- [ ] FloatingPanel 드래그 이벤트 로컬 처리 (`drag_start`, `dragging`, `drop` — 현재 주석 처리됨)
- [ ] TTS 음질 개선 (현재 외계어 느낌 → 동물의 숲 느낌으로 개선 필요, 사용자 샘플 검토 후 작업)
- [ ] 영상통화 기능 (장기 로드맵)
- [ ] StoreKit 2 캐릭터 스킨 인앱결제
- [ ] 팀 채팅 개별 채팅 프로젝트 연결 (채팅방 선택 후 1:1 대화)
- [ ] 에이전트 추가 스프라이트: 슬로스(완성), 개(완성) → 나머지 6개 미완성
- [ ] `AgentSettingsView`: role/job 필드 복원 (현재 persona만 있음)
- [ ] 백엔드 `cheer` 이벤트 타입 처리 추가

---

### [2026-03-28] Claude Code — WebSocket 의존성 제거 + UI 복원 + 직업 프리셋

**WebSocket → 로컬 전환 (완료):**
- `TeamTableView.swift`: 하단 입력창이 WebSocket 대신 AIService 직접 호출하도록 전환
- `TeamTableView.swift`: 종료 메뉴 sendSystemEvent → 로컬 addChatLog + TTS
- `AgentSeatView`: 더블탭 인사말 sendSystemEvent → 로컬 addChatLog + TTS
- `AgentChatView.swift`: wsClient 의존성 완전 제거 (WebSocket 라이브 스피킹 표시 제거)
- `SettingsView.swift`: 응원받기 버튼 sendSystemEvent → 로컬 처리
- `FloatingPanel.swift`: `updateInteractionTime()` TODO 주석 해제 → 정상 호출

**UI 복원:**
- `TeamStatusView.swift`: `footerView` (소리/무음 토글, 다크모드 토글, 위치 초기화, 설정 버튼) 화면에 표시되도록 body에 추가
- `TeamTableView.swift`: 에이전트 팝업 메뉴 위치 수정 — 1~3번은 오른쪽, 4번(index≥3)은 왼쪽에 표시하여 화면 잘림 방지
- `AgentMenuPopupView`: `popupOnLeft` 파라미터 추가

**기능 추가:**
- `AgentSettingsView.swift`: 직업 프리셋 시스템 추가 (14개 직업별 대표 프롬프트)
  - PM, 백엔드, 프론트엔드, UI/UX, QA, 데이터분석, DevOps, ML, 마케터, CEO, 고객지원, 콘텐츠, 비서, 보안전문가
  - 프리셋 선택 시 기본 프롬프트 자동 적용, 세부 성격은 별도 커스텀 가능
  - `custom_job_{agentID}` AppStorage로 선택 직업 저장
- `AIService.swift`: Gemini 모델 `gemini-1.5-flash-latest` → `gemini-2.0-flash-lite`로 변경 (API 가용성 문제 해결)

**수정 파일:** TeamTableView.swift, TeamStatusView.swift, AgentChatView.swift, SettingsView.swift, FloatingPanel.swift, AgentSettingsView.swift, AIService.swift

### [2026-03-28] Claude Code — 캐릭터별 감정 대사 + TTS 개선

**캐릭터별 감정 대사 시스템:**
- `CharacterDialogues.swift` 새 파일 생성
  - 구글 스프레드시트 캐릭터 설정 시트에서 11캐릭터 × 15감정 상태 대사 임포트
  - `CharacterDialogues.randomLine(for:state:)` 정적 함수 제공
- `AgentWindowManager.swift`: `speakLocalEvent(text:state:)` 개선
  - `state` 파라미터 추가 — 캐릭터별 대사 우선, 없으면 기존 텍스트 폴백
  - `handleStartup()`, `handleWake()` → `.greeting` 상태 대사 사용
  - `checkIdle()`: 15분 → `.idle`, 30분 → `.sleeping` 대사 사용
- `TeamTableView.swift`: 캐릭터 고유 대사 연결
  - 에이전트 팝업 음성 버튼 → `.greeting` 대사
  - 에이전트 더블탭 → `.greeting` 대사 (+ characterName을 TTS에 전달)
  - `agentDragBegan` → `.drag` 대사
  - `agentDragEnded` → `.landing` 대사

**TTS 개선 (Apple 기본 TTS 강화):**
- `SpeechManager.swift`: `useAnimalTTS` 기본값 `false`로 변경 (외계인 목소리 문제 해결)
- 캐릭터별 전용 Apple TTS 목소리 배정 (`characterVoiceMap`):
  - 레오 → Rocko (낮고 차분), 루나 → Sandy (밝고 활발), 치코 → Flo (감성적)
  - 렉스 → Grandpa (느리고 낮음), 케이 → Reed (중성적), 래키 → Eddy (활발)
  - 모코 → Reed, 핀 → Rocko, 폴라 → Sandy, 몽몽 → Shelley, 올리버 → Grandpa
- 각 캐릭터별 pitchMultiplier + rate를 AnimalTTSManager 프로필에서 재활용

**수정 파일:** CharacterDialogues.swift (신규), AgentWindowManager.swift, TeamTableView.swift, SpeechManager.swift

### [2026-03-28] Antigravity — 개별 대화창 버그 수정 및 기능 추가
- **`AgentChatView.swift`**: + 버튼 클릭 시 앱 멈춤 버그 수정 (DispatchQueue.main.async로 방 생성 후 선택 처리)
- **`AgentChatView.swift`**: 대화(프로젝트) 이름 변경 기능 추가 (더블탭 인라인 편집 + 우클릭 컨텍스트 메뉴)
- **`AgentChatView.swift`**: − 버튼 아이콘 교체 → 팀 협업창 스타일 (↙ 화살표) + 최소화 시 헤더바 표시
- **`AgentChatView.swift`**: 창 최소 높이 `minHeight: 480` 설정으로 초기 열릴 때 너무 작은 버그 해결
- **`AgentWindowManager.swift`**: 개별 채팅창 초기 크기 420×900 → 600×620 수정, `minSize` 300×480 복원

### [2026-03-29] Antigravity — 단일 대화창 고도화 및 치명적 버그 수정
- **`AgentChatView.swift`**: `EXC_BREAKPOINT` 크래시 해결 (AppKit NSPanel 프레임 수정을 `DispatchQueue.main.async`로 감싸 SwiftUI 애니메이션 충돌 방지)
- **`AgentChatView.swift`**: 프로젝트 이름 더블클릭 수정 기능 개선 (macOS Button 이벤트 간섭 해결을 위해 `onTapGesture`로 교체)
- **`AgentChatView.swift`**: 창 가로 크기(800px) 미반영 문제 해결 (`onAppear` 시 강제 리사이즈 및 `chat_single` ID 동기화)
- **`AgentWindowManager.swift`**: 개별 채팅창을 **단일 인스턴스(`chat_single`)**로 통합하여 중복 창 생성 방지 및 에이전트 전환 알림 구현, **초기 및 전환 시 가로/세로 크기를 600x520px로 최적화**
- **`AgentWindowManager.swift`**: 시스템 로그(`isSystem: true`) 필터링 강화 (드래그, 수면, 인사말 등 모든 시스템 대사를 팀 협업창에서 차단)
- **`TeamStatusView.swift`**: 사이드바 프로젝트 이름 최대 6글자 노출 및 왼쪽 정렬 레이아웃 수정
- **`TeamTableView.swift`**: 에이전트 팝업 메뉴 위치 재수정 (1~3번은 캐릭터 오른쪽 바깥 `.topLeading` + `x:100`, 4번은 왼쪽 바깥 `.topTrailing` + `x:-100`으로 배치하여 가독성 및 화면 잘림 방지)
- **`backend/main.py`**: Gemini 모델 중복 코드 제거 및 `gemini-1.5-flash-latest` 안정화 버전 유지
- **사용성 개선**: 개별 채팅창에서 에이전트 전환 시 해당 에이전트와 나눈 개인 대화방이 없으면 즉시 자동 생성하도록 로직 보완

### [2026-03-29] Claude & Antigravity 합동 — 캐릭터 프로필 파일 폴백 및 통합
- **`CharacterSpriteScene.swift`**: 치코 스프라이트 완전 적용 (23개 모션, 폴백 체인 구현, 기본 복귀 상태 `typing`으로 변경)
- **`CharacterSpriteScene.swift`**: 드래그 중 스프라이트가 비정상적으로 확대되어 발만 보이는 버그 해결 (애니메이션 첫 프레임이 아닌 전체 프레임 중 최대 크기를 기준으로 Scene 스케일을 계산하도록 수정) 및 `.drag` 상태를 루프 모션(`loopingStates`)에 추가하여 드래그 내내 모션이 유지되도록 개선
- **`AgentSeatView.swift` / `SpriteAgentView.swift`**: SpriteKit 애니메이션이 없는 캐릭터의 경우 Assets에 저장된 고유 프로필 이미지를 띄우는 폴백(`fallbackImageName`) 로직 구현
- **`AgentChatView.swift` & `ChatComponents.swift`**: 앱 전반적으로 사용되던 기본 이모지(`Text(agent.emoji)`)를 모두 제거하고, Assets의 11개 얼굴 프로필 아이콘(`Image(agent.fallbackImageName)`)이 둥근 모양(`clipShape(Circle())`)으로 노출되도록 전면 개편
- **`TeamStatusView.swift`**: '팀 협업 중' 리스트의 에이전트 아이콘을 이모지 대신 프로필 이미지로 교체하고, 원형 배경에 꽉 차도록(`.scaledToFill()`) 레이아웃 최적화
- **`SettingsView.swift` & `TeamTableView.swift`**: 메인 창 상단의 '팀 이름' 명패 배경 색상을 사용자가 직접 변경할 수 있도록 `ColorPicker` 기능 추가 및 HEX 기반 색상 저장 로직 구현
- **`Color+Hex.swift` [NEW]**: SwiftUI `Color`와 HEX 문자열 간 상호 변환 및 배경색 밝기에 따른 텍스트 색상 자동 반전(`isDark`) 유틸리티 추가
- **`AgentWindowManager.swift`**: 업로드된 파일명(`렉스`, `올리버`, `몽몽` 등) 변경 사항을 코드 상의 `fallbackImageName` 매핑과 완벽히 일치하도록 최종 수정
- **`Assets.xcassets`**: 단순 나열되어 있던 PNG 파일들을 `Contents.json`을 포함한 정식 `.imageset` 구조로 변환하고, 파일명 인코딩을 **NFC(유니코드 정규화)**로 통일하여 빌드 환경에서 이미지가 로컬 경로 문제 없이 정상적으로 로딩되도록 조치
- **`ChatComponents.swift`**: 개별 대화창의 '사용자' 및 '팀 전체 채팅' 아이콘이 빈칸으로 나오던 문제를 해결하기 위해, 이미지가 없는 경우 SF Symbols(`person.2.circle.fill`)를 기본값으로 사용하도록 보완
- **`AgentSeatView.swift`**: 메인 팀 화면(요원 배치창)에서도 치코와 같은 전용 애니메이션 캐릭터가 아닌 경우, 이모지 대신 사용자 제공 프로필 이미지가 우선적으로 나타나도록 렌더링 로직 고도화



### [2026-03-29] Claude Code — 스프라이트 레이아웃 최적화 & 프로필 이미지 폴백 시스템

**스프라이트 화면 보정 (위아래 잘림 문제 해결):**
- `CharacterSpriteScene.swift`: `anchorPoint = CGPoint(x:0.5, y:0.0)` 씬 하단 고정 → 발만 보이던 버그 해결
- `SpriteAgentView.swift`: `scene.size` 100×120 → 100×140 (세로 여유 확보)
- `AgentSeatView.swift`: 선택 영역 80×80 → 100×100, SpriteAgentView 프레임 100×140 명시
- `CharacterSpriteScene.fitCharacterToScene()`: 스케일 90% → 95%
- `loadAndPlay()`: 첫 프레임 크기 적용 후 fitCharacterToScene() 자동 호출

**AnimationState rawValue 파일명 동기화:**
- `backToWork`: "back_to_work" → "backwork" (실제 파일 치코_backwork_001.png에 맞춤)
- `clockOut`: "clock_out" → "clockout"
- `clockIn`: "clock_in" → "clockin"
- `returnToTyping`: "return_to_typing" → "typing_return"
- `idleLoop` 신규: "idle_loop"
- `lowering` 신규: "lowering" (내려감 — dropped의 신규 파일명 대응)

**모션 통합 및 폴백 체인 구현:**
- `fallbackStates` 딕셔너리: 파일 없는 상태 → 대체 상태 자동 매핑
  - thinking→idle, praise→agree, sleeping→resting, clockOut→resting
  - disagree→angry, lookLeft/Right→look→idle, dropped→lowering
- `resolveWithFallback()`: 체인 순서로 파일 탐색, 최대 5단계, 방문 집합으로 무한루프 방지
- 1회 재생 후 복귀: `.idle` → `.typing` (업무 중이 기본 상태)

**캐릭터 프로필 이미지 폴백 시스템:**
- `AgentConfig.swift`: `fallbackImageName: String` 프로퍼티 추가
- `CharacterSpriteScene.swift`: fallbackEmoji(SKLabelNode) → fallbackImageName(SKSpriteNode)
- `SpriteAgentView.swift` / `CharacterAnimationController`: 파라미터명 fallbackEmoji → fallbackImageName
- `AgentWindowManager.swift`: 11개 에이전트 fallbackImageName 매핑
  (치코_profile, leo_profile, luna_profile, moco_profile, pin_profile, rex_profile,
   kai_profile, lucky_profile, polar_profile, mongmong_profile, oliver_profile)
- `Assets.xcassets`: 프로필 이미지 `.png` 직접 복사 등록

**수정 파일:** CharacterSpriteScene.swift, SpriteAgentView.swift, AgentSeatView.swift,
AgentConfig.swift, AgentWindowManager.swift, Assets.xcassets

---

### [2026-03-29] Claude Code — 로드맵 수립 (TTS / 감정-스프라이트 / 에이전트 고도화)

**향후 구현 방향 계획 수립:**

**TTS 교체 (AnimalTTS 폐기):**
- 현재 espeak-ng phoneme WAV 방식 → 외계인 음성 수준으로 사용 불가, 완전 교체 결정
- 채택 방안: Apple AVSpeechSynthesizer + AVAudioEngine DSP (Animal Crossing 방식 오프라인 구현)
  - AVAudioUnitTimePitch: 캐릭터별 pitch(cents) + rate 실시간 조절
  - 치코(+400, 1.15x 빠름) / 렉스(-400, 0.75x 느림) 등 11개 VoiceProfile 정의
  - 0 추가 용량, 완전 오프라인, 즉시 구현 가능
- 장기: Chatterbox CoreML (+1.5GB, zero-shot 음성 복제, 구현 1~2개월)

**감정-스프라이트 연결 (버그 확인 및 수정 계획):**
- TeamTableView 라인 57: `isSpeaking: false` 하드코딩 발견 → 대화해도 캐릭터 무표정
- 수정 계획:
  - AgentWindowManager: `speakingAgentID`, `agentEmotions[agentID]` @Published 추가
  - SpeechManager.speak(): agentID 파라미터, didFinish에서 clearAgentSpeaking() 콜백
  - AgentWindowManager.detectEmotion(): AI 응답 텍스트 → AnimationState 감지
  - TeamTableView: isSpeaking 하드코딩 해제
  - AgentSeatView: agentEmotions 기반 state 결정

**에이전트 고도화 (OpenClo Lite):**
- AgentOrchestrator: [DELEGATE:agentID] 태그 기반 에이전트 간 위임
- SharedWorkspace: 에이전트 간 공유 프로젝트 컨텍스트
- 자율 협업 워크플로우 (기획→디자인→개발→QA 흐름)

**외부 서비스 연동 (Tool Use / Function Calling):**
- Gemini/Claude/OpenAI 모두 Function Calling 지원 → AIService.swift 도구 정의 추가만으로 가능
- ToolExecutor.swift (신규): AgentTool 프로토콜, GoogleCalendarTool, GmailTool, WebSearchTool
- Google OAuth → KeychainManager 토큰 저장 (이미 있음), SettingsView 연동 버튼 추가
- 우선순위: Google Calendar > Gmail > Web Search > Notion > GitHub

---

## 📝 다음 작업 시 이 파일에 아래 형식으로 추가

```
### [YYYY-MM-DD] [Antigravity / Claude Code]
- 작업한 내용 요약
- 수정 파일 목록
```
