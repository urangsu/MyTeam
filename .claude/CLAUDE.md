# MyTeam: AI 협업 워크룸

**One-liner:** 팀 채팅 + 워크룸(room-scoped AI tasks) + 로컬 artifact 관리 + 캐릭터(Chiko) 경험

**Current Priority:** Round 196A-230Z-FINAL 완료 → Workroom runtime wiring + room-safe routing + product surface validation

---

## G-Stack Product Mindset

Act like a ruthless Silicon Valley product architect.

**Ship the smallest version that proves the product loop:**
- Prefer fast, direct, production-shaped implementation over broad theoretical planning.
- Protect first-party UX: no sluggish flows, no confusing empty states, no fake-ready surfaces.
- Every feature must improve core loop: **Workroom → Chiko → document/action → artifact → next action**
- Hide/defer anything unfinished, unsafe, or not actually usable.
- No clever architecture unless it removes bottlenecks or reduces future risk.
- Keep: local-first, room-scoped, fail-closed behavior.

**Before committing:**
1. Does this make first user experience faster or clearer?
2. Reduces product/architecture risk?
3. Smaller, cleaner, more shippable than alternative?
4. Survives demo-day product review?

---

## Hard Rules (Non-Negotiable)

1. **Workroom = Product unit, not just chat** — room-scoped artifacts, no cross-room linking, room visibility enforced
2. **Character system sacred** — AnimationState, CharacterDialogues, SpriteAgentView preserved always
3. **Build fails = stop immediately** — fix before proceeding, no documentation workarounds
4. **No external writes on primary surfaces** — mail/calendar/delete/upload must be clearly gated/blocked
5. **Local-first guarantee** — app works without API key, with local templates + fallbacks
6. **User privacy first** — no password entry, no API key storage in chat/forms, Keychain only
7. **Explicit task continuity** — `/compact` summary + current task state always preserved
8. **No Apple TTS** — user rejects machine voice; use Qwen3TTS or silence

---

## Key Docs Paths

- Workroom spec: `docs/WorkroomCoreLoop.md` + `docs/WorkroomProductizationPolicy.md`
- Character deferral: `docs/character/CharacterReactionBridgeBacklog.md`
- Routing: `MyTeam/WorkflowOrchestrator.swift` (dispatcher + core loop)
- Room scope: `MyTeam/AgentWindowManager.swift` (currentRoomID, room state)
- Artifacts: `MyTeam/ArtifactCardView.swift` + `RecentArtifactIndex`
- Build config: `.claude/settings.local.json` + xcodebuild commands below

---

## Build & Release

```bash
xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Debug build
xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Release build
```

Both must: **BUILD SUCCEEDED**, 0 errors, 0 new Swift warnings.

---

## Known Bottlenecks (Archived, see docs/archive/)

- Workroom character reaction engine → deferred Round 231A
- Multi-user collaboration → future phase
- App Store submission QA → pending
- CharacterReactionBridgeBacklog full impl → post-196

See `docs/archive/claude-context/` for round specs, completion reports, QA checklists.

---

## Immediate Unblock

- ✅ Round 196A-230Z pbxproj fix + Workroom handlers complete
- ✅ Round 246B-250Z: Approval UX, Office Review, Supertonic3 skeleton, KSkillAssistRuntime
- ✅ Round 250A-255Z: KSkillAssistCardView (structured card), RouterBurnInSuite (7 K-skills burn-in)
- ✅ Round 256A-260Z: Character bridge wiring, 7 new events, App Store policy docs
- ✅ Round 261A-265Z: 4 skill result cards (spell-check, privacy-terms, diagnostics, accounting-tax), accounting-tax skill manifest
- 🔄 Next: App Store Connect metadata upload, screenshots, manual QA checklist

---

**Last update:** 2026-05-24 Round 272

---

## Skill routing

When the user's request matches an available skill, invoke it via the Skill tool. When in doubt, invoke the skill.

Key routing rules:
- Product ideas/brainstorming → invoke /office-hours
- Strategy/scope → invoke /plan-ceo-review
- Architecture → invoke /plan-eng-review
- Design system/plan review → invoke /design-consultation or /plan-design-review
- Full review pipeline → invoke /autoplan
- Bugs/errors → invoke /investigate
- QA/testing site behavior → invoke /qa or /qa-only
- Code review/diff check → invoke /review
- Visual polish → invoke /design-review
- Ship/deploy/PR → invoke /ship or /land-and-deploy
- Save progress → invoke /context-save
- Resume context → invoke /context-restore
