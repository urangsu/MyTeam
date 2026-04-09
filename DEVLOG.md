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
4. **SettingsView 필수 UI 항목 무단 삭제 금지** — 어떤 뷰 개편 시에도 아래 항목은 반드시 존재해야 함:
   - 사용자 호칭 (`UserDefaults("userTitle")`)
   - 사용자 위치 (`@AppStorage("userLocation")`)
   - 팀 이름 (`@AppStorage("teamName")`)
   - 팀 명패 색상 (`@AppStorage("teamNameColor")`)
   - 에이전트창 투명도 (`@AppStorage("agentWindowOpacity")`)
   - API 키 (Gemini / Claude / OpenRouter) + 검증 버튼
   - 에이전트별 LLM 라우팅 (`UserDefaults("llmProvider_agent_N")`)
   - 닫기(X) 버튼 (`NSApp.keyWindow?.close()`)

---

## 🪟 창별 기능 목록 (필수 기능 / 개발 예정)

### TeamTableView (메인 플로팅 팀 창, 460×280)
| 상태 | 기능 |
|------|------|
| ✅ | 에이전트 4명 표시 (스프라이트/프로필) |
| ✅ | 팀 이름 명패 배지 |
| ✅ | 각 에이전트 클릭 → 팝업 메뉴 (Chat/Voice/Settings/Swap) |
| ✅ | 팀 채팅방 버튼 |
| 🔵 | 에지 스냅핑 애니메이션 |

### AgentChatView (개별 채팅창, 700×620)
| 상태 | 기능 |
|------|------|
| ✅ | iMessage 스타일 버블 (사용자 우측 파란, 에이전트 좌측 회색) |
| ✅ | 타이핑 인디케이터 (... 바운스) |
| ✅ | 말풍선 삭제(X) + 삭제 모드 Jiggle |
| ✅ | 날짜 구분선, 타임스탬프 |
| ✅ | 스크롤 자동 하단 이동 |
| 🔵 | 채팅창 스크롤 ↔ 창 이동 충돌 해결 |

### TeamStatusView (팀 협업현황창, 620×480)
| 상태 | 기능 |
|------|------|
| ✅ | 다중 채팅방 사이드바 |
| ✅ | 방 생성/삭제/이름 변경 |
| ✅ | 반투명 배경 (NSVisualEffectView) |

### SettingsView (설정창, 460×600)
| 상태 | 기능 |
|------|------|
| ✅ | 사용자 호칭·위치 설정 |
| ✅ | 팀 이름·명패색·창 투명도 |
| ✅ | API 키 (Gemini/Claude/OpenRouter) + 검증 버튼 |
| ✅ | 에이전트별 LLM 라우팅 (11명) |
| ✅ | 닫기(X) 버튼 |
| ✅ | NSVisualEffectView 반투명 배경 |
| 🔵 | 창 크기 조절 가능하게 변경 |

### AgentSettingsView (에이전트별 커스텀 설정)
| 상태 | 기능 |
|------|------|
| ✅ | 성격 커스텀 텍스트 입력 |
| ✅ | 보조 업무(직업 프리셋) 14종 |
| 🔵 | 캐릭터 음성 레퍼런스 WAV 업로드 UI |

---

## 📋 작업 이력

### 2026-04-05 (3차): [Claude Code] ONNX 온디바이스 TTS + UX 대폭 개선
- **[핵심 기능] ONNX Runtime 온디바이스 TTS 파이프라인 구현 (ONNXTTSManager.swift)**
  - 7개 ONNX 모델 (T3 prefill/decode, S3Gen enc/cfm, HiFiGAN f0/backbone, VE) 추론 파이프라인
  - cam_plus/s3tokenizer export 실패 → Python pre-compute 우회 전략 적용
  - `precompute_embeddings.py`: 11개 캐릭터 speaker embedding + prompt tokens 미리 계산 완료
  - T3 임베딩 가중치 추출 (text_emb, speech_emb, pos_emb 6개 .npy 파일)
  - SpeechManager TTS 우선순위: ONNX → Chatterbox HTTP → 캐릭터 음절 WAV
- **[버그 수정] 이름 태그 첫 글자 잘림 (AIService.swift)**
  - 정규식이 구분자 없이도 한글을 태그로 인식하던 문제 → 콜론/괄호 필수 매칭으로 변경
- **[버그 수정] 에이전트창 크기 변동 (채팅/협업 전환 시)**
  - `updateStatusWindowWidth()`가 `teamPanel`을 변경하던 버그 → `statusPanel`로 수정
- **[버그 수정] 말풍선 영구 표시 문제**
  - TTS 실패 시 `finishSpeaking()` 미호출 → guard 실패 경로에 명시적 호출 추가
  - 안전장치: `setAgentSpeaking()` 후 최대 30초 타임아웃 자동 clear
- **[버그 수정] OnDeviceTTSManager 스트리밍 실패 시 reference 직접 재생 문제**
  - `success = true` 반환하던 로직 → `false` 반환으로 변경 (음절 WAV 폴백 허용)
- **[UX 개선] 카톡 스타일 채팅 구현**
  - 긴 AI 응답을 1~3문장씩 끊어서 별도 말풍선으로 전송
  - 타이핑 딜레이: 첫 메시지 0.3~0.8초, 이후 글자수 비례 (20대 타이핑 속도)
  - `TypingIndicatorView`: 캐릭터 색상 "..." 바운스 애니메이션 (ChatComponents.swift)
  - `AgentWindowManager.typingAgentIDs`: 타이핑 중인 에이전트 추적
- **[UX 개선] 채팅창/설정창 스크롤 문제 해결**
  - FloatingPanel: 팀 패널만 커스텀 드래그, 나머지는 기본 NSPanel 동작
  - 설정창/협업현황창 `isMovableByWindowBackground = false`
  - 설정창 `.clipped()` 추가 (UI 오버플로 수정)
- **[UX 개선] 대사 시간 인식 + AI 시간 컨텍스트**
  - CharacterDialogues: "좋은 아침" 5~11시에만, 드래그 중 "종료" 대사 차단
  - AIService 시스템 프롬프트에 현재 날짜/시간 자동 주입
- **[버그 수정] NSSound "Already playing" 중복 재생 방지**
- **[핵심 수정] 오디오 재생 Mac mini 호환성**
  - AVAudioEngine PlayerNode: Mac mini에서 무음 확인 → 사용 중지
  - AVAudioPlayer: Mac mini에서 무음 확인 → 사용 중지
  - NSSound: 유일하게 작동 → 모든 오디오 재생 NSSound로 통일
  - ONNX TTS PCM 출력: WAV 파일 생성 → NSSound 재생
  - SpeechManager: animalEngine/animalPlayer/animalPitch 완전 제거
  - SpeechManager 앱 시작 시 ONNXTTSManager 미리 초기화 (1.9GB 모델 로딩 시간 확보)
- 수정 파일: `ONNXTTSManager.swift`, `SpeechManager.swift`, `AIService.swift`, `FloatingPanel.swift`, `AgentWindowManager.swift`, `AgentChatView.swift`, `ChatComponents.swift`, `CharacterDialogues.swift`, `SettingsView.swift`, `OnDeviceTTSManager.swift`, `SoundPlayer.swift`
- 신규 파일: `precompute_embeddings.py`, `Resources/PrecomputedVoice/*.json`

### 2026-04-05 (2차): [Claude Code] 캐릭터 음절 TTS + Rive 폐기 + 워크트리 충돌 해결
- **[핵심 기능] 캐릭터 음절 WAV 기반 TTS 구현 (Apple TTS 완전 제거)**
  - SpeechManager에서 Apple TTS(AVSpeechSynthesizer) 관련 코드 전부 삭제
  - 캐릭터별 음절 WAV(CharacterPhonemes/) 로드 → 텍스트 음절 분해 → 순차 재생
  - useAnimalTTS ON: 캐릭터 프로필 피치/배속/리버브 적용 (동물의 숲 스타일)
  - useAnimalTTS OFF: 정상 속도 재생 (또는 Chatterbox 서버 가용 시 스트리밍)
  - 폴백: 레퍼런스 음성 직접 재생 (음절 WAV 없을 때)
