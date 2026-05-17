# CharacterReaction Delegate Strategy Decision

**Date**: 2026-05-17 (Round 232)
**Status**: Decision finalized — agentEmotions path first, delegate deferred

---

## Two Available Paths

### Path A: agentEmotions (current, active)

```
Workroom event
  → CharacterReactionEventSink.shared.notifyXxx()
  → CharacterReactionEngine.shared.processEvent()
  → CharacterReactionMapping.reactionFor(event)
  → applyEmotionToManager(state:)
  → AgentWindowManager.agentEmotions[agentID] = state
  → AgentSeatView reads agentEmotions[config.id]
  → SpriteAgentView(state: emotionState)
  → CharacterSpriteScene.loadAndPlay(state:)
```

**Status**: ✅ Fully connected. No additional code required.

### Path B: CharacterReactionDelegate (deferred)

```
Workroom event
  → CharacterReactionEngine.processEvent(_:delegate:)
  → delegate.applyCharacterReaction(animationState:responseText:duration:)
  → SpriteAgentView (if conforming)
  → CharacterSpriteScene.loadAndPlay(state:)
```

**Status**: ⏳ Deferred. Protocol is defined. No conformance implemented yet.
`delegate` is nil at runtime. Engine falls through to no-op on delegate call.

---

## Decision

**Use Path A (agentEmotions) as primary and sole path for now.**

Reasons:
1. Already working — no additional implementation risk
2. `AgentWindowManager.agentEmotions` is the established mechanism for emotion state
3. `AgentSeatView` already reads `agentEmotions` and passes to `SpriteAgentView`
4. Adding delegate conformance to `SpriteAgentView` creates coupling between the reaction engine and the character rendering layer before manual QA verifies the basic path works
5. No SpriteKit replacement — existing PNG sequence loader is correct as-is

---

## When to Revisit Delegate Path

Consider adding `CharacterReactionDelegate` conformance only if:

- Manual QA shows `agentEmotions` path has delay or coverage issues
- A use case requires per-frame callbacks not available via `@Published` observation
- `AgentSeatView` is refactored in a way that breaks `agentEmotions` binding

If adding delegate:
- Add conformance to `AgentSeatView` (not `SpriteAgentView` directly)
- Keep conformance small: map `animationState` → update `emotionState` local var
- Do not replace `agentEmotions` path — run both in parallel
- Do not modify `CharacterSpriteScene`, `CharacterDialogues`, or `SpriteAgentView` structure

---

## What Is Preserved (Non-Negotiable)

| Component | File | Status |
|-----------|------|--------|
| `AnimationState` enum | `CharacterSpriteScene.swift` | ✅ Untouched |
| `CharacterSpriteScene` | `CharacterSpriteScene.swift` | ✅ Untouched |
| `SpriteAgentView` | `SpriteAgentView.swift` | ✅ Untouched |
| `CharacterDialogues` | `CharacterDialogues.swift` | ✅ Untouched |
| `AgentSeatView` | `AgentSeatView.swift` | ✅ Untouched |
| `agentEmotions` dict type | `AgentWindowManager.swift` | ✅ Untouched `[String: AnimationState]` |

---

## Prohibited Additions

- No `CharacterMood` enum
- No `CharacterActivity` enum
- No `CharacterEmotionMode`
- No SpriteKit runtime replacement
- No 3D / rigging
- No Mesh AI pipeline
