# Mac Build Failure Playbook

## Overview

Troubleshooting guide for common xcodebuild failures encountered in Round 116A and beyond. Each section covers error pattern, root cause, and recovery steps.

## Error Pattern Reference

### 1. "error: Sendable conformance"

**Pattern**:
```
error: 'ProductSurfacePolicy' does not conform to protocol 'Sendable'
```

**Root Cause**:
- Enum property not marked Sendable
- Nested type missing Sendable

**Fix**:
```swift
// ❌ Wrong
enum ProductSurfacePolicy {
    static let showsPlannedConnectorsInRelease = false
}

// ✅ Correct
enum ProductSurfacePolicy: Sendable {
    static let showsPlannedConnectorsInRelease = false
}
```

**Recovery Steps**:
```bash
# 1. Check file
grep -n "enum ProductSurfacePolicy" MyTeam/*.swift

# 2. Add :Sendable if missing
# (Edit file to add ": Sendable")

# 3. Verify all policy files
grep "enum.*SurfacePolicy\|enum.*Policy:" MyTeam/*.swift

# 4. Rebuild
xcodebuild -scheme MyTeam -configuration Release clean build
```

### 2. "Cannot find file in target"

**Pattern**:
```
error: file not found: MyTeam/ProductSurfacePolicy.swift
```

**Root Cause**:
- File created but not registered in pbxproj
- File moved but pbxproj reference not updated

**Fix**:
```bash
# 1. Verify file exists
ls -la MyTeam/ProductSurfacePolicy.swift

# 2. Run target audit
python3 scripts/pbxproj_target_audit.py

# 3. Auto-register if available
ruby scripts/mac_register_round116_files.rb

# 4. Or manual registration in Xcode:
# - Open MyTeam.xcodeproj
# - Right-click target → Add Files
# - Select ProductSurfacePolicy.swift
# - Ensure target is checked

# 5. Commit
git add MyTeam/MyTeam.xcodeproj/project.pbxproj
git commit -m "Register ProductSurfacePolicy.swift in target"

# 6. Rebuild
xcodebuild -scheme MyTeam -configuration Release clean build
```

### 3. "No such module 'Foundation'"

**Pattern**:
```
error: no such module 'Foundation'
could not find module for target 'MyTeam'
```

**Root Cause**:
- pbxproj syntax corrupted during merge
- XcodeProj gem modified file incorrectly

**Fix**:
```bash
# 1. Check pbxproj syntax
plutil -lint MyTeam/MyTeam.xcodeproj/project.pbxproj

# 2. If invalid, restore from git
git checkout HEAD -- MyTeam/MyTeam.xcodeproj/project.pbxproj

# 3. Manually re-register missing files:
ruby scripts/mac_register_round116_files.rb

# 4. Rebuild
xcodebuild -scheme MyTeam -configuration Release clean build
```

### 4. "Circular dependency between modules"

**Pattern**:
```
error: circular dependency between modules 'MyTeam' and 'MyTeam'
```

**Root Cause**:
- CharacterCatalog imports ToolContractValidator
- ToolContractValidator imports CharacterCatalog
- Break the cycle through forward declarations or separated protocols

**Fix**:
```swift
// ToolContractValidator.swift should NOT import CharacterCatalog
// Instead, access through static methods only:

// ❌ Wrong (creates cycle)
import CharacterCatalog
let manifest = CharacterCatalog.assetManifest(for: "chiko")

// ✅ Correct (no import needed if accessed dynamically)
// Or use protocol: CharacterAssetProvider

// CharacterCatalog.swift can import ToolContractValidator fine
// (unidirectional is OK)
```

**Recovery Steps**:
```bash
# 1. Identify import causing cycle
grep -n "^import" MyTeam/ToolContractValidator.swift MyTeam/CharacterCatalog.swift

# 2. Remove CharacterCatalog import from ToolContractValidator
# (Use static references only)

# 3. Rebuild
xcodebuild -scheme MyTeam -configuration Release clean build
```

### 5. "Type mismatch: expected CharacterDLC?"

**Pattern**:
```
error: cannot convert return expression of type 'CharacterDLC' to return type 'CharacterDLC?'
```

**Root Cause**:
- releasePrimaryCharacter() returns CharacterDLC but should return CharacterDLC?
- Or character lookup returns nil for "chiko"