- **[음절 생성] Python 스크립트 개선판 작성**
  - `generate_all_syllables.py`: 무음 감지/재시도 5회, 프롬프트 변형, 진행률 표시
  - 파일명에 캐릭터 접두사 포함 (Xcode PBXFileSystemSynchronizedRootGroup 충돌 방지)
  - `--characters` 옵션으로 특정 캐릭터만 재생성 가능
- **[빌드 에러] RiveRuntime 패키지 완전 폐기**
  - pbxproj에서 Rive 관련 6개 참조 제거 (BuildFile, Framework, packageRef, productDep 등)
  - RiveAgentView.swift를 빈 스텁으로 교체
  - Package.resolved에서 rive-ios 항목 제거
- **[빌드 에러] 워크트리(.claude/worktrees/) 빌드 충돌 해결**
  - 원인: PBXFileSystemSynchronizedRootGroup이 워크트리 내 중복 파일까지 스캔
  - 해결: 워크트리 제거 (`git worktree remove`)
- **[버그 수정] 음소거 버튼이 TTS를 막지 못하는 문제**
  - SpeechManager.speak() 진입 시 isSilentMode 즉시 체크 추가
- 수정 파일: `SpeechManager.swift`, `RiveAgentView.swift`, `project.pbxproj`, `Package.resolved`
- 신규 파일: `generate_all_syllables.py` (Python)

### 2026-04-05 (1차): [Claude Code] TTS 파이프라인 전면 재구축 및 빌드 에러 해결
- **[핵심 기능] 동물의 숲 TTS 모드 구현 (SpeechManager.swift)**
  - 설정의 "🐾 기본 TTS" 토글(useAnimalTTS)이 ON이면 레퍼런스 음성을 동물의 숲 스타일로 재생
  - AnimalTTSManager.characterProfiles의 캐릭터별 피치/배속/볼륨 프로필 재활용
  - AVAudioEngine + TimePitch + Reverb 파이프라인으로 레퍼런스 음성에 고피치/빠른속도/공간감 적용
  - 텍스트 길이에 비례한 재생 시간 조절 (짧은 문장은 짧게, 긴 문장은 반복)
  - 레퍼런스 음성 미발견 시 Apple TTS로 자동 폴백
- **[치명적 버그 수정] 음소거 버튼 무시 문제 해결**
  - SpeechManager.speak() 진입 시점에 isSilentMode 체크 추가
  - 동물TTS 루프 내에서도 매 반복마다 isSilentMode 체크
  - TeamOrchestrator 순차 발화 중 음소거 전환 시에도 즉시 차단
- **[치명적 버그 수정] AVAudioBuffer mDataByteSize(0) 크래시 완전 해결**
  - OnDeviceTTSManager 오디오 엔진을 지연 초기화(lazy)로 전환
  - Chatterbox 서버 없으면 엔진 자체를 만들지 않음 → CoreAudio 초기화 에러 원천 차단
  - `isServiceAvailable` 플래그 기반으로 서버 부재 시 즉시 실패 반환
- **[빌드 에러 해결] project.pbxproj 중복 프로젝트 참조 제거**
  - 동일 MyTeam.xcodeproj 4중 참조 + 고아 그룹/파일 참조 전부 제거 → "Multiple commands produce" 해결
- **[배포 대응] TTSServiceManager Python 서버 의존성 분리**
  - Python venv 미존재 시 서비스 시작 건너뜀 → 배포 환경 블로킹 방지
- **TTS 우선순위 체계 확립**:
  1. useAnimalTTS ON → 레퍼런스 음성 + 캐릭터별 피치/배속 (동물의 숲)
  2. useAnimalTTS OFF + Chatterbox 서버 가용 → 스트리밍 음성 클로닝
  3. useAnimalTTS OFF + 서버 없음 → Apple Eloquence TTS (캐릭터별 매핑)
- 수정 파일: `SpeechManager.swift`, `OnDeviceTTSManager.swift`, `TTSServiceManager.swift`, `project.pbxproj`

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

### 2026-04-08: [Claude Code] 3개 긴급 수정 — SettingsView 복구 + NPZ 로더 + ONNX 패딩
- **[UI 복구] SettingsView.swift 전면 재작성 (G-Stack UI/UX 표준)**
  - 3탭: 사용자&팀 / API 설정 / 에이전트 라우팅
  - 사용자 호칭·위치, 팀 이름·명패색·창 투명도 복구 (AppStorage 연결)
  - API 설정 탭: 동적 Picker(Gemini/Claude/OpenRouter) + 선택된 제공자만 표시 + API 키 검증 버튼(AIService.validateKey 연결)
  - 에이전트 라우팅 탭: 11명 에이전트별 LLM 제공자·Model ID 개별 설정 UI (UserDefaults("llmProvider_agent_N"))
  - 닫기(X) 버튼 복구, NSVisualEffectView 반투명 배경(sidebar material)
  - Apple HIG Form/Section 레이아웃 적용
- **[버그 수정] T3MLXModel.swift — NPZ 로더 교체**
  - `MLX.loadArrays(.npz)` → `unknownExtension` 크래시 수정
  - `T3MLXModel.loadNPZ(url:)` 구현: ZIP 파싱 + DEFLATE(Compression 프레임워크) + `parseNPYData` 직접 호출
  - Zero-Copy: `.mappedIfSafe` 강제, 1.95GB 파일 복사 없음
- **[버그 수정] MLXModelManager.swift — 투트랙 레퍼런스 오디오 로딩**
  - 1순위: `{char}_reference.wav` (무손실, 아티팩트 없음)
  - 2순위: `{char}_reference.mp3` 폴백 + 경고 로그 (`⚠️ WAV 에셋 누락. 테스트용 MP3 Fallback으로 로드 중...`)
  - `decodeWAVToFloat32` → `decodeAudioToFloat32` (WAV/MP3 공용)
- **[버그 수정] MLXInferenceService.swift — ONNX Conv 최소 패딩**
  - `Conv padded input tensor height 1 is smaller than the kernel height 16` 수정
  - `runS3GenEncoder()` 진입 시 `MIN_SEQ_LEN=32` 미달 시 zero-pad 강제 적용

### 2026-04-07: [Claude Code] Mock → Real 추론 파이프라인 교체 + ModelRouter 구현
- **[핵심 기능] T3 MLX-Swift 네이티브 TTS 추론 (온디바이스, App Store 배포 가능)**
  - `MLXModelManager.swift`: WAV 전용 레퍼런스 로드 (MP3 절대 금지), Zero-Copy Memory Mapping (Bundle URL → MLX.loadArrays 직결, 파일 복사 없음)
  - `T3MLXModel.swift` (신규): Llama 30-layer FP16 모델, RoPE + KV Cache + AR 디코딩, BPE 토크나이저 (grapheme_mtl_merged_expanded_v1.json)
  - `MLXInferenceService.swift`: CoreML EP 강제 (ANE/GPU 가속, CPU 폴백 불허), 실제 파이프라인 (Text → BPE → T3(MLX) → ve.onnx → s3gen(CoreML) → hifigan(CoreML) → PCM 청크)
- **[핵심 기능] ModelRouter + 에이전트별 동적 LLM 라우팅**
  - `AgentConfig.swift`: `llmProvider: LLMProvider` (gemini/claude/openRouter) + `openRouterModelId: String?` (동적 모델 ID)
  - `AIService.swift`: `getResponseStream(agentConfig:)` — 에이전트별로 Gemini/Claude/OpenRouter 중 선택, OpenRouter는 modelId를 API 페이로드에 직접 삽입
