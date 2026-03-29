# MyTeam Development Log

## Completed Work

### 1. Minimize/Restore Crash Fix (Completed)
**Date:** 2026-03-28
**Commit:** 4dd5eff (Update gitignore for Xcode user data)

**Issue:** App crashed with EXC_BREAKPOINT when minimizing then restoring individual chat window. Window size didn't restore properly.

**Root Cause:**
- SwiftUI `withAnimation(.spring(...))` transaction conflicting with AppKit `panel.setFrame(animate:true)` in onChange handler
- Missing restore logic in onChange handler

**Solution (AgentChatView.swift):**
1. Removed `withAnimation` from restore button (line 191)
2. Added `DispatchQueue.main.async` to onChange handler (line 134) to separate SwiftUI render cycle from AppKit window update
3. Implemented complete minimize/restore flow with proper minSize constraints

**Files Modified:**
- `AgentChatView.swift`: onChange handler, restore button
- `AgentWindowManager.swift`: updateChatWindowSize accepts minSize parameter

---

### 2. Phase 1 Refactoring: File Structure Optimization (Completed)
**Date:** 2026-03-28
**Commit:** e2bec6a (Refactor: Split large monolithic files into focused modules)

**Objective:** Reduce file size and improve code organization without breaking backward compatibility

**New Files Created (6):**

1. **AgentConfig.swift** (~30 lines)
   - Extracted from: AgentWindowManager.swift
   - Type Path: `AgentWindowManager.AgentConfig` (nested extension maintained)
   - Properties: id, name, role, emoji, color, isPremium, status, spriteName, dragEmoji, dragRotation, dragSoundName, dropSoundName

2. **ChatModels.swift** (~25 lines)
   - Extracted from: AgentWindowManager.swift
   - Types: `AgentWindowManager.ChatRoom` and `AgentWindowManager.ChatLog` (both Codable)

3. **ChatComponents.swift** (~100 lines)
   - Extracted from: AgentChatView.swift
   - Components: JiggleEffect, IMMessageBubble, DateSeparator, ChatBubble
   - Features: Copy to clipboard, agent display, timestamp, dark mode support

4. **AgentMenuPopupView.swift** (~45 lines)
   - Extracted from: TeamTableView.swift
   - Menu with 5 buttons: Chat, Voice, Settings, Swap
   - Features: Nested MenuButton helper, left/right positioning

5. **AgentSeatView.swift** (~130 lines)
   - Extracted from: TeamTableView.swift
   - Features: Speech bubbles (3-sentence grouping), sprite animation, status indicator, double-tap greeting

6. **AgentPersona.swift** (~110 lines)
   - Extracted from: AIService.swift
   - Contains: AgentPersona struct, 8 agent definitions, AIServiceError enum

**Files Reduced in Size:**

| File | Before | After | Reduction |
|------|--------|-------|-----------|
| AIService.swift | 460 | 350 | 110 lines (-24%) |
| AgentChatView.swift | 830 | 720 | 110 lines (-13%) |
| TeamTableView.swift | 397 | 230 | 167 lines (-42%) |
| AgentWindowManager.swift | 558 | ~510 | ~48 lines (-9%) |
| **Total** | **2,245** | **1,810** | **435 lines (-19%)** |

**Key Design Decision: Backward Compatibility**
- All extracted types use `extension AgentWindowManager { struct Name ... }` pattern
- Existing code references (e.g., `AgentWindowManager.AgentConfig`) still work without modification
- No breaking changes to public APIs
- Allows incremental refactoring without updating all call sites

**Xcode Project Integration:**
- Project uses `PBXFileSystemSynchronizedRootGroup` (Xcode 15+)
- All .swift files automatically included in build
- No manual file references needed
- No duplicate entries possible

---

---

### 3. 오늘 작업 (2026-03-29)

