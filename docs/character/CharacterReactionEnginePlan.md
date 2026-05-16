# Character Reaction Engine Plan

**Scope**: Round 231A
**Status**: Design document (not yet implemented)
**Goal**: Bridge Workroom events to character animation states without replacing existing system

---

## Design Philosophy

The character system in MyTeam is intentionally **reactive, not proactive**. The character doesn't initiate workflows — it responds to user and system events with visual/audio feedback.

```
User Action / System Event
  ↓
WorkflowOrchestrator detects event
  ↓
CharacterReactionEngine interprets state
  ↓
AnimationState updated
  ↓
SpriteAgentView re-renders with new expression
  ↓
Optional dialogue + TTS queued
```

This keeps the character **assistive, not intrusive**.

---

## New Event Model

### WorkroomCharacterEvent

```swift
enum WorkroomCharacterEvent: Equatable, Sendable {
    /// App launched
    case appOpened

    /// Workroom/conversation opened
    case workroomOpened(roomID: UUID, workroomName: String)

    /// User submitted a prompt
    case promptSubmitted(text: String, wordCount: Int)

    /// AI document generation started
    case documentGenerationStarted(documentType: String)

    /// File read started
    case fileReadStarted(fileName: String)

    /// Artifact successfully created
    case artifactCreated(fileName: String, type: String)

    /// Artifact verification shows warning
    case artifactVerificationWarning(reason: String)

    /// Artifact verification failed
    case artifactVerificationFailed(reason: String)

    /// Error recovery process started
    case recoveryStarted(fromError: String)

    /// Waiting for user approval to continue
    case approvalWaiting(forAction: String)

    /// Task completed successfully
    case taskCompleted(summary: String)

    /// Long idle detected (5+ minutes)
    case idleLong(minutesIdle: Int)

    /// Error occurred
    case errorOccurred(type: String, recoverable: Bool)
}
```

---

## State Mapping

### Core Mapping: WorkroomCharacterEvent → AnimationState

```swift
func mapToAnimationState(_ event: WorkroomCharacterEvent) -> AnimationState {
    switch event {
    case .appOpened:
        return .clockIn

    case .workroomOpened:
        return .clockIn  // Same as app open

    case .promptSubmitted:
        return .thinking

    case .documentGenerationStarted:
        return .typing

    case .fileReadStarted:
        return .thinking  // or .typing if analyzing while reading

    case .artifactCreated:
        return .joy

    case .artifactVerificationWarning:
        return .confused

    case .artifactVerificationFailed:
        return .sad

    case .recoveryStarted:
        return .thinking  // "trying again"

    case .approvalWaiting:
        return .resting  // Not a current state; add in v2

    case .taskCompleted:
        return .backToWork  // Ready for next task

    case .idleLong:
        return .sleeping

    case .errorOccurred(let type, let recoverable):
        return recoverable ? .thinking : .sad
    }
}
```

### Dialogue Pairing: Event → CharacterDialogues Selection

```swift
func selectDialogue(for event: WorkroomCharacterEvent) -> String? {
    switch event {
    case .appOpened, .workroomOpened:
        return CharacterDialogues.greeting.random()  // "좋은 아침이에요!"

    case .promptSubmitted(let text, _):
        if text.count < 10 {
            return CharacterDialogues.confused.random()  // "뭐라고 하신 거죠?"
        }
        return CharacterDialogues.thinking.random()  // "생각 중이에요..."

    case .documentGenerationStarted(let type):
        if type == "meeting_minutes" {
            return "회의록 작성 중입니다"
        }
        return CharacterDialogues.typing.random()  // "작성 중..."

    case .fileReadStarted(let fileName):
        return "'\(fileName)' 읽는 중..."

    case .artifactCreated(let fileName, _):
        return "'\(fileName)' 완료했어요!" + " 🎉"

    case .artifactVerificationWarning:
        return CharacterDialogues.confused.random()  // "뭔가 이상한데..."

    case .artifactVerificationFailed:
        return CharacterDialogues.sad.random()  // "실패했어요..."

    case .recoveryStarted:
        return "다시 시도할게요"

    case .approvalWaiting:
        return "결정 기다리는 중입니다"

    case .taskCompleted(let summary):
        return "완료됐어요! \(summary)"

    case .idleLong(let minutesIdle):
        if minutesIdle > 10 {
            return CharacterDialogues.sleeping.random()  // "음..."
        }
        return nil  // Stay in current state

    case .errorOccurred(let type, _):
        return "오류가 발생했습니다: \(type)"
    }
}
```

