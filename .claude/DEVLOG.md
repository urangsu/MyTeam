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
**Commit:** (진행 중)

**배경:** 치코(agent_5) 23개 모션 PNG 시퀀스 제작 완료 (12~48프레임, 모두 영문 state명)

**파일 배치 구조:**
```
MyTeam/MyTeam/Resources/Sprites/치코/
  치코_{state명}_{001~}.png
  (예: 치코_idle_001.png, 치코_disagree_001.png)
```
Xcode에서 "Create folder references"(파란 폴더)로 추가 필요

**코드 변경:**

1. `CharacterSpriteScene.swift` — AnimationState 15 → 26개로 확장
   - 신규 추가: look, lifted, dropped, backToWork, loopReturn, typing, clockOut, resting, clockIn, returnToTyping, confused
   - loopingStates에 typing, resting 추가 (지속형 루프 상태)
   - loadTextures: `Bundle.main.path(inDirectory: "Sprites/치코")` 서브디렉토리 우선 탐색 후 flat/Assets fallback

2. `AgentWindowManager.swift` — agent_5 치코 `spriteName: nil → "치코"` 활성화

**AnimationState 반복 정책:**
- **루프 (6개):** idle, speaking, thinking, sleeping, typing, resting
- **1회 후 idle 복귀 (18개):** 나머지 모든 상태

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

- **1197b59** - fix: Remove sidebar collapse button from project sidebar header
- **76ad628** - fix: Reduce chat window width to 700px with consistent height
- **ad0f9d1** - doc: Add development log documenting refactoring phases and crash fix
- **e2bec6a** - Refactor: Split large monolithic files into focused modules (6 new files, 4 modified)
- **4dd5eff** - Update gitignore for Xcode user data
- **f547fa3** - Fix nested git repository to push properly
- **bf793cd** - Initial commit
