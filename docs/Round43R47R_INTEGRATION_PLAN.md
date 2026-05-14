# Round 43R-47R — Product Surface Real Integration Plan

## Overview
Round 43R-47R focuses on integrating the UI components and views created in Round 43A-47H into the actual product surface. This requires:

1. **Target Registration** (requires Xcode on macOS)
2. **View Integration** (code changes)
3. **Message Surface Updates** (code changes)
4. **Build & Verification** (requires xcodebuild on macOS)

## Phase 1: Target Registration (Xcode Required)

### Files to Register in Xcode Target "MyTeam"
```
MyTeam/FirstLaunchBannerView.swift
MyTeam/LocalOnlyModeCardView.swift  
MyTeam/StarterActionStripView.swift
MyTeam/StarterActionDispatcher.swift
```

### Steps (on macOS with Xcode)
1. Open `MyTeam/MyTeam.xcodeproj` in Xcode
2. Select target "MyTeam"
3. Go to Build Phases → Compile Sources
4. Click "+" and add the 4 new .swift files
5. Verify no duplicate entries
6. Save project

## Phase 2: Code Integration (Linux/macOS)

### 2.1 FirstLaunchBannerView Integration

**Files to Modify:**
- `MyTeam/TeamStatusView.swift`
- `MyTeam/DailyBriefingCardView.swift`
- `MyTeam/FirstLaunchBannerView.swift` (already created)

**Location in TeamStatusView:**
- Add after header section (line ~210), before agentListView
- Show banner if `shouldShowFirstLaunchBanner` is true
- Banner dismisses when user taps API key button

**Location in DailyBriefingCardView:**
- Add in empty state (when no briefing items)
- Before "실행 가능한 액션이 없습니다." text

**Integration Code Pattern:**
```swift
if shouldShowFirstLaunchBanner {
    FirstLaunchBannerView(
        state: firstLaunchState,
        onDismiss: { /* hide banner */ },
        onOpenSettings: { /* navigate to settings */ }
    )
    .transition(.move(edge: .top).combined(with: .opacity))
}
```

### 2.2 LocalOnlyModeCardView Integration

**Files to Modify:**
- `MyTeam/SettingsView.swift`
- `MyTeam/AgentWindowManager.swift` (for state)

**Location in SettingsView:**
- Add in API Key section (when key is missing)
- Show local features available (3-4 items)
- Include "Set API Key" button

**Integration Code Pattern:**
```swift
if !hasAPIKey {
    LocalOnlyModeCardView(
        onOpenSettings: { /* show file */ }
    )
}
```

### 2.3 StarterActionStripView Integration

**Files to Modify:**
- `MyTeam/TeamStatusView.swift` or `MyTeam/DailyBriefingCardView.swift`
- `MyTeam/StarterActionDispatcher.swift` (already created)
- `MyTeam/WorkflowOrchestrator.swift` (for routing)

**Location:**
- In empty state or first-launch state
- Replace/supplement basic empty message
- Show 4 starter action buttons

**Integration Code Pattern:**
```swift
StarterActionStripView(
    actions: StarterActionProvider.actions(for: firstLaunchState),
    onActionTap: { action in
        Task {
            await StarterActionDispatcher.dispatch(
                action,
                roomID: currentRoomID,
                manager: manager,
                orchestrator: orchestrator,
                onFileIntakeRequested: {
                    isFileIntakeSheetPresented = true
                }
            )
        }
    }
)
```

### 2.4 FirstResultActionStripView Integration

**Files to Modify:**
- `MyTeam/ArtifactCardView.swift`
- `MyTeam/StarterActionStripView.swift` (already has FirstResultActionStripView)

**Location:**
- After first artifact created
- Show 4 action buttons (요약, 표, 체크리스트, Finder)
- Only for markdown/txt artifacts with valid hash

**Conditions:**
```swift
if let artifact = recentArtifact,
   artifact.fileExists,
   artifact.hashValid,
   artifact.type == .markdown || artifact.type == .text {
    FirstResultActionStripView(
        actions: StarterActionProvider.actionsForFirstResult(),
        onActionTap: { action in
            // Handle first result action
        }
    )
}
```

### 2.5 SettingsView Message Simplification

**Files to Modify:**
- `MyTeam/SettingsView.swift`
- `MyTeam/AssistantConnectorCenterView.swift`

**Changes:**
1. Hide OAuth client ID explanations (general users)
2. Show only: "API key status", "Local features available", "Connection status"
3. Remove lengthy descriptions
4. Move debug settings to DEBUG-only section

**Messages to Use:**
```swift
"로컬 문서와 파일 기능은 바로 사용할 수 있습니다.
연결 기능은 읽기 전용 또는 준비 중입니다.
메일 발송, 일정 생성, 파일 삭제는 자동 실행하지 않습니다."
```

### 2.6 Connector Center State Labels

**Files to Modify:**
- `MyTeam/AssistantConnectorCatalog.swift`
- `MyTeam/AssistantConnectorPolicy.swift`
- `MyTeam/AssistantConnectorCenterView.swift`

**State Label Standardization:**
```swift
enum ConnectorStateLabel: String {
    case available       // Fully operational
    case readOnly        // Read-only access
    case planned         // Preparation in progress
    case requiresApproval // Needs user approval
    case blocked         // Blocked by policy
    case unavailable     // Not yet implemented
}
```

**Mapping:**
- Calendar read → readOnly or unavailable
- Calendar write → blocked
- Gmail metadata → planned or unavailable
- Gmail body read → requiresApproval or planned
- Mail send → blocked
- Naver → planned