#### 3-1. Xcode 프로젝트 경로 혼선 수정
**문제:** git worktree가 3곳에 생성되어 Xcode가 `.claude/worktrees/sleepy-euler/` 의 구버전 프로젝트를 열고 있었음
- `/Users/su/Desktop/MyTeam/MyTeam/` — 메인(최신)
- `.claude/worktrees/sleepy-euler/MyTeam/` — 구버전 (800px, 리팩토링 없음)
- `.claude/worktrees/gallant-nash/MyTeam/` — 구버전

**해결:** `open /Users/su/Desktop/MyTeam/MyTeam/MyTeam.xcodeproj` 로 올바른 경로 직접 오픈

#### 3-2. 개별 채팅창 가로 크기 700px으로 조정
**Commits:** 76ad628, 1197b59
- `AgentChatView.viewWidth`: 800 → 700 (사이드바 축소 시 680 → 650)
- `AgentWindowManager.showChat` 초기 창 크기: 800×620 → 700×620
- `onChange` 복원 높이: 600 → 620 (일관성)

#### 3-3. 프로젝트 사이드바 접기 버튼 제거
**Commit:** 1197b59
- `projectSidebarView` 헤더에서 `sidebar.squares.left` 버튼 삭제
- 사이드바는 항상 펼쳐진 상태로 고정

#### 3-4. 채팅창 초기 크기 버그 수정 (SwiftUI/AppKit 크기 충돌)
**문제 원인:**
- SwiftUI `.frame(idealWidth: viewWidth, maxWidth: .infinity)` modifier가 NSHostingController를 통해 NSPanel 크기를 **지속적으로 오버라이드**함
- `isMinimized` 변경 시 SwiftUI 레이아웃이 재계산되면서 창 크기가 임의로 변경됨
- `onAppear`에서 초기 크기 설정 코드가 없어 SwiftUI가 먼저 창 크기를 결정함

**해결:**
1. Group 전체에 걸린 `.frame(idealWidth:, minWidth:, maxWidth:, ...)` 제거
2. `isMinimized` 분기별 독립 설정:
   - 최소화: `minimizedBarView.frame(width: 280, height: 52)` (NSPanel 크기 고정)
   - 복원: `.frame(maxWidth: .infinity, maxHeight: .infinity)` (NSPanel이 크기 결정)
3. `onAppear`에서 `DispatchQueue.main.async`로 초기 창 크기 700×620 강제 설정

**핵심 원칙:** SwiftUI `idealWidth`는 NSHostingController를 통해 NSPanel 크기를 경쟁적으로 조절한다. NSPanel이 크기를 담당하려면 SwiftUI 뷰는 `maxWidth/maxHeight: .infinity`로 NSPanel에 맞게 채워야 한다.

---

---

### 4. Phase 1 리팩토링 상세 (2026-03-28~29)

#### 추출된 파일 구조 (6개 신규)

| 파일 | 원본 | 내용 |
|------|------|------|
| `AgentConfig.swift` | AgentWindowManager.swift | `AgentWindowManager.AgentConfig` struct (14 프로퍼티) |
| `ChatModels.swift` | AgentWindowManager.swift | `AgentWindowManager.ChatRoom`, `ChatLog` (Codable) |
| `ChatComponents.swift` | AgentChatView.swift | JiggleEffect, IMMessageBubble, DateSeparator, ChatBubble |
| `AgentMenuPopupView.swift` | TeamTableView.swift | 팝업 메뉴 4개 버튼 (Chat/Voice/Settings/Swap) |
| `AgentSeatView.swift` | TeamTableView.swift | 에이전트 카드 (말풍선, 스프라이트, 상태 표시) |
| `AgentPersona.swift` | AIService.swift | AgentPersona struct, 8개 에이전트 정의, AIServiceError |

**설계 원칙:** 모든 추출 타입은 `extension AgentWindowManager { struct Name... }` 패턴 사용
→ 기존 코드 `AgentWindowManager.AgentConfig` 참조 변경 없이 호환

---

### 5. 치코 스프라이트 시스템 적용 (2026-03-29)
**Commits:** 46abe69, 구글 프롬프트 개선 작업

