# Policy Fixture Matrix

## Overview

Reference documentation for static policy enums governing Release surface visibility, routing, and capability restrictions. Use this matrix to verify policy implementation against expected behavior.

## 1. Starter Action Expectations

**Policy File**: `StarterActionPolicy.swift`

| Action ID | Korean Text | Allowed in Release | Status |
|-----------|-------------|-------------------|--------|
| `회의록_양식` | "회의록 양식" | ✅ Yes | Core starter action |
| `앱_출시_체크리스트` | "앱 출시 체크리스트" | ✅ Yes | Core starter action |
| `최근_문서_요약` | "최근 문서 요약" | ✅ Yes | Artifact reuse action |
| `최근_문서_회의록` | "최근 문서 회의록" | ✅ Yes | Artifact reuse action |
| `최근_문서_액션아이템` | "최근 문서 액션아이템" | ✅ Yes | Artifact reuse action |
| `메일_보내줘` | "메일 보내줘" | ❌ No | Blocked: external write |
| `일정_만들어줘` | "일정 만들어줘" | ❌ No | Blocked: calendar write |
| `파일_삭제해줘` | "파일 삭제해줘" | ❌ No | Blocked: file delete |
| `외부_업로드` | "외부 업로드" | ❌ No | Blocked: external upload |
| `캘린더_쓰기` | "캘린더 쓰기" | ❌ No | Blocked: calendar write |

**Verification**: RouterBurnInSuite must have test cases for all allowed actions + all 5 blocked actions

## 2. First Result Action Policy by Artifact State

**Policy File**: `FirstResultActionPolicy.swift`

### Valid Artifact State

| State | `ArtifactState` | Allowed Actions | Default | Notes |
|-------|----------|-----------|---------|-------|
| Valid file present | `.valid` | `["summary", "table", "checklist", "revealInFinder"]` | `"summary"` | Full action set available |

**Implementation**:
```swift
case .valid:
    return ["summary", "table", "checklist", "revealInFinder"]
```

### Invalid Artifact States

| State | `ArtifactState` | Allowed Actions | Default | Notes |
|-------|----------|-----------|---------|-------|
| File missing | `.missingFile` | `[]` | `nil` | No actions available |
| Hash mismatch | `.hashMismatch` | `[]` | `nil` | No actions available |
| Wrong room | `.wrongRoom` | `[]` | `nil` | No actions available |

**Implementation**:
```swift
case .missingFile, .hashMismatch, .wrongRoom:
    return []
```

**Verification**: ArtifactCardView must check `FirstResultActionPolicy.isActionAllowed()` before displaying action buttons

## 3. Character Visibility and Purchasability Matrix

**Policy Files**: 
- `ProductSurfacePolicy.swift` (shows/hides placeholder characters)
- `ReleaseVisibleCharacterPolicy.swift` (visibility rules based on asset manifest)
- `CharacterCatalog.swift` (asset manifest + visibility helpers)

| Character | ID | Manifest Status | Visible in Release | Purchasable | Notes |
|-----------|----|----|---|---|---|
| Chiko (치코) | `char.builtin.chiko` | isPlaceholder: false | ✅ Yes | ❌ No | Default character, all sprites ready |
| Leo (레오) | `char.builtin.leo` | isPlaceholder: true | ❌ No | ❌ No | Placeholder, hidden |
| Luna (루나) | `char.builtin.luna` | isPlaceholder: true | ❌ No | ❌ No | Placeholder, hidden |
| Moko (모코) | `char.builtin.moko` | isPlaceholder: true | ❌ No | ❌ No | Placeholder, hidden |
| Rex (렉스) | `char.builtin.rex` | isPlaceholder: true | ❌ No | ❌ No | Placeholder, hidden |
| Kei (케이) | `char.builtin.kei` | isPlaceholder: true | ❌ No | ❌ No | Placeholder, hidden |
| Lucky (래키) | `char.builtin.lucky` | isPlaceholder: true | ❌ No | ❌ No | Placeholder, hidden |
| Pola (폴라) | `char.builtin.pola` | isPlaceholder: true | ❌ No | ❌ No | Placeholder, hidden |
| Mongmong (몽몽) | `char.builtin.mongmong` | isPlaceholder: true | ❌ No | ❌ No | Placeholder, hidden |
| Oliver (올리버) | `char.builtin.oliver` | isPlaceholder: true | ❌ No | ❌ No | Placeholder, hidden |
| Pin (핀) | `char.builtin.pin` | isPlaceholder: true | ❌ No | ❌ No | Placeholder, hidden |
| Sena (세나) | `char.premium.sena` | isPlaceholder: true | ❌ No | ❌ No | Premium, coming soon |
| Kai (카이) | `char.premium.kai` | isPlaceholder: true | ❌ No | ❌ No | Premium, coming soon |
| Yuna (유나) | `char.premium.yuna` | isPlaceholder: true | ❌ No | ❌ No | Premium, coming soon |

