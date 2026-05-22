# Round 254TTS-NOTICE: Mac Build Handoff

**Date:** 2026-05-22  
**Cloud Status:** ✅ Static verification complete  
**Mac Status:** 🔄 Pending local build and runtime verification  
**Branch:** `cloud/round252-supertonic-license-lock`

---

## Overview

Round 254TTS-NOTICE implements Supertonic License Notice + Use Restriction UX Gate in TTS Lab.

**Cloud side (completed):**
- Notice policy file structure (`SupertonicTTSNoticePolicy.swift`)
- Notice card UI (`SupertonicNoticeCardView.swift`)
- TTSLabView integration (notice section, acceptance gate on synthesis button)
- Policy fields (TTSProductPolicy)
- Diagnostic fields (RuntimeDiagnosticsService)
- Validators (ToolContractValidator)
- Static preflight verification (`scripts/preflight_round254tts_notice.sh`: 18/18 PASS)

**Mac side (to verify locally):**
- Debug build validation
- Release build validation
- Runtime behavior: notice display, acceptance toggle, state persistence
- App bundle integration

---

## What Was Implemented

### Files Created (Cloud)

1. **MyTeam/SupertonicTTSNoticePolicy.swift**
   - Static properties: `currentNoticeVersion` (version 254-2026-05)
   - UserDefaults keys: `licenseAcceptedKey`, `useRestrictionsAcceptedKey`, `noticeVersionKey`
   - Methods: `acceptCurrentNotice()`, `resetNoticeAcceptance()`, `isCurrentNoticeAccepted` (computed)
   - Content: `licenseNoticeText` (Supertonic as sole candidate, OpenRAIL-M/MIT licenses)
   - Content: `useRestrictionsText` (prohibited uses: sarcasm, deceptive audio, harassment, personal data abuse)

2. **MyTeam/SupertonicNoticeCardView.swift**
   - SwiftUI View accepting `@Binding accepted: Bool`
   - Callbacks: `onAccept`, `onReset`
   - Layout: Header (실험 기능 badge), license section, use restrictions section, toggle button
   - Button text when unaccepted: "고지를 확인하고 실험 기능 사용"
   - Reset button when accepted: Allows user to re-review notice

### Files Modified (Cloud)

1. **MyTeam/TTSLabView.swift**
   - Added: `@State private var noticeAccepted: Bool = false`
   - Added: `.onAppear` restoration of `noticeAccepted` from `SupertonicTTSNoticePolicy.isCurrentNoticeAccepted`
   - Added: `supertonicNoticeSection` displaying `SupertonicNoticeCardView` with binding
   - Modified: ONNX synthesis button disabled condition includes `|| !noticeAccepted`
   - Warning text when not accepted: "Supertonic 고지와 사용 제한을 확인해야 ONNX 합성을 실행할 수 있습니다."

2. **MyTeam/TTSProductPolicy.swift**
   - Added: `static let licenseNoticeRequired = true`
   - Added: `static let useRestrictionNoticeRequired = true`
   - Added: `static let userNoticeAcceptanceRequired = true`
   - Maintained: `canShipAsProductFeature = false` (all release gates still locked)

3. **MyTeam/RuntimeDiagnosticsService.swift**
   - Added 6 fields to `RuntimeDiagnosticsSnapshot`:
     - `supertonicNoticePolicyAvailable`
     - `supertonicLicenseNoticeRequired`
     - `supertonicUseRestrictionNoticeRequired`
     - `supertonicNoticeAcceptanceRequired`
     - `supertonicNoticeAccepted`
     - `supertonicReleaseGateStillLocked`

4. **MyTeam/ToolContractValidator.swift**
   - Added 4 Round 254 validators:
     - `validateSupertonicNoticePolicyAvailable()`
     - `validateSupertonicUseRestrictionNoticePolicy()`
     - `validateSupertonicNoticeAcceptanceGatePolicy()`
     - `validateSupertonicReleaseGateStillLockedPolicy()`

5. **docs/TTSProviderPolicy.md**
6. **docs/SupertonicCommercialLicenseReview.md**
7. **docs/SupertonicUseRestrictions.md**
   - Added Round 254TTS-NOTICE update sections

---

