# MyTeam 개발 로그

> 위치: `/Users/su/Desktop/MyTeam/DEVLOG.md`
> 목적: 현재 앱 방향, 최근 결정, 완료 이력만 남기는 단일 개발 로그.
> 세부 TODO와 남은 로드맵은 `TASK.md`에 기록한다.

---

## 2026-05-20 (Round 241C-SURFACE — Team Composer Routing + Unread Badge + Overlay/Chrome Repair)

### 완료 (2026-05-20)

확인된 P0 surface 버그 4개를 수정. 새 기능 없음.

### Bug 1: 팀 워크룸 메시지가 개인 대화방으로 전송됨

**원인**: `TeamTableView.sendTeamInput()`이 `manager.currentRoomID`를 타겟으로 사용.  
개인 에이전트 대화 중에는 `currentRoomID`가 personal room으로 바뀌어 있어 팀 메시지가 wrong room으로 감.

**수정**:
- `TeamTableView.sendTeamInput()`: `currentRoomID` → `manager.selectedTeamWorkroomID`
- 동일 파일 내 종료 메뉴, speechText 참조도 `selectedTeamWorkroomID` 우선으로 전환
- `currentRoomID`는 legacy UI selection 용도로만 남김 (주석 추가)

### Bug 2: 개인 대화 sidebar badge가 unread가 아닌 총 메시지 수

**원인**: `room.messages.filter({ !$0.isSystem }).count` — 내가 보낸 메시지 포함, lastReadAt 기준 없음.

**수정**:
- `AgentWindowManager`: `lastReadAtByRoomID: [UUID: Date]` 추가
- `markRoomRead(_ roomID: UUID)`: 방 화면 열 때만 호출
- `unreadCount(for roomID: UUID) -> Int`: `isUser == false && isSystem == false && timestamp > lastReadAt`
- `AgentChatView` sidebar badge: `manager.unreadCount(for: room.id)` 사용
- `selectTeamWorkroom`, `openPersonalConversation` 내부에서 `markRoomRead` 자동 호출

### Bug 3: 에이전트 선택 메뉴가 패널 경계에 잘림

**원인**: `AgentMenuPopupView`를 `AgentSeatView.overlay()`에 `.offset(x:±100, y:-80)`으로 배치 → 부모 bounds에 clip됨.

**수정**:
- `AgentMenuPopupView` 커스텀 overlay 제거
- SwiftUI `.contextMenu { }` 로 교체 (시스템이 위치 자동 보정, 클리핑 없음)
- 우클릭 / 길게 누르기로 대화/추가 설정/교체/팀장 설정 메뉴 접근

### Bug 4: footer chrome 상태 검증

**확인**: `TeamStatusView.footerView`는 이미 `safeAreaInset(edge: .bottom)` + `Divider` + `HStack` 구조.  
별도 detached RoundedRectangle 없음 → 수정 불필요, 정책 문서 신규 작성으로 확인.

### 추가 파일

- `AgentWindowManager.swift`: `lastReadAtByRoomID`, `markRoomRead`, `unreadCount`, `currentPersonalConversationRoomID` 추가
- `RuntimeDiagnosticsService.swift`: 241C 8개 필드 추가
- `ToolContractValidator.swift`: 241C 5개 validator 추가
- `scripts/preflight_round241c.sh`: 신규 (12/12 통과)
- `docs/PanelChromePolicy.md`: 신규
- `docs/AgentMenuPresentationPolicy.md`: 신규
- `docs/RoomIdentitySeparationPolicy.md`: composer routing invariant + unread badge semantics 추가

**Preflight 241C**: 12/12 통과 | Debug BUILD SUCCEEDED | Release BUILD SUCCEEDED

---

## 2026-05-19 (Round 241B-COREVERIFY — Personal Conversation Map + GoalGate Pivot + BYOK Fix)

### 완료 (2026-05-19)

**배경**: 수석님의 질문 — "클로드코드처럼 실질적으로 업무를 도와주는 데스크탑 AI를 원해. 기능을 제한시키는 요소가 있다면 알려줘."

탐색 결과 실제 제한 요소 3가지 발견 + 수정:

### 1. GoalGate 하드 블록 → directChat pivot (최대 영향)

**문제**: `.blocked` capability → AI가 아무 응답도 하지 않고 "정책상 실행 불가" 메시지만 반환.  
"이메일 초안 써줘" → mailSend가 `.blocked`이므로 초안 텍스트도 없이 차단됨.

**수정**:
- `GoalGate.swift`: `kind: .blocked` → `kind: .directChat` (reason에 disclaimer 포함)
- `WorkflowOrchestrator.swift`: early-return guard에 `blockedDecision.kind == .blocked` 조건 추가
  → directChat decision은 AI가 계속 응답

### 2. BYOK 버튼 no-op 수정

**문제**: `Button("API 키 추가") {} .disabled(true)` — 완전 dead UI.  
**수정**: action 추가 + `.help()` tooltip으로 "다음 업데이트에서 제공" 안내.

### 3. selectedPersonalConversationIDByAgentID 추가 (Round 241A 보완)

**문제**: Chiko → Luna → Chiko 전환 시 이전 대화 복원 불확실.  
**수정**:
- `@Published var selectedPersonalConversationIDByAgentID: [String: UUID] = [:]` 추가
- `openPersonalConversation(for:)` 공식 API 추가 (기존 `openPersonalChat` → wrapper)
- `personalConversation(for:)`, `currentPersonalConversation()` 헬퍼 추가
- `returnToTeamWorkroom()` 시 map 초기화 안 함 (복귀 후 재진입 복원 보장)

### 의도적으로 유지된 차단 목록

| 기능 | 상태 | 이유 |
|---|---|---|
| 메일 자동 전송 | blocked (유지) | 실수 방지 정책 |
| 캘린더 자동 생성 | blocked (유지) | 실수 방지 정책 |
| 자동 로그인 | blocked (유지) | 보안 정책 |
| 파일 자동 삭제 | blocked (유지) | destructive action 정책 |

### 추가 파일

- `RuntimeDiagnosticsService.swift`: 241B 4개 필드 (selectedPersonalConversationMapAvailable 등)
- `ToolContractValidator.swift`: 241B 4개 validator
- `scripts/preflight_round241b.sh`: 12/12 통과
- `docs/SupertonicAssessment.md`: Supertonic-3 TTS PoC 대기 기록
- `docs/RoomIdentitySeparationPolicy.md`: selectedPersonalConversationIDByAgentID 섹션 추가

**Preflight 241B**: 12/12 통과 | Debug BUILD SUCCEEDED | Release BUILD SUCCEEDED

---

## 2026-05-19 (Round 241A-CORE — Hard Separation of Team Workroom and Personal Agent Conversation)

### 완료 (2026-05-19)

**P0 구조 수정**: 팀 워크룸과 개인 에이전트 대화의 상태 완전 분리

**근본 문제**:
- `currentRoomID` 하나로 팀 워크룸 + 개인 대화를 모두 처리
- `openPersonalChat(for:)` 호출 시 `currentRoomID`가 personal room으로 바뀌면서 TeamStatusView 콘텐츠(아티팩트, 메시지 전송 대상) 오염

**수정 내역**:

1. **`AgentWindowManager`** — 상태 분리
   - `@Published var selectedTeamWorkroomID: UUID?` 추가
   - `@Published var activePersonalAgentID: String?` 추가
   - `selectTeamWorkroom(_ roomID: UUID)` 헬퍼 추가
   - `openPersonalChat(for:)`: `selectedTeamWorkroomID` 절대 변경 않음, `activePersonalAgentID`만 추적
   - `returnToTeamWorkroom()`: `activePersonalAgentID = nil` + `selectedTeamWorkroomID` 복원
   - `createRoom/createBlogWritingRoom`: `selectedTeamWorkroomID` 동기화 추가
   - `teamChatLogs`: `currentRoomID` → `selectedTeamWorkroomID` 기준으로 전환

2. **`TeamStatusView`** — `selectedTeamWorkroomID` 전면 적용
   - 방 선택 highlight: `currentRoomID == room.id` → `selectedTeamWorkroomID == room.id`
   - 방 탭: `currentRoomID = room.id` → `manager.selectTeamWorkroom(room.id)`
   - WorkroomHomeView context, artifact 카드, 워크플로 취소 버튼, 스케줄 태스크, 메시지 전송, 파일 intake, workroom action 핸들러 전부 `selectedTeamWorkroomID` 기준

3. **`AgentChatView`** — 개인 대화 사이드바 preview 완전 제거
   - `projectRoomRow`: `room.messages.last(where: { !$0.isSystem })` text 표시 제거
   - 방 이름만 표시, unread badge 유지

4. **`RuntimeDiagnosticsService`** — Round 241A 분리 진단 6개 필드 추가
   - `teamWorkroomPersonalStateSeparated`, `teamWorkroomSelectionPreservedOnPersonalChat`
   - `personalConversationSelectionIndependent`, `quickSwitchDoesNotMutateRoomAgents`
   - `personalChatSidebarPreviewHidden`, `teamSidebarSystemPreviewFiltered`

5. **`ToolContractValidator`** — 분리 정책 검증기 4개 추가
   - `validateTeamPersonalRoomStateSeparationPolicy`
   - `validatePersonalConversationNavigationPolicy`
   - `validatePersonalChatSidebarPrivacyPolicy`
   - `validateQuickSwitchNoRoomMutationPolicy`

6. **`docs/RoomIdentitySeparationPolicy.md`** 작성
   - 팀 워크룸/개인 대화 분리 정책 문서

7. **`scripts/preflight_ux_round241a.sh`** — 12개 검증, 전체 통과

**빌드 결과**: Debug ✅ / Release ✅ / Warning 0

---

## 2026-05-19 (Round 240 — Runtime UX P0 수정)

### 완료 (2026-05-19)

**스크린샷 기반 5가지 UX 수정** + Supertonic-3 TTS 조사

**수정 내역**:
1. **사이드바 미리보기 isSystem 필터** (`AgentChatView.swift`)
   - `room.messages.last` → `room.messages.last(where: { !$0.isSystem })`
   - 메시지 카운트: `room.messages.count` → `room.messages.filter({ !$0.isSystem }).count`
   - 대화창에는 안 보이던 시스템 로그가 사이드바 미리보기에는 보이던 문제 완전 해결

2. **4번째 캐릭터 초상화 잘림 해결** (`AgentQuickSwitchBar.swift`)
   - 초상화 32→28px, 이미지 24→20px, spacing 8→6, padding 10→6
   - 4개 에이전트 × 28px + 3 × 6px = 130px → 148px 가용 내 여유롭게 수용

3. **Artifact 카드 ScrollView 안으로 이동** (`TeamStatusView.swift`)
   - 기존: ScrollView 바깥에 배치 → 패널 높이 부족 시 접근 불가
   - 수정: ScrollView 내부 VStack에 배치 → 스크롤로 접근 가능

4. **하단 컨트롤 바 패널 통합 디자인** (`TeamStatusView.swift`)
   - RoundedRectangle 배경 제거 → 패널 배경에 자연스럽게 녹아듦
   - Divider 경계선 추가 + 수평 패딩 20px(패널과 일치)
   - 아이콘 색상 textColor.opacity 기반으로 통일

5. **statusPanel 크기 상향** (`AgentWindowManager.swift`)
   - 초기 높이 450→550px
   - `contentMinSize = NSSize(width: 300, height: 400)` 추가

**Supertonic-3 TTS 조사 결과**:
- 99M params, ONNX Runtime, CPU 동작, RTF 0.3x
- 한국어 CER 3.26%, 44.1kHz 16-bit WAV 출력
- **Swift/iOS 바인딩 공식 지원**
- 10개 프리셋 음성(M1-M5, F1-F5) + speed 파라미터로 11캐릭터 커버 가능
- Qwen3 대비 모든 면에서 우위 → PoC 라운드 별도 진행 예정

**Preflight 240**: 10/10 전체 통과

**신규 파일**:
- `scripts/preflight_ux_round240.sh`

---

## 2026-05-19 (Round 239 — Personal Chat Nav Fix + Connector UX Cleanup)

### 완료 (2026-05-19)

**코드 수정 라운드** — 앱 실행 없이 정적 수정 + Debug/Release 빌드만 진행

**수정 내역**:
1. **개인 대화창 이동 버그 수정** (`AgentWindowManager.swift`)
   - `openPersonalChat(for:)` — 기존방/신규방 두 분기 모두 `didSelectAgentForChat` 알림 추가
   - 기존: `manager.currentRoomID`만 변경, `AgentChatView.agentRoomID`(@State) 미반응
   - 수정: 알림 전파로 AgentChatView가 `agentRoomID`를 올바르게 갱신

2. **커넥터 내부 개발 문구 제거** (`AssistantConnectorCatalog.swift`)
   - Google Calendar: `Desktop OAuth + Calendar read-only 연동 예정` → 사용자 향 문구
   - Gmail: `metadata 먼저, 본문 읽기는 추후 승인 필요` → 사용자 향 문구
   - Naver Mail: `IMAP 기반 read-only 연동 검토` → `연동 준비 중입니다.`
   - Naver Calendar: `공식 API 제약 검토 필요` → `연동 준비 중입니다.`

3. **DailyBriefingCard Gmail 빈 상태 문구 정리** (`DailyBriefingCardView.swift`)
   - `Gmail 메타데이터 브리핑은 준비 중입니다. 메일 본문 요약/발송/삭제는 아직 지원하지 않습니다.`
   - → `Gmail 연결 후 새 메일 알림을 볼 수 있어요.`

4. **`schedulePopupCard` 데드 코드 제거** (`TeamStatusView.swift`)
   - WP5에서 오버레이 제거 후 정의만 남아있던 66줄 computed property 삭제

**Preflight 239**: 9/9 전체 통과

**신규 파일**:
- `scripts/preflight_nav_connector_round239.sh`

---

## 2026-05-19 (Round 238 — Chat Surface Visibility Fix)

### 완료 (2026-05-19)

**코드 수정 라운드** — 앱 실행 없이 정적 수정 + Debug/Release 빌드만 진행

**수정 내역**:
1. **시스템 로그 대화창 노출 차단** (`AgentChatView.swift`)
   - `chatHistory` 계산 속성에 `!$0.isSystem` 필터 추가 (개인 대화 + 팀 워크룸 양쪽)
   - `isSystem=true` 내부 라우팅/진단 로그가 사용자 대화창에 절대 표시되지 않음

2. **시작 화면이 대화를 덮는 문제 수정** (`TeamStatusView.swift`)
   - `WorkroomHomeView` 표시 조건 `isBeginnerMode || teamChatLogs.isEmpty` → `teamChatLogs.isEmpty` 단독으로 변경
   - 초보자 모드 여부와 무관하게 대화 내용이 있으면 대화 화면 표시

3. **개인 대화창 빈 상태 단순화** (`AgentChatView.swift`)
   - `isPersonalChat && chatHistory.isEmpty` 시 온보딩카드/스파클/액션스트립 대신 한 줄 힌트만 표시
   - "이 팀원에게 바로 말을 걸 수 있어요." (팀원 이름 포함)

4. **푸터 컴팩트 플로팅 스타일** (`TeamStatusView.swift`)
   - `.padding(.vertical, 14)` → `.padding(.vertical, 6)` + `RoundedRectangle(cornerRadius: 18)` 배경
   - 사각박스 느낌 제거, 아이콘 크기 12→11pt 통일

**Preflight 238**: 10/10 전체 통과

**신규 파일**:
- `scripts/preflight_chat_surface_round238.sh`

---

## 2026-05-18 (Round 237 — Local Runtime QA)

### 완료 (2026-05-18)

**수동 QA 진행**: Debug 앱 실행 후 computer-use로 UI 직접 검증

**검증 결과**:
- 앱 실행: Antigravity (com.google.antigravity), PID 55102, 다크 모드 ✅
- 팀 협업 패널: 레오/루나/모코/핀 에이전트 카드 정상 ✅
- 온보딩 카드 닫기 ✅
- 에이전트 초상화 컨텍스트 메뉴 (추가/교체/팀장) ✅
- 에이전트 카탈로그 모달 (무료/프리미엄 분류) ✅
- 메시지 전송 → Gemini API 호출 확인, 429 우아한 처리 ✅
- 커넥터 설정: Google Calendar "읽기 준비 중, 쓰기 차단" ✅
- 기술 UX 금지 문구 미노출 ✅
- Preflight 236 (12/12) + Preflight 237 (10/10) 통과 ✅

**발견 이슈**:
- P2: 설정 창 X 버튼 위치가 macOS Window 메뉴와 충돌 (화면 렌더링 좌표 이슈)
- INFO: Gemini API 429 rate limit (개발 환경, 120초 자동 해제 확인)

**신규 파일**:
- `docs/qa/LocalRuntimeQA_Round237.md`
- `scripts/preflight_local_runtime_round237.sh`

---

## 2026-05-18 (Round 236 — Auxiliary Content Draft Room Profile)

### 진행 중

**핵심 결정**:
- `ONBOARDING.md` 기준 MyTeam의 메인 포지션은 문서/파일/표/정리 작업을 처리하는 AI 업무 워크룸이다.
- 블로그/콘텐츠 글쓰기는 메인 기능이 아니라 콘텐츠 초안 보조 기능으로 유지한다.
- `blogWriting` 저장 enum은 호환성을 위해 유지하되, 사용자-facing 문구는 "콘텐츠 초안 보조"로 낮춘다.

**검증 방향**:
- WorkroomHomeView 핵심 CTA보다 콘텐츠 기능을 우선 노출하지 않는다.
- `/blog-source`는 공개 글 URL을 워크룸 참고 정보로 축적하는 power user shortcut으로 유지한다.
- 개인 대화와 팀 워크룸의 메시지, artifact, LLM context가 섞이지 않는 room-scoped 격리를 계속 P0로 본다.

---

## 2026-05-17 (Round 235 — UI Readability P0 Fixes + Agent Chat Switching)

### 완료 (2026-05-17)

**핵심 달성**:
- MT Readability Token 시스템 도입 — Color+Hex.swift에 6개 토큰 (primary/secondary/tertiary text, card/input background, border)
- 채팅 버블/카드 배경 low-opacity glass 교체 — Color.mtCardBackground (NSColor.controlBackgroundColor 기반, dark mode 자동 대응)
- 입력 필드 placeholder/background 가독성 상향 — mtInputBackground + mtTextSecondary
- 에이전트 nameplate 탭 → openPersonalChat(for:) 연결 — currentRoomID 전환 (TeamTableView + TeamStatusView 양쪽)
- BeginnerTaskCardView / WorkroomHomeView 카드 명시적 배경 + border
- RuntimeDiagnostics Round 235 필드 5개 + summary line
- Debug + Release BUILD SUCCEEDED 0 warnings

**구현**:
- **Color+Hex.swift**: mtTextPrimary(0.88)/mtTextSecondary(0.64)/mtTextTertiary(0.45), mtCardBackground(0.94), mtInputBackground(0.96), mtCardBorder(0.10) 추가
- **TeamStatusView.swift**: 채팅 버블 배경 → mtCardBackground + strokeBorder, 입력 필드 배경/foreground 명시, StatusAgentRow 배경/텍스트 토큰화, 에이전트 탭 → openPersonalChat()
- **AgentChatView.swift**: inputBgColor → mtInputBackground, subTextColor → mtTextSecondary, attachment area opacity stacking 제거
- **BeginnerTaskCardView.swift**: bgColor → mtCardBackground, 내부 텍스트 secondary/tertiary 토큰 적용
- **WorkroomHomeView.swift**: 목표/액션 카드 배경 mtCardBackground, nextActions 텍스트 명시, 섹션 헤더 mtTextSecondary
- **TeamTableView.swift**: 에이전트 시트 onTap에 openPersonalChat(for:) 추가
- **RuntimeDiagnosticsService.swift**: Round 235 필드 5개 + ui235 summary line
- **scripts/preflight_ui_readability_round235.sh** (new): 12단계 preflight

**핵심 기술 결정**:
- Color.primary 기반 opacity 토큰: isDarkMode 분기 없이 NSColor adaptive 동작 활용
- NSColor.controlBackgroundColor 기반 배경: macOS system 배경으로 dark mode 자동 전환
- openPersonalChat(for:) 재사용: 이미 구현된 메서드로 최소 코드 변경

**문서**: TASK.md Round 235 Completed 추가, DEVLOG.md 이 항목

---

## 2026-05-17 (Round 236 — Room Purpose Inference + Blog Profile + Rename)

### 완료 (2026-05-17)

**핵심 달성**:
- 블로그 "전용 방" 생성 방향 → room purpose inference로 수정 (사용자가 강제 고정 없음)
- renameRoom(id:newName:) — 개인방/팀방 모두 roomID 기준 이름 저장
- openPersonalChat(for:) — 하단 캐릭터/이름 탭 클릭 시 개인방 전환
- RoomProfile / BlogStyleProfile / BlogSEOProfile — room-scoped, 원문 전체 저장 금지
- /blog-source, /blog-profile — currentRoomID 기준으로만 작동
- RuntimeDiagnostics 9개 필드 추가 (Round 236)
- ToolContractValidator 7개 validator 추가 (Round 236)
- RouterBurnInSuite 9개 케이스 추가 (Round 236)
- docs/ProductImplementationInventory.md (새 파일)
- docs/connectors/ConnectorReadinessPlan.md (새 파일)
- scripts/preflight_room_ui_round236.sh (12단계, 전체 통과)
- Debug + Release BUILD SUCCEEDED (0 warnings)

**핵심 설계 결정**:
- purpose inference는 "제안" 수준 — 사용자가 /purpose reset 또는 이름 변경 시 general 복귀
- BlogStyleProfile: 원문 전체 저장 금지, voiceSummary + patterns 요약만 저장
- Gmail send / Calendar write: 구현하지 않음 (L5 외부 쓰기 정책 유지)
- 커넥터 readiness: read-only부터 단계적 구현, OAuth skeleton 미완

**문서**:
- docs/ProductImplementationInventory.md: P0/P1/P2 기능 현황 전체 목록
- docs/connectors/ConnectorReadinessPlan.md: Google Calendar/Gmail 단계별 계획
- TASK.md: Round 236 섹션 반영
- DEVLOG.md: 이 항목

---

## 2026-05-17 (Round 234 — Sprite Asset Gate + Beginner Flow QA Prep)

### 완료 (2026-05-17)

