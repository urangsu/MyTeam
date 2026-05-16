# Character Reaction Bridge Backlog

## Current System Status (Round 196)

### Preserved Components
- **AnimationState**: Character sprite animation framework (idle, typing, joy, sad, confused, etc.)
- **CharacterDialogues**: English + Korean dialogue mappings for each character
- **SpriteAgentView**: SpriteKit-based character sprite renderer
- **CharacterSpriteScene**: PNG sequence loader (`Sprites/{id}/{id}_{state}_{index}.png`)
- **AgentWindowManager.agentEmotions**: Emotion state tracking per agent
- **TeamTableView**: Drag/landing dialogue trigger logic

### Currently Connected Events
- **Drag gesture** → `.drag` state + character dialogue + audio
- **Landing gesture** → `.landing` state + character dialogue + audio
- **Double-tap** → `.greeting` dialogue + audio
- **AI text detection** → Emotion classification → `agentEmotions` update → sprite state
- **Startup/Wake/Idle/Sleep** → Local event dialogue + TTS playback

### Character Sprite Paths Preserved
```
MyTeam/CharacterSpriteScene.swift          # PNG loader
MyTeam/SpriteAgentView.swift               # SpriteKit wrapper
MyTeam/CharacterDialogues.swift            # Dialogue definitions
MyTeam/AgentSeatView.swift                 # Gesture handling
MyTeam/TeamTableView.swift                 # Drag/landing trigger
MyTeam/AgentWindowManager.swift            # Emotion state
MyTeam/CharacterVoiceConfig.swift          # Voice assignment
```

## Workroom Event Bridge Gap

### Not Yet Connected
The following Workroom events do NOT trigger character reactions:

1. **Workroom opened** 
   - Desired: Character shows `.clockIn` / `.greeting` animation
   - Current: No animation, just WorkroomHomeView load

2. **Document generation started**
   - Desired: Character shows `.typing` animation during LLM processing
   - Current: No visual feedback in Workroom context

3. **File reading started**
   - Desired: Character shows `.thinking` / `.look` animation
   - Current: No animation

4. **Artifact created / generation complete**
   - Desired: Character shows `.joy` / `.agree` animation + celebratory dialogue
   - Current: Silent artifact card appearance

5. **Verification failed**
   - Desired: Character shows `.confused` / `.sad` animation + diagnostic dialogue
   - Current: Silent error message

6. **Approval waiting**
   - Desired: Character shows `.resting` / `.thinking` animation + waiting dialogue
   - Current: Just status badge

7. **Task completed**
   - Desired: Character shows `.backToWork` / `.joy` animation + completion dialogue
   - Current: Silent task completion

8. **User switches rooms**
   - Desired: Character acknowledges room change
   - Current: No acknowledgement

## Why Deferred to Round 231A+

1. **Workroom model stable** — Core loop wiring (Round 196) completes without character bridge
2. **Character system unchanged** — All existing sprite/dialogue/emotion code preserved
3. **No blocking risk** — Workroom launches without reactions; reactions are enhancement
4. **Cleaner scope** — Character reaction engine deserves dedicated round
5. **Sprite production pending** — Awaiting new character sprite sequences for Workroom-specific states

## Implementation Path for Round 231A

### 1. Define WorkroomEventType enum
```swift
enum WorkroomEventType {
    case roomOpened(roomID: UUID, roomName: String)
    case documentGenerationStarted(promptType: String)
    case documentGenerationComplete(artifactID: String)
    case fileReadingStarted(fileName: String)
    case verificationFailed(reason: String)
    case approvalWaiting(taskID: String)
    case taskCompleted(taskID: String)
    case userSwitchedRooms(fromRoom: UUID, toRoom: UUID)
}
```

### 2. Create CharacterReactionEngine
- Maps WorkroomEventType → AnimationState
- Maps WorkroomEventType → CharacterDialogue
- Triggers TTS playback
- Updates AgentWindowManager.agentEmotions

### 3. Wire WorkroomHomeView events to CharacterReactionEngine
- WorkroomHomeView.onPrimaryActionTapped → fire event
- WorkroomHomeView.onNextActionTapped → fire event
- WorkflowOrchestrator completion → fire event

### 4. Extend Sprite Sequences
- Add `Sprites/{id}/{id}_clockIn_{index}.png`
- Add `Sprites/{id}/{id}_typing_{index}.png`
- Add `Sprites/{id}/{id}_thinking_{index}.png`
- Add `Sprites/{id}/{id}_joy_{index}.png`
- (and others per design)

### 5. Extend CharacterDialogues
- workroomOpened: "어떤 일을 도와드릴까요?"
- documentGenerating: "문서를 만들고 있어요. 잠깐만 기다려주세요."
- artifactCreated: "완성했어요! 확인해보세요."
- verificationFailed: "음, 다시 한 번 시도해볼까요?"
- etc.

## Risk Assessment
- **Zero regression risk** — Deferred work does not modify existing character code
- **Clean merge path** — Round 231A can be implemented independently on main

## Files to NOT Modify (Round 196)
- CharacterSpriteScene.swift
- SpriteAgentView.swift
- CharacterDialogues.swift
- AnimationState enum
- AgentSeatView drag/landing logic
- TeamTableView drag/landing trigger

## Validation Checklist (Round 196)
- [x] CharacterDialogues file preserved
- [x] SpriteAgentView file preserved
- [x] CharacterSpriteScene file preserved
- [x] AgentWindowManager.agentEmotions preserved
- [x] TeamTableView drag/landing callback preserved
- [x] No character.emotion state reset on Workroom open
- [x] No sprite asset deletion or path change