## Mac Local Verification Script

A verification script is provided at `scripts/local_round254tts_macverify.sh`.

**On Mac, run:**
```bash
bash scripts/local_round254tts_macverify.sh
```

### What the Script Checks

**Part 1: Static Source Code** (runs on any platform)
1. Notice version defined in SupertonicTTSNoticePolicy
2. UserDefaults keys (license, restrictions, version)
3. SupertonicNoticeCardView.swift exists
4. Card view accepts @Binding parameter
5. TTSLabView integrates notice section
6. ONNX synthesis button has noticeAccepted gate
7. Notice acceptance restoration logic present
8. TTSProductPolicy flags (licenseNoticeRequired, etc.) defined

**Part 2: Mac Build** (requires macOS + Xcode)
9. Debug build succeeds with no unexpected errors
10. Release build succeeds with no unexpected errors
11. No new Swift warnings introduced
12. Notice implementation files present in source tree

**Part 3: Runtime** (manual verification after app launch)
1. Launch MyTeam app → TTS Lab
2. Verify SupertonicNoticeCardView displays:
   - License notice: "Supertonic3은 유일한 TTS 후보입니다..."
   - Use restrictions: "다음 용도는 금지됩니다..."
3. Verify ONNX synthesis button is **disabled** until notice accepted
4. Click "고지를 확인하고 실험 기능 사용"
5. Verify button state changes and synthesis becomes enabled
6. Quit and relaunch
7. Verify acceptance state persists (notice remains accepted)
8. Edit SupertonicTTSNoticePolicy version to test re-acceptance trigger

---

## How to Use This Handoff

### Prerequisites

- macOS 12.x or later
- Xcode 14.x or later
- Swift 5.7+
- MyTeam repository cloned locally

### Step 1: Fetch Latest Changes

```bash
cd /path/to/MyTeam
git fetch origin cloud/round252-supertonic-license-lock
git checkout cloud/round252-supertonic-license-lock
```

### Step 2: Run Static Verification (Cloud checks)

```bash
bash scripts/local_round254tts_macverify.sh
```

Expected output: ✅ PASS (items 1–8, runtime warnings about macOS being skipped)

### Step 3: Build on Mac with Xcode

```bash
xcodebuild -project MyTeam/MyTeam.xcodeproj \
           -scheme MyTeam \
           -configuration Debug \
           build
```

Expected: `BUILD SUCCEEDED`

```bash
xcodebuild -project MyTeam/MyTeam.xcodeproj \
           -scheme MyTeam \
           -configuration Release \
           build
```

Expected: `BUILD SUCCEEDED`, 0 new errors, 0 new warnings

### Step 4: Manual Runtime Verification

1. Open MyTeam.xcodeproj in Xcode
2. Scheme: MyTeam, Configuration: Debug
3. Run on Mac (⌘R or Product → Run)
4. Navigate to TTS Lab
5. Verify notice card displays correctly
6. Test acceptance toggle and persistence
7. Review Section: Runtime Verification above for full checklist

### Step 5: Report Results

When complete, report:
- Mac Debug build: PASS/FAIL
- Mac Release build: PASS/FAIL
- Runtime verification: PASS/FAIL
- Any warnings or errors encountered

Post results as comment on Issue #3 or PR #2.

---

## Expected Behavior After Implementation

### When User Opens TTS Lab (TTSLabView)

1. **Notice Card Appears**
   - Header: "실험 기능" badge + Supertonic icon
   - Body: License notice text (Supertonic as sole candidate, OpenRAIL-M/MIT)
   - Section: Use restrictions (7 prohibited uses)
   - Button: "고지를 확인하고 실험 기능 사용"

2. **ONNX Synthesis Button State**
   - Initially: 🔴 **Disabled** (red background, grayed text)
   - Reason: `!noticeAccepted` condition active
   - Warning text: "Supertonic 고지와 사용 제한을 확인해야 ONNX 합성을 실행할 수 있습니다."

3. **User Clicks Acceptance Button**
   - Notice card updates: Button → "고지를 초기화" (reset button)
   - ONNX synthesis button: 🟢 **Enabled** (normal button state)
   - Acceptance stored in UserDefaults under version key

