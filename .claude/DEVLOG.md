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

- **e2bec6a** - Refactor: Split large monolithic files into focused modules (6 new files, 4 modified)
- **4dd5eff** - Update gitignore for Xcode user data
- **f547fa3** - Fix nested git repository to push properly
- **bf793cd** - Initial commit