**배경:** 치코(agent_5) 23개 모션 PNG 시퀀스 제작 (12~48프레임, 500×502px 정사각형)

#### 5-1. 초기 문제점 분석
- **원본 영상:** 9:16 비율이지만, PNG 내보내기는 500×502(1:1 정사각형)로 이미 크롭됨
- **씬 크기 불일치:** 100×120 (5:6 비율) vs 500×502 스프라이트 → 상단/하단 잘림
- **드래그 시 목 잘림:** 80×80 선택 영역이 스프라이트 출력 영역 제한
- **기본 상태:** idle → typing으로 변경 필요

#### 5-2. 파일 배치 및 rawValue 매핑
**실제 파일 구조:**
```
MyTeam/MyTeam/MyTeam/Resources/Sprites/치코/
  치코_idle_001.png ~ 048.png
  치코_typing_001.png
  치코_agree_001.png
  ... (23개 모션, 674개 파일)
```

**rawValue 수정 (파일명과 동기화):**
| 케이스 | 구 rawValue | 신 rawValue | 파일명 |
|--------|----------|----------|--------|
| `dropped` | `"drop"` | `"drop"` | ✅ 유지 |
| `backToWork` | `"back_to_work"` | `"backwork"` | ✅ 수정 |
| `clockOut` | `"clock_out"` | `"clockout"` | ✅ 수정 |
| `clockIn` | `"clock_in"` | `"clockin"` | ✅ 수정 |
| `returnToTyping` | `"return_to_typing"` | `"typing_return"` | ✅ 수정 |
| `idleLoop` | `"idle_loop"` | `"idle_loop"` | ✅ 신규 추가 |

#### 5-3. 화면 레이아웃 최적화
**문제:** 100×120 씬이 1:1 스프라이트에 맞지 않아 위아래 크롭
**해결:**
- AgentSeatView: 선택 영역 80×80 → 100×100으로 확대
- SpriteAgentView: 프레임 명시적 지정 100×140 (세로 여유)
- SpriteScene: 크기 100×120 → 100×100 (1:1 스프라이트에 맞춤)
- fitCharacterToScene: 스케일 여백 90% → 95% (더 많이 표시)

#### 5-4. 폴백 상태 체인 구현
**문제:** 새로운 모션 통합으로 일부 상태는 파일이 없지만 코드 호환성 유지 필요

**해결: fallbackStates 매핑**
```swift
private let fallbackStates: [AnimationState: AnimationState] = [
    .thinking   : .idle,       // 생각중 → 대기
    .praise     : .agree,      // 칭찬 → 긍정대답 (파일 통합)
    .sleeping   : .resting,    // 수면 → 휴식
    .clockOut   : .resting,    // 퇴근 → 휴식 진입
    .disagree   : .angry,      // 부정대답 → 화남
    .lookLeft   : .look,       // 좌우보기 → 두리번
    .lookRight  : .look,
    .look       : .idle,
    .dropped    : .lowering,   // 구파일 없으면 신규 파일 탐색
]
```

**동작:**
1. 요청 상태 → loadTextures 시도
2. 파일 없으면 → fallbackStates 체인 추적
3. 최종 idle까지 탐색 (파일 반드시 존재)

#### 5-5. 기본 복귀 상태 변경
**변경:** 1회 모션 후 idle → **typing**으로 복귀
- 이유: 앱의 기본(default) 상태는 '업무 중' (타이핑)
- 여러 모션 재생 후 자연스럽게 업무 상태로 돌아감

#### 5-6. 제미나이 프롬프트 최적화
**목표:** 9:16 원본에서 500×700으로 크롭했을 때 캐릭터 전신이 다 보임

