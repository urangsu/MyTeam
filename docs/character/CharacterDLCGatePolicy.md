# Character DLC Gate Policy

## Overview

This document defines the strict policy for when characters can be offered for purchase (DLC) or shown in the Release build of MyTeam.

## Core Principle

**No character is visible or purchasable in Release mode until ALL six conditions are met.**

This policy ensures users never encounter:
- Placeholder sprites
- Disabled purchase buttons
- "Coming Soon" characters
- Incomplete DLC workflows

## Six Conditions for Release Visibility

Every character must satisfy **all six conditions** before being shown to Release users:

### Condition 1: Production Sprite Asset Available
- [ ] Idle pose sprite created and finalized
- [ ] Working pose sprite created and finalized
- [ ] Success pose sprite created and finalized
- [ ] Small icon (64x64/128x128) created
- [ ] App Store hero pose created
- [ ] All sizes available (1x, 2x)
- [ ] All sprites use consistent baseline
- [ ] No placeholder/temporary assets

**Definition of "Available"**: Assets are committed to repo, integrated into code, and tested in UI.

**What Does NOT Count**:
- "Almost done" assets
- Designs approved but not yet rendered
- Prototype sprites
- Assets in external design tools

---

### Condition 2: Role-Specific Workflow Implemented
- [ ] Character's unique prompts are implemented
- [ ] Persona prompt is set and tested
- [ ] Primary tool workflows connected
- [ ] Agent pipeline integrated
- [ ] Character responds distinctly vs. other agents

**Examples**:
- **Sena**: App Store submission tool, privacy terms tool
- **Kai**: Code review tool, architecture assessment
- **Yuna**: Content strategy tool, blog research skill

**What Does NOT Count**:
- "Planned" workflows
- Workflows in development
- Untested prompts
- Skills shared with other characters (generic)

---

### Condition 3: App Store Screenshot-Safe Visual
- [ ] Character sprite doesn't have aliasing artifacts
- [ ] Works in both dark and light mode
- [ ] Legible at 64x64px (icon size)
- [ ] Professional appearance for App Store
- [ ] No visual glitches or transparency issues
- [ ] Baseline alignment matches other team members

**Who Reviews**: Design team + Product team  
**Standard**: Must be screenshot-ready for marketing materials

---

### Condition 4: StoreKit Product Tested
- [ ] Product ID defined in ProductIDCatalog
- [ ] Product metadata entered in App Store Connect
- [ ] Price set and approved
- [ ] Localization complete (if needed)
- [ ] Product tested in StoreKit sandbox
- [ ] Purchase flow completes without errors

**Testing Checklist**:
- [ ] Sandbox purchase succeeds
- [ ] Receipt validation works
- [ ] Entitlements granted post-purchase
- [ ] Price displays correctly in UI

**What Does NOT Count**:
- Product ID defined but not tested
- Purchase flow "partially" working
- Sandbox testing deferred to later

---

### Condition 5: In-App Purchase Flow Verified
- [ ] DLC button visible and clickable
- [ ] Purchase modal appears correctly
- [ ] Price and description displayed accurately
- [ ] Purchase completes successfully in sandbox
- [ ] Character unlocks after purchase
- [ ] "Purchased" state persists across app restart
- [ ] No error dialogs in normal flow

**Manual QA Checklist**:
- [ ] Click "Purchase" button
- [ ] Confirm purchase in system dialog
- [ ] Verify character appears in roster
- [ ] Close and reopen app
- [ ] Character still visible (persistence)

---

### Condition 6: Restore Purchase Verified
- [ ] Restore purchase logic implemented
- [ ] Restore purchase works in sandbox
- [ ] Character re-appears after restore
- [ ] Works across multiple test devices
- [ ] No errors in console during restore

**Scenario Testing**:
- [ ] Purchase on Device A
- [ ] Restore on Device B with same Apple ID
- [ ] Character appears on Device B
- [ ] Can use purchased character immediately

---

## Release vs. DEBUG Mode

### DEBUG Mode
```swift
#if DEBUG
// Show ALL characters
let displayedCharacters = CharacterCatalog.all
// DLC buttons visible even for incomplete characters
// Can test incomplete premium characters
#endif
```

**Allowed in DEBUG**:
- Placeholder sprites
- Coming Soon characters
- Disabled purchase buttons
- Untested DLC workflows

### Release Mode
```swift
#if !DEBUG
// Show ONLY completed characters
let displayedCharacters = CharacterCatalog.builtIn + 
                         CharacterCatalog.premium
                            .filter { $0.hasMetAllConditions() }
#endif
```

**Hidden in Release**:
- Any character with placeholder sprite
- Any character missing condition 1-6
- Disabled DLC buttons
- "Coming Soon" labels
- Premium tab if no complete premiums

---

## Implementation Code Pattern

### Character Model Extension
```swift
// CharacterDLC.swift or similar
extension CharacterDLC {
    var hasMetAllConditions: Bool {
        guard !self.isBuiltIn else { return true } // Built-in always visible
        
        return self.hasProductionSprite &&
               self.hasImplementedWorkflow &&
               self.isScreenshotSafe &&
               self.hasTestedStoreKitProduct &&
               self.hasPurchaseFlowVerified &&
               self.hasRestorePurchaseVerified
    }
}
```