---

## Integration Points

### 1. WorkflowOrchestrator

**Location**: `MyTeam/WorkflowOrchestrator.swift`

```swift
// In dispatch() method
async func dispatch(userMessage: String, roomID: UUID, manager: AgentWindowManager) async {
    let event = WorkroomCharacterEvent.promptSubmitted(
        text: userMessage,
        wordCount: userMessage.split(separator: " ").count
    )
    
    CharacterReactionEngine.shared.process(event: event, agentID: manager.currentAgentID)
    
    // ... existing dispatch logic ...
}

// In runUniversalDocumentWorkflow()
do {
    CharacterReactionEngine.shared.process(
        event: .documentGenerationStarted(documentType: "document"),
        agentID: manager.currentAgentID
    )
    
    let result = try await runUniversalDocument(...)
    
    CharacterReactionEngine.shared.process(
        event: .artifactCreated(fileName: result.filename, type: "document"),
        agentID: manager.currentAgentID
    )
} catch {
    CharacterReactionEngine.shared.process(
        event: .artifactVerificationFailed(reason: error.localizedDescription),
        agentID: manager.currentAgentID
    )
}
```

### 2. AgentWindowManager (Idle Detection)

**Location**: `MyTeam/AgentWindowManager.swift`

```swift
// Add idle timer
private var idleTimer: Timer?
private var lastInteractionTime = Date()

func resetIdleTimer() {
    lastInteractionTime = Date()
    idleTimer?.invalidate()
    
    idleTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: false) { [weak self] _ in
        let minutesIdle = 5
        CharacterReactionEngine.shared.process(
            event: .idleLong(minutesIdle: minutesIdle),
            agentID: self?.currentAgentID ?? ""
        )
    }
}

// Call in chatInputView submission, menu click, window focus, etc.
```

### 3. ResultVerifier (Error Handling)

**Location**: `MyTeam/ResultVerifier.swift`

```swift
func verify(artifact: Artifact) -> VerificationResult {
    if hasError {
        CharacterReactionEngine.shared.process(
            event: .artifactVerificationFailed(reason: errorMessage),
            agentID: "system"
        )
        return .error(message: errorMessage)
    }
    
    if hasWarning {
        CharacterReactionEngine.shared.process(
            event: .artifactVerificationWarning(reason: warningMessage),
            agentID: "system"
        )
    }
    
    return .success
}
```

---

## CharacterReactionEngine Implementation

### Structure

```swift
actor CharacterReactionEngine {
    static let shared = CharacterReactionEngine()
    
    private var agentAnimationStates: [String: AnimationState] = [:]
    private var eventQueue: [WorkroomCharacterEvent] = []
    
    nonisolated func process(
        event: WorkroomCharacterEvent,
        agentID: String
    ) {
        Task { await self.processInternal(event: event, agentID: agentID) }
    }
    
    private func processInternal(
        event: WorkroomCharacterEvent,
        agentID: String
    ) async {
        let newState = mapToAnimationState(event)
        agentAnimationStates[agentID] = newState
        
        // Update SpriteAgentView via @EnvironmentObject
        NotificationCenter.default.post(
            name: NSNotification.Name("AgentAnimationStateChanged"),
            object: nil,
            userInfo: ["agentID": agentID, "state": newState.rawValue]
        )
        
        // Optional: queue dialogue
        if let dialogue = selectDialogue(for: event) {
            CharacterDialogues.queue(dialogue, agentID: agentID)
            // TTS follows if enabled
        }
    }
}
```

### Why Actor?