- **G-Stack 4가지 원칙 적용**:
  1. ✅ WAV 무손실 전용 (MP3 아티팩트 방지)
  2. ✅ ONNX CoreML EP 강제 (MLX↔CPU 병목 제거, ANE 가속)
  3. ✅ Zero-Copy Memory Mapping (1.95GB 파일 복사 금지, App Hang 방지)
  4. ✅ OpenRouter 동적 모델 ID (agentConfig.openRouterModelId 페이로드 주입)
- 신규 파일: `MLXModelManager.swift`, `T3MLXModel.swift`, `MLXInferenceService.swift` (완전 재작성)
- 수정 파일: `AgentConfig.swift` (llmProvider, openRouterModelId 필드 추가), `AIService.swift` (ModelRouter 구현, Gemini/Claude/OpenRouter SSE 파이프라인)

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

### 2026-04-05 (4차): [Antigravity] Xcode 중복 빌드 오류(Multiple commands produce) 해결
- **[버그 수정] 중복 리소스 및 소스 코드 충돌 해결**
  - 원인: `MyTeam.xcodeproj`의 `PBXFileSystemSynchronizedRootGroup`이 루트(`.`)를 동기화하면서, 하위 폴더에 남아있던 `.claude/worktrees/`의 중복 소스 코드를 모두 컴파일하려고 시도함.
  - 조치: 문제가 되는 `.claude/` 폴더를 프로젝트 루트 바깥인 `/Users/su/Desktop/MyTeam/Backup_claude_worktrees`로 이동시켜 격리함 (삭제 없이 보존).
  - 조치: 불필요하게 생성된 빈 중복 폴더인 `MyTeam/MyTeam/MyTeam/`을 삭제함.
- 결과: `AnimationState is ambiguous` 오류 및 `Multiple commands produce` 오류 해결 완료.

---

### 2026-04-05 (5차): [Claude Code] ONNX T3 모델 그래프 수술 + E2E 파이프라인 검증

- **[핵심] T3 ONNX 모델 Gather OOB 버그 수정 (t3_prefill.onnx, t3_decode.onnx)**
  - CumSum 노드 bool→INT64 Cast 삽입 (이전 세션에서 적용)
  - Gather_4, Gather_6 인덱스 OOB 수정: CumSum→Flatten 출력에 마지막 원소 패딩 (Slice+Concat)
  - Python `onnx` 라이브러리로 그래프 노드 삽입, 토폴로지 순서 보장
  - 수정 스크립트: `/Users/su/Desktop/TTS맨/chatterbox/fix_gather_oob.py`
  - 백업: `t3_prefill.onnx.bak_prefix`, `t3_decode.onnx.bak_prefix`

- **[핵심] Python E2E 파이프라인 검증 완료**
  - T3 prefill → speech tokens 생성 ✅ (seq≥2 모두 동작)
  - S3Gen encoder (token+prompt+xvector → mu/mask/conds/spks) ✅
  - CFM ODE loop 10 Euler steps ✅
  - HiFiGAN (source_len = T_mel × 480, 출력: magnitude+phase STFT) ✅
  - ISTFT (n_fft=16, hop=4) → PCM → WAV → afplay 재생 ✅
  - 검증 스크립트: `/Users/su/Desktop/TTS맨/chatterbox/test_e2e.py`

- **[버그 수정] OnDeviceTTSManager.swift:405 컴파일 에러**
  - `player.scheduleBuffer()` → `await player.scheduleBuffer()` (macOS 12+ async 오버로드)

- **[확인] S3Gen mel_mask bool→float 변환** (이전 세션 작업, 동작 확인)
  - `extractBoolsAsFloats()` 메서드 추가, S3Gen encoder mask 처리 수정

- **[작업] BPE 토크나이저 파일 복사**
  - `grapheme_mtl_merged_expanded_v1.json` → `/Users/su/Desktop/TTS맨/chatterbox/onnx_models/`

**수정 파일**: `OnDeviceTTSManager.swift`, `t3_prefill.onnx`, `t3_decode.onnx`
**신규 파일**: `fix_gather_oob.py`, `test_e2e.py` (검증 스크립트)

### 2026-04-05 (6차): [Claude Code] ONNX TTS 실행 문제 진단 및 수정

**증상**: 앱 빌드→실행 시 (1) main thread 경고 수백 개, (2) 앱 멈춤, (3) S3Gen 추론 실패

**진단 결과**:
1. **main thread 경고** — `Task.detached`로 로딩해도 CoreML EP가 내부적으로 `dispatch_sync(main_queue)` 호출 (ONNX Runtime 알려진 이슈). CoreML EP를 비활성화하면 해결됨
2. **앱 멈춤 원인** — T3 AR 루프가 KV cache 없이 매 스텝마다 전체 시퀀스를 prefill 재실행. 1.9GB Transformer 30층 × 매 스텝 full forward = CPU에서 극도로 느림 (O(n²) 복잡도). Mac mini M4 24GB에서도 한 문장 합성에 수분 소요
3. **S3Gen 실패** — `try?`로 에러 디테일이 삼켜지고 있었음. `do-catch`로 변경하여 정확한 에러 출력되도록 수정

**수정 내용**:
- `ONNXTTSManager.swift`:
  - `Task { await loadAll() }` → `Task.detached(priority: .userInitiated)` (백그라운드 로딩)
  - CoreML EP 비활성화 → CPU EP만 사용 (main thread 경고 근본 해결)
  - T3 AR max tokens 500→100 (실용적 상한)
  - T3/S3Gen/HiFiGAN 에러를 `try?` → `do-catch`로 변경 (디테일 로그)
  - 컴파일 경고 수정: `let count` 미사용 제거, `MainActor.run` 리턴값 `_ =` 처리
- `SpeechManager.swift`:
  - ONNX TTS 호출 조건에서 `!useAnimalTTS &&` 제거 → ONNX ready이면 항상 1순위
  - `let semitones` 미사용 경고 수정

**현실적 한계 및 결정**:
- Mac mini M4 (CPU only, KV cache 없음)에서 ONNX T3 AR 추론은 **너무 느림** (한 문장에 수분, 발열 64도)
- **결정: ONNX 비활성화, Chatterbox HTTP 서버를 1순위로 전환**

### 2026-04-05 (7차): [Claude Code] TTS 우선순위 최종 변경

**변경 내용**:
- `SpeechManager.swift` TTS 우선순위 변경:
  - 1순위: **Chatterbox HTTP 서버** (`OnDeviceTTSManager.isServiceAvailable` → `speak()`)
  - 2순위: 캐릭터 음절 WAV (NSSound)
  - 3순위: 레퍼런스 오디오 폴백
  - ONNX: **비활성화** (`_ = ONNXTTSManager.shared` 주석 처리)
- `ONNXTTSManager.swift`:
  - CoreML EP 비활성화 (main thread 경고 근본 원인)
  - T3 AR max tokens 500→100
  - 에러 로그 `try?` → `do-catch`로 변경
  - `Task.detached` 백그라운드 로딩
  - 컴파일 경고 수정 (`let count` 제거, `_ = MainActor.run`)
- `SpeechManager.swift`:
  - `let semitones` 미사용 경고 수정

**수정 파일**: `SpeechManager.swift`, `ONNXTTSManager.swift`

**TTS 서버 시작법** (Chatterbox HTTP):
```bash
cd ~/Desktop/TTS���/chatterbox
.venv/bin/python3 tts_service.py
# → http://127.0.0.1:9999 에서 리스닝
# → Swift 앱이 자동 감지하여 사용
```

