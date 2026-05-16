# Character Reaction Bridge Backlog

## Existing System (Preserved)

Current character runtime uses:
- `AnimationState` — enumeration of sprite states (idle, typing, speaking, etc.)
- `CharacterDialogues.swift` — dialogue database with emotional context
- `SpriteAgentView.swift` — SwiftUI view for rendering character sprites with animations
- `CharacterSpriteScene.swift` — SceneKit scene for 3D character rendering
- `AgentWindowManager.agentEmotions` — agent emotion tracking
- `TeamTableView` drag/landing reactions with dialogue triggers

## Currently Connected Flows

### Direct UI Events
- Drag agent start → `.drag` animation + "무겁네요" dialogue
- Agent lands on table → `.landing` animation + success dialogue
- Double-tap agent → `.greeting` dialogue + wave animation
- Startup/wake/idle/sleep transitions → localized dialogue + optional TTS

### AI Text Processing
- AgentChatView receives LLM text → `detectEmotion()` analyzes sentiment
- Emotion detected → `agentEmotions[agentID]` updated in real-time
- UI re-renders with character expression matching emotion

### Persistence
- `AgentWindowManager.agentEmotions` persists within session
- Character state reset on app restart (intentional — fresh start)

## Identified Gaps (To Bridge)

### Workroom-Triggered Events

| Event | Desired State | Current Status | Target Round |
|---|---|---|---|
| Workroom opened | `.clockIn` / greeting | Not connected | 231A |
| User submits prompt | `.thinking` / "생각 중" | Partial (text-based) | 231A |
| Document generation starts | `.typing` / "작성 중" | Not connected | 231A |
| File read begins | `.thinking` / "읽는 중" | Not connected | 231A |
| Artifact created successfully | `.joy` / "완료됐어요!" | Not connected | 231A |
| Verification warning | `.confused` / "뭔가 이상한데?" | Not connected | 231A |
| Verification failed | `.sad` / "실패했어요" | Not connected | 231A |
| Error recovery starts | `.thinking` / "다시 시도 중" | Not connected | 231A |
| Approval waiting | `.resting` / "잠깐 대기할게요" | Not connected | 231A |
| Task completed | `.backToWork` / "좋아요!" | Not connected | 231A |
| Long idle (5+ min) | `.sleeping` / "음..." | Not connected | 231A |

### Optional v2 States (Post-v1)

- `.holdingDocument` — showing a document
- `.checklistStamping` — completing checklist items
- `.coffeeBreak` — break time dialogue
- `.searchingFile` — file intake in progress
- `.organizingDesk` — cleanup action
- `.waitingApproval` — anticipatory state

## Architecture Decision

**Do not replace AnimationState in this round.**

The existing character system is fundamentally sound. Instead:
1. Create `WorkroomCharacterEventBridge` (simple event-to-state mapper)
2. Hook it into WorkflowOrchestrator lifecycle callbacks
3. Reuse existing AnimationState + CharacterDialogues
4. Keep SpriteAgentView, CharacterSpriteScene untouched

This preserves stability and allows v1 release without character redesign.

## Implementation Plan (Round 231A)

### New File: WorkroomCharacterEventBridge.swift

```swift
enum WorkroomCharacterEvent {
    case appOpened
    case workroomOpened(roomID: UUID)
    case promptSubmitted(text: String)
    case documentGenerationStarted
    case fileReadStarted(fileName: String)
    case artifactCreated(fileName: String)
    case artifactVerificationWarning
    case artifactVerificationFailed(reason: String)
    case recoveryStarted
    case approvalWaiting
    case taskCompleted
    case idleLong
}

// Maps WorkroomCharacterEvent → AnimationState
func mapToAnimationState(_ event: WorkroomCharacterEvent) -> AnimationState
```

### Hooks in WorkflowOrchestrator
- `dispatch()` entry → `.promptSubmitted`
- `runUniversalDocumentWorkflow()` start → `.documentGenerationStarted`
- `runUniversalDocumentWorkflow()` success → `.artifactCreated`
- `runUniversalDocumentWorkflow()` failure → `.artifactVerificationFailed`

### Hooks in AgentWindowManager
- `openWorkroom()` → `.workroomOpened`
- Idle timer (5+ min) → `.idleLong`

### UI Integration
- SpriteAgentView already supports AnimationState
- No view changes needed
- Event bridge just updates state, view reacts automatically

## Testing (Round 231A)

- [Pending] Workroom open triggers clockIn animation
- [Pending] Prompt submission triggers thinking state
- [Pending] Document generation shows typing animation
- [Pending] Artifact creation triggers joy reaction
- [Pending] Error detection shows sad/confused state
- [Pending] Long idle shows sleeping state
- [Pending] No character sprite regressions

## Deferred (Post-v1)

- [ ] CharacterMood/CharacterActivity introduction
- [ ] Sprite sheet production (team asset)
- [ ] Voice/dialogue personalization
- [ ] Multi-agent emotional interaction
- [ ] DLC character purchase flow

---

**Status**: Backlog documented, ready for Round 231A implementation
**Preserves**: All existing character files and state machine
**Risk**: Low (non-breaking, additive only)