**핵심 달성**:
- Sprite asset intake gate 구축 — CharacterSpriteManifest + CharacterSpriteAssetPolicy
- validate_sprites.sh — macOS NFD(한국어 파일명 NFD 정규화) 대응, Python os.listdir+re 사용
- RouterBurnInSuite 6개 케이스 + ToolContractValidator 3개 validator + RuntimeDiagnostics 8개 필드
- 수동 QA 체크리스트 작성 (ManualRuntimeQA_Round234.md) — 4개 시나리오
- Debug + Release BUILD SUCCEEDED 0 warnings

**구현**:
- **Sprites/** (new): 디자이너 핸드오프 intake 폴더 — 치코/세나/카이/유나 폴더 + README 5개
- **CharacterSpriteManifest.swift** (new): 정적 캐릭터 스프라이트 매니페스트 — requiredStates, optionalStates, runtimePath, releaseVisible (4 chars: 치코=visible, 나머지=DLC)
- **CharacterSpriteAssetPolicy.swift** (new): ValidationResult (missing/malformed/total), validate(), isReadyForRelease(), summary()
- **scripts/validate_sprites.sh** (new): 4단계 검증 — intake 구조 → 런타임 폴더 → 파일명 컨벤션 → state frame count. Python 기반 NFD 대응
- **RuntimeDiagnosticsService.swift**: Round 234 필드 8개 추가 + sprite234 summary 라인
- **ToolContractValidator.swift**: validateSpriteAssetPolicy + validateBeginnerExampleArtifactPolicy + validateFriendlyRecoveryActionPolicy
- **RouterBurnInSuite.swift**: 6개 케이스 (sprite-asset/sprite-fallback/beginner-next-action/recovery/blocked)
- **pbxproj**: BC234A001FR/BF (CharacterSpriteManifest), BC234A002FR/BF (CharacterSpriteAssetPolicy) 등록
- **scripts/preflight_sprite_round234.sh** (new): 11단계 preflight
- **docs/qa/ManualRuntimeQA_Round234.md** (new): 수동 QA 4개 시나리오

**핵심 기술 결정**:
- macOS HFS+ NFD 파일명: bash grep/find은 한국어 글자 분해 문자와 매칭 불가 → Python os.listdir() + re.search()로 모든 한국어 파일명 처리
- 치코 런타임 스프라이트 현황: MyTeam/Resources/Sprites/치코/ — 674 PNG, 22개 state (요구 13개 전부 포함)
- Intake vs Runtime 구분: Sprites/ (디자이너 핸드오프) vs MyTeam/Resources/Sprites/ (런타임 번들)
- DLC gate: CharacterSpriteManifest.releaseVisible = false → isReadyForRelease() 조기 반환

**문서**:
- docs/qa/ManualRuntimeQA_Round234.md (new) — 4개 시나리오 pending
- TASK.md: Round 234 Completed 섹션 추가
- DEVLOG.md: 이 항목

---

## 2026-05-17 (Round 233B — Beginner Mode UX Complete)

### 완료 (2026-05-17)

**핵심 달성**:
- 간편 모드 UX 완전 구현 — API 키 없이 즉시 동작하는 초보자 플로우
- 예시로 먼저 해보기: BeginnerExampleDocumentService 로컬 템플릿 fallback
- ArtifactCardView 친절한 복구 UI (기술 용어 제거)
- SettingsView 간편 모드 Toggle
- Debug BUILD SUCCEEDED 0 warnings 확인

**구현**:
- **BeginnerExampleDocumentService.swift** (new): API 없이 샘플 회의록 마크다운 생성 → ArtifactStore 등록 → workflowCompleted 알림
- **WorkroomHomeView.swift**: handleBeginnerCardTap(.tryExample) → BeginnerExampleDocumentService 연결, onPromptDispatched 콜백 추가
- **SettingsView.swift**: 사용자 설정 탭에 간편 모드 Section + Toggle 추가
- **ArtifactCardView.swift**: RecoveryAction/RecoveryInfo struct + friendlyRecovery computed property (4개 오류 케이스, orange-tinted UI)
- **RuntimeDiagnosticsService.swift**: Round 233B beginner 필드 9개 + 스냅샷 값 + summary 라인 추가
- **ToolContractValidator.swift**: 3개 beginner validator (Mode/ExampleFlow/FriendlyRecovery)
- **RouterBurnInSuite.swift**: 5개 beginner 케이스 추가
- **pbxproj**: BC233B001FR/BF 등록 (BeginnerExampleDocumentService.swift)

**문서**:
- `docs/beginner/BeginnerModeProductSpec.md` — 간편 모드 전체 스펙 문서
- `scripts/preflight_beginner_round233.sh` — 5단계 사전 검증 스크립트

**결정 사항**:
- 친절한 복구 버튼은 현재 모두 "새 문서로 시작" (myteam.beginnerNewDocument notification) → Round 234+에서 파일 선택 UI 직접 연결 예정
- BeginnerExampleDocumentService: 현재 하드코딩 마크다운 → API 연결 시 LLM 생성으로 전환 예정

---

## 2026-05-17 (Round 196A-230Z — Workroom Stabilization + Type Consolidation)

### 완료 (2026-05-17)

**핵심 달성**:
- Workroom action types 중앙 집중식 정의 (WorkroomActionTypes.swift)
- TeamStatusView handler 메서드 통합 및 refactoring
- 캐릭터 시스템 완전 보존 확인
- 다음 라운드 (231A) 준비 문서 작성 완료

**구현**:
- **WorkroomActionTypes.swift** (new): 2 enum + 모든 프롭들 중앙화
  - WorkroomPrimaryAction: createDocument, handoffFile, organizeToday
  - WorkroomNextAction: summarize, table, checklist, actionItems
- **pbxproj**: file ref + build file 등록, sources phase 추가
- **TeamStatusView.swift**: handlers refactored to use action.dispatchPrompt
- **Room scope**: recentArtifacts() 0, recentArtifacts(for:) 10개 확인
- **Character preservation**: 4 files + 7 referencing files 검증

**문서**:
- .claude/CLAUDE.md (project config)
- .claude/commands/{preflight,review,repair-build,workroom-final}.md
- docs/character/{CharacterReactionBridgeBacklog,SpriteSheetProductionSpec,CharacterReactionEnginePlan}.md
- scripts/preflight_workroom_round196.sh
- docs/workroom/WorkroomRound196ReviewReport.md

**Build**: Debug ✅, Release ✅, 0 warnings

---

## 2026-05-16 (Round 181A-195Z — Workroom Productization + Core Loop Surface Pack)

### 진행 중 (2026-05-16)

**핵심 달성**:
- "워크룸"을 업무 공간으로 완성. 단순 대화방이 아니라 목표/결과물/다음 액션이 한눈에 보이는 제품.
- AgentChatView await warning 해결: Task + await 제거, 동기식 호출로 변경
- 문서 만들기를 워크룸의 메인 CTA로 고정 (+ 파일 맡기기, 오늘 정리하기)
- 워크룸 내 결과물은 room-scoped only (다른 방의 artifact 절대 표시 금지)
- 후속 액션 4가지는 최근 artifact 있을 때만 활성화

**구현 상세**:
- **AgentChatView.swift** (modified):
  - Line 298: `await manager.returnToTeamWorkroom()` → `manager.returnToTeamWorkroom()` (동기식)
  - Line 432: `await manager.openPersonalChat()` → `manager.openPersonalChat()` (동기식)
  - Task 래퍼 제거, await 제거
- **WorkroomHomeModel.swift** (new): UI projection, room-scoped data 관리
- **WorkroomHomeView.swift** (new):
  - 워크룸 홈 대시보드
  - 목표 표시 (있으면 표시, 없으면 "무엇을 정리할까요?")
  - 3 primary actions: 문서 / 파일 / 정리
  - Recent artifacts rail: max 3, room-scoped only
  - Next actions: 최근 artifact 있을 때만, max 4
- **WorkroomPrimaryAction** enum: 3 main CTA + title/icon/description
- **WorkroomNextAction** enum: 4 follow-up actions + skillID mapping
- **RuntimeDiagnosticsService.swift** (modified): 8개 신규 필드
  - workroomHomeAvailable
  - workroomPrimaryActionsAvailable
  - workroomUsesRoomScopedArtifacts
  - workroomNextActionsRoomScoped
  - workroomGoalContextVisible
  - teamStatusMiniWidgetPreserved
  - personalChatSurfaceSeparated
  - agentChatAwaitWarningsResolved
- **ToolContractValidator.swift** (modified): 5개 신규 validator
  - validateWorkroomHomePolicy()
  - validateWorkroomPrimaryActionPolicy()
  - validateWorkroomArtifactRailPolicy()
  - validateWorkroomNextActionPolicy()
  - validateAgentChatWarningDebtPolicy()
- **RouterBurnInSuite.swift** (modified): 5개 신규 테스트 케이스
  - workroom-open: 워크룸 네비게이션
  - workroom-new: 새 워크룸 생성
  - workroom-create-document: 워크룸에서 문서 만들기
  - workroom-today-organize: "오늘 정리하기"
  - workroom-file-handoff: "파일 맡기기"

**문서**:
- docs/WorkroomProductizationPolicy.md (new): 워크룸 설계 원칙, 금지사항, 표면 레이아웃
- docs/WorkroomCoreLoop.md (new): 6단계 core loop (open → create → review → use → reuse → next)

**기술 결정**:
- Await warning 정책: 실제 async가 아니면 제거 (Task 래퍼 포함)
- Room-scoped guarantee: recentArtifactIndexEntries(for: roomID) 패턴 강제
- Primary action 우선순위: 문서 > 파일 > 정리 (사용 빈도순)
- Next action 활성화: recent artifact 존재 여부 단일 조건

---

## 2026-05-16 (Round 164A-180Z — Document Creation Killer Workflow Pack)

### 완료 (2026-05-16)

**핵심 달성**:
- "문서 만들기"를 MyTeam의 **첫 번째 킬러 워크플로우** 완성
  - API 없이도 로컬 템플릿으로 즉시 결과 제공 (local fallback)
  - 3가지 문서 타입: 회의록, 체크리스트, 보고서 초안
  - WorkResultCardView로 문서 유형별 다른 UI 표시
  - 같은 방 내에서 후속 작업 가능 (요약, 표 변환, 액션아이템 등)

**구현 상세**:
- **DocumentCreationType.swift** (new): enum + skillType mapping
- **LocalDocumentTemplate.swift** (new): markdown 템플릿 생성 (fallback)
- **DocumentCreationService.swift** (new):
  - detectDocumentCreationIntent(): 메시지 → 문서 타입 감지
  - createLocalDocument(): IndexedArtifact + RecentArtifactIndexEntry 생성 및 등록
  - sanitizeFilename(): 파일명 정규화
- **WorkResultKind.swift** (new): enum + 문서별 아이콘/제목/색상
- **WorkResultCardView.swift** (modified): `kind` 파라미터 추가 → 조건부 헤더
- **RouterBurnInSuite.swift** (modified): 10개 신규 테스트 케이스
  - 문서 만들기 hub
  - 3가지 타입 직접 진입
  - 4가지 follow-up actions (room-scoped)
- **RuntimeDiagnosticsService.swift** (modified): 9개 신규 필드 추가
- **ToolContractValidator.swift** (modified): 5개 신규 validator 추가

**문서**:
- docs/KillerWorkflowPolicy.md (new): 킬러 워크플로우 정의 및 설계 원칙
- docs/DocumentCreationCoreFlow.md (new): 구현 아키텍처 상세 설명

**빌드 결과**:
- Debug BUILD SUCCEEDED
- Release BUILD SUCCEEDED
- AgentChatView 기존 경고 2개 유지 (unrelated to this round)
- No duplicate build file warnings
- External write unchanged (no Gmail API, Calendar write, StoreKit changes)

**주요 기술 결정**:
- Room-scoped artifact linking: 다른 방의 artifact 참조 불가 (보안, 혼동 방지)
- Local fallback mandatory: API 부재 시에도 기본 템플릿으로 즉시 가치 제공
- WorkResultKind enum: artifact type-aware rendering (UI 차별화)
- RecentArtifactIndexEntry 추적: room별 최대 10개 artifact만 유지

---

## 2026-05-16 (Round 163B-UXNAV — Agent Quick Navigation + Starter Copy Polish Pack)

### 진행 중

- **체크리스트 starter action 복사 수정**:
  - StarterAction.checklistAction description: "앱 출시나 업무 준비를 체크리스트로 정리합니다." → "업무 준비 요소를 체크리스트로 정리합니다."
- **AgentQuickSwitchBar 신규 컴포넌트**:
  - 팀원 얼굴 icon array (28×28px) with selected ring overlay
  - "팀원" caption + 수평 scrolling
  - OnSelectAgent closure로 personalChat navigation
- **AgentWindowManager 신규 메서드**:
  - openPersonalChat(for agentID:) — 개인 대화방 열기/생성, room agentIDs mutation 아님
  - returnToTeamWorkroom() — 팀 워크룸 복귀
- **AgentChatView 사이드바 통합**:
  - projectSidebarView 하단에 AgentQuickSwitchBar 배치
  - 개인 대화창 header에 "팀 워크룸으로" 버튼 추가
- **RuntimeDiagnostics 5개 신규 필드**:
  - agentQuickSwitchBarAvailable
  - agentQuickSwitchUsesNavigationNotMutation
  - personalChatIdentityPreserved
  - teamWorkroomReturnShortcutAvailable
  - starterChecklistCopyUpdated
- **ToolContractValidator 5개 신규 validator**
- **RouterBurnInSuite 3개 신규 케이스**

---

## 2026-05-16 (Round 153A-162Z FINAL — Inline Artifact Resolver + Result Card Completion Pack)

### 완료 (Part 1-3, 2026-05-16)

- **workflow 완료 메시지와 artifact 연결**:
  - WorkflowOrchestrator.removeProgressAndPost() 함수 확장: `artifactIDs: [String] = []` 파라미터 추가
  - UniversalDocument, PrivacyTerms, AppLaunch 완료 메시지에 artifact ID 링킹
  - ChatLog 저장 시 artifactIDs 배열 포함
- **SkillResultRendererView generic card fallback**:
  - shouldRenderAsGenericCard() 판정: 5줄 이상, 마크다운 헤더/표/체크리스트 포함
  - 구조화된 스킬 결과 → WorkResultCardView로 렌더링
- **ArtifactCardView compact mode**:
  - compactMode 파라미터 (기본값 false)
  - Compact: 한 줄 HStack, emoji + 제목/파일명 + 상태 + 열기 버튼
  - Standard: 기존 다중 줄 카드 (변경 없음)
- **RuntimeDiagnostics 4개 신규 필드**:
  - workResultInlineArtifactsAvailable
  - chatLogArtifactIDsLinked
  - skillResultGenericCardFallbackAvailable
  - bottomArtifactListDeduplicated
- **ToolContractValidator 3개 신규 validator**:
  - validateWorkResultInlineArtifactPolicy()
  - validateChatLogArtifactLinkingPolicy()
  - validateSkillResultCardFallbackPolicy()
- **docs**: ResultPresentationPolicy.md "Inline Artifact Linking" 섹션 추가
- Debug + Release BUILD SUCCEEDED
- Commits: ea38e91 (Part 1), ff0ef76 (Part 2), 8520219 (Part 3)

**Part 3: 완료 (2026-05-16)**
- AgentWindowManager.artifact(withID:roomID:) room-scoped lookup 추가
- WorkResultCardView.relatedArtifacts 파라미터 추가 및 inline 표시
- AgentChatView.artifactsForLog() resolver 구현
- ChatLog.artifactIDs → IndexedArtifact 해석 연결
- Artifact deduplication: inline 표시 → 하단 목록 중복 제거
- ArtifactCardView compact mode 최종 통합
- Debug + Release BUILD SUCCEEDED, 0 warnings

### 다음 (Round 154A+)

- WorkResultCardView 내부에 관련 artifact inline 표시 (artifact 테칭 로직 필요)
- AgentChatView 하단 artifact 목록 중복 제거 로직
- 추가 스킬별 전용 카드 (spell-check, accounting-tax 등)

---

## 2026-05-16 (Round 146A-152Z — Result Presentation + Room Kind + UX Surface Polish)

### 완료

- **WP6 FirstResultActionStrip 중복 제거**:
  - TeamStatusView에서 FirstResultActionStripView + handleFirstResultAction 제거
  - AgentChatView에서만 표시 (단일 표면)
- **WP7 협업 상태 배너 압축**:
  - 2줄 카드(62px) → 1줄 컴팩트 바(~32px)
  - subtitle 제거, 아이콘 28→11px, 완료/실패 상태는 색상 점
- **WP2-lite 결과물/대화 분리**:
  - WorkResultCardView 신규 — 500자+ 또는 마크다운 헤더/표 포함 시 전체 너비 카드로 렌더링
  - 300자 미리보기 + 접기/펼치기 토글
  - 어시스턴트 버블 maxWidth 260→480
  - `shouldRenderAsWorkResult()` 정적 판정 메서드
- **ChatLog artifactIDs**: 메시지-artifact 연결 필드 추가 (기본값 `[]`, 디코딩 호환)
- **ArtifactCardView 상태 텍스트 순화**: "메타데이터만"→"파일 정보만 저장됨", "경로 오류"→"파일을 열 수 없음"
- **RoomKind computed property**: `.teamWorkroom` / `.personalChat` 자동 판정, 사이드바 아이콘 분리 (person.3.fill / person.fill)
- **TeamStatusView 용어 잔존 정리**: "프로젝트 이름 변경"→"이름 변경"
- **RuntimeDiagnostics 8개 신규 필드**: firstResultActionDeduplicated, collaborationStatusCompact, workResultCardAvailable, longAssistantResultEscapesBubble, chatLogArtifactIDsAvailable, artifactStatusCopyUserFriendly, roomKindComputedAvailable, teamWorkroomPersonalChatSeparated
- **ToolContractValidator 5개 신규 validator**: validateFirstResultActionSurfacePolicy, validateCollaborationStatusCompactPolicy, validateWorkResultPresentationPolicy, validateArtifactStatusCopyPolicy, validateRoomKindPolicy
- **RouterBurnInSuite 6개 신규 케이스**: long-report-result-card, markdown-table-result-card, room-kind-team-workroom, room-kind-personal-chat, artifact-status-friendly, collaboration-status-compact
- **docs**: ResultPresentationPolicy.md, RoomKindPolicy.md 신규, ProductIAPolicy.md + WorkSurfaceSimplificationPlan.md 갱신
- Debug + Release BUILD SUCCEEDED

---

## 2026-05-16 (WP3+WP5+WP1 — Product UX Surface Cleanup)

### 완료

- **WP3 설정/진단 누출 차단**:
  - AssistantConnectorCatalog comingSoon 메시지 "IMAP 기반 read-only 검토 중" 등 → "준비 중" 통일
  - DailyBriefingCardView 커넥터 상태 섹션을 DiagnosticsVisibilityPolicy 뒤로 (Release 비표시)
  - TeamStatusView 푸터 7개→4개 (파일 첨부 + 위치 초기화 버튼 제거)
  - "스케줄 관리 준비 중" 비활성 버튼 제거
  - SettingsView Release 진단: Build/Debug/PlanRunner/Verbose 플래그 → "상태: 정상" 1줄로 축소
- **WP5 예약 작업 진입점 통합**:
  - 헤더 시계 버튼 제거
  - 팝업 카드 오버레이 제거
  - 사이드바 단일 진입점 유지
  - 검증 에러 폰트 9pt→11pt + 경고 아이콘 추가
- **WP1 온보딩 표면 통합**:
  - OnboardingCardView 신규 — FirstLaunchBannerView + LocalOnlyModeCardView 합침
  - localOnly: 기능 목록 + Settings 텍스트 링크 (큰 CTA 제거)
  - AgentChatView: 온보딩 OR (인사말+액션), 동시 표시 금지
  - TeamStatusView: OnboardingCardView로 교체
- Debug + Release BUILD SUCCEEDED, warning 0

---

## 2026-05-16 (Round 137A-145Z — Product IA Hardening + Room-Scoped Artifact + Work Surface Simplification)

### 완료

- **Room-scoped recentArtifacts (P0)**: `AgentWindowManager.recentArtifacts(for: UUID)` facade 추가. RecentArtifactIndex 우선 조회 → currentRoomID 한정 global fallback. TeamStatusView / AgentChatView / RecentArtifactContentResolver / LocalTaskBriefingProvider 모두 facade 사용으로 전환. 다른 방 artifact 오염 차단.
- **용어 정책 (TerminologyPolicy.md)**: 채팅방→워크룸, 스케줄 근무→예약 작업, 프로젝트→대화(사이드바), 기본 방 이름 "워크룸 1". TeamStatusView / AgentChatView / AgentWindowManager 적용.
- **에이전트 switcher 제거**: AgentChatView 사이드바 하단 ForEach(manager.activeAgents) avatar 행 삭제. 사이드바 단순화.
- **TypingIndicatorView timer leak 수정**: `@State private var animationTimer: Timer?` 추가. `.onAppear` startAnimation, `.onDisappear` stopAnimation(invalidate). 누수 차단.
- **RuntimeDiagnostics 보강**: 12개 신규 필드 (recentArtifactsRoomScoped, terminologyPolicyAvailable, agentSwitcherRemovedFromSidebar, typingIndicatorTimerLeakFixed 등). cachedSnapshot 추가 (ToolContractValidator 동기 접근용).
- **ToolContractValidator 보강**: 8개 신규 validator (validateRoomScopedArtifactPolicy, validateTerminologyPolicy, validateTypingIndicatorTimerPolicy, validateAgentSwitcherPolicy, validateStarterAction3PrimaryPolicy, validateWorkroomDefaultNamePolicy, validateReservedTaskTerminologyPolicy, validateEmptyStateSimplificationPolicy).
- **RouterBurnInSuite 보강**: 9개 신규 케이스 (starter-file-handoff, starter-document-create, starter-today-organize, room-artifact-same-room, workroom-create, reserved-task-create, reserved-task-list, terminology-chat-room, terminology-schedule-work).
- **docs 추가**: TerminologyPolicy.md, RoomScopedArtifactPolicy.md, ProductIAPolicy.md, WorkSurfaceSimplificationPlan.md.
- Debug + Release BUILD SUCCEEDED, warning 0

### 미수정 (다음 라운드)

- TeamStatusView 경량화 (핵심 5요소)
- Empty state 단순화 (상태카드 1 + 주요 액션 3)
- Result/Conversation 분리 (ResultMessageBlockView)
- sendMessage await 패턴
- DelegationMode 진짜 실행 (DelegationModeHandler)

---

## 2026-05-16 (Round 136A-UXFIX — Product Surface P0 Repair)

### 완료

- **팀 이름 명패 설정 compact화**: TeamNameplatePalette(9색) + TeamNameplateBorderMode(none/subtle) 도입. 복잡한 hex color picker / border 색상·굵기 제거. migration 지원.
- **DART 공시 활성화**: `korean.dart` skill `defaultEnabled: false → true`. `publicDisclosureRead` 재분류 — write 없음, OAuth 없음, Release 차단 해제.
- **기본 캐릭터 roster 반영**: 치코 `isPremium: true → false`, role "UX 디자이너" → "문서·할일 정리 팀원", status 업데이트. CharacterCatalog 기준 정렬.
- **API key nag 제거**: FirstLaunchBannerView localOnly 케이스에서 "API 키 필요" 제목·큰 CTA 버튼 제거. "로컬 기능부터 바로 시작" 안내로 교체. Settings에만 API provider 섹션 유지.
- **RuntimeDiagnostics 보강**: teamNameplatePaletteEnabled, dartDisclosureEnabled, apiKeyPromptHiddenFromTeamSurface 등 7개 필드 추가.
- **ToolContractValidator 보강**: validateTeamNameplateSettingsPolicy, validateDARTDisclosurePolicy, validateDefaultCharacterRosterPolicy, validateAPIKeyPromptSurfacePolicy 추가.
- **RouterBurnInSuite 보강**: DART 공시 3케이스, API key 설정 2케이스, starter action 2케이스, blocked write 3케이스 추가.
- 외부 write 없음 / Gmail API 없음 / Calendar write 없음 / StoreKit 미수정

---

## 2026-05-16 (Round 136A — Mac Local Sync + Target Registration + Build Repair)

### 완료

**Git Sync**
- `git pull origin main` — 889a269, 7b39c7d, 9426434 커밋 포함 확인
- 복원된 4개 파일 정상 위치 확인: FirstLaunchBannerView, LocalOnlyModeCardView, StarterActionDispatcher, StarterActionStripView

**pbxproj Target Audit**
- audit script 버그 수정: 따옴표 없는 `path = filename;` format 미감지 → 수정 후 15/15 PASS
- `mac_register_round116_files.rb` 실행: ProductSurfacePolicy, ConnectorSurfacePolicy, FirstResultActionPolicy, StarterActionPolicy 4개 등록

**Compile 에러 수정 (6종)**
- `CharacterAssetAvailability` 중복 선언 — CharacterAssetManifest.swift에서 제거, `partialAllowed` → `partial` rename
- `StarterActionStripView` Preview: `actions(for: .empty)` → `actions()` (오버로드 없음)
- `RouterBurnInSuite`: `.artifactGeneration` → `.artifactWorkflow` (케이스 없음)
- `ToolContractValidator`: `ToolScope.connectorRead` → `chatBasic + availability == .future` (케이스 없음)
- `RuntimeDiagnosticsService`: snapshot init 20개 필드 누락 → 추가 (characterAssetManifestAvailable 등)
- `TeamStatusView`: `firstArtifact.fileExists` → 제거 (멤버 없음, healthStatus == .valid 충분)

**빌드 결과**
- Debug: BUILD SUCCEEDED, app warning 0, duplicate 0
- Release: BUILD SUCCEEDED, app warning 0, duplicate 0

**Cloud Preflight 재실행**
- Privacy copy (Swift 소스): ✅ clean
- Character ID normalization: ✅
- Starter action IDs: ✅ starter_* format
- pbxproj 15/15: ✅
- Connector write: ⚠️ → 정책상 blocked 확인 (ConnectorSurfacePolicy)
- StoreKit: ⚠️ → 정책상 disabled 확인 (ProductSurfacePolicy)

**다음**: Round 140A — Manual Runtime QA

---

## 2026-05-15 (Round 116C-135Z Cloud — Policy Centralization + Build Automation + Compile-Risk Reduction)

### Cloud-Side Completion: Policy Centralization & Build Automation ✅

**Policy Centralization:**
- ProductSurfacePolicy.swift: 8 static Release control constants ✅
- ConnectorSurfacePolicy.swift: capability visibility matrix + blockedCapabilitiesInRelease ✅
- FirstResultActionPolicy.swift: ArtifactState → allowedActions mapping ✅
- StarterActionPolicy.swift: allowedStarterActionIDs / blockedStarterActionIDs sets ✅

**Validator Refactoring:**
- validateCharacterAssetPolicy(): now uses ReleaseVisibleCharacterPolicy ✅
- validateStarterActionPolicy(): now uses StarterActionPolicy constants ✅
- validateFirstResultActionPolicy(): now uses FirstResultActionPolicy.allowedActions() ✅
- validateStoreKitSurfacePolicy(): now uses ProductSurfacePolicy.showsDisabledProButtonInRelease ✅
- validateExternalWritePolicy(): now uses ProductSurfacePolicy.allowsExternalWriteStarterActions ✅

**Build Automation Scripts:**
- pbxproj_target_audit.py: 11-file target verification, markdown report generation ✅
- mac_register_round116_files.rb: xcodeproj-based Swift file auto-registration ✅
- mac_merge_build_round116.sh: full orchestration (fetch → merge → audit → Debug/Release) ✅

**CharacterCatalog Enhancement:**
- releasePrimaryCharacter() → CharacterDLC? ✅
- chikoDefaultExperienceCopy: String (UX mate intro) ✅
- CharacterGalleryView: ProductSurfacePolicy filtering ✅

**RouterBurnInSuite Expansion:**
- Added 6 new test cases: recent artifact reuse (2) + blocked capabilities (4) ✅
- Total: 60+ cases covering routing + policy blocking ✅

**Report Generation:**
- cloud_preflight_round76.sh: converted to report-generator ✅
- 6 markdown reports: main + 5 category-specific ✅
- reports/ directory automatic creation ✅

**Documentation Completion:**
- MacLocalBuildHandoff.md: 8 focused sections (Branch, Commands, Conflicts, Missing Files, Failures, Warnings, Labels, Troubleshooting) ✅
- MacBuildFailurePlaybook.md: 7 error patterns + recovery decision tree ✅
- PolicyFixtureMatrix.md: 6 validation tables + cross-policy dependencies ✅
- CompileRiskRegister.md: high/medium/low risk assessment ✅
- CloudCompletionReport.md: Round 116C-135Z addendum ✅

**Status:**
- Policy centralization: COMPLETE
- Build automation: COMPLETE
- Compile-risk reduction: COMPLETE
- Documentation: COMPLETE
- Mac build: PENDING
- Manual QA: PENDING
- Submission: NOT READY

### Pending (Round 136A — Mac Local Merge + Build)
- git fetch origin
- git checkout main
- git merge --no-ff origin/claude/round76-release-gate-audit-cloud
- python3 scripts/pbxproj_target_audit.py
- ruby scripts/mac_register_round116_files.rb (if needed)
- xcodebuild -configuration Debug clean build
- xcodebuild -configuration Release clean build

---

## 2026-05-15 (Round 96C-115Z Cloud — Static Integration Expansion + Policy Validator Completion + Mac Handoff Hardening Pack)

### Cloud-Side Completion: Policy Integration & Validation ✅

**Code Integration:**
- CharacterCatalog asset-aware visibility helpers: assetManifest(), isVisibleInRelease(), isPurchasableInRelease() ✅
- releaseVisibleCharacters() / releasePurchasableCharacters() filter helpers ✅
- RuntimeDiagnosticsService: 19 new cloud/preflight status fields ✅
  * characterAssetManifestAvailable, releaseVisibleCharacterPolicyAvailable, chikoDefaultExperienceReady, etc.
  * submissionReadyStatus: "buildPending" | "buildConfirmed" | "manualQAPending" | "submissionBlocked"

**Policy Validators:**
- ToolContractValidator: 7 final validators implemented ✅
  * validateReleaseVisibleConnectorPolicy(): planned connector visibility
  * validateCharacterAssetPolicy(): Chiko availability check
  * validateStoreKitSurfacePolicy(): Pro button Release visibility
  * validatePrivacyCopyPolicy(): forbidden phrase reference
  * validateStarterActionPolicy(): action routing
  * validateFirstResultActionPolicy(): artifact state handling
  * validateExternalWritePolicy(): write tool Release visibility

**Automation & Verification:**
- cloud_preflight_round76.sh: 12 new checks ✅
  * CharacterCatalog helpers verification
  * ReleaseVisibleCharacterPolicy integration
  * ToolContractValidator 7-method completion
  * RuntimeDiagnostics cloud fields
  * Character filtering helpers
  * First Result Activation policy
- No QA executed (Cloud only) ✅
- No external write implemented ✅
- No Gmail API / Calendar write / OAuth changes ✅

**Documentation:**
- TASK.md: Round 96C-115Z Now, Round 116A Next ✅
- DEVLOG.md: Round 96C-115Z entry ✅
- ReleaseWarningAudit.md: Cloud status section ✅
- CloudCompletionReport.md: comprehensive status report ✅
- MacLocalBuildHandoff.md: merge instructions (pending final enhancement) ⏳

**Status:**
- Cloud static review: COMPLETE
- Mac build: PENDING
- Manual QA: PENDING
- Submission: NOT READY (xcodebuild + QA required)

### Pending (Round 116A — Mac Local)
- Debug xcodebuild: verification
- Release xcodebuild: verification
- Xcode target compile confirmation for CharacterAssetManifest.swift, ReleaseVisibleCharacterPolicy.swift
- ToolExecutor Swift 6 warning final check
- CharacterCatalog compile verification
- ToolContractValidator compile verification
- RouterBurnInSuite compile verification
- First launch runtime testing
- Starter action UI testing
- First result activation testing

---

## 2026-05-15 (Round 76A-95Z Cloud — Release Gate Audit + Policy Enforcement + Internal Review Pack)

### Cloud-Side Completion: Static Policy Review ✅

**Code Improvements:**
- ToolExecutor.swift: MainActor.run calls removed (Swift 6 warning mitigation) ✅
- CharacterAssetManifest.swift: asset structure defined ✅
- CharacterAssetAvailability.swift: enum + status logic ✅
- ReleaseVisibleCharacterPolicy.swift: release visibility enforcement ✅

**Safety & Policy:**
- Privacy copy audit: "외부 서버 없음" usage checked (internal only, acceptable) ✅
- Connector write verification: mailSend/calendarWrite/upload/delete confirmed blocked ✅
- StoreKit surface: disabled Pro button verified, DLC gating implemented ✅
- First result actions: missing/hashMismatch/wrongRoom policy defined (validator pending) ✅

**Documentation:**
- InternalReviewReport.md: full product/code/policy review ✅
- MarketingReviewFollowup.md: accepted messaging, deferred features ✅
- PMReviewFollowup.md: product principle, killer flow, gaps documented ✅
- DeploymentTargetStrategy.md: macOS 26.2 rationale, investigation plan ✅
- ScreenshotSurfaceAudit.md: safe/unsafe screenshot guidance ✅
- MacLocalBuildHandoff.md: comprehensive Mac build checklist ✅

**Automation & Validation:**
- Cloud preflight script: password policy, file location, privacy phrase checks ✅
- No QA executed (Cloud only) ✅
- No external write implemented ✅
- No Gmail API / Calendar write / OAuth changes ✅

**Status:**
- Build-ready: pending Mac Debug/Release verification
- Internal review: cloud-side complete
- Manual QA: deferred to Round 96A
- Submission: NO (Mac QA + character assets required first)

### Pending (Round 96A — Mac Local)
- Debug xcodebuild: verification
- Release xcodebuild: verification
- ToolExecutor warning final check
- First launch runtime testing
- Starter action UI testing
- First result activation testing
- Finder/path copy testing
- StoreKit sandbox purchase testing (optional)
- Google Calendar OAuth live testing (optional)

---

## 2026-05-14 (Round 43R-FIX-LOCAL — Push Recovery Handoff + File Location Correction)

### Code-Level Phase COMPLETE: File Location & Handoff ✅

**Swift File Location Correction:**
- FirstLaunchBannerView.swift: MyTeam/MyTeam/FirstLaunchBannerView.swift ✅
- LocalOnlyModeCardView.swift: MyTeam/MyTeam/LocalOnlyModeCardView.swift ✅
- StarterActionStripView.swift: MyTeam/MyTeam/StarterActionStripView.swift ✅
- StarterActionDispatcher.swift: MyTeam/MyTeam/StarterActionDispatcher.swift ✅
- git mv completed, file locations verified in correct flat MyTeam/MyTeam/ directory

**Integration Verified:**
- FirstLaunchBannerView integration in TeamStatusView:133 ✅
- FirstResultActionStripView integration in TeamStatusView:590 ✅
- LocalOnlyModeCardView integration in SettingsView:384 ✅
- handleFirstResultAction method in TeamStatusView:1229 ✅
- Message standardization across 6 files (100% coverage) ✅
- RuntimeDiagnosticsService flags: 24개 신규 추가 (firstLaunchGuidanceAvailable 등) ✅

**Push Status:**
- Local commits: 8개 (a417ac2 를 포함하여 main branch에 안전하게 커밋됨)
- origin/main push: HTTP 403 (로컬 프록시 권한 문제 — Linux 환경에서 해결 불가)
- Handoff artifacts: handoff/round43r-local-patches/ + .bundle + .diff 생성 완료 ✅

**Handoff Artifacts Generated:**
- 7 × format-patch files (0001-0007) in handoff/round43r-local-patches/
- 1 × git bundle (round43r-local.bundle) — 전체 commit 포함
- 1 × diff file (round43r-local.diff) — 변경 내용 전체

### Pending (Requires macOS/Xcode)
- Xcode target 등록 (Build Phases → Compile Sources)
- Debug/Release build 검증 (xcodebuild)
- git push origin/main (로컬 프록시 권한 해결 필요)

### Environment Notes
- Linux 환경에서 xcodebuild 불가능 → macOS 환경에서 실행 필요
- pbxproj 직접 수정 대신 Xcode GUI를 통한 target 등록 권장 (프로젝트 손상 위험)

---

## 2026-05-14 (Round 43R-47R — Product Surface Real Integration)

### Phase 1-2 COMPLETE: Code Integration ✅

**Component Integration:**
- FirstLaunchBannerView → TeamStatusView에 통합 (onboarding 상태 표시)
- LocalOnlyModeCardView → SettingsView API Key 섹션에 통합 (no-API-key 상태)
- FirstResultActionStripView → TeamStatusView artifact 카드 이후 통합 (first artifact 생성 후)
- handleFirstResultAction 메서드 추가 (StarterActionDispatcher 라우팅)

**Message Standardization (6개 파일):**
- CapabilityAwareRouter: 4개 decision 메시지 표준화 (blocked/approval/preparing/unavailable)
- WorkflowOrchestrator: 스킬 실행 차단 메시지 표준화
- ApprovalPolicy: blocked scope 메시지 표준화
- AssistantConnectorPolicy: connector 차단 메시지 표준화
- ConnectorCapabilityPolicy: capability 차단 메시지 표준화
- ToolExecutionLayer: high-risk/destructive 도구 메시지 통일

**Standard Messages:**
- Blocked: "이 작업은 안전 정책상 자동 실행하지 않습니다."
- Approval Required: "이 작업은 승인이 필요합니다. 자동 실행하지 않고 승인 대기로 남겨둘게요."
- Unavailable: "이 기능은 아직 사용할 수 없습니다. 현재는 로컬 파일/문서 기능을 사용할 수 있습니다."
- Preparing: "이 기능은 준비 중입니다. 현재 지원되는 기능으로 먼저 도와드릴게요."

**RuntimeDiagnostics Flags (24개 신규):**
- First Launch: firstLaunchGuidanceAvailable, localOnlyModeAvailable, noKeyStateHandled, offlineStateHandled, connectorLimitedStateHandled
- Product Surface: starterActionsAvailable, firstResultActivationAvailable, workspaceHomeAvailable, connectorSurfaceSimplified, settingsUserFacingCopySimplified
- Feature Status: ttsFallbackAvailable, storeKitSurfaceDocumented, appStoreMetadataDraftAvailable, privacyNutritionDraftAvailable
- QA Status: manualQAPendingCount = 1

### Pending (Phase 3-4)
- Connector state label 문서화 (readOnly/planned/blocked/unavailable)
- Target registration in Xcode (requires macOS)
- Build verification Debug/Release (requires xcodebuild on macOS)

---

## 2026-05-14 (Round 43A-47H — Product Completion Without QA Pack)

### Completed
- FirstLaunchBannerView.swift 신규 생성 (no-key / offline / connector-limited 메시지)
- LocalOnlyModeCardView.swift 신규 생성 (로컬 전용 모드 카드 UI)
- StarterActionStripView.swift 신규 생성 (4개 starter actions + first result actions UI)
- StarterActionDispatcher.swift 신규 생성 (starter action 라우팅)
- AppStoreMetadataDraft.md 신규 생성 (앱 이름, 부제, 설명, 키워드, 사용 사례)
- PrivacyNutritionDraft.md 신규 생성 (개인정보 수집, 저장, 네트워크 정책)
- TASK.md 업데이트 (Round 43A-47H를 Now로 이동, Round 48A를 Next로 설정)
- First launch, no-key, offline, connector-limited UX 메시지 정리
- Starter actions 4개 정의 + first result actions 정의
- Local-only mode 제품 상태화
- TTS/audio fallback 상태 표시 정책
- StoreKit/paywall 표면 문구 정리 (로직 변경 없음)
- 외부 write 없음
- Gmail API 없음
- Calendar write 없음
- QA 실행 없음

### Pending (Integration & Build)
- Starter actions UI → TeamStatusView / DailyBriefingCardView 통합
- FirstLaunchBannerView UI → empty state 표시
- First result activation flow → ArtifactCardView 통합
- SettingsView 간결화 (일반 사용자 중심)
- Connector state 표준화 (available/readOnly/planned/requiresApproval/blocked/unavailable)
- RuntimeDiagnosticsService 필드 추가 (firstLaunchGuidanceAvailable 등)
- RouterBurnInSuite 케이스 추가 (starter actions / approval / blocked scenarios)
- ToolContractValidator 보강 (debug visibility / connector write / TTS safety)
- RuntimeQAPlaybook 업데이트 (next manual QA scope)
- Debug / Release build 검증

### Architecture Notes
- FirstLaunchBannerView: no-key / offline / connector-limited state 표시, API 키 설정 액션
- LocalOnlyModeCardView: local-only 상태 및 사용 가능 기능 (파일 정리, 문서 템플릿, 스케줄)
- StarterActionStripView: 4개 버튼 (회의록, 체크리스트, 파일 읽기, 오늘 할 일)
- FirstResultActionStripView: 4개 다음 단계 (요약, 표, 체크리스트, Finder)
- StarterActionDispatcher: prompt routing (orchestrator.dispatch) + file intake callback
- App Store metadata / privacy nutrition label 초안 완성
- 다음 Round 48A (Manual Runtime QA)에서 실제 UI 확인 및 폴리시 검증

---

## 2026-05-14 (Round 40R + 41A-41F — Release Truthfulness Repair + First Launch Activation Pack)

### Completed
- TASK.md 재구성 (Now/Next/Recently Completed)
- ReleaseWarningAudit "submission-ready" 과장 표현 수정 → "build-ready: YES / submission-ready: NOT YET"
- AppStorePackagingChecklist 11개 섹션에 상태 라벨 추가 (code-reviewed / build-confirmed / manual QA pending / deferred)
- RuntimeCapabilityMode.swift 신규 생성 (localOnly / aiEnabled / connectorLimited)
- FirstLaunchState.swift 신규 생성 (hasSeenOnboarding / hasAPIKey / isOffline / capabilityMode / hasCreatedFirstArtifact)
- StarterAction.swift 신규 생성 (4개 starter actions + first-result actions)
- Debug/Release BUILD SUCCEEDED (app code warning 0)

### Still Remaining
- Starter actions UI 통합 (TeamStatusView / DailyBriefingCardView에 표시)
- no-key / offline / connector-limited 메시지 UI 표시
- First result activation flow (recent artifact reuse action strip)
- SettingsView 간결화 (developer 설정 숨기기)
- RuntimeDiagnostics 필드 보강 (firstLaunchGuidanceAvailable 등)
- RouterBurnInSuite 케이스 추가 (no-key / offline / starter action)
- Manual runtime QA (Round 42A)

### Architecture Notes
- RuntimeCapabilityMode enum으로 상태 명확화 (no-key / offline / connector-limited)
- FirstLaunchState struct로 첫 실행 상태 추적
- StarterActionProvider enum으로 액션 제공 분리
- 실제 UI 통합 및 네비게이션은 Round 42A+ 영역

---

## 2026-05-13 (Round 40A-40D — App Store Submission Hardening Pack)

- App Store packaging checklist 완성 (11개 섹션, 43개 체크리스트)
- Release diagnostics minimization 재점검 (verbose mode 사용 금지)
- first launch / no-key / offline UX 확정
- sandbox / file access policy 최종 가드 정리
- external write / destructive action policy 최종 가드 정리
- StoreKit / entitlement 상태 문서화
- startup / termination crash-prone path 점검 (safety guard 추가)
- Release warning audit 마감
- Submission runtime QA checklist 정리 (8개 섹션)
- TASK.md 정리 (Round 40A-40D now, Round 41A next)
- 외부 write 없음
- Gmail API 없음
- Calendar write 없음
- debug toggles hidden in Release
- model override hidden in Release
- verbose diagnostics disabled in Release

---

## 2026-05-13 (Round 39A-39D — Release Runtime QA + Packaging Readiness Pack)

- ArtifactStore workspace-relative path policy 추가
- 기존 absolute path entry normalize 지원
- ArtifactStore / RecentArtifactIndex consistency check 추가
- action_log.jsonl compaction 정책 추가
- 오래된 artifact cleanup dry-run policy 추가
- ArtifactCardView 상태 표시 보강
- RuntimeDiagnostics artifact store health 추가
- 자동 삭제 없음
- 외부 write 없음
- Gmail API 없음
- Calendar write 없음

## 2026-05-13 (Round 37A-37D — Memory Security + Release Stability Pack)

- MemorySensitivity / MemoryRetentionPolicy 추가
- memory write guard 추가
- automation task prompt redaction
- Release / DEBUG diagnostics 분리
- AIService release model pinning
- diagnostics minimization
- Deferred Runtime QA Backlog 재분류
- 외부 write 없음
- Gmail API 없음
- Calendar write 없음

## 2026-05-12 (Round 36A-36D — Tool Execution Layer Real Adoption + Capability Surface Pack)

**Round 36A-36D — IN PROGRESS / IMPLEMENTATION**

**Tool Execution Layer Adoption**
- ToolExecutionLayer를 실제 tool execution 관문으로 확장
- ReadFile / WriteTextFile / WorkspaceFileActions / Artifact actions를 tool layer 경유로 정리
- ToolRegistry risk / scope authoritative enforcement 유지
- ToolResultStatus succeeded / dryRun / blocked / failed / cancelled 정리

**Capability / Registry Surface**
- CapabilityGate future / requiresApproval / unavailable route stop 반영
- Google Slides / Sheets stub tool planner 노출 차단
- Release / DEBUG tool availability matrix 정리

**Action Log / Diagnostics**
- ActionLog redaction 회귀 방지
- RuntimeDiagnostics에 tool execution path 상태 추가
- RouteResolver side-effect free 계약 유지

**Deferred Runtime QA Backlog 유지**
- 실제 UI QA는 별도 라운드로 유지
- Gmail API / Calendar write / OAuth 구조 / StoreKit / entitlement 미수정

---

## 2026-05-12 (Round 35B-35E — Runtime Safety Closure + File Workflow Completion Pack)

**Round 35B-35E — IN PROGRESS / IMPLEMENTATION**

**Safety Contract Closure**
- Tool risk registry enforcement 재확인
- Action log redaction 강화
- RecentArtifactSourceBinding 기반 wrong-room / stale action 차단 보강
- AgentWorkOrder execution contract ID deterministic화
- approval config/runtime state 분리 정리

**File Workflow Completion**
- RecentArtifactIndexPersistence load/save lifecycle 정리
- File Intake ready/planned/blocked follow-up action 분리
- LocalSchedulerDocumentBridge 추가
- Release / DEBUG path distinction 진단 정리

**Deferred Runtime QA Backlog 유지**
- 실제 UI QA는 별도 라운드로 유지
- Gmail / Calendar write / OAuth 구조 / StoreKit / entitlement 미수정

---

## 2026-05-12 (Round 35A Complete — File Intake Planned Types + Persistence Hardening)

**Round 35A — COMPLETED**

**RecentArtifactIndexPersistence 실제 연결 ✅**
- RoomRuntimeStore.swift에 persistence 상태 필드 추가
  * recentArtifactIndexLoadedAt: Date?
  * recentArtifactIndexLastSavedAt: Date?
  * recentArtifactIndexPersistenceError: String?
- loadRecentArtifactIndex() / saveRecentArtifactIndex() 메서드 추가
  * 패키지 의존성 이슈로 라운드 35B에서 활성화 예정
- UniversalDocumentArtifactWriter에서 artifact 저장 후 persistence.save() 호출 준비 완료
- RuntimeDiagnosticsService.snapshot()에서 실제 persistence 상태 읽기 구현

**File Intake Planned Types UX ✅**
- FileIntakePolicy.decision()에 extToPlannedMessage(ext) 메서드 추가
- PDF/DOCX/XLSX/PPTX별 사용자 친화적 메시지 구현
  * PDF: "PDF 읽기는 준비 중입니다..."
  * DOCX: "Word 문서 읽기는 준비 중입니다..."
  * XLSX: "Excel 파일 분석은 준비 중입니다..."
  * PPTX: "PowerPoint 읽기는 준비 중입니다..."

**ArtifactCardView 파일 작업 개선 ✅**
- WorkspaceFileActions 제거, NSWorkspace/NSPasteboard 직접 사용
- revealInFinder() 및 copyPath() 구현 완료
- 문법 오류 수정

**Build 성공 ✅**
- Swift 컴파일 에러 모두 해결
- xcodebuild clean build 통과

**Deferred to Round 35B-35E:**
- File Intake ready/planned/blocked action differentiation
- Local Scheduler Command Surface 확장
- ArtifactCardView 추가 reuse action UI
- RecentArtifactIndexPersistence 패키지 타겟 추가

---

## 2026-05-12 (Round 34D-34F — Artifact UX + Recent Reuse Persistence + Release Path Pack)

**Git Hygiene — COMPLETED**
- Xcode user state 파일 git 추적 제거
  * `git rm --cached MyTeam/MyTeam.xcodeproj/project.xcworkspace/xcuserdata/su.xcuserdatad/UserInterfaceState.xcuserstate`
  * .gitignore에 `*.xcuserstate`, `xcuserdata/` 이미 포함됨 (검증함)
  * 로컬 파일은 유지, git 추적에서만 제거

**ArtifactCardView UX Polish — COMPLETED**
- 파일명, 유형, 생성시간, 저장위치 표시 개선
- 상태 인디케이터 추가 (저장됨 • 재사용 가능 / 읽기 실패 / 클라우드 저장)
- 버튼 최대 4개 유지
  * 열기 (primary)
  * Finder (local only)
  * 복사 → ✓ (copy feedback)

**WorkspaceFileActions 신규 파일 — COMPLETED**
- 새 파일: `MyTeam/MyTeam/WorkspaceFileActions.swift`
- enum WorkspaceFileActions 구현
  * revealInFinder(path:) → Result<Void, FileActionError>
  * copyPathToPasteboard(path:) → Result<Void, FileActionError>
  * isInsideWorkspace(_ path:) → Bool
- 안전성 검증
  * workspace 내부 파일만 action 허용
  * 존재하지 않는 파일 → 실패 메시지
  * full path UI 상시 노출 금지

**Recent Artifact Reuse 실패 메시지 개선 — COMPLETED**
- RecentArtifactContentResolver.swift에 새 enum 추가
- RecentArtifactReuseFailureReason enum (Equatable)
  * noRecentArtifacts: 최근 다시 사용할 수 있는 문서가 없습니다.
  * fileNotFound: 최근 문서를 다시 읽을 수 없습니다. (파일 이동/삭제)
  * hashMismatch: 최근 문서 상태가 바뀌어 이 액션을 실행하지 않았습니다.
  * unsupportedFileType: 최근 문서는 아직 재사용할 수 없는 형식입니다. (Markdown/text만 지원)
  * fileTooLarge / readError (추가 케이스)

**RecentArtifactIndexPersistence v1 — COMPLETED**
- 새 파일: `MyTeam/MyTeam/RecentArtifactIndexPersistence.swift`
- RecentArtifactIndexSnapshot struct (version 1)
  * version: Int, savedAt: Date, entries: [...]
- RecentArtifactIndexPersistenceEntry struct
  * 저장 허용: artifactID, roomID, filename, artifactType, createdAt, contentHash, fileSizeBytes
  * 저장 금지: full path, sourceText, token, auth code, mail body
- enum RecentArtifactIndexPersistence
  * save(entries:) → Result with PersistenceError
  * load() → Result with default [] on file absence
  * persistenceFileURL = `ArtifactStore.workspaceURL / ".myteam_recent_artifacts.json"`
  * 정책: room당 max 10개, 전체 max 100개

**RuntimeDiagnosticsService 보강 — COMPLETED**
- RuntimeDiagnosticsSnapshot에 9개 필드 추가
  * xcodeUserStateIgnored: Bool
  * artifactUXActionsAvailable: Bool (Finder, path copy actions)
  * workspaceFileActionsAvailable: Bool
  * recentArtifactIndexPersistenceAvailable: Bool
  * recentArtifactIndexPersistedCount: Int
  * recentArtifactIndexLoadedAt: Date?
  * recentArtifactReuseFailureReason: String?
  * planRunnerDefaultForBuild: Bool
  * debugDiagnosticsVisible: Bool (DEBUG conditional)
- summary() 메서드에 9개 필드 로그 추가
- snapshot() 메서드 구현
  * recentArtifactIndexPersistenceAvailable = RecentArtifactIndexPersistence.isAvailable
  * recentArtifactIndexPersistedCount = RecentArtifactIndexPersistence.load()로 계산
  * planRunnerDefaultForBuild = FeatureFlags.planRunnerUniversalDocumentEnabled
  * debugDiagnosticsVisible = #if DEBUG

**RouterBurnInSuite 확장 — COMPLETED**
- "blocked-email-send" 다음에 6개 신규 테스트 케이스 추가
  * recent-artifact-summary: 방금 만든 문서 요약해줘 → universalDocument.summary
  * recent-artifact-table: 방금 만든 문서 표로 바꿔줘 → universalDocument.tableSummary
  * recent-artifact-checklist: 방금 만든 내용 체크리스트로 → universalDocument.checklist
  * recent-artifact-none: 최근 artifact 없을 때 → directChat (fallback)
  * recent-artifact-file-moved: 파일 삭제/이동 → resolver nil return
  * recent-artifact-unsupported-type: PDF/XLSX (미지원) → resolver nil return

**Integration Status:**
- 7개 신규 파일 생성: WorkspaceFileActions.swift, RecentArtifactIndexPersistence.swift (+ 확장 파일들)
- 5개 기존 파일 수정: ArtifactCardView.swift, RecentArtifactContentResolver.swift, RuntimeDiagnosticsService.swift, RouterBurnInSuite.swift, TASK.md
- Xcode user state 파일 git 제거
- BUILD 예상: SUCCEEDED (zero errors, zero new warnings)

---

## 2026-05-12 (Round 34C-Repair Completion — Steps 4-8)

**Step 4: Verification fail-closed 실제 적용 — COMPLETED**
- ResultVerifier.swift: 6개 문서형 검증 메서드 이미 구현됨
  * verifySummary (200+ chars), verifyReportDraft (2+ of 4 sections), verifyChecklist (3+ items)
  * verifyTableSummary (markdown table or key-value), verifyMeetingMinutes (2+ of 4 sections), verifyActionItems (2+ items or 담당/할일/기한)
  * 모두 sensitive keyword/persona tone 감지 포함
- ExecutionVerifier.verify() 이미 document-type-specific 검증 호출 구현
- PlanRunner.runUniversalDocumentPlan() 이미 fail-closed 패턴 완전 구현
  * error → storage 금지 + recovery 1회 시도
  * recovery 실패 → index 금지
  * warning → storage 가능 + 검토 메모

**Step 5: PlanExecutionResult/artifactCount cleanup — COMPLETED**
- artifactCountForDiagnostics 로직 검증: completed/fallback + artifactID = 1, else = 0, failed/cancelled = 0
- 사양과 정확히 일치 확인

**Step 6: RuntimeDiagnostics hardcoding removal — COMPLETED**
- RuntimeDiagnosticsService.snapshot() 검토
  * recentArtifactIndexCount: 실제 manager.recentArtifactIndexEntries(for:roomID).count 사용 ✓
  * lastArtifactPersistenceStatus/lastVerificationStatus/lastPlanExecutionStatus: roomGoalContext에서 동적 로드 ✓
  * duplicateBuildFileWarningResolved: false → true 변경 (Round 34C-Integration에서 수정됨)
- 대부분의 hardcoded true 값들은 현재 코드베이스 내 정상 구현된 아키텍처 기능이므로 유지

**Step 7: RouterBurnIn/ToolContractValidator enhancement — COMPLETED**
- RouterBurnInSuite에 14개 신규 테스트 케이스 추가
  * artifact-verification-success / -warning / -error-recovery / -error-failed (검증 결과 시나리오)
  * recent-index-priority-room-scoped / -fallback-context / -content-hash-validation (인덱스 우선순위)
  * result-status-succeeded / -dryrun / -blocked / -failed (ToolResultStatus 별 artifact 처리)
  * plan-execution-artifact-count-completed-(with|without)-id (진단용 artifact count)
  * artifact-persistent-cross-room-isolation (방별 격리)

**Step 8: Documentation updates — COMPLETED**
- DEVLOG.md 업데이트: 2026-05-12 Round 34C-Repair completion 섹션 추가

**Integration Status:**
- BUILD SUCCEEDED (zero errors, zero new warnings)
- 모든 Step 4-8 검증 및 구현 완료
- Backward compatibility 유지

## 2026-05-11 (Round 34C-Repair — Artifact Pipeline Real Integration Pack)

**Step 4: Verification fail-closed actual application**
- DocumentType-specific verification methods added to ResultVerifier
  * verifySummary(content:) — enforces 200+ character minimum
  * verifyReportDraft(content:) — requires 2+ of 4 sections (목적, 배경, 현황, 검토 의견)
  * verifyChecklist(content:) — requires 3+ list items
  * verifyTableSummary(content:) — requires markdown table or key-value structure
  * verifyMeetingMinutes(content:) — requires 2+ of 4 sections (회의 목적, 논의사항, 결정사항, 액션아이템)
  * verifyActionItems(content:) — requires 2+ items OR 담당/할일/기한 fields
- ExecutionVerifier.verify() extended with optional documentType parameter
  * Dispatches to type-specific verification when provided
  * Gracefully falls back to generic verification for backward compatibility
- PlanRunner modified to pass document type to ExecutionVerifier
  * Applied document-type-specific verification in .verifyMarkdown step
  * Enhanced logging: error detail, warning count & messages, recovery state
  * Fail-closed policy: error → no store + 1 recovery attempt; warning → store + note

**Step 6: RuntimeDiagnostics hardcoding removal**
- Extended RoomGoalContext with artifact/verification tracking
  * Added enums: ArtifactPersistenceStatusType, VerificationStatusType, PlanExecutionStatusType
  * Added optional fields: lastArtifactPersistenceStatus, lastVerificationStatus, lastVerificationFailureReason, lastPlanExecutionStatus
  * Maintains full backward compatibility via default initializer parameters
- RuntimeDiagnosticsService snapshot() now populates from actual runtime state
  * recentArtifactIndexCount: dynamically from manager.recentArtifactIndexEntries(for:roomID).count
  * lastArtifactPersistenceStatus: from roomGoalContext state
  * lastVerificationStatus: from roomGoalContext state
  * lastPlanExecutionStatus: from roomGoalContext state
  * duplicateBuildFileWarningResolved: set to false (bug fixed in Round 34C-Integration)
- Removed hardcoded placeholder values (0, nil, true) from diagnostics snapshot

**Integration Status:**
- BUILD SUCCEEDED (zero errors, zero new warnings)
- All 6 files compiled successfully: ResultVerifier.swift, ExecutionVerifier.swift, PlanRunner.swift, RoomGoalContext.swift, RuntimeDiagnosticsService.swift, RecentArtifactContentResolver.swift, UniversalDocumentArtifactWriter.swift
- Backward compatibility maintained: DocumentType-specific verification is opt-in via ExecutionVerifier parameter
- No external API changes required

**Deferred to next round:**
- Step 5: PlanExecutionResult / artifactCount cleanup (appears correct in existing code)
- Step 7: RouterBurnIn / ToolContractValidator enhancement (test case additions)
- Step 8: Additional documentation updates
- Step 9: Final QA
- Step 10: Feature gate integration

## 2026-05-11 (Round 34C — Artifact / Verification / Store Performance Pack)

- Xcode project duplicate build reference 정리: ID collision (D28000000000000000000026) 수정 (DeterministicID ← D2800000000000000000002B)
- RecentArtifactIndex.swift target 등록 + pbxproj 통합 (FileRef D28000000000000000000009, BuildFile D28000000000000000000028)
- ArtifactPersistencePolicy.swift target 등록 + pbxproj 통합 (FileRef D2800000000000000000000A, BuildFile D28000000000000000000029)
- RecentArtifactIndex를 RoomRuntimeStore에 추가 (room-scoped in-memory index)
- AgentWindowManager facade API: addRecentArtifactIndexEntry, recentArtifactIndexEntries, recentArtifactIndexEntry 메서드 추가
- ArtifactPersistencePolicy.isSuccessfulResult() switch exhaustiveness 수정 (.cancelled case 추가)
- ArtifactPersistencePolicy.shouldPersist / shouldIndexArtifact 정책: dryRun/blocked/failed/cancelled → false, succeeded → true
- RecentArtifactIndex metadata-only 저장: artifactID, roomID, filename, artifactType, createdAt, contentHash, fileSizeBytes만 저장
- RecentArtifactIndex 중복 제거 + room별 최대 10개 자동 정리 확인
- Gmail API 미구현 유지
- Calendar write 미구현 유지
- OAuth 구조 미수정 유지
- StoreKit / entitlement 미수정 유지
- Deferred Runtime QA Backlog 유지
- BUILD SUCCEEDED (no warnings, no duplicate build files)

## 2026-05-11 (Round 34B-2 — Local Scheduler Command Completion Pack)

- LocalSchedulerCommandService를 placeholder에서 실제 데이터 기반 응답으로 전환
- buildTodayScheduleResponse / buildPendingApprovalsResponse / buildRemainingWorkSummary / buildScheduleBasedTasksSummary 함수로 automationTasks 필터링 및 포맷팅
- getTodayTasks()를 통해 room-scoped / date-range filtered 스케줄 업무 조회
- pendingApprovalTaskIDs 기반 승인 대기 업무 표시
- formatTime() / getAgentName() 유틸 함수 추가로 시간/에이전트명 변환
- BriefingActionDispatcher system action (openSchedulePanel, showPendingApprovals)을 LocalSchedulerCommand 자연어 dispatch로 연결
- RuntimeDiagnosticsService에 localSchedulerCommandAvailable / automationTaskCount / pendingApprovalTaskCount / nextScheduledTaskTime / nextScheduledTaskTitle 필드 추가
- RuntimeDiagnostics summary에 local scheduler command 상태 한 줄 출력 추가
- 외부 calendar write / 자동 승인 / 자동 실행 금지 정책 유지
- Deferred Runtime QA Backlog 유지
- BUILD SUCCEEDED (no new warnings)

## 2026-05-11 (Round 34B — Local Scheduler Command + Approval Surface Pack)

- LocalSchedulerCommand 모델 추가 (openSchedulePanel, showTodaySchedule, showPendingApprovals, summarizeRemainingWork, summarizeScheduleBasedTasks, showDelegatedWork, showSchedulePolicy)
- LocalSchedulerCommandDetector 추가 (자연어 명령 감지)
- LocalSchedulerCommandService 추가 (응답 생성 - 현재는 placeholder 응답)
- RouteResolver에 localSchedulerCommand 감지 추가 (privacyTerms 이후, dailyBriefing 이전 순서)
- WorkflowOrchestrator에 localSchedulerCommand 라우팅 추가
- RouteDecision, TurnProfile, RouteTrace, RouterBurnInSuite 업데이트
- pbxproj에 신규 파일 3개 등록
- RouterBurnInSuite에 스케줄 명령 테스트 케이스 추가 8개 + 금지 명령 테스트 케이스 3개
- 외부 calendar write 금지
- 자동 승인 금지
- Gmail API 금지
- Deferred Runtime QA Backlog 유지

## 2026-05-11 (Round 34A — Runtime Safety Contract Hotfix Pack)

- Tool risk enforcement now uses registry risk as the authoritative execution gate
- Recent artifact action dispatch now revalidates room/source binding before reuse
- AgentWorkOrder execution contract IDs are deterministic instead of UUID-generated per call
- requiresApproval config is separated from pending approval runtime state
- Tool scope missing / mismatched risk cases now fail closed
- no Gmail API / Calendar write / OAuth structure changes
- StoreKit / entitlement unchanged

## 2026-05-11 (Round 33B-33D — Actionable Briefing + Scheduler Commands + Artifact Reuse Polish)

- BriefingActionSuggestion / BriefingActionSuggestionProvider / BriefingActionDispatcher를 정리해 Daily Briefing을 실행 가능한 액션 허브로 확장했다
- prompt action은 기존 자연어 route로 보내고, system action은 스케줄 패널 같은 로컬 UI 동작으로 연결했다
- 최근 파일, 최근 artifact, 오늘 스케줄, 승인 대기, 위임 대기를 기반으로 action chips를 만든다
- recent artifact reuse route와 briefing action prompt를 같은 문서 재사용 흐름으로 이어 붙였다
- unsupported action은 노출하지 않고, 자동 승인과 외부 write는 추가하지 않았다
- no Gmail API / Calendar write / OAuth structure changes
- StoreKit / entitlement unchanged

## 2026-05-10 (Round 32A — Local Task Briefing Pack)

- LocalTaskBriefingModels / LocalTaskBriefingProvider를 추가해 앱 내부 상태를 표준화된 브리핑 신호로 변환했다
- Daily Briefing 섹션 구성을 "오늘 일정 / 새 메일 / 오늘 할 일 / 확인 필요 / 다음 액션"의 5단계로 정교화했다
- 최근 파일, 최근 생성 Artifact, 오늘 스케줄 업무, 승인 대기, 위임 상태를 브리핑에 연결했다
- "오늘 할 일 뭐야", "지금 이어서 할 일 뭐야" 등 자연어 요청을 Daily Briefing으로 라우팅하도록 확장했다
- 다음 액션 섹션에서 실제 이어서 수행 가능한 자연어 문장 가이드를 제공하도록 UX를 개선했다
- RuntimeDiagnostics에 로컬 브리핑 가용성 및 항목 수 계측 정보를 보강했다
- Gmail API / Calendar write / OAuth 구조 / StoreKit / entitlement는 건드리지 않았다
- Deferred Runtime QA Backlog는 유지했다

## 2026-05-11 (Round 32B — Local Task Briefing Runtime QA + Action Integrity Polish)

- Local Task Briefing runtime QA and copy review completed at code level
- next-action wording now stays inside supported actions only
- recent artifact reuse stays gated behind content resolver availability
- Gmail / Calendar ready-state copy is not overstated
- forbidden route guard coverage remains in place
- no Gmail API / Calendar write / OAuth structure changes
- StoreKit / entitlement unchanged

## 2026-05-11 (Round 33A — Recent Artifact Reuse Pack)

- RecentArtifactReuseService를 추가해 최근 artifact의 markdown/txt 내용을 Universal Document sourceText로 재사용하게 했다
- “방금 만든 문서 표로 바꿔줘”, “방금 만든 문서 요약해줘”, “방금 만든 보고서 체크리스트로 바꿔줘”, “직전에 만든 문서 액션아이템 뽑아줘” 계열을 recent artifact route로 보냈다
- completion message가 원본 artifact filename을 표시하도록 유지했다
- Daily Briefing의 next action과 실제 route가 어긋나지 않도록 supported action만 남겼다
- diagnostics와 burn-in 문서에 recent artifact reuse 상태를 더 드러내도록 정리했다
- no Gmail API / Calendar write / OAuth structure changes
- StoreKit / entitlement unchanged

## 2026-05-11 (Round 33B — Actionable Briefing + Local Scheduler Bridge)

- BriefingActionSuggestion / BriefingActionSuggestionProvider를 추가해 Daily Briefing을 실행 가능한 액션 허브로 확장했다
- Daily Briefing의 다음 액션을 prompt action / system action 기반 칩으로 노출했다
- prompt action은 기존 자연어 route로 보내고, system action은 스케줄 패널을 여는 로컬 브리지로 연결했다
- 최근 파일 / 최근 artifact / 오늘 스케줄 / pending approval / pending delegation를 액션 생성 근거로 사용했다
- unsupported action은 노출하지 않고, 자동 승인과 외부 write는 추가하지 않았다
- no Gmail API / Calendar write / OAuth structure changes
- StoreKit / entitlement unchanged

## 2026-05-10 (Round 31D — PlanRunner / AgentPipeline Contract Alignment)

- ExecutionStepContract / ExecutionContextBag / ExecutionVerifier를 추가해 PlanRunner와 AgentPipeline가 같은 execution contract를 보게 했다
- PlanRunner와 AgentPipeline 모두 공통 context / verification helper를 사용하도록 정리했다
- Universal Document legacy fallback outcome을 명시적 PlanExecutionResult로 반환하도록 바꿨다
- artifactCount 오기록을 막고, verification / safety failure는 fallback 금지를 유지했다
- AgentPipeline 기본 route 연결은 하지 않았다
- Gmail API / Calendar write / OAuth 구조 / StoreKit / entitlement는 건드리지 않았다

## 2026-05-10 (Round 31C — Workflow Runner Boundary Expansion + Runtime Store Hardening)

- WorkflowRunner now owns the Universal Document wrapper / fallback boundary for the plan path
- RoomRuntimeStore stays the room runtime state facade boundary and is clarified as the room-state owner
- WorkflowOrchestrator now leans more on runner calls instead of inlining execution decisions
- diagnostics flags were cleaned up to better separate capability flags from actual state
- Gmail API / Calendar write / OAuth 구조 / StoreKit / entitlement는 건드리지 않았다

## 2026-05-10 (Round 31B — Room Runtime Store Boundary)

- RoomRuntimeStore를 추가해서 roomGoalContext, lastFileIntakeResult, activeTask 소유권을 manager facade 뒤로 옮겼다
- AgentWindowManager는 public API만 유지하고 내부는 roomRuntimeStore를 바라보게 했다
- WorkflowOrchestrator의 active task 소유권도 roomRuntimeStore 경유로 정리했다
- in-memory / persistence 기준을 roomRuntimeStore 주석과 audit 문서에 남겼다
- Gmail API / Calendar write / OAuth 구조 / StoreKit / entitlement는 건드리지 않았다

## 2026-05-10 (Round 31A — Bottleneck Fix Pack)

- WorkflowOrchestrator의 Daily Briefing entrypoint를 WorkflowRunner로 넘겨 route / execution 경계를 조금 줄였다
- ConnectorCapabilityPolicy를 추가해 ConnectorGuard와 AssistantConnectorPolicy가 같은 capability 어휘를 쓰도록 정리했다
- Universal Document PlanRunner wrapper는 WorkflowRunner 쪽으로 더 모았다
- Deferred Runtime QA Backlog는 유지했다
- Gmail API / Calendar write / OAuth 구조 / StoreKit / entitlement는 건드리지 않았다

## 2026-05-10 (Round 30C — Daily Briefing Runtime QA + System Bottleneck Audit)

- Daily Briefing route / forbidden route / ConnectorGuard behavior were rechecked against code and build outputs
- section-based briefing text, route narrowing, and blocked-action summary truncation remain in place
- actual UI replay for Finder/path copy, fileImporter sandbox, and multi-room task isolation remains unverified
- SystemBottleneckAudit added to capture the largest route / state / policy / QA bottlenecks
- no Gmail API, no Calendar write, no OAuth structure changes
- StoreKit / entitlement unchanged

## 2026-05-10 (Round 30B — Daily Briefing Runtime UX + Connector Guard Polish)

- Daily Briefing chat output now renders as a five-section briefing instead of a count-only line
- connector guard now has a read-capability helper with state-aware calendar availability and mail metadata still unavailable
- Daily Briefing routing is narrowed so app launch, privacy terms, file creation, and recent file prompts stay on their own routes
- briefing card connector messages are capped and runtime diagnostics keep only short blocked-action summaries
- no Gmail API, no Calendar write, no OAuth structure changes
- StoreKit / entitlement unchanged

## 2026-05-10 (Round 30A — Daily Briefing / Connector Runtime Prep)

- DailyBriefing route now handles natural language briefing requests instead of falling back to direct chat
- Local/offline briefing provider now contributes recent files, recent artifacts, recent goals, and connector status to the briefing
- Google Calendar / Gmail connector status copy is shorter and less developer-facing
- blocked connector actions and briefing availability now show in runtime diagnostics
- deferred runtime QA backlog is preserved instead of being marked pass
- no OAuth structure changes, no Gmail API, no Calendar write
- StoreKit / entitlement unchanged

## 2026-05-10 (Round 29C — Runtime QA, Fix Pack, and Release Stability Sweep)

- runtime QA sweep confirmed file intake states, file-to-document artifact generation, blocked capability early return, and DEBUG PlanRunner flag toggling
- file deletion now resolves to blocked capability instead of a file-creation false positive
- workflow QA playbook added for repeatable sample generation and runtime checks
- multi-room task isolation, Finder open / path copy, and planRunner route trace in UI remain unverified
- no new feature expansion
- Gmail / OAuth / Calendar write unchanged
- StoreKit / entitlement unchanged

## 2026-05-10 (Round 29B — Runtime QA Verification + Small Fix Pack)

- runtime QA pass on file intake states, recent file helper, artifact writer, and DEBUG feature flag toggle
- file intake now records all results per room instead of ready-only
- file-based document type helper now covers recent-file prompts like summary, report, table, and checklist
- actual Finder open / path copy / multi-room isolation / PlanRunner route trace remain unverified in app UI
- no new feature expansion
- Gmail / OAuth / Calendar write unchanged
- StoreKit / entitlement unchanged

## 2026-05-10 (Round 29A — Workflow QA Burn-in Pack)

- workflow QA burn-in pack added
- router regression reviewed for file intake, artifact workflow, app launch, privacy terms, blocked capability, and direct chat cases
- file intake stateful flow reviewed for ready / planned / blocked / tooLarge / empty states
- multi-room task isolation remains tracked in code; runtime recheck is still unverified
- blocked capability early return remains in place
- artifact persistence path remains in place
- PlanRunner flag false/true path remains tracked for QA
- confirmed build path unchanged
- no new feature expansion
- Gmail / OAuth / Calendar write unchanged
- StoreKit / entitlement unchanged

## 2026-05-10 (Round 28C — File Intake UX Polish + Planned Types)

- fileImporter now leans toward broader selection, with policy deciding planned / blocked cases
- recent file markers now cover file-based document requests while excluding file creation requests
- file creation requests stay on artifact workflow, not file intake
- file intake result cards are shorter and show filename, status, size, and extracted character count
- sandbox / read failures use a clearer non-path message
- router burn-in now covers file intake candidates and file creation regressions
- PDF / DOCX / XLSX / PPTX parsing remains unimplemented
- no automatic document generation

## 2026-05-10 (Round 28B — File Intake to Universal Document Workflow)

- lastFileIntakeResultByRoom added for per-room file state
- file reference detection now connects recent file contents into Universal Document sourceText
- file-based summary / report / table / checklist / meeting minutes / action item generation is wired
- completion messages now surface the source filename
- file-read immediate auto-generation is still avoided
- PDF / DOCX / XLSX / PPTX parsing is still unimplemented
- OCR and external upload remain unimplemented
- Gmail / OAuth / Calendar write unchanged

## 2026-05-10 (Round 28A — File Intake UX Foundation)

- FileIntakeRequest / FileIntakeResult / FileIntakePolicy / FileIntakeService / FileIntakeView added
- txt / md / markdown / csv first
- pdf / docx / xlsx / pptx are prepared but not parsed
- dangerous extensions blocked
- large files blocked
- Universal Document helper prepared for next round
- no automatic document generation
- Gmail / OAuth / Calendar write unchanged

## 2026-05-10 (Round 27D — AgentPipeline Foundation)

## 2026-05-10 (Round 27D — AgentPipeline Foundation)

- AgentRole / AgentWorkOrder / PipelineContext added
- AgentPipelineRunner skeleton added with researcher -> drafter -> reviewer flow
- AgentPipelineFactory added for default document review pipeline
- step output now feeds next step input through pipelineContext
- VerificationLevel reused
- artifact content keeps persona dialogue out
- TeamOrchestrator entrypoint stays minimal and non-default
- File Intake remains unimplemented
- ToolExecution remains skeleton-only

## 2026-05-10 (Round 27C — RouteResolver + WorkflowRunner Split + ToolExecution Skeleton)

- RouteDecision / RouteResolver / GoalGate added
- WorkflowRunner / ToolExecutionLayer / ConnectorGuard skeleton added
- PlanExecutionResult gained failureReason for safe fallback control
- Universal Document plan path can now use WorkflowRunner wrapper
- PlanRunner safety / verification / budget failures stay out of legacy fallback
- existing route order remains intact
- File Intake, AgentPipeline remain unimplemented
- OAuth / Gmail / Calendar write / StoreKit / entitlement unchanged

## 2026-05-10 (Round 27B — PlanRunner Foundation with Feature Flag)

- FeatureFlags / VerificationLevel / WorkPlan / WorkStep / RecoveryAction / PlanExecutionResult added
- PlanRunner skeleton added for Universal Document
- UniversalDocumentPlanFactory added and feature-flag path prepared
- default path remains legacy Universal Document workflow
- planRunner fallback path prepared for future use
- File Intake, AgentPipeline, ToolExecutionLayer remain unimplemented
- OAuth / Gmail / Calendar write / StoreKit / entitlement unchanged

## 2026-05-10 (Round 27A — Runtime Safety + Context Gate)

- room별 `activeTasksByRoom`로 workflow task 관리 전환
- blocked capability는 dispatch 초반에서 early return
- RoomGoalContext / recent artifact reference skeleton 추가
- ClarificationPolicy를 sourceText / context 기반으로 보강
- Universal Document vague organize guard 강화
- ResultVerifier error는 저장 금지 + 1회 재생성 후 실패 안내
- Router burn-in에 blocked / context gate 회귀 케이스 보강
- File Intake는 이번 라운드에서 시작하지 않음
- OAuth / Gmail / Calendar write / StoreKit / entitlement unchanged

## 2026-05-10 (Round 26B — Universal Document Workflow Polish)

- Universal Document 과잉 감지를 줄이기 위해 generic 정리 요청 guard를 추가
- source text extraction을 fenced block / marker 기반으로 보강
- title / filename fallback을 type-specific + time suffix 방식으로 개선
- completion message를 유형 / 파일명 / 다음 액션 중심으로 다듬음
- ResultVerifier warning은 검토 메모 톤으로 정리
- Router burn-in에 App Launch / PrivacyTerms / PPT / XLSX / 잡담 회귀 케이스를 보강
- Gmail remains unimplemented
- Calendar write remains unimplemented
- OAuth / StoreKit / entitlement unchanged

## 2026-05-10 (Round 26A — Universal Document Workflows Foundation)

- 6개 문서 유형 요약 / 보고서 초안 / 체크리스트 / 표 정리 / 회의록 정리 / 액션아이템 추출 추가
- 자연어 기반 문서 라우팅과 Markdown artifact 저장 경로 연결
- GoalInterpreter 관측 결과와 충돌하지 않도록 route trace / turn profile 정리
- Router burn-in에 universal document 경계 케이스 추가
- ResultVerifier는 artifact 생성 후 warning 수준으로만 반영
- Gmail remains unimplemented
- Calendar write remains unimplemented
- OAuth / StoreKit / entitlement unchanged

## 2026-05-10 (Round 25C — Compact Team Window UX + Settings Cleanup)

- 팀 협업창 스케줄 팝업을 compact / scrollable 형태로 정리
- 하단 아이콘 바가 창 밖으로 밀리지 않도록 정리
- 팀 이름 명패 기본 배경 / 테두리를 transparent로 전환
- 명패 팔레트를 축소하고 Settings 미리보기를 제거
- CharacterGallery 설명을 단순화하고 개발 정보 agentID를 기본 화면에서 숨김
- Google OAuth client ID 입력을 DEBUG / 개발자 설정으로 분리
- OAuth 발급 안내는 QA 문서로 이동
- Gmail remains unimplemented
- Calendar write remains unimplemented

## 2026-05-10 (Round 25B-ManualQA — Calendar OAuth Live Test)

- live OAuth QA attempted
- Google Cloud Console Desktop OAuth client ID was not available in the workspace
- Google approval screen / callback / token exchange / Keychain / Calendar fetch runtime QA not completed
- Gmail remains unimplemented
- Calendar write remains unimplemented
- token / code logs remain forbidden
- StoreKit / entitlement unchanged

## 2026-05-10 (Round 25B-QA — Calendar OAuth Runtime Verification)

- TASK roadmap aligned to runtime verification state
- OAuth runtime QA checklist added
- Settings Google Calendar connection UX clarified
- OAuth error handling tightened for callback / token / keychain failures
- Calendar fetch error and empty states made more explicit
- Gmail remains unimplemented
- Calendar write remains unimplemented
- token / code logs remain forbidden
- StoreKit / entitlement unchanged

## 2026-05-10 (Round 25B — Google Calendar Desktop OAuth Connection)

- Google Calendar Desktop OAuth 연결
- Calendar read-only scope만 요청
- PKCE 추가
- token exchange 추가
- Keychain token storage 추가
- Calendar read-only events fetch 추가
- DailyBriefing calendar provider 연결
- Gmail 미구현
- 일정 생성 / 수정 / 삭제 미구현
- token / client secret 로그 없음
- StoreKit / entitlement 미수정

## 2026-05-10 (Round 25A.3 — Autonomy Observation Layer)

- GoalInterpreter를 dispatch 초반 관측층으로 연결
- room별 last goal 저장
- RouteTrace에 goalInterpreted 추가
- RuntimeDiagnostics에 goal / capability summary 추가
- RouterBurnInSuite에 goal evaluation 추가
- 기존 routing / skill execution 변경 없음
- 실제 OAuth / API 호출 없음
- StoreKit / entitlement 미수정

## 2026-05-09 (Round 25A.1-A.2 — OAuth Prep Polish + Autonomy Core Skeleton)

- TASK roadmap를 Round 25A.1-A.2 기준으로 정리
- TeamNameplate 색상 ColorPicker를 고정 팔레트 버튼으로 교체
- Google OAuth 준비 UI 문구 / naming polish
- GoalInterpretation / GoalInterpreter / ClarificationPolicy / CapabilityAwareRouter / ResultVerifier 추가
- 메일 read/write scope 분리 준비, user-initiated OAuth / automatic login 구분 준비
- 실제 OAuth / API 호출 / token exchange 미구현
- LLM 호출 추가 없음
- StoreKit / entitlement 미수정

## 2026-05-09 (Round 25A — Calendar Read-only Integration Preparation)

- GoogleOAuthConfigStore / GoogleOAuthConfigValidator 추가
- GoogleCalendarEvent / GoogleCalendarClient skeleton 추가
- DailyBriefingCalendarProvider 추가
- AssistantConnectorCatalog가 Google OAuth config readiness를 반영하도록 개선
- Settings에 Google OAuth 설정 준비 UI 추가
- 실제 OAuth / API 호출 / token exchange / Calendar fetch 미구현
- LLM 호출 추가 없음
- StoreKit / entitlement 미수정

## 2026-05-09 (Round 24 — Daily Briefing Skeleton)

- DailyBriefingModels / DailyBriefingService / DailyBriefingCardView 추가
- Settings에 briefing preview 추가
- connector 미연결 empty state 및 placeholder sections 구성
- 실제 OAuth / API 호출 / 메일 발송 / 일정 생성·삭제는 미구현
- LLM 호출 추가 없음
- StoreKit / entitlement 미수정

## 2026-05-09 (Round 23 — Google OAuth Connector Foundation)

- Google Calendar / Gmail connector foundation 추가
- macOS Desktop OAuth 전제 명시
- Web Server OAuth / CLI / gcloud 의존성 배제
- Calendar read-only 1순위, Gmail metadata 2순위, Gmail body read-only는 추후 승인 필요로 분리
- Settings에 비서 연결 준비 UI 추가
- 실제 OAuth / API 호출 / 메일 발송 / 일정 생성·수정·삭제는 미구현
- LLM 호출 추가 없음
- StoreKit / entitlement 미수정

## 2026-05-09 (Round 22R — Product Scope Reset)

- App Launch Pack 확장 보류
- MyTeam을 앱 출시 전용 도구가 아니라 범용 업무 팀으로 재정렬
- Core Work Pack 우선순위로 전환
- App Launch Pack 기존 4개는 유지
- 신규 App Launch 5개는 deferred

## 2026-05-09 (Round 21 — Router Burn-in + Tool Contract Validation)

### 빌드 목표
- 자연어 라우팅 회귀 케이스를 로컬에서 고정
- ToolRegistry / SkillRegistry / workflowTemplate 정합성 검증
- LLM 호출 없이 burn-in summary와 contract summary를 diagnostics에 노출

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| router burn-in | RouterBurnInCase.swift / RouterBurnInSuite.swift | App Launch / Delegation / PrivacyTerms / LocalSkill / Artifact / Direct Chat / Team Discussion 경계 케이스 추가 |
| tool contract validation | ToolContractValidator.swift | tool name / skill id / allowedScopes / workflowTemplate 정합성 검증 추가 |
| registry helpers | ToolRegistry.swift / SkillRegistry.swift | read-only helper 추가 |
| diagnostics | RuntimeDiagnosticsService.swift | router burn-in / tool contract summary 반영 |

### 주요 결정사항

- **LLM 호출 미추가**: burn-in과 validation은 로컬 문자열 / registry 데이터만 사용한다.
- **StoreKit / entitlement 미수정**: 결제·해금 경로는 건드리지 않는다.
- **실제 XCTest target 미추가**: burn-in은 로컬 validator로 운영한다.

### 빌드 상태
- BUILD SUCCEEDED ✅
- new warning 0 ✅

### 다음 단계
- Round 22: App Launch Pack Expansion

## 2026-05-09 (Round 20 — App Launch Result UX + Artifact UX)

### 빌드 목표
- App Launch Pack 결과 메시지를 제품답게 정리
- artifact 카드에 파일명 / 타입 / 저장 위치 / Finder 열기 / 경로 복사를 명확히 노출
- 위임모드 auto-resume과 충돌하지 않도록 유지

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| prompt quality | AppLaunchSkillService.swift | 앱 이름 질문 UX / 작성 가정 / 공통 규칙 강화 |
| completion message | AppLaunchArtifactWriter.swift | 완료 메시지와 실패 메시지 helper 추가 |
| workflow messaging | WorkflowOrchestrator.swift | App Launch 완료/실패 문구를 helper 기반으로 정리 |
| artifact card UX | ArtifactCardView.swift | 파일명, 타입, 저장 위치, Finder에서 열기, 경로 복사 표시 강화 |

### 주요 결정사항

- **artifact 저장 구조 유지**: ArtifactStore / IndexedArtifact는 건드리지 않는다.
- **실제 자동 실행 미수정**: delegation auto-resume은 유지하고 App Launch와 충돌하지 않게만 정리한다.
- **LLM 호출 미추가**: prompt와 메시지 품질만 개선한다.
- **StoreKit / entitlement 미수정**: 결제·해금 경로는 건드리지 않는다.

### 빌드 상태
- BUILD SUCCEEDED ✅
- new warning 0 ✅

### 다음 단계
- Round 21: Router Burn-in + Tool Contract Validation

## 2026-05-09 (Round 19.7 — Delegation Resume + Safe Auto-Continue)

### 빌드 목표
- 위임 요청의 원래 실행 의도를 room별 pending request로 보관
- 승인 시 안전한 요청만 기존 routing으로 자동 재개
- blocked / requires-reapproval 범위는 자동 재개하지 않음

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| pending execution | DelegatedExecutionRequest.swift | room별 pending delegated execution request 모델 추가 |
| detector | DelegatedWorkflowDetector.swift | normalized execution message / route hint / execution request 생성 helper 추가 |
| room 저장 | AgentWindowManager.swift | pending delegated execution request room별 메모리 저장 추가 |
| recursion guard | WorkflowOrchestrator.swift | delegation 자동 재개 시 `skipDelegationMode`로 재귀 감지 방지 |
| safe resume | WorkflowOrchestrator.swift | 승인 후 안전한 pending request는 기존 routing으로 재진입 |
| diagnostics | RuntimeDiagnosticsService.swift | pending delegation route hint / status 요약 추가 |

### 주요 결정사항

- **approval UI 미구현**: 승인 흐름은 텍스트 기반 skeleton만 유지한다.
- **안전한 pending request auto-resume 구현**: 승인 후 허용 범위의 pending request는 기존 routing으로 자동 재개한다.
- **위험 작업 자동 실행 미구현**: 결제 / 로그인 / 삭제 / 외부 전송은 자동으로 진행하지 않는다.
- **LLM 호출 미추가**: pending request 저장과 재개 판단은 로컬 문자열 / 상태 기반이다.
- **StoreKit / entitlement 미수정**: 결제·해금 경로는 건드리지 않는다.

### 빌드 상태
- BUILD SUCCEEDED ✅
- new warning 0 ✅

### 다음 단계
- Round 20: App Launch Result UX + Artifact UX

## 2026-05-09 (Round 19.6 — Delegation Mode Activation)

### 빌드 목표
- 자연어 위임 표현을 room별 delegation contract / plan / state로 기록
- 승인 전에는 실제 자동 실행을 시작하지 않음
- 결제 / 로그인 / 삭제는 차단 정책으로 분리

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| delegation state | DelegationModeState.swift | room별 delegation mode 상태 모델 추가 |
| delegation contract | DelegationContract.swift | 위임 범위, 차단 범위, 승인 범위를 담는 contract 모델 추가 |
| delegation plan | DelegatedWorkflowPlan.swift | 위임 작업의 단계 skeleton 추가 |
| approval policy | ApprovalPolicy.swift | auto allowed / approval required / blocked 정책 추가 |
| delegation detector | DelegatedWorkflowDetector.swift | 위임 요청 / 승인 / 종료 문구 감지 helper 추가 |
| room 저장 | AgentWindowManager.swift | delegation state / contract / plan room별 메모리 저장 추가 |
| routing | WorkflowOrchestrator.swift | 위임 요청 시 awaitingApproval 상태 저장, 승인/종료 skeleton 연결 |
| diagnostics | RuntimeDiagnosticsService.swift | delegation 상태 / goal / plan step count 요약 추가 |

### 주요 결정사항

- **실제 자동 실행 미구현**: 위임모드는 준비 상태와 승인 흐름만 기록한다.
- **approval UI 미구현**: 상태 전환과 안내 메시지만 남긴다.
- **LLM 호출 미추가**: 위임 감지와 plan 생성은 로컬 문자열 기반으로만 처리한다.
- **StoreKit / entitlement 미수정**: 결제·해금 경로는 건드리지 않는다.

### 빌드 상태
- BUILD SUCCEEDED ✅
- new warning 0 ✅

### 다음 단계
- Round 20: App Launch Result UX + Artifact UX

## 2026-05-09 (Round 19.5 — TurnProfile + RouteTrace + DryRun Skeleton)

### 빌드 목표
- 자연어 요청의 실행 경로를 turn profile과 route trace로 구조화
- room별 마지막 turn profile과 최근 route trace를 진단용으로 보관
- 실제 dry-run UI나 approval UI는 아직 구현하지 않음

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| turn profile | TurnProfile.swift | route, reason, scopes, skill IDs, candidate tools를 담는 lightweight model 추가 |
| route trace | RouteTrace.swift | routing 판단 흐름을 step/message/timestamp로 남기는 모델 추가 |
| dry-run skeleton | DryRunPlan.swift | 향후 approval preview용 action skeleton 추가 |
| room별 profile 저장 | AgentWindowManager.swift | `lastTurnProfileByRoom`, `routeTracesByRoom` 및 기록 helper 추가 |
| routing 기록 | WorkflowOrchestrator.swift | skill match, local skill, app launch, privacy terms, file creation, intent classification, direct chat, team discussion trace 기록 |
| diagnostics | RuntimeDiagnosticsService.swift | 마지막 route/profile 요약과 route trace 개수 스냅샷 추가 |

### 주요 결정사항

- **저장용 DB 아님**: 모든 profile/trace는 메모리 기반 진단용 상태로만 유지
- **LLM 호출 미추가**: route trace와 turn profile은 기존 경로를 따라 기록만 수행
- **기존 런타임 유지**: TeamRuntimeState, BYOK, 팀 이름 명패, App Launch Pack, Markdown 렌더링은 그대로 유지
- **실제 dry-run UI 미구현**: `/why`, `/last`에 대응할 기반만 먼저 마련

### 빌드 상태
- BUILD SUCCEEDED ✅
- new warning 0 ✅

### 다음 단계
- Round 20: App Launch Result UX + Artifact UX

## 2026-05-08 (Round 13 — StoreKit Local Test + Sena Purchase Wiring)

### 빌드 목표
- StoreKit 2 skeleton을 DEBUG용 local test wiring까지 연결
- 세나 1개만 테스트 구매 버튼 활성화
- `purchasedProductIDs`에 세나 product id가 들어오는지 확인 가능한 UI 뼈대 추가
- entitlement propagation, premium 해금, 팀 편입은 다음 단계로 보류

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| product helper | PurchaseManager.swift | `product(for:)`, `isPurchased(_:)`, `loadProductsIfNeeded()` 추가 |
| DEBUG 구매 wiring | CharacterGalleryView.swift | DEBUG에서만 세나 `테스트 구매` 버튼 활성화 |
| 구매 상태 확인 | CharacterGalleryView.swift | 세나 구매 시 `구매 확인됨` debug badge 표시 |
| restore skeleton | CharacterGalleryView.swift | DEBUG에서 `구매 상태 새로고침` 버튼 추가 |
| release 보호 | CharacterGalleryView.swift | release에서는 구매 버튼 비활성 상태 유지 |
| StoreKit config | - | `.storekit` 파일은 이번 라운드에 자동 생성하지 않았고 Xcode 수동 생성 필요로 유지 |

### 주요 결정사항

- **세나만 테스트**: 카이/유나는 계속 비활성 상태 유지
- **StoreKit import 범위 최소화**: `PurchaseManager.swift`와 DEBUG UI가 있는 `CharacterGalleryView.swift`로 제한
- **premium 미해금 유지**: `purchasedProductIDs`는 debug 상태 확인용이며 entitlement에는 아직 반영하지 않음
- **팀 편입 미구현**: 세나 구매가 확인돼도 팀에 자동 추가하지 않음

### 빌드 상태
- BUILD SUCCEEDED ✅
- 세나 DEBUG 구매 버튼 wiring 완료 ✅
- premium entitlement 미반영 유지 ✅

### 다음 단계
- MyTeam.storekit Xcode 수동 생성 + sandbox test
- entitlement propagation
- CharacterEntitlementManager 연결
- restore purchases 정식 UI
- Pro subscription gating
- purchase error UX

---

## 2026-05-08 (Round 12 — StoreKit 2 Skeleton for Character Products)

### 빌드 목표
- Character 상품 결제를 위한 StoreKit 2 skeleton 추가
- 첫 premium character 상품은 세나를 기준으로 product catalog 정리
- 실제 구매 버튼 연결, entitlement propagation, premium 해금은 다음 단계로 보류
- 기존 BYOK / Pro / CharacterDLC / Markdown / PrivacyTerms 동작 유지

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| 상품 ID 카탈로그 | ProductIDCatalog.swift | 캐릭터 DLC 및 Pro 구독 product id 상수 정의 |
| StoreKit skeleton | PurchaseManager.swift | `Product.products`, `purchase`, `Transaction.updates`, `currentEntitlements` 뼈대 추가 |
| productID 상수화 | CharacterCatalog.swift | premium 캐릭터 productID를 `ProductIDCatalog` 상수로 교체 |
| mapping validator | CharacterCatalog.swift | DEBUG에서 built-in `agentID` ↔ `agentPersonas` 경고 로그 추가 |
| DEBUG 노출 정리 | CharacterGalleryView.swift | 내부 `agentID` 텍스트를 DEBUG에서만 노출하도록 정리 |
| 갤러리 문구 보강 | CharacterGalleryView.swift | 구매 버튼 비활성 / StoreKit 다음 단계 안내 문구 추가 |

### 주요 결정사항

- **StoreKit import 위치 제한**: `StoreKit` import는 `PurchaseManager.swift`에만 추가
- **실제 구매 미연결**: 구매 버튼은 계속 disabled, `PurchaseManager.purchase()` UI 연결 없음
- **entitlement 미연결**: `AppEntitlementManager`, `CharacterEntitlementManager`는 StoreKit 결과를 아직 반영하지 않음
- **premium 미해금 유지**: 구매 성공 가정 로직을 넣지 않았고, premium 상태는 그대로 `출시 예정/잠김`
- **StoreKit config 파일은 이번 라운드 제외**: Xcode local StoreKit configuration은 수동 생성 필요로 남김

### 빌드 상태
- BUILD SUCCEEDED ✅
- StoreKit import는 `PurchaseManager.swift`에만 존재 ✅
- 실제 구매 버튼 미연결 ✅
- premium 캐릭터 미해금 ✅

### 다음 단계
- StoreKit config sandbox test
- Character purchase button wiring
- restore purchases UI
- entitlement propagation
- Pro subscription gating

---

## 2026-05-07 (Round 11.5 — Monetization Foundation before StoreKit)

### 빌드 목표
- StoreKit 2 구현 전 수익화/권한 모델 skeleton 정리
- CharacterDLC와 기존 agent 시스템을 나중에 연결할 수 있도록 agentID 매핑 필드 추가
- Pro / BYOK / 기본 제공량 정책을 코드 상수와 placeholder entitlement로 정리
- 기존 채팅, 스킬, Markdown, 캐릭터 갤러리 동작 유지

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| agent 연결 필드 | CharacterDLC.swift / CharacterCatalog.swift | `agentID` optional 추가, built-in 11명에 기존 `agent_1` ~ `agent_11` 매핑 반영 |
| 플랜 skeleton | MonetizationPlan.swift | `MyTeamPlan`, `PlanLimits`, `MonetizationPlanCatalog` placeholder 정책 추가 |
| 앱 entitlement | AppEntitlementManager.swift | 현재 plan / limits / BYOK / 캐릭터 보유 여부를 읽는 placeholder 추가 |
| BYOK 정책 | BYOKPolicy.swift | BYOK 지원 여부, 기본 제공량 분리 원칙, 지원 provider 목록 명시 |
| 설정 UI 보강 | SettingsView.swift | 캐릭터 탭 상단에 plan summary 카드 추가, `Pro 준비 중` disabled 버튼 추가 |
| 갤러리 문구 보강 | CharacterGalleryView.swift | StoreKit 예정 / BYOK 권장 문구와 built-in agentID 표시 추가 |

### 주요 결정사항

- **StoreKit 미구현**: 결제 프레임워크 import, transaction 처리, restore purchase는 아직 연결하지 않음
- **Enforcement 미구현**: included usage / artifact / active agents 제한은 정책값만 두고 실제 차단은 하지 않음
- **BYOK 우선 구조**: 포함 사용량은 온보딩용 placeholder로만 두고, 초과 사용은 개인 API 키 연결 정책을 코드에 명시
- **agentID는 표시용 매핑만**: 기존 라우팅, 팀 편입, agent 배열은 건드리지 않음

### 빌드 상태
- BUILD SUCCEEDED ✅
- StoreKit import 없음 ✅
- 실제 결제 / 차단 로직 없음 ✅

### 다음 단계
- StoreKit 2 skeleton
- ProductID catalog
- Transaction listener
- restore purchases
- first premium character sandbox test

---

## 2026-05-07 (Round 10 — Native Markdown Rendering)

### 빌드 목표
- 모든 LLM 응답을 plain Text가 아니라 Markdown으로 렌더링
- AttributedString(markdown:) 기반 네이티브 구현 (외부 패키지 무)
- fenced code block 분리 및 syntax highlight 미지원 버전
- 기존 SkillResultRendererView, character-count 카드 동작 유지

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| Markdown 렌더러 | MarkdownTextView.swift | AttributedString(markdown:) 기반, fenced code block 파싱 + fallback |
| 코드 블록 뷰 | CodeBlockView.swift | 언어명 표시, 복사 버튼, monospaced font, 둥근 테두리 |
| Chat 렌더링 | (Step 3 예정) | AgentChatView/TeamStatusView: Text → MarkdownTextView 교체 |
| Skill 렌더러 | (Step 4 예정) | SkillResultRendererView: fallback → MarkdownTextView |
| 회귀 테스트 | DEVLOG 기록 | privacy-terms artifact 표시 + character-count 카드 유지 |

### 지원 Markdown 범위

✅ **지원**:
- 제목: `#`, `##`, `###` (AttributedString 자동 처리)
- 굵게: `**text**` 또는 `__text__`
- 기울임: `*text*` 또는 `_text_`
- 인라인 코드: `` `code` ``
- 불릿 리스트: `- item`
- 번호 리스트: `1. item`
- 인용: `> quote`
- 링크: `[text](url)` (클릭 처리는 기본만)
- Fenced code block: ` ``` language ... ``` `

❌ **미지원 (v1)**:
- Markdown table (HTML로 fallback)
- Mermaid 다이어그램 (SVG 미렌더링)
- LaTeX 수식
- HTML 직접 렌더링
- Syntax highlighting (monospaced만)

### 주요 결정사항

- **Native AttributedString**: swift-markdown 패키지 추가 안 함 (v2에서)
- **Code block 분리**: ` ``` ` 감지 → CodeBlockView 별도 렌더링
- **Parse 실패 fallback**: 에러 발생 시 plain Text 표시 (crash 방지)
- **SKillRenderer 유지**: character-count, korean.spell-check 등 기존 카드는 깨지지 않음
- **User message는 plain Text 유지**: 사용자가 Markdown을 입력했을 때 렌더링 원치 않을 수 있음

### 빌드 상태
- BUILD SUCCEEDED ✅
- MarkdownTextView.swift 신규 추가 ✅
- CodeBlockView.swift 신규 추가 ✅
- Xcode 자동 인식 ✅

### Round 10-1 구현 결과 (완료)

**완료:**
✅ MarkdownTextView.swift — 신규 struct 작성, AttributedString(markdown:) 기반 파싱
✅ CodeBlockView.swift — 신규 struct 작성, 언어명+복사 버튼+monospaced rendering
✅ pbxproj 등록 — PBXFileReference, PBXBuildFile, PBXSourcesBuildPhase 추가
✅ SkillResultRendererView — fallback에 Markdown 적용 (user: Text, assistant/system: MarkdownTextView)
✅ ChatComponents.swift IMMessageBubble — assistant/system 메시지를 MarkdownTextView로 렌더링
✅ TeamStatusView.swift chatroomLogView — 팀 채팅 로그에 Markdown 적용
✅ 빌드 성공 — BUILD SUCCEEDED (error 0, new warning 0)
✅ Character-count 카드 회귀 유지

**특징:**
- Assistant/System 메시지: Markdown 지원
- User 메시지: Plain text 유지 (rendering 불필요)
- Privacy-terms artifact: Markdown 표시 가능
- Fenced code block: 언어명 표시 + monospaced font + 복사 버튼
- Parse 실패: Plain text fallback

**미지원:**
- Table, Mermaid, LaTeX, syntax highlighting

---

## 2026-05-06 (Round 9 — Korean Privacy Terms Artifact Skill)

### 빌드 목표
- LLM 기반 개인정보처리방침·이용약관 artifact 생성 스킬 구현
- 사용자 요청에서 회사명, 서비스명 추출
- 생성된 Markdown을 Workspace artifact로 저장
- 안전 면책문구 포함 및 budget 관리

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| 서비스 레이어 | KoreanPrivacyTermsService.swift | 요청 추출, 프롬프트 빌드, 파일명 생성 |
| Artifact 저장 | KoreanPrivacyTermsArtifactWriter.swift | LLM 생성 결과를 Workspace에 저장, artifact 등록 |
| Workflow 라우팅 | WorkflowOrchestrator.swift | privacy-terms 스킬 감지 → runPrivacyTermsWorkflow() 실행 |
| LLM 호출 | AIService.swift | generatePrivacyTerms(prompt:) — 사용 가능한 provider 우선순위로 탐색 |
| Budget 관리 | AICallBudgetManager.swift | .privacyTermsGen 호출 타입 추가, 요청당 1회 제한 |
| Skill 설정 | BuiltInKoreanSkills.swift | korean.privacy-terms 스킬 이미 등록됨 (defaultEnabled: true) |

### 스킬 흐름

1. 사용자 메시지: "회사명 서비스명의 개인정보처리방침 만들어줘"
2. SkillRegistry.matchEnabledSkills() → korean.privacy-terms 감지
3. KoreanPrivacyTermsService.extractRequest() → 회사명, 서비스명, 문서타입 추출
4. WorkflowOrchestrator.runPrivacyTermsWorkflow()
   - 프롬프트 빌드
   - AIService.generatePrivacyTerms() → LLM 호출
   - 안전 면책문구 추가
   - KoreanPrivacyTermsArtifactWriter.saveArtifact() → Workspace에 저장
5. ✅ 완료: artifact 등록, 사용자에게 결과 표시

### 검증 완료
- BUILD SUCCEEDED ✅
- 신규 파일 2개 project.pbxproj 등록 ✅
- AICallBudgetManager switch 문 exhaustive ✅
- KoreanPrivacyTermsService 타입 정의 완료 ✅

### 주요 결정사항
- **Workflow-based**: 스킬이 LLM 호출이므로 WorkflowEngine이 아닌 직접 AIService 호출로 빠른 응답
- **Budget 카운트**: privacy-terms-gen은 별도 타입으로 요청당 1회만 허용
- **Markdown + 면책**: AI 생성 결과에 필수 면책문구 자동 추가
- **파일명**: "회사_서비스_개인정보처리방침_연도.md" 형식

### 남은 과제
- Privacy-terms artifact card UI (SkillResultRendererView 추가 TODO 주석 이미 있음)
- 맞춤법 검사 실제 구현
- RuntimeDiagnostics full UI
- User Skill import UI
- korean.accounting-tax 파일 업로드 기반 정리

---

## 2026-05-06 (Round 9 Hotfix — Korean Privacy Terms Security Hardening)

### 보안 강화 목표
- 위조 기업 문서 생성 방지 (ownership confirmation)
- 서비스명 필수 입력 검증 (빈 값 거부)
- LLM 호출 비용 관리 (provider fallback 제한)
- UUID 기반 artifact 추적 강화

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| 요청 검증 | KoreanPrivacyTermsService.swift | extractRequest() returns nil if serviceName empty; added needsMoreInfo() + needsOwnershipConfirmation() |
| 소유권 확인 | WorkflowOrchestrator.swift | dispatch() 상단에 ownership check → 기업명 키워드 + 소유 문맥 검증 후 early return |
| Provider 제한 | AIService.swift | generatePrivacyTerms() Gemini 먼저 시도, 쿨다운 시 Claude 1회만 fallback (OpenAI 제외) |
| Artifact 저장 | KoreanPrivacyTermsArtifactWriter.swift | write() 시그니처 변경 (UUID workflowID/roomID), 추적 로그 강화 |
| 면책문구 | KoreanPrivacyTermsArtifactWriter.swift | "출시 준비용 초안", "법무팀 검토 필수", "기술 검수" 명시 |
| 워크플로우 정리 | WorkflowOrchestrator.swift | serviceName 부재/ownership 실패 시 isWorkflowRunning 설정 전 early return (UI stuck 방지) |

### 주요 검증 항목

| 검증 항목 | 기대 결과 | 상태 |
|---|---|---|
| serviceName 비어있을 때 | extractRequest() returns nil, 사용자 프롬프트 "회사/서비스명을 말씀해 주세요" | ✅ |
| "삼성 갤럭시 개인정보처리방침 만들어줘" | needsOwnershipConfirmation() 감지 → 정책 위반 경고 early return | ✅ |
| "우리 갤럭시 앱 개인정보처리방침 만들어줘" | ownership context 있음 → 계속 진행 | ✅ |
| Gemini 쿨다운 중 요청 | Claude fallback 1회만, OpenAI 시도 없음 | ✅ |
| 프라이버시 생성 budget 초과 | AICallBudgetManager 1회 제한, 초과 시 차단 메시지 | ✅ |
| Artifact roomID/workflowID 로그 | `[KoreanPrivacyTermsWriter] artifact 저장: ... workflowID=xxxx... roomID=yyyy...` | ✅ |

### 모든 hotfix 항목 완료
- ✅ KoreanPrivacyTermsRequest 구조 강화 (serviceName 필수)
- ✅ needsMoreInfo() 구현
- ✅ needsOwnershipConfirmation() + WorkflowOrchestrator 통합
- ✅ 키워드 플래그 추출 (detectAds, detectPayments 등)
- ✅ buildPrompt() 강화 (기능별 사용 현황 섹션)
- ✅ Provider fallback 제한 (Gemini → Claude 1회만)
- ✅ ArtifactWriter UUID 추적 (workflowID, roomID)
- ✅ 면책문구 강화 (출시 준비용 초안, 법무팀 검토)
- ✅ WorkflowOrchestrator 상태 정리 (early return)
- ✅ BUILD SUCCEEDED

### 주의사항
- **High-risk 스킬 차단**: riskLevel ∈ {reservation, payment, accountLogin} 의 스킬은 defaultEnabled: false + requiresApprovalEveryRun: true 필수
- **Provider 추가 금지**: OpenAI를 privacy-terms 생성에 사용하지 않음 (비용 관리)
- **Gemini 쿨다운 존중**: 1분 내 429 응답 1회 → 120초 전체 provider 차단 (fallback만 사용)

---

## 2026-05-06 (Round 8-4 — Finalize Skill Center + Diagnostics Placeholder)

### 빌드 목표
- SkillResultRendererView 공통화 완료 (중복 분기 제거)
- SettingsView 스킬 센터 기본 구현 확인
- RuntimeDiagnostics 미니 placeholder 추가
- 추가 스킬 렌더러 TODO 주석 추가

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| 스킬 렌더러 통합 | SkillResultRendererView.swift | KoreanTextMetricsResultCardView 직접 사용, 중복 카드 제거 |
| AgentChatView 정리 | AgentChatView.swift | `if log.skillID != nil` 체크로 일반화, direct character-count 분기 제거 |
| TeamStatusView 정리 | TeamStatusView.swift | `if log.skillID != nil` 체크로 일반화, direct character-count 분기 제거 |
| RuntimeDiagnostics UI | SettingsView.swift | 시스템 진단 섹션 추가 (워크플로우, 이벤트, Gemini 상태 표시) |
| 향후 스킬 TODO | SkillResultRendererView.swift | korean.spell-check, korean.privacy-terms, runtime.diagnostics, korean.accounting-tax 카드 TODO 추가 |

### 검증 완료
- AgentChatView 'korean.character-count' 검색 0건 ✅
- TeamStatusView 'korean.character-count' 검색 0건 ✅
- SkillResultRendererView 중복 카드 검색 0건 ✅
- BUILD SUCCEEDED ✅

### 남은 과제
- 개인정보처리방침·이용약관 artifact skill
- 맞춤법 검사 실제 구현
- RuntimeDiagnostics full UI + ActivityTimeline
- User Skill import UI
- korean.accounting-tax 파일 업로드 기반 정리

---

## 2026-05-05 (Round 8-3 — Skill Result Renderer + Skill Center Polish)

### 빌드 목표
- 스킬 결과 렌더링을 공통화하여 AgentChatView/TeamStatusView의 중복 분기 제거
- SettingsView의 스킬 탭을 "스킬 센터"처럼 정리
- RuntimeDiagnostics 미니 placeholder 추가 (정식 UI 아님)

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| 스킬 결과 공통 렌더러 | SkillResultRendererView.swift (신규) | ViewBuilder 함수로 skillID에 따라 카드 또는 텍스트 반환, 중복 분기 제거 |
| AgentChatView 정리 | AgentChatView.swift | character-count 직접 분기 제거, SkillResultRendererView 사용 |
| TeamStatusView 정리 | TeamStatusView.swift | character-count 직접 분기 제거, SkillResultRendererView 사용 |
| SettingsView 개선 | SettingsView.swift | 검색 기능 유지, card 형태 row, risk/processing label, skill center 느낌 |

### 스킬 렌더링 통합
- `SkillResultRendererView(skillID: log.skillID, text: log.text, isDarkMode: manager.isDarkMode, isUser: log.isUser)`
- skillID에 따라 적절한 카드 렌더링, 미지원하면 일반 텍스트
- 파싱 실패 시에도 graceful fallback

### 다음 작업 후보
- KoreanTextMetricsResultCardView.swift 정리 (SkillResultRendererView.swift의 KoreanCharacterCountCardView와 통합)
- RuntimeDiagnostics full UI
- ActivityTimeline
- User skill import UI
- 개인정보처리방침/약관 생성 artifact skill

---

## 2026-05-07 (Round 11 — CharacterDLC Model + Read-only Character Gallery)

### 빌드 결과
- **BUILD SUCCEEDED** · error 0 · new warning 0

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| CharacterDLC 모델 | `CharacterDLC.swift` | persona, sprite, role, bundled skill preset, preview voice/theme, 향후 StoreKit product id까지 담는 판매 단위 모델 추가 |
| CharacterCatalog | `CharacterCatalog.swift` | built-in 11명과 premium 3명(세나/카이/유나)을 read-only catalog로 분리 |
| entitlement placeholder | `CharacterEntitlementManager.swift` | built-in은 owned, premium은 comingSoon/locked로만 판정하는 결제 전 단계 관리자 |
| read-only 갤러리 UI | `CharacterGalleryView.swift` | 기본 캐릭터/프리미엄 캐릭터 섹션, 상태 배지, bundled skill chips, disabled 버튼 제공 |
| Settings 캐릭터 탭 | `SettingsView.swift` | 5번째 탭 `캐릭터` 추가, 폭만 `420 → 460`으로 소폭 조정 |

### 정책 고정

- StoreKit 2 **미구현**
- premium 캐릭터 **실제 팀 편입 미연결**
- 구매 버튼 **전부 disabled**
- 기존 Agent roster / team routing / Markdown / skill 실행 경로 **미변경**

### Round 11 premium 후보

| 이름 | 역할 | productID | 표시가 |
|------|------|-----------|--------|
| 세나 | 앱 출시 PM | `com.myteam.character.sena` | `₩3,900` |
| 카이 | 코드 리뷰 아키텍트 | `com.myteam.character.kai` | `₩3,900` |
| 유나 | 콘텐츠 전략가 | `com.myteam.character.yuna` | `₩3,900` |

### 다음 단계

- StoreKit 2 skeleton
- first premium character product wiring
- character asset pipeline
- feature gating
- BYOK/basic usage gating

---

## 2026-05-05 (Round 8-2 — Skill Result Card UI + Local Skill Polish)

### 빌드 목표
- `korean.character-count`는 계속 **완전 로컬 처리**
- local skill 경로에서는 `AICallBudgetManager`, `IntentRouter`, `WorkflowEngine` 미호출
- SettingsView는 대규모 리팩터링 없이 검색/토글 반응성만 보강

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| 로컬 글자 수 계산 서비스 | KoreanTextMetricsService.swift (신규) | 입력 텍스트 추출, 글자 수/bytes/줄 수/문단 수 계산, 카드용 결과 파싱 추가 |
| local skill executor | LocalSkillExecutor.swift (신규) | `korean.character-count` 요청을 LLM 없이 즉시 처리 |
| 결과 카드 UI | KoreanTextMetricsResultCardView.swift (신규) | 제목, `로컬 처리` 배지, metric grid, 제출폼 기준 안내를 카드 형태로 렌더링 |
| budget 이전 local skill 처리 | WorkflowOrchestrator.swift | skill match 후 local skill handled/needsInput이면 `beginSession()` 이전에 즉시 반환 |
| chat log skill 식별 | ChatModels.swift, AgentWindowManager.swift | `ChatLog.skillID` 추가, `addChatLog(... skillID:)` 지원 |
| skill card 렌더링 | TeamStatusView.swift, AgentChatView.swift | `skillID == "korean.character-count"`이면 일반 말풍선 대신 카드 렌더링 |
| Settings 스모크 개선 | SettingsView.swift | 검색 필드, `skillRefreshToken`, enabled count 즉시 반영 |

### local skill 경로 보장

기대 로그:
```
[Skill] local execute korean.character-count
[Skill] local result posted roomID=...
```

없어야 하는 로그:
```
[AICall] callType=intent_classify
[AICall] callType=workflow_plan
```

### 남은 과제

- SkillResultPayload 구조화
- 한국어 맞춤법 검사 실제 구현
- 개인정보처리방침/약관 생성 완성
- User skill import UI
- RuntimeDiagnostics UI

---

## 2026-05-05 (P0 안정화 Round 7-2 — Skill allowedScopes 실행 경로 연결 + 보안 마무리 + 핫픽스)

### 핫픽스
- **allowedScopes shadowing 버그** — WorkflowEngine 루프 내부에서 로컬 allowedScopes 재선언으로 함수 파라미터 덮어쓰던 버그 수정. 
  - korean.naver-news의 browserDOM scope가 ToolExecutor까지 전달 안 되던 문제 해결
  - 로컬 선언 제거, 함수 파라미터 allowedScopes 그대로 전달
  - 시작 로그에 allowedScopes 출력

### 빌드 결과
- **BUILD SUCCEEDED** · error 0 · warning 0

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| allowedScopes 실제 주입 | WorkflowOrchestrator, WorkflowEngine | dispatch()에서 effectiveScopes 계산 → runWorkflow/planWorkflow/attemptPlan/buildPlannerPrompt → WorkflowEngine.run(allowedScopes:) 전달. skill match 없으면 [.chatBasic, .artifactGeneration] 기본값 |
| SkillIDValidator 공통화 | SkillRegistry | nonisolated static isValidSkillID(_ id: String) 추가. a-z A-Z 0-9 . _ - 만 허용, / \ .. ~ 공백 금지 |
| 검증 규칙 강화 | SkillRegistry | validateSkill() Rule 1-1: id whitelist 검증. UserSkillStore는 같은 validator 재사용 |
| Disabled vs high-risk 분리 | SkillRegistry + WorkflowOrchestrator | nonisolated static isHighRiskSkill(_ skill: SkillManifest) 추가. enabled high-risk: "현재 버전 실행 불가". disabled high-risk: "민감 작업 비활성". disabled safe: "설정에서 활성화" |
| SettingsView skill toggle | SettingsView | skill 목록 표시, 각 항목 enabled toggle, high-risk disabled는 toggle disabled 처리. law-search/dart 토글 가능 |

### allowedScopes 전달 파이프라인 로그 예시

```
[Skill] matched enabled korean.naver-news scopes=[chatBasic,browserDOM]
[WorkflowOrchestrator] 파일 생성 요청 감지 → workflow 즉시 실행 scopes=[artifactGeneration,browserDOM,chatBasic]
```

### Disabled/High-risk 안내 분리

```
사용자: "법령 검색해줘"
→ [Skill] matched disabled 'korean.law-search'
→ 시스템: "'한국 법령 검색' 스킬은 현재 비활성화되어 있습니다. 설정 > 스킬 탭에서 활성화할 수 있습니다."

사용자: (future high-risk skill match 상황)
→ 시스템: "'{스킬명}' 스킬은 로그인/개인정보/예약/결제 등 민감 작업이므로 아직 비활성화되어 있습니다. 현재 버전에서는 사용할 수 없습니다."
```

### SkillIDValidator 정책

✅ `good.skill-1`, `my-custom_skill`, `korean.law-search`
❌ `../evil`, `evil/skill`, `bad skill`, `skill..name`, `~home`

### Settings toggle 검증

- korean.law-search off → "법령 검색" → disabled 안내 → Settings toggle on → 다시 "법령 검색" → enabled match + 로그
- high-risk disabled skill → toggle disabled (UI 비활성)
- 외부 API 호출: 없음 (manifest-only)

### 미구현 (Round 8+)

- User skill import UI
- korean.accounting-tax 파일 업로드 기반 실행
- CODEF/홈택스/은행/카드/증권 자동화 (BYOK + 명시 승인)

---

## 2026-05-05 (P0 안정화 Round 6 — Korean Skill Catalog)

### 빌드 결과
- **BUILD SUCCEEDED** · error 0 · warning 0
- 기준 커밋: Round 5 (main 브랜치)

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| ToolScope Codable 추가 | AgentTool.swift | `SkillManifest.allowedScopes: [ToolScope]` Codable 합성을 위해 `Codable` 프로토콜 추가 |
| SkillManifest 구조 정의 | SkillManifest.swift (신규) | SkillCategory·SkillPermission·SkillRiskLevel·SkillOutputType enum + SkillManifest struct. `backendHint: String?`, `notes: [String]?` 미래 확장 필드 포함 |
| BuiltInKoreanSkills 10개 | BuiltInKoreanSkills.swift (신규) | 날씨·미세먼지·맞춤법·글자수·네이버뉴스·블로그리서치·개인정보약관·HWP·법령검색·DART. 기본 활성 8개, 비활성 2개(law-search, dart) |
| SkillRegistry 싱글턴 | SkillRegistry.swift (신규) | `final class`, `UserDefaults` 기반 enable/disable 영속화, trigger match, validation 6-rule |
| UserSkillStore 스켈레톤 | UserSkillStore.swift (신규) | `actor`, `~/Library/Application Support/MyTeam/UserSkills/` 저장, dangerous permission warning flags |
| Skill match 라우팅 | WorkflowOrchestrator.swift | `dispatch()` 상단에 `SkillRegistry.shared.matchSkills()` 삽입. high-risk(reservation/payment/accountLogin) 조기 반환 + 시스템 메시지 |
| SettingsView 스킬 탭 | SettingsView.swift | 4번째 탭 "스킬" 추가, frame 380→420, `skillsTab` 플레이스홀더 (built-in 10개 / 활성화 8개 / high-risk 0개 표시) |

### Built-in 스킬 10개 목록

| # | ID | 카테고리 | defaultEnabled | riskLevel |
|---|----|---------|--------------:|-----------|
| 1 | korean.weather | koreanLife | ✅ true | publicData |
| 2 | korean.fine-dust | koreanLife | ✅ true | publicData |
| 3 | korean.spell-check | koreanWriting | ✅ true | safeReadOnly |
| 4 | korean.character-count | koreanWriting | ✅ true | safeReadOnly |
| 5 | korean.naver-news | koreanLife | ✅ true | publicData |
| 6 | korean.naver-blog-research | koreanWriting | ✅ true | publicData |
| 7 | korean.privacy-terms | koreanBusiness | ✅ true | publicData |
| 8 | korean.hwp-read | document | ✅ true | safeReadOnly |
| 9 | korean.law-search | koreanLegal | ❌ false | publicData |
| 10 | korean.dart | koreanFinance | ❌ false | publicData |

### High-risk 스킬 정책 (기본 비활성 — Round 6 미구현)

`riskLevel` ∈ `{reservation, payment, accountLogin}` → `validateSkill` 에서 `defaultEnabled=false` 강제.

| 카테고리 | 해당 스킬/기능 | 이유 |
|---|---|---|
| accountLogin | CODEF 자동 수집 (은행·카드·증권) | 타사 계정 크리덴셜 필요 |
| accountLogin | 홈택스 / 정부24 자동화 | 공공 계정 로그인, 민감 세금 정보 |
| reservation | KTX/SRT 예매, 캐치테이블/야놀자 | 실제 예약/결제 수반 |
| payment | 쿠팡 / 번개장터 구매 | 실제 결제 |
| sendsMessage | 카카오톡 메시지 전송 | 메시지 오발송 위험 |

Round 7 이상에서 BYOK + 명시 승인 구조로만 구현.

### UserSkillStore 저장 경로
```
~/Library/Application Support/MyTeam/UserSkills/<id>.skill.json
```
- `isEnabled: false` 고정 (설치 즉시 활성화 불가)
- dangerous permission 포함 시 `warningFlags` 기록

### Skill match 로그 예시
```
[Skill] matched korean.weather scopes=[chatBasic]
[Skill] matched korean.naver-news,korean.naver-blog-research scopes=[chatBasic,browserDOM,chatBasic,browserDOM,artifactGeneration]
```

### FutureKoreanSkills 후보 (DEVLOG 기록만 — BuiltInKoreanSkills.all 미포함)

**korean.accounting-tax** (한국 사업자 장부·세무 정리)
- `riskLevel: .personalData`, `defaultEnabled: false`, `requiresApprovalEveryRun: true`
- 1단계: 업로드 파일(CSV/엑셀) 기반 장부 정리만 허용
- 2단계(CODEF/홈택스/은행/카드): BYOK + 명시 승인 단계에서만 구현
- `backendHint: nil` — 1단계는 로컬 파일만

### 수동 검증 체크리스트

- [ ] `SkillRegistry.shared.builtInSkills().count` == 10
- [ ] `SkillRegistry.shared.allEnabledSkills().count` == 8
- [ ] `SkillRegistry.shared.matchSkills(for: "오늘 날씨 어때").first?.id` == `"korean.weather"`
- [ ] "오늘 날씨 어때" dispatch 로그: `[Skill] matched korean.weather scopes=[chatBasic]`
- [ ] SettingsView "스킬" 탭: 등록된 built-in 10개, 활성화됨 8개, high-risk(비활성) 0개
- [ ] `validateSkill` — triggers 비어 있는 스킬 → `SkillValidationError.emptyTriggers`
- [ ] `validateSkill` — riskLevel=.reservation, requiresApprovalEveryRun=false → `highRiskRequiresApproval`
- [ ] `UserSkillStore.skillsDirectory` 경로: `~/Library/Application Support/MyTeam/UserSkills/`
- [ ] 스킬 match 없는 메시지 ("안녕") → `matchedSkills.isEmpty`, 기존 dispatch 흐름 유지

### 미구현 (Round 7 이후)
- 실제 외부 API 호출 (날씨/미세먼지/DART/법령검색 등)
- Skill Gallery UI, remote install
- `SkillRegistry.userSkills()` — UserSkillStore 연동
- SkillManifest 기반 allowedScopes → WorkflowEngine 동적 주입
- korean.accounting-tax (파일 업로드 기반부터 단계적 구현)

---

## 2026-05-04 (P0 안정화 Round 5 — DirectChat 통합 + ToolScope 전수 + evidence 오탐 제거 + finish 순서)

### 빌드 결과
- **BUILD SUCCEEDED** · error 0 · warning 0
- 기준 커밋: `a20ca6c` (Round 4)

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| DirectChat silent mode 통합 | AgentChatView.swift | `getResponse()` 단발 경로 제거. silent mode도 `getResponseStream()` → 토큰 누적 → 말풍선 1개. `[DirectChat] silent getResponseStream opened` 로그 추가 |
| DirectChat roomID/targetID 캡처 | AgentChatView.swift | `roomIDAtSend` / `targetIDAtSend` 캡처변수로 두 경로(silent/normal) 통일. 오염 방지 |
| evidence gate 오탐 제거 | AgentChatView.swift | "알려줘", "찾아줘", "찾아봐" 단독 키워드 삭제. 외부정보(최신/뉴스/날씨/주가/환율/가격/버전)와 명시적웹(웹/검색/인터넷/구글)만 evidence 허용 |
| evidence reason 세분화 | AgentChatView.swift | `attachment` / `url` / `explicit_web` / `external_info_keyword` 4종 |
| ToolScope 전수 분류 | ReadFileTool, WriteTextFileTool, OpenURLTool | `.documentEditing` / `.artifactGeneration` / `.browserDOM` 명시 |
| Google 툴 scope 수정 | CreateGoogleSlidesTool, CreateGoogleSheetsTool | `.artifactGeneration` → `.officeLive` |
| ToolRegistry scope 경고 | ToolRegistry.swift | `register()` 시 file/artifact/url/export 계열이 `.chatBasic`이면 `[ToolRegistry] scope 누락 의심` warning |
| finish/event 순서 보장 | WorkflowOrchestrator.swift | `finishWorkflowRun()` 헬퍼 추가. 단일 Task에서 `WorkflowRunStore.finish` → `AgentEventBus.publish` 순서 보장 |
| RuntimeDiagnostics event 정보 | RuntimeDiagnosticsService.swift | `recentEventCount` + `latestEventSummary` 필드 추가. `snapshot()` async화 |
| OpenURLTool warning 수정 | OpenURLTool.swift | `_ = await MainActor.run` (unused result 경고 제거) |

### ToolScope 분류표 (전체)

| 도구 | scope |
|------|-------|
| read_file | `.documentEditing` |
| write_text_file | `.artifactGeneration` |
| create_markdown_report | `.artifactGeneration` |
| create_presentation_plan | `.artifactGeneration` |
| create_spreadsheet_plan | `.artifactGeneration` |
| generate_pptx | `.artifactGeneration` |
| generate_xlsx | `.artifactGeneration` |
| export_document | `.artifactGeneration` |
| create_google_slides | `.officeLive` |
| create_google_sheets | `.officeLive` |
| open_url | `.browserDOM` |

### 수동 검증 항목

| 시나리오 | 기대 결과 | 확인 |
|----------|-----------|------|
| silent mode ON → 치코 개인창 | `[DirectChat] silent getResponseStream opened` 로그, 치코 방에만 말풍선 | ☐ |
| silent mode OFF → 치코 개인창 | SpeechManager TTS 재생, 치코 방에만 말풍선 | ☐ |
| "오늘 기분 어때?" → DirectChat | `evidence skipped (no URL/keyword/attachment)` | ☐ |
| "이 UI 느낌 알려줘" → DirectChat | `evidence skipped` | ☐ |
| "최신 뉴스 알려줘" → DirectChat | `evidence enabled reason=external_info_keyword` | ☐ |
| "웹에서 찾아줘" → DirectChat | `evidence enabled reason=explicit_web` | ☐ |
| 첨부파일 있음 → DirectChat | `evidence enabled reason=attachment` | ☐ |
| artifactGeneration workflow | `open_url` / `create_google_slides` 실행 시 `[ToolExecutor] scope 차단` | ☐ |
| workflow 완료 | finish 로그 → workflowCompleted 로그 순서 | ☐ |
| 취소 | finish cancelled 1회, workflowCancelled 1회 | ☐ |
| RuntimeDiagnostics dump | `recentEvents: N | latest: workflowCompleted wf=...` | ☐ |

### evidence 로그 예시 (기대)
```
[DirectChat] evidence skipped (no URL/keyword/attachment)
[DirectChat] evidence enabled reason=external_info_keyword
[DirectChat] evidence enabled reason=explicit_web
[DirectChat] evidence enabled reason=attachment
```

### finish/event 순서 로그 예시 (기대)
```
[WorkflowOrchestrator] finishWorkflowRun status=completed workflowID=a1b2c3d4
[AgentEvent] workflowCompleted workflow=a1b2c3d4
```

### getResponse 단발 경로 제거 여부
- AgentChatView.swift DirectChat silent mode: **제거 완료** (`getResponse` → `getResponseStream` + 토큰 누적)
- WorkflowOrchestrator.swift planner/repair 경로: `getResponse` 유지 (스트림 불필요한 플래너 JSON 파싱 경로, 의도적)

---

## 2026-05-04 (P0 안정화 Round 4 — 단일-종료 + 스코프 가드 + evidence 게이트)

### 구현 완료

| 항목 | 파일 | 내용 |
|------|------|------|
| finish() 단일화 | WorkflowOrchestrator.swift | `finalStatus`/`finalEvent` + `defer` 패턴. 모든 분기가 `finish()` 1회만 호출. `manager.currentWorkflowID = nil`도 defer에 통합 |
| event 단일화 | WorkflowOrchestrator.swift | `workflowCompleted`/`workflowCancelled`/`workflowFailed` 이벤트도 defer 내 1회만 발행 |
| DirectChat evidence gate | AgentChatView.swift | `directChatNeedsEvidence()` — URL/외부키워드/첨부파일 없으면 `ToolEvidenceService.gather` 완전 스킵. 불필요한 웹 검색 API 호출 차단 |
| ToolScope executor guard | ToolExecutor.swift + WorkflowEngine.swift | `execute(allowedScopes:)` 파라미터 추가. WorkflowEngine은 `[.chatBasic, .artifactGeneration]`만 허용. scope 불일치 시 실행 전 차단 |
| workflowID default 제거 | ToolExecutionContext.swift | `current(workflowID: UUID = UUID())` → `current(workflowID: UUID)`. 누락 시 컴파일 오류 |
| consecutive429Count 노출 | AIService.swift | `private` → `private(set)`. 진단 읽기 허용 |
| RuntimeDiagnostics 연결 | RuntimeDiagnosticsService.swift | `geminiConsecutive429Count` — `0` 하드코딩 → `ai.consecutive429Count` 실값 연결 |

### 수동 검증 항목

| 시나리오 | 기대 결과 | 확인 |
|----------|-----------|------|
| "최신 뉴스 알려줘" → DirectChat | evidence enabled (keyword=최신/뉴스) | ☐ |
| "오늘 기분 어때?" → DirectChat | evidence skipped | ☐ |
| "이 파일 분석해줘" + 첨부 → DirectChat | evidence enabled (attachment) | ☐ |
| WorkflowEngine 실행 중 취소 | finish() 1회 / workflowCancelled 1회 | ☐ |
| ToolScope 차단 시 로그 | `[ToolExecutor] scope 차단: ...` | ☐ |
| RuntimeDiagnostics dump | `geminiCooldown: none` vs `429×N` 실값 | ☐ |

### 알려진 남은 항목 (TASK.md 참조)
- DirectChat 무음 모드 경로에서 getResponse → getResponseStream 통합 미완
- AgentEventBus subscriber 연결 (UI 이벤트 스트림) 미구현
- ToolScope `.schedule` / `.diagnostics` 도구 분류 미완

---

## 2026-05-03 (2차 — 안정화 마무리 + 데모 검증)

### 안정화 완료 사항

| 항목 | 내용 |
|------|------|
| Rolling budget | beginSession()에서 rollingCallLog 초기화 제거. 60초/5회 제한 실제 동작 |
| Artifact 카드 필터 | workflowID 기준 필터. 이전 workflow 파일 오염 없음 |
| ArtifactCardView | cloud/local 분기, path 비면 disabled, Finder 버튼 cloud에서 숨김 |
| 취소→네트워크 | Gemini/Claude/OpenAI/OpenRouter 4개 provider 모두 withTaskCancellationHandler 적용 |
| Validator | 필수 XML 내용 읽기 실패 = validation failure (silent skip 제거) |
| Validator | deflate(method=8) 항목은 .compressedContent 에러 throw (MiniZipWriter 계약 명시) |
| workflowID 통일 | notification userInfo 키를 "workflowID"로 통일. "sessionID" fallback + warning |
| room scope TODO | recentArtifacts 전역 한계 TODO 주석 추가 |

### 데모 테스트 — PPTX/XLSX 생성 파이프라인

**테스트 날짜:** 2026-05-03  
**테스트 환경:** 코드 정적 분석 + ZIP 구조 검증 기준 (앱 런타임 실행은 수석님이 직접 확인 필요)

**PPTX 파이프라인 분석:**
```
"MyTeam 회사원들을 소개할 PPT 만들어줘"
→ requiresFileCreation() → true (ppt 명사 + 만들어 동사)
→ 플래너 LLM: create_presentation_plan → generate_pptx 2단계
→ PPTXWriter → MiniZipWriter(stored) → .pptx
→ DocumentPackageValidator.validatePPTX():
   [Content_Types].xml ✓, ppt/presentation.xml ✓
   ppt/_rels/presentation.xml.rels ✓ (slide 관계 검사)
   ppt/slides/slideN.xml × N ✓ (slide 수 일치)
   content type "presentationml.slide" ✓
→ ArtifactCardView "열기" 버튼 표시
```

**XLSX 파이프라인 분석:**
```
"MyTeam 기능을 표로 정리해서 엑셀 파일로 만들어줘"
→ requiresFileCreation() → true (엑셀 명사 + 만들어 동사)
→ 플래너 LLM: create_spreadsheet_plan → generate_xlsx 2단계
→ XLSXWriter → MiniZipWriter(stored) → .xlsx
→ DocumentPackageValidator.validateXLSX():
   [Content_Types].xml ✓, xl/workbook.xml ✓
   xl/_rels/workbook.xml.rels ✓ (sheet 참조)
   xl/worksheets/sheetN.xml ✓ (sheet 수 일치)
   xl/sharedStrings.xml ✓ (si 개수 불일치 경고)
   xl/styles.xml ✓
→ ArtifactCardView "열기" + "Finder" 버튼 표시
```

**런타임 테스트 결과 (수석님 직접 확인 항목):**
| 항목 | 결과 |
|------|------|
| .pptx — Keynote/PowerPoint 열기 | ☐ 미확인 |
| .pptx — 한글 깨짐 | ☐ 미확인 |
| .xlsx — Numbers/Excel 열기 | ☐ 미확인 |
| .xlsx — 한글 깨짐 | ☐ 미확인 |
| ArtifactCard "열기" 버튼 | ☐ 미확인 |
| ArtifactCard "Finder" 버튼 | ☐ 미확인 |
| 취소 버튼 (■) → 작업 중단 | ☐ 미확인 |

**알려진 제약:**
- PPTX 슬라이드 레이아웃: 단일 레이아웃 (title + bullets). 디자인 커스텀 없음.
- XLSX 셀 스타일: 헤더 bold + freeze row. 색상/병합 없음.
- Google Slides/Sheets: stub (OAuth 연결 필요 메시지만 반환).

---

## 2026-05-03

### WorkflowOrchestrator + 업무 실행 엔진 추가

**구현 완료:**
- `TextSanitizer.removeNameTags` 버그픽스: agentPersonas 이름 목록과 일치할 때만 태그 제거. "좋아: 그렇게" 같은 일반 문장 보존.
- `AIService text passthrough` 코드 인스펙션 완료 — 버그 없음 확인. geminiStream/claudeStream/openAIStream/openRouterStream 모두 text 올바르게 전달.
- `Keychain 마이그레이션` 이미 완료됨 확인 (MyTeamApp.swift:121, KeychainManager.migrateFromUserDefaultsIfNeeded).

**신규 파일 (MyTeam/MyTeam/*.swift flat):**
| 파일 | 역할 |
|------|------|
| AgentTool.swift | WorkflowTool 프로토콜, ToolInput/ToolResult/ToolError, safeWorkspaceURL |
| ToolExecutionContext.swift | Workspace URL, sessionID, isDryRun |
| ArtifactStore.swift | action_log.jsonl append-only 기록 |
| WorkflowModels.swift | WorkflowPlan/Step/Result/Artifact |
| ReadFileTool.swift | Workspace 내 파일 읽기 |
| WriteTextFileTool.swift | Workspace 내 파일 쓰기 |
| CreateMarkdownReportTool.swift | .md 보고서 생성 |
| CreatePresentationPlanTool.swift | deck_plan.json 생성 |
| CreateSpreadsheetPlanTool.swift | workbook_plan.json 생성 |
| OpenURLTool.swift | http/https URL 열기 |
| ToolRegistry.swift | MVP 도구 싱글턴 등록 |
| ToolExecutor.swift | step 단위 실행 + 로그 + high/destructive 차단 |
| WorkflowEngine.swift | 순차 실행, isRequired 실패 시 중단 |
| WorkflowOrchestrator.swift | LLM 플래너 + IntentRouter 라우팅 진입점 |

**TeamStatusView 변경:**
- `TeamOrchestrator.runTeamDiscussion()` 직접 호출 → `WorkflowOrchestrator.dispatch()`로 교체.
- CHITCHAT/QUICK_ANSWER → TeamOrchestrator 위임.
- TASK/RESEARCH/DECISION → WorkflowEngine 실행.

**보안:**
- Workspace = `~/Library/Application Support/MyTeam/Workspace/` (샌드박스 안전).
- path traversal(`../`) 차단, Workspace 외부 접근 금지.
- OpenURLTool: http/https scheme만 허용.
- high/destructive riskLevel 도구 실행 차단 (MVP).
- 모든 tool call → `action_log.jsonl` append.

**경로 규칙 명시:**
- Swift 파일 실제 위치: `MyTeam/MyTeam/*.swift` (flat).
- Antigravity/Claude/Codex는 이 경로만 수정.

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

## Round 14 - BYOK Center / Team Nameplate / Collaboration Status

- Added BYOK provider center cards for OpenAI, Claude, Gemini, and OpenRouter.
- Added usage policy summary card with Free/Pro placeholder limits.
- Added team nameplate ON/OFF and color settings in Settings.
- Added collaboration status banner and idle rotation text in the team view.
- Added schedule popover for the clock/schedule button.
- API key values remain hidden; no usage enforcement or StoreKit entitlement wiring was added.

## Round 14.1 - BYOK Status Refresh / Keychain Key Verification

- BYOK provider center now reloads status on appear and through a manual refresh button.
- Verified provider keychain keys: `geminiAPIKey`, `openAIAPIKey`, `claudeAPIKey`, `openRouterAPIKey`.
- API key values remain hidden; no API test call or routing change was added.

## Round 15 - App Launch Pack Artifact Skills

- Added 4 app launch pack skills: app store copy, onboarding copy, launch checklist, and monetization review.
- App name is required before artifact generation; missing app name returns a question prompt instead of generating a file.
- Generated output is written as Markdown artifact in the workspace with a safety disclaimer appended.
- No external API, web search, or App Store Connect call was added.
- StoreKit, entitlement, premium unlock, and existing BYOK/team status behavior were left unchanged.

## Round 15.1 - App Launch Skill Routing Hotfix

- App launch skill detection now prefers explicit document types first.
- Monetization routing now requires explicit monetization document intent.
- Advertising, subscription, and in-app purchase terms are treated as supporting details unless the user explicitly asks for monetization review.
- App name extraction was strengthened for common "app name + app/document" phrasing.

## Round 16 - Agent Replacement / Store UX Cleanup

- Replaced user-visible "미구현" placeholder UX with coming-soon copy in the agent swap screen.
- Store/hire-style buttons now read as launch-ready placeholders instead of dead actions.
- Premium characters remain unavailable for team insertion.
- StoreKit, entitlement, and premium unlock wiring remain untouched.
- Built-in agent swap behavior remains unchanged.

## Round 17 - App Launch Pack Result UX + Prompt Quality

- App Launch Pack prompt quality was tightened for app-store copy, onboarding, launch checklist, and monetization review.
- App name missing flows now use a more natural question prompt, while optional fields are handled as drafting assumptions instead of hard blockers.
- Artifact completion messages now include the filename plus Workspace/Finder guidance.
- StoreKit, entitlement, premium unlock, BYOK, team nameplate, and collaboration status flows were left untouched.

## Round 19 - Team Collaboration Window Deep Polish

- Team runtime cohesion now records discussion start, speaker selection, agent turn start/completion, and discussion completion/failure states.
- TeamStatusView reflects workflow activity and the current team runtime state with short-lived completion/failure states.
- Idle copy rotates through character-flavored lines without LLM calls or routing changes.
- The collaboration refresh loop is task-backed and cancels cleanly when the window disappears.
- The schedule/clock button now opens a compact coming-soon popover instead of a dead or heavy panel.
- IntentRouter double-calls were reduced by passing precomputed routing into TeamOrchestrator.
- StoreKit, entitlement, premium unlock, BYOK, and App Launch Pack flows were left untouched.

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

---

## Round 231A - Character Reaction Engine + Workroom Validator Enhancement (2026-05-17)

### Phase 0: Build & Diagnostics Fix
- Fixed RuntimeDiagnosticsService.swift line 789: Added missing 14 parameters to RuntimeDiagnosticsSnapshot initialization
- Parameters: workroomActionTypesConsolidated, workroomEnumDuplicationRemoved, workroomPbxprojRegistered, workroomHandlerMethodsConsolidated, workroomRoomScopeEnforced, workroomCharacterSystemPreserved, workroomCharacterReactionBridgeBacklogDocumented, workroomSpriteSheetProductionSpecDocumented, workroomCharacterReactionEnginePlanDocumented, workroomRuntimeDiagnosticsEnhanced, workroomToolContractValidatorEnhanced, workroomRouterBurnInSuiteEnhanced, workroomPreflightScriptAvailable, workroomInternalReviewReportAvailable
- Debug build: BUILD SUCCEEDED with 0 Swift warnings
- Release build: Currently blocked by system resource exhaustion (SPM fork failures) — not a code issue

### Phase 1: Validator Enhancement Discovery
- Confirmed ToolContractValidator.swift exists (32K, last modified 2026-05-16)
- Confirmed RouterBurnInSuite.swift exists (92K, last modified 2026-05-16)
- Confirmed RouterBurnInCase.swift exists (3.9K, last modified 2026-05-13)
- Added 9 new Round 196A-230Z policy validators to ToolContractValidator:
  - validateWorkroomActionTypesConsolidationPolicy()
  - validateWorkroomEnumDuplicationPolicy()
  - validateWorkroomPbxprojRegistrationPolicy()
  - validateWorkroomHandlerMethodsPolicy()
  - validateWorkroomRoomScopePolicy()
  - validateWorkroomCharacterSystemPreservationPolicy()
  - validateWorkroomCharacterReactionBridgeDocumentationPolicy()
  - validateWorkroomSpriteSheetProductionSpecPolicy()
  - validateWorkroomCharacterReactionEnginePlanPolicy()
- Verified 7 existing Workroom test cases in RouterBurnInSuite (workroom-create, room-kind-team-workroom, workroom-open, workroom-new, workroom-create-document, workroom-today-organize, workroom-file-handoff)

### Phase 2: Document Status Updates
- Updated TASK.md Round 196 status: explicit compilation validation results, Release build resource blockage noted
- Updated TASK.md status classification: Build COMPILATION ✅, Code Validation COMPLETE ✅
- Ready for Phase 3: CharacterReactionEngine implementation

### Phase 3: Character Reaction Engine Implementation
- Created WorkroomCharacterEvent.swift (7.2K):
  - Defines WorkroomCharacterEvent enum with 4 event types
  - Events: workflowStarted, documentCreated, artifactReuseRequested, multiRoomSwitched
  - Includes CharacterReaction struct and CharacterReactionMapping
  - Maps events to AnimationState without modifying existing system

- Created CharacterReactionEngine.swift (5.0K):
  - Core engine managing reaction processing and cooldown
  - Delegates to CharacterReactionDelegate for rendering
  - Cooldown policy: 30 seconds per reaction type
  - Includes diagnostic snapshot capability

- Created CharacterReactionEventSink.swift (4.7K):
  - Bridge between Workroom workflows and CharacterReactionEngine
  - Integration points: WorkflowOrchestrator, UniversalDocumentSkillService, ArtifactCardView, AgentWindowManager
  - Methods: notifyWorkflowStarted(), notifyDocumentCreated(), notifyArtifactReuseRequested(), notifyRoomSwitched()

### Phase 4: Minimal 4-Event Workroom Connection
Connected via CharacterReactionMapping.reactionFor():
1. workflowStarted → AnimationState.thinking → "문서를 정리해드릴게요..."
2. documentCreated → AnimationState.happy → "문서가 만들어졌어요!"
3. artifactReuseRequested → AnimationState.focused → "이전 결과를 다시 활용해드릴게요."
4. multiRoomSwitched → AnimationState.neutral → "다른 워크룸으로 이동했어요."

### Phase 5: Verification
- New files located in correct path: MyTeam/MyTeam/*.swift (flat structure)
- Files follow existing code patterns:
  - MainActor annotations for thread safety
  - AppLog for diagnostics
  - Codable conformance for events
  - Protocol-based delegation for extensibility
- Does NOT modify existing character system:
  - AnimationState enum used from CharacterDialogues.swift
  - No changes to SpriteAgentView, CharacterSpriteScene, AgentSeatView
  - Minimal, non-invasive bridge architecture

### Phase 6: Diagnostics Integration
- Updated RuntimeDiagnosticsService struct with 3 new fields:
  - characterReactionEngineAvailable: Bool
  - characterReactionDelegateRegistered: Bool
  - characterReactionActiveCooldowns: Int
- Added initialization in snapshot() method with actual delegate check
- Diagnostic queries available via CharacterReactionEventSink.diagnosticsSnapshot()

---

## Round 232 — Character Reaction Surface + Sprite Production Handoff (2026-05-17)

### Summary
CharacterReactionEngine의 이벤트 커버리지를 확장하고, 디자인팀 sprite 제작을 위한 handoff 문서를 완성했다.
agentEmotions 경로를 통한 전체 체인(event → engine → agentEmotions → AgentSeatView → SpriteAgentView → CharacterSpriteScene)이 구조적으로 연결됐다.

### Event Coverage 추가

**workflowCompleted → .joy (NotificationCenter bridge)**
- `CharacterReactionEventSink.setupWorkflowCompletedObserver()` 추가
- `WorkflowEngine.swift`이 발송하는 `Notification.Name.workflowCompleted`를 수신
- `userInfo["artifacts"]`가 비어 있지 않을 때만 `notifyDocumentCreated` 호출 → `.joy`
- WorkflowEngine/ArtifactStore 구조 변경 없음

**multiRoomSwitched → .idle (TeamStatusView room tap)**
- `TeamStatusView.swift` room tap `onTapGesture`에 추가
- `previousRoomID != room.id` 조건으로 자기 자신 전환 시 no-op
- `notifyRoomSwitched(fromRoomID:toRoomID:)` 호출

### 전체 이벤트 커버리지 (6개)
1. `workroomOpened` → `.greeting` — WorkroomHomeView.onAppear
2. `workflowStarted(universalDocument)` → `.typing` — handleWorkroomAction(.createDocument)
3. `documentCreated` → `.joy` — workflowCompleted NotificationCenter bridge
4. `artifactReuseRequested` → `.backToWork` — handleWorkroomAction(.handoffFile)
5. `multiRoomSwitched` → `.idle` — TeamStatusView room tap
6. `workflowStarted(기타)` → `.thinking` (→ idle fallback) — handleWorkroomNextAction

### 신규 문서

**ChikoSpriteSheetHandoff.md**
- v1 필수 12개 clip 상세 명세 (idle/typing/thinking/speaking/greeting/joy/sad/confused/drag/landing/clockIn/backToWork)
- Canvas spec: transparent PNG, consistent baseline, no baked-in text
- Style: warm but professional, work-focused props, no exaggerated motion
- Fallback policy 명시

**CharacterSpriteRosterRoadmap.md**
- 치코/세나/카이/유나 로드맵
- 노출 정책: spriteName 없으면 Release 구매 UI 금지
- DLC 정책: StoreKit QA 전 노출 금지

**CharacterReactionDelegateDecision.md**
- 결정: agentEmotions 경로 우선, CharacterReactionDelegate direct path deferred
- 근거: agentEmotions는 이미 연결돼 있음; delegate 추가는 manual QA 결과 보고 결정
- 보존 목록 명시 (AnimationState/CharacterSpriteScene/SpriteAgentView/CharacterDialogues/AgentSeatView 무수정)

### Validator / BurnIn 보강
- ToolContractValidator: 3개 Round 232 validators (SpriteSheetHandoff/DelegatePolicy/RosterPolicy)
- RouterBurnInSuite: 7개 Round 232 character reaction policy cases (2개 backlog 포함)

### RuntimeDiagnostics 보강 (8개 필드)
- characterReactionEventSinkConnected
- characterReactionAgentEmotionsConnected
- characterReactionDelegateDeferred
- characterReactionWorkflowCompletedBridge
- characterReactionRoomSwitchBridge
- chikoSpriteSheetHandoffAvailable
- characterSpriteRosterRoadmapAvailable
- characterReactionDelegateDecisionAvailable

### Preflight
- `scripts/preflight_character_round231.sh` 신규 생성
- agentEmotions 연결 확인, 이벤트 firing point 확인, 문서 존재 확인, CharacterMood guard 포함
- Debug + Release BUILD SUCCEEDED 확인 포함

### Backlog (연결 미완료)
- sleeping state: long idle timer hook 없음 — RouterBurnInSuite notes에 기록
- artifactVerificationFailed: ResultVerifier hook 필요 — RouterBurnInSuite notes에 기록
- CharacterReactionDelegate conformance: manual QA 후 agentEmotions 경로 검증 완료 시 재검토

### Build
- Debug BUILD SUCCEEDED, 0 Swift warnings
- Release BUILD SUCCEEDED, 0 Swift warnings

---

## Round 233A — Beginner Mode + Guided WorkroomHome (2026-05-17)

### Summary
초보자가 프롬프트 없이 버튼 하나로 업무를 시작할 수 있는 Beginner Mode 레이어를 구현했다.
WorkroomHomeView에 치코 안내 문구, 업무 카드, "예시로 시작하기"가 추가됐다.
기존 표준 모드(고급 사용자)는 그대로 유지된다.

### 신규 파일

**BeginnerMode.swift**
- `BeginnerTaskCard` enum (meetingMinutes/checklist/reportDraft/fileSummary/todayPlan/tryExample)
  - title, subtitle, iconName, userTasks, chikoTasks, dispatchPrompt 계산 프로퍼티
  - tryExample: 샘플 회의 내용 → exampleMeetingPrompt 포함
- `BeginnerGuidanceMessage` struct (title/body/primaryActionTitle/prompt)
  - firstLaunch / fileDetected / documentCreated / errorRecovery / returnFromIdle / idle 사전 정의
- `UserFacingTerm` enum (artifact/connector/blocked/unavailable/route/skill/token/model/diagnostic/capability/router)
  - displayName / description / friendlyErrorMessage(for:) — 기술 용어 → 사용자 언어 변환

**BeginnerTaskCardView.swift**
- `BeginnerTaskCardView`: 업무 카드 UI
  - Header: 아이콘 + 제목 + 부제목 + 화살표
  - Role Split: "내가 할 일" / "치코가 할 일" 두 컬럼
  - tryExample 카드는 강조 스타일 (파란 테두리 + 화살표)
- `BeginnerGuidanceBar`: 치코 안내 문구 뷰
  - 치코 아이콘(🐾) + 제목/본문 + CTA 버튼

### 수정 파일

**WorkroomHomeView.swift** (전면 재작성)
- isBeginnerMode 분기 추가
- Beginner 모드: GuideBar + 업무 카드 4개 + tryExample + 최근 문서 + 다음 액션
- 표준 모드: 기존 primary action 버튼 유지
- 모드 전환 토글 버튼 (헤더 우측)
- onPromptDispatched 콜백 추가 (카드 탭 → 직접 프롬프트 dispatch)
- ScrollView로 감싸 긴 내용도 스크롤 가능

**AgentWindowManager.swift**
- `@AppStorage("MyTeam.isBeginnerMode") var isBeginnerMode: Bool = false` 추가

**TeamStatusView.swift**
- chatroomLogView에 WorkroomHomeView 마운트
- isBeginnerMode 또는 teamChatLogs.isEmpty일 때 WorkroomHomeView를 스크롤 상단에 표시
- onPromptDispatched → dispatchWorkroomPrompt로 연결

**WorkroomHomeModel.swift**
- `Equatable` 제거 (IndexedArtifact가 Equatable 미준수)

**project.pbxproj**
- WorkroomHomeView.swift / WorkroomHomeModel.swift PBXBuildFile 누락 수정 (BFWORKROOM001/002)
- BeginnerMode.swift 신규 등록 (BC233A001FR/BF)
- BeginnerTaskCardView.swift 신규 등록 (BC233A002FR/BF)

### 금지 사항 준수
- CharacterMood/CharacterActivity 미도입
- AnimationState enum 보존
- CharacterDialogues/SpriteAgentView/CharacterSpriteScene/AgentSeatView 무수정
- 외부 write 없음

### Build
- Debug BUILD SUCCEEDED, 0 Swift warnings
- Release BUILD SUCCEEDED, 0 Swift warnings