**캐릭터 음절 WAV 생성법** (서버 없이도 동작하는 폴백용):
```bash
cd ~/Desktop/TTS맨/chatterbox

# 전체 캐릭터 일괄 생성
.venv/bin/python3 generate_all_syllables.py

# 특정 캐릭터만 (핀, 몽몽 등 음절 WAV 없는 캐릭터)
.venv/bin/python3 generate_all_syllables.py --characters 핀 몽몽
```
- 스크립트 위치: `/Users/su/Desktop/TTS맨/chatterbox/generate_all_syllables.py`
- 레퍼런스 오디오: `~/Desktop/MyTeam/MyTeam/Resources/ReferenceAudio/{캐릭��}_reference.mp3`
- 출력: `~/Desktop/MyTeam/MyTeam/Resources/CharacterPhonemes/{캐릭터}_{번호}_{음절}.wav`
- 한/영/일 음절 약 60개씩, 0.3초, 44100Hz
- 실패 시 최대 5회 재시도 + 무음 감지

### 2026-04-05 (8차): [Claude Code] KV Cache Export + INT8 양자화 — 100배 속도 향상 달성

**핵심 성과**:
- T3 모델 KV cache export 성공 (`export_kv_cache.py`)
  - `T3PrefillWrapper` / `T3DecodeWrapper` 수정: `use_cache=True`, 실제 KV 텐서 입출력
  - `DynamicCache` API 호환: `.layers[i].keys` / `.layers[i].values`
  - Dynamic axes: KV seq 축 dynamic 설정
- INT8 양자화 완료: 1953MB → 489MB (75% 감소)
- **벤치마크** (Mac mini M4, CPU only):
  - FP32 KV cache 없음: ~60초+ (이전)
  - FP32 + KV cache: 1.34초 (42배 향상)
  - **INT8 + KV cache: 0.46초** (100배+ 향상)
  - 스텝당: 0.010초

**신규 파일**:
- `/Users/su/Desktop/TTS맨/chatterbox/export_kv_cache.py` — KV cache 모델 export 스크립트
- `/Users/su/Desktop/TTS맨/chatterbox/onnx_models/t3_prefill_kv.onnx` (1953MB)
- `/Users/su/Desktop/TTS맨/chatterbox/onnx_models/t3_decode_kv.onnx` (1953MB)
- `/Users/su/Desktop/TTS맨/chatterbox/onnx_models/t3_prefill_kv_int8.onnx` (489MB)
- `/Users/su/Desktop/TTS맨/chatterbox/onnx_models/t3_decode_kv_int8.onnx` (489MB)
- `/Users/su/Desktop/TTS맨/chatterbox/onnx_models/s3gen_cfm_int8.onnx` (71MB)

**수정 파일**: `export_onnx.py` (T3PrefillWrapper, T3DecodeWrapper KV cache 지원)

### 2026-04-05 (9차): ONNX TTS E2E 동작 확인 — 소리 품질 문제 발견

**파이프라인 동작 확인**:
- T3 KV cache → S3Gen → CFM → HiFiGAN → ISTFT → PCM → NSSound **모두 동작**
- PCM 생성 성공 (147856~274576 samples, 6~11초 분량)
- **문제**: 생성된 오디오가 "찌이이이이이" 노이즈 (의미 있는 음성 아님)

**노이즈 원인 분석**:
- T3가 의미 있는 speech tokens을 생성하지 못함
  - 원본 Python 모델: `alignment_stream_analyzer`로 hallucination 감지 + 강제 EOS
  - ONNX 모델: 이 기능 없음 → stop token이 안 나와서 151토큰까지 찍히거나, 토큰 자체가 의미 없음
  - F0 예측값 0~0.8Hz (정상: 100~400Hz) → 소스 신호 이상 → 노이즈
- **Bool 텐서 문제**: S3Gen mel_mask가 bool 출력 → ORT Swift에서 tensorTypeAndShapeInfo() 실패
  - **해결**: mel_mask를 요청하지 않고 Swift에서 직접 float 1.0 배열 생성

**결정**: ONNX TTS 임시 비활성화, 음절 WAV + 레퍼런스 오디오로 소리 복원

**남은 작업** (ONNX 온디바이스 완성까지):
1. **[최우선] T3 토큰 품질 수정** — alignment_stream_analyzer 로직을 Swift로 구현하거나, ONNX에 포함
2. **export_onnx.py에서 S3Gen mel_mask를 float로 캐스팅** — `mask.float()` 추가해서 Bool 문제 근본 해결
3. CoreML EP `CPUAndGPU` V2 API 재활성화
4. `SpeechManager.swift` ONNX 1순위 복원

### 2026-04-05 (최종): CoreML 전환 결정

**ONNX 최종 진단**:
- BPE ✅, ISTFT ✅, KV cache ✅, HiFiGAN Full ✅, t3_cond_embeds ✅
- **CFG 실패**: batch=2 실행되지만 cond≈uncond → 토큰 품질 저하 → 백색소음
- Python에서 2회 호출 CFG로 첫 토큰 1763 (원본 1761과 일치) → "안녕하세요" 음성 확인
- **근본 원인**: ONNX export 시 LlamaModel 내부의 batch 분리 로직이 소실

**CoreML 직접 변환 시도**:
- F0 Predictor → CoreML ✅ (`f0_predictor.mlpackage`)
- HiFiGAN Decode → CoreML ✅ (`hifigan_decode.mlpackage`)
- **T3 (LlamaModel) → CoreML ❌**: `torch.diff`, `new_ones`, `fill` 등 미지원 op 연쇄
- transformers 5.2.0이 최신 PyTorch ops 대량 사용 → coremltools 9.0과 비호환

### 2026-04-05 (최종2): MLX 온디바이스 TTS 성공!

**🎉 M4 Mac mini에서 온디바이스 한국어 음성 생성 성공**
- MLX (Apple Silicon GPU) + CFG (2회 호출) + S3Gen + HiFiGAN → "안녕하세요" 음성 출력
- T3 MLX GPU: 1.86초, 전체 파이프라인: 6.95초
- 스크립트: `/Users/su/Desktop/TTS맨/chatterbox/mlx_t3_inference.py`

**기술 스택**:
- T3: MLX 네이티브 LlamaModel (30층, GPU 가속)
- CFG: 2회 호출 (cond + uncond → logits 결합, cfg_weight=0.5)
- S3Gen/HiFiGAN: ONNX (CPU) — 추후 MLX 변환 예정
- BPE: unicodeScalars 기반 자모 분해 (Python 동일)
- ISTFT: periodic Hann window (깨끗한 음성 검증됨)
- Conditioning: t3_cond_embeds (34토큰, perceiver 포함)

**남은 작업**: 초반 기계음 제거, S3Gen/HiFiGAN MLX 변환, Swift 앱 연결

### 2026-04-06: [Claude Code] MLX TTS 앱 통합 + UI 개선 + 속도 최적화

#### 달성한 것 ✅
1. **ONNX → MLX 전환 성공**
   - MLX (Apple M4 GPU) 네이티브 LlamaModel 30층 구현 (`mlx_t3_inference.py`)
   - T3 가중치 변환 완료 (`t3_mlx_weights.npz`, 1952MB)
   - MLX TTS HTTP 서버 구현 (`mlx_tts_server.py`, port 9998)
   - **한국어 음성 "안녕하세요" 온디바이스 생성 성공!**

2. **BPE 토크나이저 근본 수정**
   - 원인: Swift `Character`가 grapheme cluster로 자모를 합침 → 음절 토큰(2400번대) 출력
   - 해결: `unicodeScalars` 기반 분리 → Python 동일 자모 토큰(1700~1900번대)
   - BPE merge 비활성화 (Python tokenizer는 character-level)

3. **ISTFT 근본 수정**
   - 원인: `np.hanning` (symmetric, nFFT-1) vs `torch.hann_window` (periodic, nFFT) 차이
   - 해결: `0.5 * (1 - cos(2π*n/nFFT))` — periodic Hann으로 통일
   - **Python에서 깨끗한 음성 확인** (`torch.istft`와 동일 결과)

