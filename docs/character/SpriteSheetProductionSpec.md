# Sprite Sheet Production Specification

## Overview

This document specifies the sprite asset production pipeline for character animations in Chiko runtime.
**Status**: Specification ready, production deferred to post-v1
**Producer**: Design team / asset contractor
**Consumer**: `SpriteAgentView.swift`, `CharacterSpriteScene.swift`

---

## Runtime System Architecture

### Current Implementation

MyTeam uses iOS/macOS-native sprite rendering:

```
SpriteAgentView (SwiftUI view)
  ├─ Frame based on AnimationState
  ├─ Loads PNG sequence asynchronously
  └─ Renders with optional shake/drift animations

CharacterSpriteScene (SceneKit fallback)
  ├─ 3D proxy when 2D rendering not available
  ├─ Uses same AnimationState enum
  └─ Fallback to profile image if scene unavailable
```

### File Convention

```
Sprites/{characterID}/{characterID}_{state}_{frameIndex}.png

Example:
Sprites/치코/치코_idle_001.png
Sprites/치코/치코_idle_002.png
Sprites/치코/치코_typing_001.png
Sprites/치코/치코_joy_001.png
```

### Loading Pipeline

```swift
// SpriteAgentView.swift (reference)
private func loadAnimation(for state: AnimationState) {
    let imageSequence = (1...maxFrames)
        .compactMap { idx in
            NSImage(named: "치코_\(state.rawValue)_\(String(format: "%03d", idx))")
        }
    animationFrames = imageSequence
}
```

---

## Chiko Base Character (v1)

### Identity
- **Name**: 치코 (Chiko)
- **Role**: AI assistant, team workspace mascot
- **Personality**: Helpful, attentive, slightly playful
- **Visual**: Humanoid form (not childish, not robotic)

### Metadata
- **spriteName**: `"치코"`
- **fallbackImageName**: `"치코_profile"` (static fallback)
- **baseWidth**: 200 px (can scale to 80-300 px)
- **baseHeight**: 200 px

---

## Required Animation States (Tier 1 - v1 MVP)

These must be complete and production-ready for v1 release.

| State | Purpose | Frame Count | Loop | Description |
|---|---|---|---|---|
| `idle` | Default resting state | 4-6 | Yes | Subtle breathing, gentle eye blinks, relaxed posture |
| `typing` | Document generation in progress | 6-8 | Yes | Hands moving (typing motion), focused expression |
| `thinking` | Processing, analyzing file | 5-7 | Yes | Hand to chin, contemplative expression, maybe eye dots |
| `speaking` | AI response being read | 4-6 | Yes | Mouth movement (no actual sync), gesturing hands |
| `joy` | Task success, artifact created | 3-4 | No | Big smile, celebratory gesture (thumbs up / clap) |
| `sad` | Error, verification failed | 3-4 | No | Drooped expression, apologetic pose |
| `confused` | Warning, unexpected input | 3-4 | No | Head tilt, question mark expression |
| `drag` | User dragging agent | 2-3 | No | Lighter color, "floating" pose |
| `landing` | Agent dropped on table | 2-3 | No | Impact dust, pleased expression |
| `clockIn` | App/workroom opened | 2-3 | No | Wave, "Good morning" energy |
| `backToWork` | Task resumed | 2-3 | No | Stretch gesture, "Let's go" energy |
| `sleeping` | Long idle (5+ min) | 3-4 | Yes | Eyes closed, resting head, zzz |

### Frame Specifications

**Resolution**: 
- 200×200 px at standard size (scalable)
- PNG-8 or PNG-24 (transparent background required)
- No anti-aliasing artifacts at small sizes

**Timing**:
- Loop states: 100-150ms per frame
- Event states (joy/sad/confused): 120-200ms per frame
- Total loop cycle: 800ms-1200ms

**Consistency**:
- Baseline at y=180px (feet at bottom)
- Center at x=100px
- Head size relative to body consistent across all states
- No sudden scaling jumps between states

---

## Optional Animation States (Tier 2 - Post-v1)

May be added in future releases without breaking v1.

| State | Purpose | Priority |
|---|---|---|
| `holdingDocument` | Showing a document to user | Medium |
| `checklistStamping` | Completing checklist item (stamp animation) | Medium |
| `coffeeBreak` | Break time (yawn, stretch) | Low |
| `searchingFile` | File intake in progress | Medium |
| `organizingDesk` | Cleanup/organization action | Low |
| `waitingApproval` | Awaiting human approval | Medium |

---

## Production Rules

### Mandatory

- [ ] **Transparent PNG** — use PNG-24 with alpha channel
- [ ] **Consistent baseline** — all frames aligned at bottom
- [ ] **No baked-in text** — dialogue comes from CharacterDialogues.swift
- [ ] **Readable at small size** — test at 80×80 px
- [ ] **Subtle motion** — avoid jarring frame-to-frame changes
- [ ] **Work-focused aesthetic** — professional but approachable (not childish)
- [ ] **No app startup blocker** — assets load asynchronously