4. **App Quits and Relaunches**
   - Notice card: Reappears in accepted state
   - ONNX synthesis button: Remains **enabled**
   - No re-acceptance required until version bumped

5. **Notice Version Bumped** (SupertonicTTSNoticePolicy.currentNoticeVersion changed)
   - Notice card: Reappears with new content
   - ONNX synthesis button: Returns to **disabled**
   - User must re-accept new version

---

## Troubleshooting

### Build Fails with "SupertonicNoticeCardView not found"

**Cause:** File not registered in project.pbxproj

**Fix:** Ensure SupertonicNoticeCardView.swift is added to MyTeam target:
1. Open MyTeam.xcodeproj
2. Select File → Add Files to MyTeam
3. Choose `MyTeam/SupertonicNoticeCardView.swift`
4. Check "Copy items if needed"
5. Add to target: MyTeam
6. Rebuild

### Notice Card Does Not Appear in TTSLabView

**Cause:** TTSLabView may not be showing the notice section

**Fix:** Check TTSLabView for `supertonicNoticeSection`:
```swift
// Should exist in TTSLabView
VStack {
    // ... other content
    supertonicNoticeSection
    onnxSpikeSection
}
```

### ONNX Synthesis Button Never Enables

**Cause:** `noticeAccepted` state not being set to true, or button condition is incorrect

**Fix:**
1. Verify SupertonicNoticeCardView `onAccept` callback calls `SupertonicTTSNoticePolicy.acceptCurrentNotice()`
2. Verify TTSLabView updates `noticeAccepted = true` when notice is accepted
3. Check button disabled condition: Should include `|| !noticeAccepted`, not just `!noticeAccepted`

### Acceptance Does Not Persist After App Relaunch

**Cause:** UserDefaults key mismatch or .onAppear restoration logic missing

**Fix:**
1. Verify SupertonicTTSNoticePolicy defines correct keys: `licenseAcceptedKey`, `useRestrictionsAcceptedKey`, `noticeVersionKey`
2. Verify TTSLabView `.onAppear` has:
   ```swift
   .onAppear {
       noticeAccepted = SupertonicTTSNoticePolicy.isCurrentNoticeAccepted
   }
   ```

---

## Cloud Verification Results

✅ **Static Checks: 18/18 PASS**

```
✅ PASS: SupertonicTTSNoticePolicy.swift exists
✅ PASS: SupertonicNoticeCardView.swift exists
✅ PASS: TTSLabView integrates SupertonicNoticeCardView
✅ PASS: TTSLabView state: noticeAccepted
✅ PASS: TTSLabView .onAppear restoration
✅ PASS: ONNX synthesis button disabled condition checks noticeAccepted
✅ PASS: ONNX synthesis button warning text when not accepted
✅ PASS: SupertonicTTSNoticePolicy notice version: round254-2026-05
✅ PASS: SupertonicTTSNoticePolicy UserDefaults keys defined
✅ PASS: SupertonicTTSNoticePolicy license notice text present
✅ PASS: SupertonicTTSNoticePolicy use restrictions text present
✅ PASS: SupertonicNoticeCardView @Binding accepted parameter
✅ PASS: SupertonicNoticeCardView onAccept callback
✅ PASS: SupertonicNoticeCardView onReset callback
✅ PASS: TTSProductPolicy.licenseNoticeRequired = true
✅ PASS: TTSProductPolicy.useRestrictionNoticeRequired = true
✅ PASS: TTSProductPolicy.userNoticeAcceptanceRequired = true
✅ PASS: RuntimeDiagnosticsService includes 6 notice gate fields
```

---

## Next Steps (After Mac Verification)

1. ✅ Cloud static checks: DONE
2. 🔄 Mac build verification: IN PROGRESS (local)
3. 🔄 Manual runtime QA: IN PROGRESS (local)
4. ⏳ PR #2 approval and merge
5. ⏳ Final submission to App Store

---

## Contact

If you encounter any issues during local Mac verification:

1. Check the troubleshooting section above
2. Review the actual implementation files for consistency
3. Post detailed error messages in Issue #3
4. Reference this handoff document with your question

---

**Last Updated:** 2026-05-22  
**Handoff Version:** 1.0