4. **CFG (Classifier-Free Guidance) 구현**
   - 원인: ONNX batch=2 CFG가 동작 안 함 (cond≈uncond)
   - 해결: MLX에서 2회 호출 (cond + uncond) → logits 결합
   - 첫 토큰 1763 (Python 원본 1761과 거의 일치)

5. **t3_cond_embeds pre-compute**
   - T3 conditioning 전체 (spkr_enc + perceiver) 34토큰을 pre-compute
   - `precompute_embeddings.py` 수정 → 11캐릭터 JSON에 `t3_cond_embeds` 추가
   - emotion_adv (감정) 텐서 포함

6. **HiFiGAN Full ONNX export**
   - F0 + SourceModuleHnNSF + Decode 통합 (`hifigan_full.onnx`, 79.6MB)
   - torch.stft를 conv1d 기반 수동 DFT로 우회 (ONNX 호환)
   - 기존 분리 방식(hifigan_f0 + hifigan + Swift ISTFT)의 F0 스케일 문제 해결

7. **속도 최적화**
   - KV Cache warm-up: 캐릭터별 cond 34토큰 미리 계산 → prefill 0.3초 절약
   - CFG prefill only (decode는 cond만) → T3 시간 50% 절약
   - CFM 스텝 조절 (10→5→3→2→1 테스트, 최적: 5스텝)
   - 최종: 짧은 대사 1.5초, 일반 대사 3.5초

8. **UI 개선**
   - 설정창: 사용자 이름 + 호칭 한 줄 배치 (`userName` AppStorage 추가)
   - 설정창: 에이전트창 배경 투명도 슬라이더 (`agentWindowOpacity`)
   - 설정창: GPS 위치 자동 (CoreLocation + 역지오코딩)
   - 빈 파일 삭제: `AgentView.swift`, `RiveAgentView.swift`
   - 팀원 교체 TTS: 캐릭터별 성격 맞는 짧은 인사 11종

9. **앱 연결**
   - `OnDeviceTTSManager`: MLX 서버(9998) 우선 → Chatterbox(9999) 폴백
   - `SpeechManager`: debounce(0.15s), `shortenForTTS`, `speakImmediate`
   - abort 메커니즘: 파일 기반 인터럽트 (`/tmp/mlx_tts_abort`)

#### 실패/미해결 ❌
1. **ONNX CFG 실패**
   - batch=2로 실행은 되지만 cond≈uncond → CFG 효과 없음
   - ONNX export 시 LlamaModel 내부 batch 분리 로직 소실
   - **결론: ONNX 온디바이스 TTS는 포기, MLX로 전환**

2. **CoreML 직접 변환 실패**
   - `torch.diff`, `new_ones`, `fill` 등 coremltools 미지원 op 연쇄
   - transformers 5.2.0이 최신 PyTorch ops 대량 사용
   - HiFiGAN F0, HiFiGAN Decode는 CoreML 변환 성공 (작은 모델)
   - **T3 (LlamaModel 30층) CoreML 변환은 실패**

3. **INT8 양자화 품질 저하**
   - ONNX INT8: 토큰 다양성 급감 (22/31 → 6/21)
   - MLX FP16: 오히려 FP32보다 느림 (캐스팅 오버헤드)
   - **FP32 유지가 최적**

4. **음절 반복 문제**
   - "오늘 텐션 오늘 텐션 한 번" — T3가 문장 중간에서 되풀이
   - 원인: CFG를 prefill에만 적용하고 decode에서 제거 → 집중력 저하
   - 5-gram 반복 감지로 완화했으나 근본 해결 안 됨
   - **해결 방향: decode에 CFG 복원 (속도 2배 느려지지만 품질 향상)**

5. **TTS 겹침/밀림**
   - 싱글스레드 서버라 이전 요청 처리 중 새 요청 대기
   - 파일 기반 abort 구현했으나 타이밍 이슈 잔존
   - abort 파일 잔존으로 정상 요청도 204 반환하는 버그
   - **해결 방향: 비동기 서버 또는 MLX-Swift 네이티브**

6. **shortenForTTS 한계**
   - 15~25자로 자르면 문맥 손실
   - 10자 이상에서 음질 저하 (T3 모델 한계)
   - **해결 방향: 대사 자체를 짧게 기획 (5~10자)**

#### 아키텍처 현재 상태
```
Swift App (SpeechManager)
  ├─ speakImmediate() — 교체 TTS (debounce 없음)
  ├─ speak() — 일반 TTS (debounce 0.15s)
  │   └─ shortenForTTS() — 첫 구절만 추출
  ├─ stopSpeaking() — 전체 취소 + abort 파일
  └─ OnDeviceTTSManager
      ├─ MLX TTS 서버 (port 9998) ← 1순위
      ├─ Chatterbox 서버 (port 9999) ← 2순위
      └─ 음절 WAV 폴백 ← 3순위

MLX TTS 서버 (Python)
  ├─ T3 LlamaModel (MLX GPU, 30층)
  │   ├─ KV Cache warm-up (캐릭터별 cond 34토큰)
  │   ├─ CFG prefill (2회 실행)
  │   ├─ Decode (cond만, KV cache)
  │   └─ Abort 감시 스레드 (/tmp/mlx_tts_abort)
  ├─ S3Gen Encoder (ONNX CPU)
  ├─ S3Gen CFM 5steps (ONNX CPU)
  ├─ HiFiGAN Full (ONNX CPU)
  └─ ISTFT (numpy, periodic Hann)
```

**다음 세션 가이드**:
1. **경로 A 추천**: ONNX 2회 호출 CFG + CoreML EP (가장 빠름)
2. **경로 C 검토**: MLX-Swift (Llama 네이티브 지원, Apple Silicon 최적화)
3. BPE 토크나이저: unicodeScalars 기반 — **완성됨, 그대로 재사용**
4. ISTFT: periodic Hann window — **완성됨, 그대로 재사용**
5. t3_cond_embeds: 34토큰 perceiver 출력 — **완성됨, 그대로 재사용**
6. SpeechManager: ONNX 비활성화 상태, 음절 WAV 폴백으로 소리 나옴

---

#### ⚠️ 미완료 — 다음 작업자가 이어서 할 것

1. **ONNX 세션 로딩을 백그라운드 스레드로 이동** (현재 main thread 경고 수백 개)
   - `ONNXTTSManager.loadOrtSessions()` 내부의 `ORTSession()` 생성이 CoreML EP와 함께 main thread에서 실행됨
   - 해결: `loadAll()` 전체를 `Task.detached(priority: .userInitiated)` 로 감싸거나, `loadOrtSessions()`를 `DispatchQueue.global().async`에서 실행
   - `isReady` 플래그는 세션 로딩 완료 후 설정되므로 race condition 없음

2. **ONNX TTS가 실제로 호출되지 않는 문제**
   - `SpeechManager.speak()` (line 598): `if !useAnimalTTS && ONNXTTSManager.shared.isReady`
   - 현재 `useAnimalTTS = true`로 설정되어 있어서 ONNX 경로가 항상 스킵됨
   - 수정: ONNX ready이면 animalTTS 모드와 무관하게 ONNX 우선 사용
   - 변경할 코드: `if ONNXTTSManager.shared.isReady {` (line 598에서 `!useAnimalTTS &&` 제거)

3. **컴파일 경고 2개**
   - `ONNXTTSManager.swift:320` — `let count` 미사용 → `_ =` 또는 제거
   - `ONNXTTSManager.swift:1162` — `run(resultType:body:)` 리턴값 미사용 → `_ =` 추가

4. **t3_decode.onnx seq=1 에러** (우선순위 낮음)
   - t3_decode는 현재 Swift 코드에서 사용하지 않음 (AR 루프가 t3_prefill 재사용)
   - 나중에 KV cache 기반 decode로 전환할 때 수정 필요

---

---

### 2026-04-05 (최종3+): [Claude Code] 사전 합성 캐시 시스템 완성 + Thinking Character UX

#### ✅ 완료된 작업