The engine is an `actor` to safely coordinate multiple threads:
- Main thread (UI events)
- Background threads (LLM processing, file I/O)
- Workflowor chestrator Task<>

No data races, simple isolation.

---

## UI Reactivity

### SpriteAgentView Integration

Current `SpriteAgentView.swift` already observes `AnimationState`:

```swift
struct SpriteAgentView: View {
    @State var currentState: AnimationState = .idle
    
    // Existing code listens to state changes
    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AgentAnimationStateChanged"))) { notification in
        if let state = notification.userInfo?["state"] as? String,
           let newState = AnimationState(rawValue: state) {
            self.currentState = newState
        }
    }
}
```

No changes needed to SpriteAgentView — engine just pushes new states.

---

## State Transition Rules

### Allowed Transitions

```
Any state → clockIn       (workroom opened)
Any state → thinking      (prompt submitted, file reading)
thinking  → typing        (document generation confirmed)
typing    → joy           (successful artifact)
typing    → confused      (warning detected)
typing    → sad           (error detected)
joy/sad   → idle          (auto-return after 2 sec)
Any state → sleeping      (idle 5+ min)
sleeping  → idle          (user interaction)
```

### Blocked Transitions (Prevented)

```
joy/sad → joy/sad         (avoid animation interruption)
typing  → sad immediately (verify before failing)
```

---

## Configuration

### Timings (Tunable in v2)

```swift
struct CharacterReactionConfig {
    /// How long to stay in success/failure state before returning to idle
    static let successDisplayDuration: TimeInterval = 2.0
    
    /// Idle timeout to trigger sleeping state
    static let idleThresholdMinutes: Int = 5
    
    /// Debounce: ignore rapid repeated events
    static let eventDebounceInterval: TimeInterval = 0.2
}
```

### Dialogue Enable/Disable

```swift
// In SettingsView or manager
var enableCharacterDialogue: Bool = true  // User can disable

// Engine respects:
if enableCharacterDialogue {
    CharacterDialogues.queue(dialogue, agentID: agentID)
}
```

---

## Testing Plan (Round 231A)

### Unit Tests

- [ ] mapToAnimationState() returns correct state for each event
- [ ] selectDialogue() returns non-empty string for applicable events
- [ ] Blocked transitions are prevented
- [ ] Actor thread safety under concurrent event posting

### Integration Tests

- [ ] Workroom open → clockIn animation triggers
- [ ] Prompt submission → thinking state transitions
- [ ] Document generation starts → typing animation
- [ ] Artifact creation → joy animation + dialogue
- [ ] Error → sad/confused animation
- [ ] Idle 5+ min → sleeping state
- [ ] User interaction resets idle timer

### Regression Tests

- [ ] Existing character system (SpriteAgentView, CharacterDialogues, AnimationState) unchanged
- [ ] Drag/landing reactions still work
- [ ] Double-tap greeting still triggers
- [ ] AI text emotion detection (existing) coexists

---

## Deferred to v2

- [ ] CharacterMood type (unnecessary for v1)
- [ ] CharacterActivity type (unnecessary for v1)
- [ ] Personality customization
- [ ] Multi-character dialogue coordination
- [ ] Dynamic dialogue generation (vs. static pool)

---

## Risk Mitigation

| Risk | Mitigation |
|---|---|
| Animation spam (too many state changes) | Event debouncing + transition rules |
| Threading issues | Actor-based isolation |
| Dialogue interruptions | Queue dialogue, respect disable setting |
| Performance impact | Events posted async, no blocking |
| Regression of existing character system | No changes to existing files, additive only |

---

## Success Criteria (Round 231A)

- [x] Design document complete
- [ ] WorkroomCharacterEvent enum implemented
- [ ] CharacterReactionEngine implemented
- [ ] Integration points in WorkflowOrchestrator
- [ ] Integration points in AgentWindowManager
- [ ] All unit tests passing
- [ ] All integration tests passing
- [ ] Existing character system unmodified
- [ ] QA sign-off: no character animation regressions

---

**Status**: Design complete, implementation deferred to Round 231A
**Next**: Asset production (SpriteSheetProductionSpec) + engine coding
