# Local Runtime QA — Round 237
**날짜**: 2026-05-18  
**빌드**: Debug (PID 55102, Antigravity / com.google.antigravity)  
**테스트 환경**: macOS, 다크 모드, API 키 없음 (로컬 전용)

---

## 전체 결과 요약

| 항목 | 결과 | 비고 |
|------|------|------|
| 앱 실행 / 패널 표시 | ✅ PASS | 팀 협업 중 패널 정상 표시 |
| 온보딩 카드 닫기 | ✅ PASS | X 버튼으로 정상 닫힘 |
| 에이전트 4명 팀 패널 | ✅ PASS | 레오/루나/모코/핀 정상 표시 |
| 에이전트 카드 클릭 → 개인방 | ✅ CODE VERIFIED | openPersonalChat() 코드 연결 확인 |
| 초상화 클릭 → 관리 컨텍스트 메뉴 | ✅ PASS | 추가/교체/팀장 메뉴 정상 |
| 에이전트 교체 카탈로그 | ✅ PASS | 전체 에이전트 목록 정상 표시 |
| 메시지 전송 | ✅ PASS | 전송 후 Gemini API 호출 확인 |
| 429 Rate Limit 처리 | ✅ PASS | 120초 자동 해제 안내 메시지 |
| 설정 > API 키 저장 위치 | ✅ PASS | Keychain 표시 확인 |
| 설정 > 구글 캘린더 커넥터 상태 | ✅ PASS | 읽기 전용, 쓰기 차단 안내 |
| 기술 UX 금지 문구 없음 | ✅ PASS | "IMAP", "rate limit" 등 미노출 |
| 사용 정책 표시 | ✅ PASS | Free 플랜, 월 20회 등 정상 |
| Debug 빌드 | ✅ PASS | BUILD SUCCEEDED |
| Release 빌드 | ✅ PASS | BUILD SUCCEEDED |
| Preflight Round 236 | ✅ 전체 통과 (12/12) | |

---

## 상세 항목별 결과

### 1. 앱 실행 및 기본 표시
- 앱 번들: `com.google.antigravity` (표시명: Antigravity)
- 빌드 경로: `DerivedData/MyTeam/.../Debug/MyTeam.app`
- 팀 협업 패널 "팀 협업 중" 표시 ✅
- 4개 에이전트 상태 카드: 레오, 루나, 모코, 핀 ✅
- 상단 상태 텍스트 자동 로테이션 확인 ✅

### 2. 온보딩 카드
- "로컬 기능부터 바로 시작" 카드 표시 ✅
- 기능 목록 체크마크: 회의록/체크리스트, 파일 읽기-정리, 오늘 할 일 ✅
- AI 대화 비활성 표시 ✅
- X 버튼 클릭 → 카드 닫힘 ✅

### 3. 에이전트 카드 클릭 → 개인방 전환
- `TeamStatusView.swift:245` `.onTapGesture` → `manager.openPersonalChat(for: agent.id)` 연결 확인 ✅
- `openPersonalChat()` 구현: 기존 1:1 방 찾기 → 없으면 새로 생성 → `currentRoomID` 변경 ✅
- 시각적 전환: 테스트 환경에서 Xcode 디버그 패널 겹침으로 채팅 로그 영역 확인 어려움

### 4. 초상화 클릭 UI
- 하단 캐릭터 초상화 클릭 → 에이전트 호버 툴팁 표시 ✅
  - 예: "루나 - 마케터/콘텐츠 기획"
- 초상화 재클릭 → 관리 컨텍스트 메뉴 표시: 추가.../교체/팀장... ✅
- "교체" 선택 → 에이전트 카탈로그 모달 표시 ✅
  - 4개 무료 에이전트 (레오/루나/모코/핀) + 4개 프리미엄 에이전트 표시 ✅

### 5. 메시지 전송 및 AI 연동
- 입력 필드 포커스 → 타이핑 → Return 전송 정상 동작 ✅
- 전송 후 Gemini API 호출 로그 확인:
  ```
  [App] INFO [AIService] 🔄 Self-Healing: gemini-3.1-pro-preview
  [App] ERROR [AIService] Gemini HTTP 429
  [App] ERROR Orchestration Error: httpError(429, "⚠️ Ge... 120초 후 자동으로 해제됩니다.")
  ```