**[버그 수정] refHash 정수/부동소수점 불일치 (캐시 항상 미스 문제)**
- 원인: Python `str(mtime)` = `"1775361817.1432633"` vs Swift `"\(mtime)"` 정밀도 다름 → SHA256 불일치 → 캐시 항상 미스
- 수정: 양쪽 모두 초 단위 정수로 통일
  - `SpeechCacheManager.swift:44` → `sha256Prefix8("\(Int(mtime))")`
  - `pregenerate_dialogues.py:73` → `sha256_prefix8(str(int(mtime)))`
- 이후 `pregenerate_dialogues.py` 재실행 (11캐릭터 × ~60개 대사 합성 완료)

**[핵심 버그 수정] MLX TTS 서버 — CFG decode 복원 + Abort 버그 수정 + CoreML EP**
- `/Users/su/Desktop/TTS맨/chatterbox/mlx_tts_server.py`
  - T3 decode 루프에 CFG 적용 (`CFG_DECODE_W=0.3`, cond/uncond 2회 forward → 가중합) → 음절 반복("오늘 텐션 오늘 텐션") 완전 제거
  - Abort 버그 수정: `abort_target_id` 변수 도입 → 해당 요청만 취소, 다음 요청에 영향 없음
  - S3Gen/HiFiGAN ONNX 세션에 `CoreMLExecutionProvider` 적용 (일부 ANE/GPU 가속)
  - 서버 시작 시 잔존 abort 파일 자동 제거

**[신규 파일] SpeechCacheManager.swift**
- 사전 합성 캐시 전담 관리 (`~/Library/Application Support/MyTeam/SpeechCache/`)
- 캐시 키: `{캐릭터명}_{refHash}_{textHash}.wav`
  - `refHash` = SHA256(PrecomputedVoice JSON mtime 정수)[:8] → 음성 파일 교체 시 자동 무효화
  - `textHash` = SHA256(sanitized+shortened 텍스트)[:8] → `{title}` 치환 후 해싱이므로 호칭 변경도 자동 처리
- 런타임 캐시 + 번들 캐시 2단계 조회
- `saveAsync()`: MLX 합성 결과 백그라운드 저장 + 구 refHash 파일 자동 삭제
- `playCached()`: NSSound 즉시 재생 (딜레이 <50ms)

**[신규 파일] pregenerate_dialogues.py**
- `CharacterDialogues.swift` 파싱 (괄호 깊이 기반, 중첩 Swift 배열 처리)
- `{title}` 포함 대사 자동 스킵 (호칭은 수시로 바뀌므로 사전 합성 무의미)
- 11캐릭터 × ~60개 고정 대사 → MLX TTS 서버로 합성 → `SpeechCache/` 저장
- 실행: `cd ~/Desktop/TTS맨/chatterbox && .venv/bin/python3 pregenerate_dialogues.py`

**[UX 기능] SpeechManager.swift — 캐시 통합 + onAudioStarted 콜백**
- `executeTTS()` 0순위: `SpeechCacheManager.cachedURL()` → NSSound 즉시 재생 (<50ms)
- `onAudioStarted: (() -> Void)?` 프로퍼티 추가 → 오디오 재생 시작 순간 메인스레드 콜백
  - 캐시 히트: `sound.play()` 직전 호출
  - MLX 서버 경로: `onWavDataReady` 시점 (WAV 수신 → 재생 직전) 호출
- `isCached(rawText:characterName:) -> Bool` public 메서드 추가 (AgentChatView UX 분기용)
- `onWavDataReady` 콜백: MLX 합성 WAV를 `SpeechCacheManager.saveAsync()`로 자동 캐시 저장

**[UX 기능] "Thinking Character" — 텍스트·음성 동기화 (AgentChatView.swift)**
- AI 응답 수신 후 캐시 히트 여부로 분기:
  - **캐시 히트 (빠른 경로)**: 텍스트 즉시 표시 + 바로 재생 (thinking 생략)
  - **캐시 미스 (느린 경로)**: typing... 인디케이터 유지 → `onAudioStarted` 콜백 시 텍스트 표시 + 음성 동시 해제
- 기존 청크별 타이핑 딜레이 루프 제거 → MLX 합성 시간이 자연스러운 "생각하는 시간"으로 대체
- 무음 모드: TTS 없이 텍스트 즉시 표시

**수정 파일:**
- `MyTeam/MyTeam/SpeechManager.swift`
- `MyTeam/MyTeam/AgentChatView.swift`
- `MyTeam/MyTeam/SpeechCacheManager.swift` (신규)
- `/Users/su/Desktop/TTS맨/chatterbox/mlx_tts_server.py`
- `/Users/su/Desktop/TTS맨/chatterbox/pregenerate_dialogues.py` (신규)

**빌드**: `** BUILD SUCCEEDED **` 확인

---

### [2026-04-06] [Antigravity]
- **TTS 엔진 순차 스트리밍 플랜 감사 및 치명적 버그 수정**
  - **버그 1 (Mac mini 무음)**: `speakChunk`의 이펙트 재생 경로에 `AVAudioEngine + AVAudioPlayerNode`가 도입되어 있었으나, 이미 Mac mini(M4)에서 해당 엔진이 무음으로 동작하는 문제가 알려져 있었음.
  - **버그 2 (오디오 겹침/데드락)**: `player.scheduleFile(at: nil, completionHandler:)`의 핸들러가 재생 완료 시점이 아닌 "버퍼 스케줄 직후"에 즉시 호출되어, `withCheckedContinuation`이 즉시 `resume`되고 모든 청크가 동시에 음성 출력되는 현상 발생.
  - **해결 완료**: `playWithEffects`를 **NSSound + duration 기반 지연 대기** 로직으로 전면 교체. (`AVAudioEngine` 완전 제거)
  - **음질 타협**: NSSound는 피치(pitch) 조절을 지원하지 않아 동물 TTS 모드 시 볼륨만 매핑하고 이펙트는 포기함. 고품질 MLX 음성만으로도 충분한 개성이 살아난다고 판단.
  - **죽은 코드 정리**: `executeTTS`의 `if false /* CoreMLTTSManager /*` 블록과 구식 음절 WAV 폴백 호출 찌꺼기 완전 제거 (TTS 경로를 캐시 → MLX 서버 → 무음으로 명료화).

- **TASK.md 업데이트: 앱스토어 배포 기준의 TTS 고도화 로드맵 작성**
  - **프로젝트 목표 명시**: 사용자 목표인 "애플 제품 같은 완성도, 앱스토어 배포" 기준에 맞춰 Python 서버가 구조적 블로커임을 안내.
  - **Phase 1**: 캐시 극대화 (AI 커먼 리액션 사전 합성, 번들 내포 포함).
  - **Phase 2**: **MLX-Swift 네이티브 전환 (필수)**. Python HTTP API를 Swift 네이티브 코드로 교체해 앱스토어 심사 통과 보장.
  - **Phase 3**: 초경량 한국어 모델 교체 검토 (VITS2-Korean 등).
  
**수정 파일:**
- `MyTeam/MyTeam/SpeechManager.swift`
- `TASK.md`

---

### [2026-04-06] [Antigravity]
- **Mac App Store 샌드박스 완벽 대응 및 보안 강화 (Priority 1 완료)**
  - **절대경로 하드코딩 제거**: `SpeechManager.swift`, `ONNXTTSManager.swift` 코드 내부의 `/Users/su/Desktop/...` 및 `~/` 계열 절대경로들을 모두 찾아 제거. 샌드박스가 허용하는 `FileManager.default.urls(for: .applicationSupportDirectory)`로 폴백되도록 리팩토링.
  - **API 키 Keychain 기반 암호화 적용**: `SettingsView.swift`와 `AIService.swift`가 `UserDefaults`(@AppStorage)를 통해 API 키를 평문으로 입출력하던 보안 취약점을 해결. 자체 `KeychainManager`를 도입하여 암호화 저장소에 보관하도록 구조 개선 완료. `MyTeamApp.swift` 시작 시 자동 마이그레이션 적용.