**Fix**:
```swift
// ❌ Wrong
static func releasePrimaryCharacter() -> CharacterDLC {
    character(id: "char.builtin.chiko")!  // Force unwrap—risky
}

// ✅ Correct
static func releasePrimaryCharacter() -> CharacterDLC? {
    character(id: "char.builtin.chiko")  // Safe optional
}
```

**Recovery Steps**:
```bash
# 1. Check current signature
grep -A2 "func releasePrimaryCharacter" MyTeam/MyTeam/CharacterCatalog.swift

# 2. Verify character("char.builtin.chiko") exists
grep -n "char.builtin.chiko" MyTeam/MyTeam/CharacterCatalog.swift

# 3. Update return type if needed
# (Edit CharacterCatalog.swift)

# 4. Rebuild
xcodebuild -scheme MyTeam -configuration Release clean build
```

### 6. "FeatureFlags not available in Release"

**Pattern**:
```
error: 'FeatureFlags' is only available in iOS/macOS X.X
```

**Root Cause**:
- Policy files using FeatureFlags (compile-time varies by config)
- Should use ProductSurfacePolicy constants instead

**Fix**:
```swift
// ❌ Wrong (depends on runtime FeatureFlags)
enum ProductSurfacePolicy: Sendable {
    static let showsPlannedConnectorsInRelease = FeatureFlags.debugToolVisible
}

// ✅ Correct (static constant)
enum ProductSurfacePolicy: Sendable {
    static let showsPlannedConnectorsInRelease = false  // Release: always false
}
```

**Recovery Steps**:
```bash
# 1. Find FeatureFlags usage in policy files
grep -n "FeatureFlags" MyTeam/ProductSurfacePolicy.swift \
  MyTeam/ConnectorSurfacePolicy.swift \
  MyTeam/FirstResultActionPolicy.swift \
  MyTeam/StarterActionPolicy.swift

# 2. Replace with static values
# ProductSurfacePolicy.showsPlannedConnectorsInRelease = false (Release constant)

# 3. Rebuild
xcodebuild -scheme MyTeam -configuration Release clean build
```

### 7. "MainActor.run overcall"

**Pattern**:
```
warning: sendable type 'String' should not be isolated to the main thread
```

**Root Cause**:
- Using MainActor.run for pure value operations (String, Int, etc.)
- Leftover from earlier refactoring

**Fix**:
```swift
// ❌ Wrong (overcall)
let name = await MainActor.run { tool.name }

// ✅ Correct (String is pure value, no isolation needed)
let name = tool.name
```

**Recovery Steps**:
```bash
# 1. Find MainActor.run calls
grep -n "await MainActor.run" MyTeam/ToolExecutor.swift

# 2. Remove if accessing pure values (String, Int, Bool)
# Keep only if accessing @MainActor properties

# 3. Rebuild
xcodebuild -scheme MyTeam -configuration Release clean build
```

## Recovery Decision Tree

```
Is it a compilation error or warning?
├─ Compilation ERROR
│  ├─ Sendable/protocol conformance?
│  │  └─ → Add ": Sendable" to enum/struct
│  ├─ File not found?
│  │  └─ → Run pbxproj_target_audit.py + mac_register_round116_files.rb
│  ├─ Type mismatch?
│  │  └─ → Check signature matches call sites
│  └─ Circular dependency?
│     └─ → Remove cross-imports, use protocols
└─ WARNING
   ├─ MainActor overcall?
   │  └─ → Remove for pure value types
   ├─ FeatureFlags usage?
   │  └─ → Replace with static policy constants
   └─ Otherwise?
      └─ → Review CompileRiskRegister.md
```

## Testing Recovery

After applying any fix:

```bash
# Clean build (required after pbxproj changes)
xcodebuild -scheme MyTeam -configuration Release clean

# Rebuild
xcodebuild -scheme MyTeam -configuration Release build

# Verify no errors
echo "Exit code: $?"  # Should be 0
```

## Escalation

If none of these patterns match:

1. **Capture full error output**:
   ```bash
   xcodebuild -scheme MyTeam -configuration Release build 2>&1 | tee build_error.log
   ```

2. **Check CompileRiskRegister.md**: High/medium-risk items may have additional context

3. **Review CloudCompletionReport.md**: Known limitations section

4. **Compare with working build**: 
   ```bash
   git log --oneline | head -5  # See recent commits
   git show HEAD:MyTeam/ProductSurfacePolicy.swift  # What was committed
   ```

---

**Playbook Version**: Round 116A  
**Last Updated**: Post-cloud-completion  
**Status**: Ready for Mac build troubleshooting  