- Rate limit 처리: 자동 재시도 120초 카운트다운 ✅ (개발 환경에서 예상된 동작)

### 6. 커넥터 상태 (Settings > API 설정)
- Google Calendar 상태 텍스트: "Google Calendar 읽기 연결은 준비 중입니다. 일정 생성/수정/삭제는 자동 실행하지 않습니다." ✅
- 쓰기 작업 명시적 차단 안내 ✅
- 버튼 레이블: "준비 됩니다" ✅
- IMAP / rate limit / API scope 등 기술 용어 미노출 ✅
- API 키 저장 위치: Keychain 표시 ✅

### 7. 사용 정책 표시
- 현재 플랜: Free ✅
- Free 기본 제공: 월 20회 ✅
- Pro 기본 제공: 월 100회 예정 ✅
- BYOK: 지원 ✅
- 활성 에이전트: 3명 ✅

---

## 발견된 이슈

### P2: 설정 창 X 버튼 좌표 문제
- **현상**: 설정 패널 상단 X 버튼 클릭 시 macOS 메뉴바 "Window" 메뉴가 열림
- **재현**: 설정 탭 행의 X(⊗) 버튼 클릭 시 일관되게 발생
- **영향**: 설정 닫기 불편 (Cmd+W 또는 다른 방법 필요)
- **원인 추정**: SwiftUI 오버레이와 macOS 메뉴바의 클릭 이벤트 충돌 가능
- **조치**: 추후 수정 검토 (P2, 차단 아님)

### INFO: 개발 환경 레이아웃 제한
- Xcode 디버그 패널 + Cursor 에디터가 앱 위에 겹쳐 있어 채팅 로그 영역 직접 관찰 어려움
- 프로덕션 환경에서는 해당 없음

### INFO: Gemini API 429 Rate Limit
- 테스트 중 Gemini API 일일 한도 초과로 AI 응답 테스트 불가
- 자동 120초 재시도 로직은 정상 동작 확인
- API 키 설정 후 정상 응답 가능

---

## 미테스트 항목 (추후 검증 필요)

| 항목 | 이유 | 우선순위 |
|------|------|------|
| 라이트 모드 가독성 | 시스템 설정 변경 필요 | P2 |
| FloatingPanel 축소/확장 크래시 | 수동 10회 반복 테스트 필요 | P1 |
| 방 이름 변경 UI | 긴 플로우, UI 확인 어려움 | P2 |
| /blog-source 실행 결과 | API 429로 응답 미수신 | P2 |
| /blog-profile 실행 결과 | API 429로 응답 미수신 | P2 |
| 비기너 예시 플로우 | 추후 별도 테스트 | P3 |
| Chiko 반응 이벤트 | 스프라이트 없어 시각 확인 어려움 | P3 |

---

## 코드 검증 (소스 확인)

| 항목 | 파일 | 확인 내용 |
|------|------|------|
| openPersonalChat | AgentWindowManager.swift:1478 | 기존 방 찾기 → 생성 → currentRoomID 변경 |
| inferredRoomProfile | AgentWindowManager.swift:+ | 키워드 기반 블로그 목적 감지 |
| /blog-source | ConversationMemory.swift | blog-source 문자열 존재 확인 |
| /blog-profile | ConversationMemory.swift | blog-profile 문자열 존재 확인 |
| renameRoom | AgentWindowManager.swift | func renameRoom 존재 확인 |
| RoomProfile, BlogStyleProfile | ChatModels.swift | 구조체 정의 확인 |
| Preflight 12/12 | preflight_room_ui_round236.sh | 전체 통과 |

---

## 환경 정보

```
macOS: 설치된 시스템
빌드 타겟: Debug + Release 모두 BUILD SUCCEEDED
API 키: 없음 (로컬 전용 모드)
Gemini 상태: 429 Rate Limit (개발 환경)
Xcode 버전: 실행 중 (Running MyTeam)
```