- **수정 파일 목록**
  - `MyTeam/MyTeam/SpeechManager.swift`
  - `MyTeam/MyTeam/ONNXTTSManager.swift`
  - `MyTeam/MyTeam/SettingsView.swift`
  - `MyTeam/MyTeam/AIService.swift`
  - `MyTeam/MyTeam/KeychainManager.swift`
  - `MyTeam/MyTeam/MyTeamApp.swift`

---

## 📝 다음 작업 시 이 파일에 아래 형식으로 추가

```markdown
### [YYYY-MM-DD] [Antigravity / Claude Code]
- 작업한 내용 요약
- 수정 파일 목록
```

---

### [2026-04-07] [Antigravity]
- **[우선순위 2] SpeechManager Massive Class 해체 — 아키텍처 전면 리팩토링 완료**

  #### 배경
  896줄의 SpeechManager 하나가 STT 권한 요청, 마이크 엔진, 오디오 재생(NSSound/AVAudioPlayer), 동물TTS 음절 파싱, WAV 포맷 변환, MLX/Chatterbox 분기까지 모든 것을 담당하던 Massive Class 상태였음. 향후 MLX-Swift 네이티브 전환, 피치/속도 이펙트 복구가 불가능한 구조.

  #### 신규 생성 파일 (단일 책임 원칙 적용)
  - **`AudioPlayable.swift`** — 재생 추상화 프로토콜 + `PlaybackCommand` 구조체 (pitch/rate/volume 탑재). `AVAudioEnginePlaybackService`로의 갈아끼움 경로를 DI 형태로 명시.
  - **`NSSoundPlaybackService.swift`** — 현재 과도기 구현체. pitch/rate 미지원 명시, AVAudioEngine 전환 TODO 주석 포함.
  - **`AudioPlaybackService.swift`** — `actor`로 선언된 Thread-safe State Machine.
    - **Actor Reentrancy 방어**: 상태 변경(`.playing`)을 await 이전 동기적으로 확정 후 I/O.
    - **AsyncStream 소비자 패턴**: 큐에 데이터 주입 즉시 재생 시작 (Early-Bird Streaming).
  - **`PermissionsManager.swift`** — 마이크/음성인식 TCC 권한 전담 actor. `AudioCaptureService`에서 권한 코드 완전 분리.
  - **`AudioCaptureService.swift`** — 순수 STT 버퍼링만 담당.
    - Barge-in 지원: 재생 중에도 마이크 강제 정지 없음.
    - 탭 콜백 내 메인 스레드 블로킹 제거.
    - `setVoiceProcessingEnabled(true)` TODO 주석 삽입 — AVAudioEngine 전환 시 활성화하면 하드웨어 AEC가 켜져 무전기식 에코 방지 로직 자체가 불필요해짐.
  - **`AnimalTTSService.swift`** — "배열 반환" 금지, "스트림 주입(Stream Injection)" 방식.
    - 음절 하나 파싱 즉시 `AudioPlaybackService.enqueue()` 주입 → 딜레이 0.
    - `PlaybackCommand`에 캐릭터별 pitch/rate/volume 탑재하여 배출.

  #### 수정 파일
  - **`SpeechManager.swift`** — 896줄 → 약 230줄의 순수 오케스트레이터로 다이어트.
    - Barge-in 감지(AI 재생 중 사용자 끼어들기 → 재생 즉시 중단).
    - VPIO(Voice Processing I/O) TODO 주석 명시.
    - 모든 기존 공개 API(`speak`, `speakChunk`, `speakImmediate`, `prefetchChunk`, `stopSpeaking`, `requestAuthorization` 등) 100% 호환 유지.

  #### 기술 부채 명시 (추후 해소 예정)
  - `NSSoundPlaybackService`는 pitch/rate 미지원 → **`AVAudioEnginePlaybackService`** 전환 필수 (AVAudioUnitTimePitch, AVAudioUnitVarispeed 노드 연결).
  - `AudioCaptureService` 내 `setVoiceProcessingEnabled(true)` 주석 해제로 하드웨어 AEC 활성화 → Barge-in 감지 코드 제거 가능.

- **수정 파일 목록**
  - `MyTeam/MyTeam/AudioPlayable.swift` (신규)
  - `MyTeam/MyTeam/NSSoundPlaybackService.swift` (신규)
  - `MyTeam/MyTeam/AudioPlaybackService.swift` (신규)
  - `MyTeam/MyTeam/PermissionsManager.swift` (신규)
  - `MyTeam/MyTeam/AudioCaptureService.swift` (신규)
  - `MyTeam/MyTeam/AnimalTTSService.swift` (신규)
  - `MyTeam/MyTeam/SpeechManager.swift` (전면 교체)

---

### [2026-04-07] [Antigravity]
- **True Real-Time AVAudioEngine 리팩토링 및 안정화 완료**
  - **레거시 제거**: `NSSound` 기반의 땜빵식 재생과 WAV 파일 I/O(디스크 쓰기/읽기)를 완전히 제거하고 `AVAudioEngine` 기반의 순수 인메모리 PCM 파이프라인으로 전환.
  - **세션 멀티플렉싱**: `WebSocketStreamManager` (Actor)를 도입하여 `stream_id` 기반의 제어 프레임을 처리하고, 여러 캐릭터의 오디오 스트림이 섞이지 않도록 세션을 완벽히 격리.
  - **동적 리샘플링 및 노이즈 방어**:
    - `AVAudioConverter` 재사용 풀링을 통해 CPU 오버헤드 최소화.
    - 100ms 미만의 **Jitter Pre-buffering** 워터마크를 도입하여 네트워크 지연 시 발생하는 팝핑/찌직 노이즈 원천 차단.
    - 버퍼 언더런 시 Silence Padding 및 세션 종료 시 **Node Detach (Teardown)** 로직을 추가하여 메모리 누수 및 엔진 붕괴 방지.
  - **Actor 기반 메모리 캐싱**: `AnimalTTSCacheManager` (Actor)를 분리하여 수백 개의 음절 WAV 파일을 앱 구동 시 비동기로 PCM Data로 변환하여 메모리에 적재. 재생 시 I/O 지연 0초 달성.
  - **샌드박스 안정성**: 절대경로 하드코딩 및 임시 파일 생성을 배제하여 Mac App Store 심사 기준 충족.

- **수정 파일 목록**
  - `MyTeam/MyTeam/AudioPlaybackService.swift` (전면 재작성)
  - `MyTeam/MyTeam/WebSocketStreamManager.swift` (신규 작성)
  - `MyTeam/MyTeam/WebSocketClient.swift` (JSON 파싱/바이너리 분리 로직 수정)
  - `MyTeam/MyTeam/AnimalTTSService.swift` (Actor 캐시 연동 및 Pre-loading 도입)
  - `MyTeam/MyTeam/SpeechManager.swift` (URL 제거 및 PCM 주입 방식으로 연동 수정)
  - `MyTeam/MyTeam/AudioPlayable.swift` (Protocol 명세 업데이트)