**개선 포인트:**
1. **프레임 내 유지:** 꼬리, 귀 등 모든 신체 부위가 500×700 안에 포함
2. **합계 루프:** 첫 프레임 = 마지막 프레임 (무한 루프 시 뚝 끊기지 않음)
3. **배경색 매칭:** 원 배경이 캐릭터 털 색상과 조화 (갈색, 회색 등)
4. **크기 일관성:** 모든 캐릭터가 동일 800×800 캔버스로 일관된 프로필

**공통 제미나이 프롬프트:** (별도 문서화)

---

### 6. 캐릭터 프로필 이미지 & 폴백 시스템 (2026-03-29)
**Commits:** 신규 추가

**배경:** 스프라이트 애니메이션 없는 캐릭터(레오, 루나 등)도 단순 이모지 대신 전문적인 프로필 이미지 표시

#### 6-1. 코드 변경 사항
**수정 파일 5개:**

1. **CharacterSpriteScene.swift**
   - `fallbackEmoji: String` → `fallbackImageName: String`
   - `emojiNode: SKLabelNode?` → `fallbackImageNode: SKSpriteNode?`
   - setupCharacterNode: SKLabelNode(emoji) → SKSpriteNode(imageName) 생성
   - showEmojiFallback/hideEmojiFallback: 이미지 노드 사용

2. **SpriteAgentView.swift**
   - 파라미터: `fallbackEmoji` → `fallbackImageName`
   - setupScene: `scene.fallbackEmoji = ...` → `scene.fallbackImageName = ...`
   - CharacterAnimationController도 동일 변경
   - Preview 업데이트 (100×140)

3. **AgentConfig.swift** (신규 프로퍼티 추가)
   - `let fallbackImageName: String` — Assets에 등록된 이미지 파일명
   - 용도: 스프라이트 없을 때 표시할 캐릭터 원형 프로필

4. **AgentWindowManager.swift**
   - allAvailableAgents 각 AgentConfig에 `fallbackImageName` 값 추가:
     ```
     agent_1 (레오):    "leo_profile"
     agent_2 (루나):    "luna_profile"
     agent_3 (모코):    "moco_profile"
     agent_4 (핀):      "pin_profile"
     agent_5 (치코):    "치코_profile"
     agent_6 (렉스):    "rex_profile"
     agent_7 (케이):    "kai_profile"
     agent_8 (래키):    "lucky_profile"
     agent_9 (폴라):    "polar_profile"
     agent_10 (몽몽):   "mongmong_profile"
     agent_11 (올리버): "oliver_profile"
     ```

5. **AgentSeatView.swift**
   - SpriteAgentView 호출: `fallbackEmoji: config.emoji` → `fallbackImageName: config.fallbackImageName`

#### 6-2. Assets.xcassets에 이미지 등록
**방법:** `/Users/su/Desktop/MyTeam/MyTeam/MyTeam/Assets.xcassets/` 에 직접 이미지 파일 복사

**등록된 이미지:**
- `치코_profile.png` (다람쥐 원형 프로필)
- `leo_profile.png` (여우)
- `luna_profile.png` (토끼)
- `moco_profile.png` (햄스터)
- `pin_profile.png` (펭귄)
- `rex_profile.png` (나무늘보)
- `kai_profile.png` (개)
- `lucky_profile.png` (너구리)
- `polar_profile.png` (북극곰)
- `mongmong_profile.png` (푸들)
- `oliver_profile.png` (돼지)

#### 6-3. 동작 원리
**스프라이트 있을 때 (치코):**
1. SpriteAgentView → loadAndPlay(state: .typing)
2. CharacterSpriteScene: loadTextures("typing") 성공
3. SKSpriteNode에 애니메이션 표시 ✅

**스프라이트 없을 때 (레오 등):**
1. SpriteAgentView → loadAndPlay(state: .typing)
2. CharacterSpriteScene: loadTextures("typing") 실패
3. fallbackStates: .typing → .idle 폴백 → 여전히 실패
4. showEmojiFallback() → fallbackImageNode 표시 ✅
5. "leo_profile" 이미지가 SKSpriteNode로 렌더링됨

---

---