### 2.7 Approval/Blocked Message Standardization

**Files to Modify:**
- `MyTeam/CapabilityAwareRouter.swift`
- `MyTeam/GoalGate.swift`
- `MyTeam/WorkflowOrchestrator.swift`
- `MyTeam/BriefingActionDispatcher.swift`

**Message Copy Standard:**
```swift
// Blocked (Policy)
"이 작업은 안전 정책상 자동 실행하지 않습니다."

// Unavailable (Not implemented)
"이 기능은 아직 사용할 수 없습니다. 현재는 로컬 파일/문서 기능을 사용할 수 있습니다."

// Approval Required
"이 작업은 승인이 필요합니다. 자동 실행하지 않고 승인 대기로 남겨둘게요."

// Feature Preparing
"이 기능은 준비 중입니다. 현재 지원되는 기능으로 먼저 도와드릴게요."
```

## Phase 3: RuntimeDiagnostics Flags (Code Changes)

**Files to Modify:**
- `MyTeam/RuntimeDiagnosticsService.swift`

**Flags to Connect:**
```swift
// First Launch / Onboarding
firstLaunchGuidanceAvailable: Bool
localOnlyModeAvailable: Bool
noKeyStateHandled: Bool
offlineStateHandled: Bool
connectorLimitedStateHandled: Bool

// Product Surface
starterActionsAvailable: Bool
firstResultActivationAvailable: Bool
workspaceHomeAvailable: Bool
connectorSurfaceSimplified: Bool
settingsUserFacingCopySimplified: Bool

// Feature Status
ttsFallbackAvailable: Bool
storeKitSurfaceDocumented: Bool
appStoreMetadataDraftAvailable: Bool
privacyNutritionDraftAvailable: Bool

// QA Status
manualQAPendingCount: Int  // = 1 (Round 48A)
```

## Phase 4: Build & Verification (xcodebuild on macOS)

### Step 1: Add Files to Target (Xcode)
- Register new Swift files in project.pbxproj
- Verify no warnings about duplicate build files

### Step 2: Build Debug
```bash
xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Debug build
```

**Success Criteria:**
- BUILD SUCCEEDED
- 0 Swift warnings in app code
- All new views compile without errors

### Step 3: Build Release
```bash
xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Release build
```

**Success Criteria:**
- BUILD SUCCEEDED
- 0 Swift warnings in app code
- Debug toggles hidden
- Connector write tools hidden

## Files to Modify (Summary)

### High Priority (Integration)
- [ ] TeamStatusView.swift - Add FirstLaunchBannerView, StarterActionStripView
- [ ] DailyBriefingCardView.swift - Add FirstLaunchBannerView, StarterActionStripView
- [ ] ArtifactCardView.swift - Add FirstResultActionStripView
- [ ] SettingsView.swift - Simplify copy, add LocalOnlyModeCardView
- [ ] StarterActionDispatcher.swift - Already created, verify routing

### Medium Priority (State & Messages)
- [ ] AssistantConnectorCenterView.swift - Update state labels
- [ ] AssistantConnectorPolicy.swift - Define state labels
- [ ] WorkflowOrchestrator.swift - Update message copy
- [ ] BriefingActionDispatcher.swift - Update message copy
- [ ] CapabilityAwareRouter.swift - Update message copy

### Low Priority (Diagnostics)
- [ ] RuntimeDiagnosticsService.swift - Add/connect new flags
- [ ] DiagnosticsVisibilityPolicy.swift - Ensure Release hides debug info

## Xcode Project File Note

**Critical:** The new Swift files are NOT yet registered in `MyTeam.xcodeproj`. 

**Resolution:**
1. Open project in Xcode on macOS
2. Go to: Target "MyTeam" → Build Phases → Compile Sources
3. Click "+" and select:
   - FirstLaunchBannerView.swift
   - LocalOnlyModeCardView.swift
   - StarterActionStripView.swift
   - StarterActionDispatcher.swift
4. Verify entries (should have no duplicates)
5. Save project (Xcode auto-saves)
6. Build to verify

## Testing Strategy

Since this round does NOT include manual QA:

1. Build must pass (Debug & Release)
2. Zero compiler warnings in app code
3. Unused view warnings should not appear
4. All integration points should type-check correctly
5. Message copy should be consistent

## Expected Commit Summary

```
Round 43R-47R — Product Surface Real Integration + Build Recovery Pack

- Integrated FirstLaunchBannerView into TeamStatusView / DailyBriefingCardView
- Integrated LocalOnlyModeCardView into SettingsView  
- Integrated StarterActionStripView into empty states
- Integrated FirstResultActionStripView into ArtifactCardView
- Connected StarterActionDispatcher routing to WorkflowOrchestrator
- Standardized connector state labels (available/readOnly/planned/blocked/unavailable)
- Simplified SettingsView copy for general users
- Updated approval/blocked/unavailable messages for consistency
- Connected RuntimeDiagnostics flags to actual states
- Verified no external write, no Gmail API, no Calendar write
- Target registration pending (requires Xcode on macOS)
- Debug/Release build verification pending (requires xcodebuild on macOS)
```

## Status

- **Code Integration:** In progress
- **Target Registration:** Pending (macOS/Xcode)
- **Build Verification:** Pending (macOS/xcodebuild)
- **Manual QA:** Deferred to Round 48A

---

Last Updated: 2026-05-14
Round: 43R-47R