### [2026-04-07] [Antigravity] (오후 세션)
- **Perfect Lip-Sync 아키텍처 (재생 시작 시 텍스트 팝업) 구현 완료**
  - **오디오 엔진 후킹**: `AudioPlaybackService` 내에서 버퍼가 큐에 쌓여 실제 스피커로 첫 소리가 흘러나오기 시작하는 찰나의 시점(`playerNode.play()` 직후 첫 버퍼)에 `onPlaybackStarted` 이벤트를 발화하는 초정밀 립싱크 배관 구축.
  - **비동기 타이밍 버그 해결**: 기존에 SSE 모델 응답 청크가 모이자마자 UI 스레드에 텍스트를 던지던 방식(TTS 버퍼 대기로 인해 텍스트-싱크 극심한 불일치 발생)을 폐기. `textPayload`와 `onPlaybackStarted` 콜백을 큐에 심어 보내는 방식으로 변경.
  - **UI 종속성 파괴 극의 (`AgentChatView.swift` 리팩토링)**: 
    - `AgentChatView` 내부의 난해했던 텍스트 분리 정규식(`splitIntoMessageChunks`, `splitSentences`) 로직 및 인위적인 대기 타이머 루프 전면 제거 (약 70줄 감량).
    - 순환 참조 없이 `SpeechManager.shared.processRealtimeSSEStream(...)` 15줄짜리 클로저로 텍스트 출력 권한을 100% 오디오 엔진의 타이밍에 위임.
  - **컴파일 종속성 복구 (Exit 0)**: `TeamOrchestrator`, `IntentRouter`, `SettingsView` 등 `AIService.swift`의 구버전 시그니처에 의존하던 모든 에러 격추 완료. Swift 6 Concurrency Issue 방어.

- **수정 파일 목록**
  - `MyTeam/MyTeam/AudioPlayable.swift` (PlaybackCommand Payload 추가)
  - `MyTeam/MyTeam/AudioPlaybackService.swift` (scheduleBuffer 후킹 완료)
  - `MyTeam/MyTeam/SpeechManager.swift` (SSE 콜백 배관 재작성)
  - `MyTeam/MyTeam/MLXInferenceService.swift` (취소 콜백 명시)
  - `MyTeam/MyTeam/AgentChatView.swift` (UI 동기식 루프 삭제)
  - `MyTeam/MyTeam/AIService.swift`, `MyTeam/MyTeam/TeamOrchestrator.swift`, `MyTeam/MyTeam/IntentRouter.swift`, `MyTeam/MyTeam/SettingsView.swift`, `MyTeam/MyTeam/AgentWindowManager.swift` (호환성 버그 패치)

---

### [2026-04-07] [Antigravity] (야간 세션 - Phase 6 완료)
- **온디바이스 네이티브 인프라 보안 및 메모리 방어선 완수**
  - **군사급 보안 인프라**: `Security` 프레임워크 기반 `KeychainManager.swift` 구축 완료. API 키를 안전하게 암호화 보관.
  - **Settings UI**: macOS 네이티브 `TabView` 기반의 `SettingsView.swift` 구현 및 `openRouterModelId` 동적 스위칭 지원.
  - **100% Swift 네이티브 BPE Tokenizer**: `BPETokenizer.swift` 구축. Hangul Jamo 분해(`UnicodeScalar` 연산) 및 `grapheme_mtl` 병합 논리 적용.
  - **메모리 릭 원천 방어**: `MLXInferenceService.swift`의 AsyncStream 핫 루프 통과 시점(MLX 텐서 → CoreML 캐스팅 등 연산 집약 부위)에 `@autoreleasepool` 강제 삽입.
  - **모듈 의존성 패치**: `import onnxruntime`을 `import OnnxRuntimeSwift`로 원복하여 Swift Package Manager 의존성 회복.

- **수정/생성 파일 목록**
  - `MyTeam/MyTeam/KeychainManager.swift` (신규)
  - `MyTeam/MyTeam/SettingsView.swift` (신규)
  - `MyTeam/MyTeam/BPETokenizer.swift` (신규)
  - `MyTeam/MyTeam/MLXInferenceService.swift`
  - `MyTeam/MyTeam/AIService.swift`

### [2026-04-08] [Claude Code] (최종 교정 — 글로벌 테마 동기화 + 모델명 동적 라우팅)
- **SettingsView 테마 결함 수술 + OpenAI 모델명 하드코딩 파괴**
  
  - **결함 1: OS 다크모드 강제 종속 제거**
    - ❌ 이전: `Color(red: 0.12, green: 0.12, blue: 0.12)` 하드코딩으로 OS 설정에 강제 종속
    - ✅ 수술: `manager.isDarkMode` (AgentWindowManager의 글로벌 테마 상태) 구독
    - ✅ 팀 협업창 테마 토글과 설정창 배경색 **100% 실시간 동기화**
    - ✅ 사용자가 팀 협업창에서 테마 버튼을 누르면 설정창도 즉시 변경
  
  - **결함 2: OpenAI 모델명 하드코딩 파괴**
    - ❌ 이전: `openAIStream()` 내부에 `let model = "gpt-4o"` 대못 박기
    - ✅ 수술: `@AppStorage("openAIModelId")` 필드 추가 → SettingsView의 API 설정 탭에서 사용자가 직접 입력
    - ✅ `openAIStream(modelId: String)` 메서드 시그니처 변경 → 동적 주입
    - ✅ `getResponseStream()`에서 UserDefaults 읽어 modelId 전달
    - ✅ API 바디에 동적으로 주입: `"model": modelId`

  - **구현 상세**:
    - SettingsView Tab 2 (API 설정)의 OpenAI 섹션에 "Model ID" TextField 추가
    - openAIModelId 기본값: "gpt-4o"
    - AIService.swift: `let modelId = UserDefaults.standard.string(forKey: "openAIModelId") ?? "gpt-4o"` → openAIStream() 전달
    - 콘솔 로그도 동적: `"OpenAI SSE 채널 오픈 (model: \(modelId), agent: \(agentID))"`

- **이전 수정: SettingsView 레이아웃 완전 재설계 + OpenAI 통합 + 동물의숲 TTS**
  
  - **윈도우 크기 및 레이아웃**:
    - 460×600 → **380×420** (압축)
    - GPS 버튼 좌측 배치 (입력칸 앞)
    - 팀 이름을 한 줄로 통합 (레이블 + TextField + ColorPicker)
    - X 버튼 크기 증대 (title2), 탭 헤더 라인에 정렬
    - Dark/Light 모드 자동 대응
  
  - **탭 구조 3가지**:
    1. **사용자 설정** (이전: 사용자 & 팀)
       - 호칭, 위치 (GPS 버튼), 팀 이름, 팀 색상
       - **新: "동물의숲 TTS" 토글** (ON: 피치/속도 조정 / OFF: 기본 TTS)
       - 에이전트창 투명도 Slider
    
    2. **API 설정** (동일)
       - Gemini / OpenAI / Claude / OpenRouter
       - 선택한 제공자만 키 입력란 표시
       - API 키 검증 버튼
    
    3. **위치별 라우팅** (신규, 11명 → **4개 위치**)
       - 좌측(Team 1), 우측상단(Team 2), 우측중단(Team 3), 우측하단(Team 4)
       - 각 위치별 LLM 뇌 선택 (Gemini/OpenAI/Claude/OpenRouter)
       - OpenRouter 선택 시 Model ID 입력란 동적 표시
  
  - **상태 관리**:
    - `@AppStorage("animalTTSEnabled")` — 동물의숲 TTS 토글
    - `@AppStorage("llmProvider_pos_N")` — 위치별 LLM 라우팅 (N=0~3)
    - `@AppStorage("openRouterModelId_pos_N")` — 위치별 OpenRouter 모델 ID
  
  - **APIService.swift 통합**:
    - `openAIStream()` 실제 구현 추가 (gpt-4o, SSE 파싱 OpenAI 포맷)
    - switch provider에 `.openAI` 케이스 exhaustive 완성

- **수정/생성 파일**
  - `MyTeam/MyTeam/SettingsView.swift` (완전 재작성, 380×420)
  - `MyTeam/MyTeam/AgentConfig.swift` (LLMProvider에 openAI 추가)
  - `MyTeam/MyTeam/AIService.swift` (openAIStream() 구현, switch exhaustive 해결)

## 📝 다음 작업 시 이 파일에 아래 형식으로 추가

```markdown
### [YYYY-MM-DD] [Antigravity / Claude Code]
- 작업한 내용 요약
- 수정 파일 목록
```
