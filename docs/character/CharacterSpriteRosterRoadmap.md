# Character Sprite Roster Roadmap

**Updated**: 2026-05-17 (Round 234)
**Status**: Chiko v1 runtime confirmed (674 PNG). CharacterSpriteManifest + AssetPolicy gate in place. Others DLC-gated.

---

## Roster

| Character | ID | Role | Status |
|-----------|-----|------|--------|
| 치코 (Chiko) | `chiko` | General assistant, primary workroom companion | ⏳ v1 sprites in design |
| 세나 (Sena) | `sena` | Launch / PM / marketing specialist | 🔒 Hidden — sprites not ready |
| 카이 (Kai) | `kai` | Code review / technical analysis | 🔒 Hidden — sprites not ready |
| 유나 (Yuna) | `yuna` | Content / blog / copy writing | 🔒 Hidden — sprites not ready |

---

## Visibility Policy

**Rule**: A character must NOT appear in the purchase or promotion UI until all of the following are true:

1. ✅ `spriteName` is set (non-empty)
2. ✅ v1 Required sprite clips are delivered and tested
3. ✅ Character-specific workflow is implemented and QA'd
4. ✅ StoreKit entitlement QA complete (DLC characters only)

**Enforcement**: Characters without sprites must be filtered out in Release builds.
Placeholder sprites must never appear in screenshots or marketing materials.

---

## Per-Character Minimum Requirements

Each character needs at minimum:

| Clip | rawValue | Purpose |
|------|----------|---------|
| idle | `idle` | Default waiting state |
| typing | `typing` | Working / processing |
| thinking | `thinking` | Analyzing (fallback → idle) |
| joy | `joy` | Success / artifact created |
| sad | `sad` | Failure / error |
| greeting | `greeting` | Welcome / workroom open |
| Fallback profile | — | Single face image, shown if no clips available |

---

## Chiko (치코) — Current Target

- **v1 Required**: idle, typing, thinking, speaking, greeting, joy, sad, confused, drag, landing, clockIn, backToWork
- **v1 Optional**: agree, resting, sleeping, look
- **Handoff doc**: `docs/character/ChikoSpriteSheetHandoff.md`
- **Fallback**: `치코_profile.png`
- **Target release**: TBD — pending design delivery

---

## Sena (세나) — Future

- **Role**: Launch readiness, PM tracking, marketing copy
- **Unlocked by**: All 5 AppLaunchPack workflow stages complete + sprite delivery
- **DLC**: TBD (may be included in base or sold as DLC)
- **Status**: Not started. Hidden in all builds.

---

## Kai (카이) — Future

- **Role**: Code review, architecture review, technical documentation
- **Unlocked by**: Code-review workflow QA complete + sprite delivery
- **DLC**: TBD
- **Status**: Not started. Hidden in all builds.

---

## Yuna (유나) — Future

- **Role**: Blog writing, content strategy, copy editing
- **Unlocked by**: Content workflow QA complete + sprite delivery
- **DLC**: TBD
- **Status**: Not started. Hidden in all builds.

---

## DLC Policy

- DLC character sprites are NOT included in the base app bundle.
- DLC sprites are delivered via StoreKit-gated download.
- No DLC character appears in any UI until StoreKit QA is complete.
- No placeholder or "coming soon" character tile in Release builds.

---

## Milestone Checklist

### Chiko v1 Ship
- [x] All v1 required sprite clips confirmed in runtime bundle (674 PNG, Round 234)
- [x] `CharacterSpriteManifest` + `CharacterSpriteAssetPolicy` gate (Round 234)
- [x] `scripts/validate_sprites.sh` — macOS NFD 대응 (Round 234)
- [x] `Sprites/치코/` intake 폴더 scaffold (Round 234)
- [ ] `CharacterSpriteScene` loads clips without crash (manual QA pending)
- [ ] `AnimationState` fallback chain verified for each missing clip (manual QA pending)
- [ ] `AgentSeatView` renders Chiko in idle/typing during normal use (manual QA pending)
- [ ] Workroom events trigger correct state transitions (manual QA pending)
- [ ] `치코_profile.png` as fallback confirmed working

### Future Characters (per character)
- [ ] Role-specific workflow implemented
- [ ] Sprite clips delivered (minimum set above)
- [ ] Runtime loading tested
- [ ] StoreKit QA complete (if DLC)
- [ ] Character removed from hidden list in `AgentConfig`