### Forbidden

- ❌ Baked-in timestamp / date
- ❌ Company branding (Anthropic logos, external company marks)
- ❌ Copyrighted character likenesses
- ❌ Animated text / floating UI elements
- ❌ Transparency below 50% (must be fully opaque or fully transparent per pixel)
- ❌ Color gradients that won't compress well in PNG-8

### Optional (High Polish)

- Subtle shadow under feet (adds depth)
- Hair flow animation (very subtle)
- Eye highlight reflection
- Micro-expressions (surprise, delight)

---

## File Naming & Organization

```
Assets/
├─ Sprites/
│  └─ 치코/
│     ├─ 치코_idle_001.png
│     ├─ 치코_idle_002.png
│     ├─ 치코_idle_003.png
│     ├─ 치코_typing_001.png
│     ├─ ...
│     └─ 치코_sleeping_004.png
│
└─ Fallback/
   └─ 치코_profile.png   (static 200×200 fallback)
```

### Naming Convention

```
{characterID}_{stateName}_{frameNumber:03d}.png

Examples:
치코_idle_001.png       ✓ Correct
치코_idle_1.png         ✗ Missing zero-padding
치코_Idle_001.png       ✗ Wrong case (enum uses lowercase)
치코_idle_001.jpg       ✗ Wrong format (PNG only)
```

---

## Integration Checklist

### For Designer/Asset Producer

- [ ] All Tier 1 states have complete sprite sheets
- [ ] Frame counts match `maxFramesPerState` in animation controller
- [ ] Baseline alignment checked visually
- [ ] Small-size readability tested (80×80 viewport)
- [ ] PNG optimization applied (TinyPNG or similar)
- [ ] Fallback profile image created (static 200×200)
- [ ] Filenames exactly match specification
- [ ] No blank/corrupted PNG files

### For Developer (Integration)

- [ ] Assets folder structure created
- [ ] `SpriteAgentView.loadAnimation()` tested with all states
- [ ] `CharacterSpriteScene` fallback tested
- [ ] Async loading doesn't block main thread
- [ ] Profile image renders when sprite unavailable
- [ ] No console warnings about missing assets
- [ ] Performance test: 60 FPS on M1 Mac, no memory spike

### For QA

- [ ] Character visible on app startup
- [ ] All state transitions smooth
- [ ] Drag/drop doesn't corrupt animation
- [ ] Long idle triggers sleeping state correctly
- [ ] Fallback to profile doesn't look broken
- [ ] Works in light and dark mode
- [ ] No asset corruption in release build

---

## Multi-Character Future (Post-v1)

Before adding paid DLC or additional characters, ensure:

| Requirement | Status |
|---|---|
| `spriteName` in AgentProfile available | [Pending] |
| Character role defined (drafter/reviewer/researcher/etc) | [Pending] |
| Idle state animation complete | [Pending] |
| Typing/thinking/joy states complete | [Pending] |
| Success dialogue defined | [Pending] |
| Fallback profile image available | [Pending] |
| Workflow event mapping defined | [Pending] |

---

## Asset Delivery

### Format

- PNG-24 (RGBA) or PNG-8 + alpha
- 200×200 px base size
- Compressed but not lossy (PNG standards)
- Organized in folder structure per spec

### Delivery Method

- [ ] Zip archive with folder structure
- [ ] Checksum verification (SHA256)
- [ ] Readme with frame counts per state
- [ ] Reference image showing all states

### Timeline

- **v1 (Chiko only)**: Ready for alpha
- **v2 (Optional additional characters)**: Post-release
- **v3 (DLC store)**: Deferred to business model phase

---

## Sprite Technical Limits

| Aspect | Limit | Rationale |
|---|---|---|
| File size per PNG | ≤ 50 KB | Memory + load time |
| Total asset folder | ≤ 2 MB | App download size |
| Frame count per state | ≤ 10 | Animation smoothness vs file count |
| Animation duration | 0.8–1.5 sec | Avoid jank or visual fatigue |
| Color palette | 256+ unique colors OK | PNG-24 can handle rich colors |

---

## Troubleshooting

| Issue | Solution |
|---|---|
| Sprites not loading | Check filename case (must be lowercase state names) |
| Animation stuttering | Increase frame duration (120ms minimum) |
| Aliasing at small size | Redraw with less fine detail |
| Memory spikes during load | Reduce frame count or PNG size |
| Corruption after app restart | Verify PNG checksums, re-export |

---

**Status**: Specification complete, ready for design team handoff
**Next**: Round 231A implementation + asset production integration
