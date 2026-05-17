# Chiko Sprite Sheet Handoff

**Version**: v1
**Updated**: 2026-05-17 (Round 232)
**Status**: ⏳ Design team pending

---

## Goal

Chiko should feel like a quiet work teammate, not a toy mascot.
Small size, subtle motion, professional but warm.

---

## Runtime Format

```
Sprites/치코/치코_{state}_{index}.png
```

Example:
```
Sprites/치코/치코_idle_001.png
Sprites/치코/치코_idle_002.png
Sprites/치코/치코_typing_001.png
Sprites/치코/치코_thinking_001.png
Sprites/치코/치코_joy_001.png
```

---

## Canvas Spec

| Item | Spec |
|------|------|
| Format | Transparent PNG |
| Size | Consistent across all states (e.g. 256×256 or 512×512 — decide once, keep fixed) |
| Baseline | Consistent foot/anchor point across all clips |
| Background | None (transparent) |
| Text | No text baked into image |
| Orientation | Forward-facing default |

---

## v1 Required Clips

### idle
- **Trigger**: Waiting for user input
- **Feel**: Quietly sitting at desk, calm, available
- **Motion**: Subtle idle breath or micro-movement. Minimal.
- **Frames**: 4–8 frames loop

### typing
- **Trigger**: Document generation in progress
- **Feel**: Working at keyboard or on documents
- **Motion**: Typing gesture, occasional glance at screen
- **Frames**: 6–10 frames loop

### thinking
- **Trigger**: AI preparing response, analyzing
- **Feel**: Thoughtful, processing — not stuck
- **Motion**: Slight head tilt, hand on chin, or gentle look-up
- **Frames**: 4–8 frames loop
- **Note**: Fallback to idle if file missing — still ship idle first

### speaking
- **Trigger**: Agent answering / explaining
- **Feel**: Talking, gesturing slightly
- **Motion**: Mouth/face movement, small hand gesture
- **Frames**: 4–8 frames loop

### greeting
- **Trigger**: Workroom opened
- **Feel**: Brief professional greeting — nod or small wave
- **Motion**: One-shot (not loop), ends with return to idle
- **Frames**: 6–12 frames, play once

### joy
- **Trigger**: Artifact created successfully
- **Feel**: Quietly happy — small celebration, not over the top
- **Motion**: Shoulders rise, subtle smile, maybe a check-mark gesture
- **Frames**: 8–12 frames, play once then return to typing/idle

### sad
- **Trigger**: Workflow failure / error
- **Feel**: Slightly dejected, not dramatic
- **Motion**: Head lowers slightly, posture softens
- **Frames**: 6–10 frames, hold then return

### confused
- **Trigger**: Verification warning, ambiguous input
- **Feel**: Tilted head, questioning look
- **Motion**: Head tilt, slight brow raise
- **Frames**: 4–8 frames loop briefly then idle

### drag
- **Trigger**: User picks up the character widget
- **Feel**: Slightly surprised but not alarmed — lifted state
- **Motion**: Legs dangle, arms slightly out
- **Frames**: 3–6 frames loop while held

### landing
- **Trigger**: Character widget put down
- **Feel**: Settles in, brief recovery
- **Motion**: Lands, adjusts, quick settle
- **Frames**: 4–8 frames, play once then idle

### clockIn
- **Trigger**: App opened / workroom started
- **Feel**: Arriving at desk, getting ready
- **Motion**: Sets down bag/item, opens laptop, sits in
- **Frames**: 8–16 frames, play once

### backToWork
- **Trigger**: Task resumed after pause, artifact reuse
- **Feel**: Returning to focus, back at keyboard
- **Motion**: Turns back to screen, resumes typing posture
- **Frames**: 6–10 frames, play once then typing

---

## Style Guidelines

### Do
- Warm but professional
- Small office teammate energy
- Work-focused props: document, checklist, pen, laptop, coffee cup
- Subtle motion — less is more
- Readable at small sizes (64×64 equivalent)
- Consistent line weight and palette across states

### Do not
- No childish exaggeration
- No heavy crying or falling
- No excessive speed or bounciness
- No UI chrome baked in (no speech bubbles, no buttons)
- No text inside sprite frames
- No background color or shadow baked in
- No screen glow or heavy VFX

---

## Fallback Policy

If a clip is missing, `CharacterSpriteScene` automatically falls back:

| Missing | Fallback |
|---------|---------|
| `thinking` | → `idle` |
| `speaking` | → `idle` |
| `sad` | → `idle` |
| `confused` | → `idle` |
| `sleeping` | → `resting` → `idle` |
| `backToWork` | → `typing` → `idle` |

Priority: ship `idle` and `typing` first. App will not crash without other clips.

---

## Delivery Checklist

- [ ] `치코_idle_001.png` … `치코_idle_NNN.png`
- [ ] `치코_typing_001.png` … loop
- [ ] `치코_thinking_001.png` … loop (optional v1, fallbacks to idle)
- [ ] `치코_speaking_001.png` … loop
- [ ] `치코_greeting_001.png` … one-shot
- [ ] `치코_joy_001.png` … one-shot
- [ ] `치코_sad_001.png` … hold
- [ ] `치코_confused_001.png` … brief loop
- [ ] `치코_drag_001.png` … loop
- [ ] `치코_landing_001.png` … one-shot
- [ ] `치코_clockin_001.png` … one-shot
- [ ] `치코_backwork_001.png` … one-shot
- [ ] Fallback profile image: `치코_profile.png` (single frame, face only)

---

## Handoff Notes

After delivery, drop files into `MyTeam/Sprites/치코/` in the Xcode project.
Add the `Sprites/` folder as a Resources group reference.
No code changes required — `CharacterSpriteScene` loads by filename pattern automatically.