## 📊 오늘(2026-03-29) 핵심 성과

### 🎬 치코 스프라이트 애니메이션 완전 적용
- **23개 모션** PNG 시퀀스 (500×502px, 674개 파일)
- **폴백 상태 체인** 구현 (파일 없으면 유사 모션으로 자동 대체)
- **화면 레이아웃 최적화** (100×140 씬, 95% 스케일)
- **기본 상태 변경** (idle → typing)

### 🖼️ 캐릭터 프로필 이미지 시스템
- **11개 캐릭터** 원형 프로필 이미지 (Assets.xcassets 등록)
- **스프라이트 폴백** (애니메이션 없으면 프로필 이미지 표시)
- **일관된 구성** (모든 캐릭터가 통일된 방식으로 표시)

### 🔧 코드 개선
- **파일명/rawValue 동기화** (5개 케이스 수정)
- **폴백 체인** (무한 루프 방지, 최대 5단계 탐색)
- **4개 파일 수정** (Scene, View, Config, Manager)
- **1회 모션 후 자동 복귀** (typing으로 통일)

### 📝 문서화
- DEVLOG 5.5장 추가 (스프라이트 최적화, rawValue 매핑, 레이아웃 개선)
- DEVLOG 6장 추가 (이미지 폴백 시스템, 코드 변경, 동작 원리)

### 🎨 제미나이 프롬프트 최적화
- 씬 포함/프레임 경계 명시
- 루프 연속성 강화
- 500×700 크롭 기반 구도
- 배경색 캐릭터 색상 매칭

---

## TODO: Future Phases

### Phase 2: Service Layer Refactoring (Planned)
- Extract AI provider implementations (GeminiProvider, OpenAIProvider, ClaudeProvider)
- Create ChatRoomManager separate from AgentWindowManager
- Move window management into dedicated WindowManager

### Phase 3: View Layer Refactoring (Planned)
- Split AgentChatView into: ChatHeaderView, ChatLogView, ChatInputView
- Extract ProjectSidebarView component
- Create reusable ProjectListItem component

### Phase 4: Model Organization (Planned)
- Create Models/ folder with focused model files
- Consolidate error types into shared Error.swift
- Standardize data flow patterns

---

## Technical Notes

**Animation Context Isolation:**
The crash fix demonstrates the importance of separating SwiftUI and AppKit animation contexts. Use DispatchQueue to ensure clean execution contexts when mixing frameworks. This prevents uncaught NSException from animation transaction conflicts.

**File Organization Strategy:**
Extracted code maintains original type paths through nested extensions. This enables incremental refactoring without breaking existing code. When ready for true module separation, types can be moved to true separate modules.

**Compilation Performance Impact:**
- Splitting large files reduces recompilation scope
- Editing AgentChatView now recompiles ~720 lines instead of 830
- Future phases will further optimize build times

---

## Git History

**2026-03-29 (오늘)**
- **[진행 중]** - feat: Add fallback image system for character profiles (11 characters)
- **[진행 중]** - refactor: Update CharacterSpriteScene with fallback state chain and 1:1 sprite support
- **[진행 중]** - Update SpriteAgentView, AgentConfig, AgentWindowManager, AgentSeatView for image fallback
- **46abe69** - Fix nil crash in CharacterSpriteScene.loadAndPlay (guard characterNode before hideEmojiFallback)
- **[진행 중]** - doc: Update DEVLOG with sprite system, layout optimization, image fallback implementation

**2026-03-28~29**
- **1197b59** - fix: Remove sidebar collapse button from project sidebar header
- **76ad628** - fix: Reduce chat window width to 700px with consistent height
- **ad0f9d1** - doc: Add development log documenting refactoring phases and crash fix
- **e2bec6a** - Refactor: Split large monolithic files into focused modules (6 new files, 4 modified)
- **4dd5eff** - Update gitignore for Xcode user data
- **f547fa3** - Fix nested git repository to push properly
- **bf793cd** - Initial commit