### View Filtering
```swift
// CharacterGalleryView.swift
var visibleCharacters: [CharacterDLC] {
    #if DEBUG
    return CharacterCatalog.all
    #else
    return CharacterCatalog.all.filter { char in
        char.isBuiltIn || char.hasMetAllConditions
    }
    #endif
}
```

### DLC Button Gating
```swift
// PurchaseManager.swift
func shouldShowDLCButton(for character: CharacterDLC) -> Bool {
    #if DEBUG
    return true // Show even for incomplete
    #else
    return character.hasMetAllConditions
    #endif
}
```

---

## Enforcement Checklist

**Every Release Build Must Pass**:

- [ ] No placeholder sprites visible in UI
- [ ] No "Coming Soon" character cards shown
- [ ] No disabled DLC purchase buttons visible
- [ ] All visible characters have condition 1-6 met
- [ ] RuntimeDiagnostics confirms policy compliance
- [ ] No character appears "locked" or "unavailable"

**Automated Check**:
```swift
#if !DEBUG
let visibleChars = CharacterGalleryView.visibleCharacters
for char in visibleChars {
    assert(char.hasMetAllConditions, 
           "Character \(char.name) visible but missing conditions!")
}
#endif
```

---

## Exception Policy

**There are NO exceptions to the six conditions.**

Rationale:
- Incomplete DLC = user frustration
- Placeholder sprites = brand damage
- Coming Soon = broken trust
- Partial implementation = support burden

Rather than show incomplete work:
- Keep character hidden in Release
- Show in DEBUG for development
- Launch when ready with full 6 conditions

---

## Gradual Rollout Path

### Step 1: Development (DEBUG only)
- Implement character workflow
- Create sprite assets
- Test in simulator

### Step 2: Validation
- Verify all 6 conditions met
- Have design + product approve
- Test full purchase flow

### Step 3: Soft Launch (if applicable)
- Hidden in Release, visible in DEBUG
- Beta testers provide feedback
- Final polish iteration

### Step 4: Full Release
- All conditions confirmed
- Character visible to all users
- DLC purchasable
- Marketing materials updated

---

## Character Roadmap with Gating

| Character | Condition 1 | Condition 2 | Condition 3 | Condition 4 | Condition 5 | Condition 6 | Release |
|-----------|-------------|-------------|-------------|-------------|-------------|-------------|---------|
| Chiko | ❌ Pending | ✅ Done | ❌ Pending | N/A | N/A | N/A | Visible (built-in) |
| Sena | ❌ Not started | ❌ Not started | ❌ Not started | ❌ Not tested | ❌ Not tested | ❌ Not tested | Hidden |
| Kai | ❌ Not started | ❌ Not started | ❌ Not started | ❌ Not tested | ❌ Not tested | ❌ Not tested | Hidden |
| Yuna | ❌ Not started | ❌ Not started | ❌ Not started | ❌ Not tested | ❌ Not tested | ❌ Not tested | Hidden |

---

## Testing Workflow

### Before Each Release Build

1. **Asset Check**
   ```bash
   find assets/characters -name "*placeholder*" || echo "No placeholders found ✅"
   ```

2. **Code Check**
   ```bash
   grep -r "isComingSoon: true" MyTeam/CharacterCatalog.swift && echo "⚠️ Coming Soon found" || echo "No Coming Soon ✅"
   ```

3. **UI Verification**
   ```swift
   // In RuntimeDiagnosticsService:
   let allVisibleChars = visibleCharacters()
   for char in allVisibleChars {
       XCTAssert(char.hasMetAllConditions, "Gate violation: \(char.name)")
   }
   ```

### Release Candidate QA

**Manual Verification**:
- [ ] Open Character Gallery
- [ ] Count visible characters (should be 1 = Chiko for v1.0)
- [ ] No "Coming Soon" labels visible
- [ ] No disabled buttons visible
- [ ] No placeholder sprites visible
- [ ] Chiko looks professional and production-ready

---

## Documentation & Communication

### When Adding Character to Roadmap

1. Create character entry in CharacterCatalog (marked `isComingSoon: true`)
2. Document in CharacterRosterPlan.md
3. Keep hidden in Release mode
4. Mark conditions as "not met" in tracking doc
5. Communicate timeline to team

### When Character Meets Condition

1. Update tracking spreadsheet
2. Note date completed
3. Prepare PR/review if condition 4+ met
4. Update CharacterDLCGatePolicy.md roadmap

### When Character Ready for Release

1. Verify all 6 conditions one final time
2. Update CharacterCatalog (`isComingSoon: false`)
3. Run Release build verification
4. Update marketing/App Store copy
5. Communicate launch to team

---

## Compliance Audit

**Monthly or before major release**:

1. Check all visible characters meet 6 conditions
2. Verify no placeholders in Release assets
3. Confirm DLC buttons only for ready characters
4. Review support tickets for character-related complaints
5. Update CharacterDLCGatePolicy.md if policies change

---

**Last Updated**: 2026-05-15  
**Status**: Active & Enforced  
**Owner**: Product & Engineering Team  
**Exceptions**: None permitted
