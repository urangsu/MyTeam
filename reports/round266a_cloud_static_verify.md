# Round 266A-CLOUD-VERIFY — AssistOnly Governance Static Verification Report

**Date:** 2026-05-21  
**Round:** 266A-275Z + 266A-CLOUD-VERIFY  
**Status:**
- Cloud static checked ✅
- Mac build pending ⏳
- Manual QA pending ⏳
- Submission not ready ⛔

---

## Preflight Result: 13/13 PASSED

| Check | Description | Result |
|-------|-------------|--------|
| 1 | assistOnlySkillIDs exists in SkillAvailabilityResolver | ✅ PASS |
| 2 | accounting-tax assistOnly override in SkillAvailabilityResolver | ✅ PASS |
| 3 | accounting-tax disclaimer text present in AccountingTaxSummaryCardView | ✅ PASS |
| 4 | accounting-tax disclaimer marked non-collapsible (Always visible comment present) | ✅ PASS |
| 5 | KSkillAssistRuntime formatMarkdown uses Korean UX section headers | ✅ PASS |
| 6 | hardBlockedActions not exposed in user-facing quoted strings | ✅ PASS |
| 7 | No invalid ToolScope.assistOnly references in skill files | ✅ PASS |
| 8 | RouterBurnInSuite has 10 governance K-skill burn-in cases (10 found) | ✅ PASS |
| 9 | All 4 dedicated skill card routes present in SkillResultRendererView | ✅ PASS |
| 10 | Supertonic3 isEnabled reads UserDefaults (not hardcoded true) | ✅ PASS |
| 11 | Supertonic3 isolated to lab/diagnostic/routing files only | ✅ PASS |
| 12 | No StoreKit/OAuth/Gmail/CalendarWrite changes in Round 266A commits | ✅ PASS |
| 13 | All 4 policy docs present | ✅ PASS |

---

## Static Audit Results

### 1. .assistOnly References
All `.assistOnly` references are valid `FeatureAvailability` enum case uses. No invalid `ToolScope.assistOnly` found.

Confirmed locations:
- `WorkflowOrchestrator.swift:225` — `SkillAvailabilityResolver.availability(for:) == .assistOnly`
- `CapabilityFallbackService.swift:36` — `case .assistOnly:` in feature switch
- `SkillAvailabilityResolver.swift:18,24,26,28,30,32,34,36,38,40` — `return .assistOnly`
- `BuiltInKoreanSkills.swift:263` — comment only, no actual enum usage

### 2. SkillPermission Audit
ToolContractValidator uses `.sendsMessage`, `.makesReservation`, `.handlesPayment` — all confirmed as valid cases in `SkillManifest.swift:37-39`.

`accountingTaxSkill` has empty `permissions: []` array — no banned permissions present.

### 3. ToolScope Audit
`BuiltInKoreanSkills.accountingTaxSkill` uses `allowedScopes: [.chatBasic]` only. No `.assistOnly` ToolScope reference found.

### 4. ExpectedRoute Audit
All 10 new RouterBurnInSuite cases use:
- `.localSkill` — 9 cases (K-skills routing)
- `.privacyTerms` — 1 case (개인정보 처리방침)

All are valid enum cases in `RouterBurnInCase.ExpectedRoute`.

### 5. AssistOnly Hard-Block Policy

**Verified:** No external write functions called from assistOnly skills.

`hardBlockedActions` user-facing strings describe what AI will NOT do:
- "자동 로그인 대행" / "자동 좌석 예매 확정" / "결제 정보 처리" — KTX
- "자동 예약 확정" / "결제 정보 처리" / "개인정보 제출" — Reservation
- "매수/매도 확정 추천" / "수익 보장" / "투자자문 확정 표현" — Stock
- "실제 DART API 조회한 척하기" / "투자자문 확정 표현" — DART
- "실시간 검색 결과 꾸며내기" / "원문 없는 기사 내용 인용" — News
- "법률 자문 확정 표현" / "최신 법령 조회한 척하기" — Law
- "원본 파일 자동 수정" / "외부 업로드" — File

