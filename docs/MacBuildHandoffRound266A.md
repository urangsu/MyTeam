# Round 266A Mac Build Handoff

## Cloud status
- Cloud static checked
- Mac build pending
- Manual QA pending
- Submission not ready

## Branch
- `claude/myteam-product-completion-H97FZ`
- Two Round 266A-275Z commits: `6ef1c80`, `d980de2`
- Cloud preflight: 13/13 passed

## Build commands

```bash
xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Debug build
xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Release build
```

Both must produce zero errors and zero new Swift warnings.

## Files modified in Round 266A-275Z

| File | Change |
|------|--------|
| `MyTeam/ToolContractValidator.swift` | +5 validators (assistOnly, dedicated cards, disclaimer, sections, priority) |
| `MyTeam/RuntimeDiagnosticsService.swift` | +6 governance diagnostic fields |
| `MyTeam/RouterBurnInSuite.swift` | +10 K-skill burn-in cases |
| `MyTeam/KSkillAssistRuntime.swift` | Section headers updated to Korean UX terms |
| `MyTeam/AccountingTaxSummaryCardView.swift` | Disclaimer hardened; non-collapsible comment added |
| `MyTeam/SkillAvailabilityResolver.swift` | `assistOnlySkillIDs` property added |
| `MyTeam/BuiltInKoreanSkills.swift` | `accountingTaxSkill` manifest created |

## Must verify on Mac

### Compile targets (xcodebuild)
- ToolContractValidator.swift — 5 new validators must compile
- RuntimeDiagnosticsService.swift — 6 new diagnostic fields + snapshot init must compile
- RouterBurnInSuite.swift — 10 new cases use `.localSkill` / `.privacyTerms` routes only
- SkillAvailabilityResolver.swift — `assistOnlySkillIDs` property, `korean.accounting-tax` case
- BuiltInKoreanSkills.swift — `accountingTaxSkill` manifest with correct scopes
- SkillResultRendererView.swift — dedicated card routing before catch-all
- AccountingTaxSummaryCardView.swift — disclaimer rendering

### Behavioral checks (manual QA)
- Ask "세금 계산 도와줘" → renders AccountingTaxSummaryCardView (not generic card)
- Ask "KTX 예매 도와줘" → renders KSkillAssistCardView with 4 Korean sections
- Disclaimer "세무·회계 판단은..." visible without any scroll/expand
- Hard-blocked actions section visible without scroll/expand in any assistOnly response
- No audio by default (TTS silent, no Supertonic3 auto-start)

## Known risks (compile-time)

| Risk | File | Details |
|------|------|---------|
| enum mismatch | RouterBurnInSuite.swift | All 10 new cases use `.localSkill` or `.privacyTerms` only |
| initializer mismatch | RuntimeDiagnosticsService.swift | 6 new fields must be in snapshot init |
| SkillPermission mismatch | ToolContractValidator.swift | Uses `.sendsMessage`, `.makesReservation`, `.handlesPayment` — all confirmed in SkillManifest.swift |
| ToolScope mismatch | BuiltInKoreanSkills.swift | accountingTaxSkill uses `.chatBasic` only — no `.assistOnly` |
| FeatureAvailability | SkillAvailabilityResolver.swift | `.assistOnly` is valid FeatureAvailability case |

## Preflight to run on Mac before committing any fix

```bash
./scripts/preflight_round266a_cloud_verify.sh
```

Expected: 13/13 PASSED

## If build fails

1. Read error message
2. Identify which file/line
3. If enum mismatch: check RouterBurnInCase.ExpectedRoute enum definition
4. If initializer mismatch: check RuntimeDiagnosticsSnapshot init (all fields must be present)
5. If SkillPermission/ToolScope not found: check SkillManifest.swift for actual enum cases
6. Fix, re-run preflight, rebuild
7. Do NOT push a failing build

## After build succeeds

1. Update `reports/round266a_cloud_static_verify.md` with Mac build result
2. Update `DEVLOG.md`: "Mac build: Debug BUILD SUCCEEDED, 0 warnings / Release BUILD SUCCEEDED, 0 warnings"
3. Update `TASK.md`: Round 266A → completed
4. Commit: `chore: record round 266A mac build success`
5. Push to `claude/myteam-product-completion-H97FZ`