**Visibility Rules**:
- `isVisibleInRelease()`: `!isPlaceholder && (hasIdleSprite || hasWorkingSprite)`
- `isPurchasableInRelease()`: `isDLCReady && !isPlaceholder`

**Verification**: 
- CharacterGalleryView filters with `ProductSurfacePolicy.characterVisibilityInRelease()`
- Only Chiko should appear in Release character gallery

## 4. Connector Capability Visibility Matrix

**Policy File**: `ConnectorSurfacePolicy.swift`

| Capability | Enum Value | Visible in Release | Write Blocked | Notes |
|-----------|---------|---|---|---|
| Read (connectors read) | `.read` | ✅ Yes | ❌ No | Allowed, read-only |
| Calendar Write | `.calendar` | ❌ No | ✅ Yes | Blocked: cannot create/modify events |
| Mail Send | `.mail` | ❌ No | ✅ Yes | Blocked: cannot send messages |
| External Upload | `.externalUpload` | ❌ No | ✅ Yes | Blocked: cannot upload to external services |
| File Delete | `.fileDelete` | ❌ No | ✅ Yes | Blocked: cannot delete files |

**Blocked Capabilities Set**:
```swift
static let blockedCapabilitiesInRelease: Set<ConnectorCapability> = [
    .calendar, .mail, .externalUpload, .fileDelete
]
```

**Verification**:
- All write tools (calendar, mail, delete, upload) must have `debugOnly=true` OR `plannerVisible=false`
- ToolContractValidator.validateReleaseVisibleConnectorPolicy() enforces this

## 5. Product Surface Policy Constants

**Policy File**: `ProductSurfacePolicy.swift`

| Constant | Value | Meaning |
|----------|-------|---------|
| `showsPlannedConnectorsInRelease` | `false` | Planned (unimplemented) connectors hidden |
| `showsDisabledProButtonInRelease` | `true` | Pro button shown but disabled |
| `showsPlaceholderCharactersInRelease` | `false` | Placeholder characters hidden from gallery |
| `showsCharacterDLCInRelease` | `true` | DLC characters shown (but unavailable) |
| `allowsExternalWriteStarterActions` | `false` | No starter actions for write tools |
| `allowsCalendarWriteSurface` | `false` | Calendar write completely disabled |
| `allowsMailSendSurface` | `false` | Mail send completely disabled |
| `truthfulPrivacyCopyRequired` | `true` | All privacy copy verified as truthful |

**Verification**:
- ToolContractValidator checks all constants match Release intent
- Any `true` on write capabilities should trigger validation error

## 6. Cross-Policy Dependencies

```
ProductSurfacePolicy
├─ characterVisibilityInRelease()
│  └─ Uses: CharacterCatalog.assetManifest()
│           ReleaseVisibleCharacterPolicy.isVisibleInRelease()
├─ proButtonStateInRelease()
│  └─ Determines: "disabled" vs "hidden"
└─ dlcVisibilityInRelease()
   └─ Controls: DLC section visibility in CharacterGalleryView

StarterActionPolicy
├─ allowedStarterActionIDs: Set<String>
├─ blockedStarterActionIDs: Set<String>
└─ Referenced by: RouterBurnInSuite test cases
                  ToolContractValidator.validateStarterActionPolicy()

FirstResultActionPolicy
├─ allowedActions(for state)
└─ Referenced by: ArtifactCardView
                  ToolContractValidator.validateFirstResultActionPolicy()

ConnectorSurfacePolicy
├─ blockedCapabilitiesInRelease: Set<ConnectorCapability>
├─ isVisibleInRelease(_ capability)
├─ isWriteBlocked(_ capability)
└─ Referenced by: ToolContractValidator.validateReleaseVisibleConnectorPolicy()
```

## Validation Checklist

Run before considering Round 116A complete:

- [ ] StarterActionPolicy: 5+ allowed, 5 blocked action IDs defined
- [ ] FirstResultActionPolicy: valid state returns [summary, table, checklist, revealInFinder]
- [ ] FirstResultActionPolicy: invalid states (.missing*, .hash*, .wrong*) return []
- [ ] CharacterCatalog.assetManifest("chiko"): isPlaceholder=false, hasIdleSprite=true, hasWorkingSprite=true
- [ ] All other built-in characters: isPlaceholder=true
- [ ] ReleaseVisibleCharacterPolicy.isVisibleInRelease(chikoManifest): returns true
- [ ] ProductSurfacePolicy: all 8 static properties defined and correct for Release
- [ ] ConnectorSurfacePolicy: blockedCapabilitiesInRelease has 4+ capabilities
- [ ] CharacterGalleryView: uses ProductSurfacePolicy.characterVisibilityInRelease()
- [ ] RouterBurnInSuite: has test cases for all 5 allowed + 5 blocked starter actions
- [ ] ToolContractValidator: calls all 7 validators in validate()

---

**Matrix Version**: Round 116A  
**Last Updated**: Post-policy-centralization  
**Status**: Reference documentation for QA and Mac verification  