All are policy-informing strings, not execution calls.

### 6. Dedicated Card Routing Priority

`SkillResultRendererView.swift` switch statement order confirmed:
1. `case "korean.character-count":` — line 16
2. `case "korean.spell-check":` → SpellCheckResultCardView — line 20  
3. `case "korean.privacy-terms":` → PrivacyTermsArtifactCardView — line 23
4. `case "runtime.diagnostics":` → DiagnosticsResultCardView — line 26
5. `case "korean.accounting-tax":` → AccountingTaxSummaryCardView — line 29
6. `case _ where KSkillAssistRuntime.isAssistSkillID(skillID):` — line 32 (catch-all)
7. `default:` — line 35 (generic fallback)

Priority order is correct. Dedicated cards precede catch-all.

### 7. Accounting-Tax Disclaimer

Disclaimer at `AccountingTaxSummaryCardView.swift:126`:
```swift
Text("세무·회계 판단은 실제 증빙과 계약 구조에 따라 달라질 수 있으므로 전문가 확인이 필요합니다.")
```

Policy comment at line 120:
```swift
// Always visible — legal disclaimer (non-collapsible; removing or wrapping in DisclosureGroup is prohibited)
```

Not inside any `DisclosureGroup`. Always visible. ✅

### 8. TTS Isolation

`Supertonic3TTSConfig.isEnabled` reads:
```swift
UserDefaults.standard.bool(forKey: "supertonic3ExperimentalEnabled")
```
Defaults false. No hardcoded `true`. ✅

`TTSRoutingPolicy.selectedProvider()` requires both `isEnabled == true` AND `isModelAvailable()` for Supertonic3 selection. Default state: returns `nil` (silent). ✅

Supertonic3 references exist in:
- `Supertonic3*.swift` files (infrastructure/config)
- `TTSLabView.swift` (dev lab UI only)
- `TTSRoutingPolicy.swift` (routing, gated)
- `RuntimeDiagnosticsService.swift` (diagnostics)
- `DiagnosticsResultCardView.swift` (diagnostics UI)
- `ToolContractValidator.swift` (governance validation)
- `ONNXRuntimeAdapter.swift` (runtime boundary layer)
- `TTSProviderModels.swift` (provider enum definitions)
- `SpeechManager.swift` (routing, gated)
- `project.pbxproj` (build file registration)

No app launch auto-init. Model not bundled. No download logic. ✅

### 9. Restricted Operations

No changes to:
- StoreKit ✅
- OAuth ✅
- Gmail API ✅
- Calendar write ✅
- External write APIs ✅

---

## Governance Summary

| Policy | Status |
|--------|--------|
| 12 assistOnly skills classified | ✅ Cloud static checked |
| No external writes from assistOnly skills | ✅ Cloud static checked |
| accounting-tax renders with dedicated card | ✅ Cloud static checked |
| accounting-tax disclaimer always visible | ✅ Cloud static checked |
| KSkillAssistCardView catch-all after hardcoded cards | ✅ Cloud static checked |
| Korean UX section headers only (no internal terms) | ✅ Cloud static checked |
| Supertonic3 Dev Lab gated only | ✅ Cloud static checked |
| TTS silent by default | ✅ Cloud static checked |
| 10 K-skill governance burn-in cases | ✅ Cloud static checked |
| 4 policy docs exist | ✅ Cloud static checked |
| StoreKit/OAuth/Gmail/Calendar unchanged | ✅ Cloud static checked |

---

## Mac Build Checklist (pending)

```
[ ] Debug xcodebuild — 0 errors, 0 warnings
[ ] Release xcodebuild — 0 errors, 0 warnings
[ ] Manual test: accounting-tax renders dedicated card
[ ] Manual test: disclaimer visible without scroll/expand
[ ] Manual test: KTX intent → KSkillAssistCardView with 4 sections
[ ] Manual test: TTS silent at launch
[ ] Manual test: assistOnly burns-in in RouterBurnInSuite
```
