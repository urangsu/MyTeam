# Mac Local Build Handoff — Round 116A

## Overview

Cloud round (96C-115Z) complete with policy centralization, compile-risk identification, and build automation scripts. This document guides the Mac local merge and build sequence.

**Status**: Ready for Mac merge and build verification

## Branch

```
Cloud Branch:  claude/round76-release-gate-audit-cloud
Merge Target:  main
Strategy:      git merge --no-ff
```

## Exact Commands

Run these commands sequentially on Mac:

```bash
# Step 1: Fetch latest
cd ~/Desktop/MyTeam
git fetch origin

# Step 2: Checkout main
git checkout main

# Step 3: Merge cloud branch
git merge --no-ff origin/claude/round76-release-gate-audit-cloud \
  -m "Merge Round 116A: policy centralization and build automation"

# Step 4: Audit pbxproj target (check which files are missing)
python3 scripts/pbxproj_target_audit.py

# Step 5: Debug build
xcodebuild \
  -scheme MyTeam \
  -configuration Debug \
  -derivedDataPath build/Debug \
  clean build

# Step 6: Release build
xcodebuild \
  -scheme MyTeam \
  -configuration Release \
  -derivedDataPath build/Release \
  clean build

# Step 7: Verify ToolExecutor Swift 6 warnings
grep -i "toolexecutor\|mainactor" build/Release/*.log 2>/dev/null || echo "✅ No ToolExecutor warnings"

# Step 8: Verify validator compilation
grep -i "ToolContractValidator" build/Release/*.log 2>/dev/null | grep -i "error" || echo "✅ Validator compiled"
```

## If Merge Conflicts

Merge conflicts typically occur in:
- `project.pbxproj` (file registration)
- `DEVLOG.md` (multiple rounds of work)
- `TASK.md` (status updates)

**Resolution Steps**:

1. Open Xcode: `open MyTeam/MyTeam.xcodeproj`
2. Resolve conflicts in Xcode UI (easier for pbxproj)
3. For text files:
   ```bash
   # View conflicts
   git status
   
   # Resolve manually (use VS Code or your editor)
   code .
   
   # Verify resolution
   git diff
   
   # Complete merge
   git add .
   git commit --no-edit
   ```

## If Swift Files Are Missing From Target

If `pbxproj_target_audit.py` reports missing files:

```bash
# Auto-register missing files
ruby scripts/mac_register_round116_files.rb

# Verify registration
python3 scripts/pbxproj_target_audit.py

# Commit registration
git add MyTeam/MyTeam.xcodeproj/project.pbxproj
git commit -m "Register missing Swift files in target"
```

**Files That Must Be Present**:
- CharacterAssetManifest.swift
- ReleaseVisibleCharacterPolicy.swift
- ProductSurfacePolicy.swift
- ConnectorSurfacePolicy.swift
- FirstResultActionPolicy.swift
- StarterActionPolicy.swift
- (11 other files from earlier rounds)

## If Debug Build Fails

**Common Causes**:

1. **Sendable conformance mismatch**
   - Check if new policy files implement `Sendable`
   - Verify: `enum ProductSurfacePolicy: Sendable { ... }`

2. **Type mismatch in CharacterCatalog helpers**
   - Ensure `releasePrimaryCharacter()` returns `CharacterDLC?`
   - Ensure `chikoDefaultExperienceCopy` is `String`

3. **Missing imports**
   - Policy files need: `import Foundation`

**Recovery**:
```bash
# Clean and rebuild
xcodebuild \
  -scheme MyTeam \
  -configuration Debug \
  -derivedDataPath build/Debug \
  clean

# Check error details
xcodebuild -scheme MyTeam -configuration Debug build 2>&1 | tee build_debug.log

# Fix issues (consult error log)
# Rerun build
```

## If Release Build Fails

**Common Causes**:

1. **FeatureFlags access in policy files**
   - Policy files should NOT import FeatureFlags
   - Policy decisions must be compile-time constants

2. **MainActor isolation in validators**
   - ToolContractValidator methods must be static
   - No `@MainActor` needed in policy validator

3. **Circular dependency**
   - CharacterCatalog → ReleaseVisibleCharacterPolicy
   - ToolContractValidator → (all policy files)
   - Check import order

**Recovery**:
```bash
# Clean and rebuild Release
xcodebuild \
  -scheme MyTeam \
  -configuration Release \
  -derivedDataPath build/Release \
  clean

# Full build with verbose output
xcodebuild \
  -scheme MyTeam \
  -configuration Release \
  -derivedDataPath build/Release \
  build -verbose 2>&1 | tee build_release.log

# Review compilation order in build_release.log
# Fix import statements and Sendable conformance
```

## If ToolExecutor Warning Remains

**Expected Warning**: None (removed in Round 76A-95Z)

**If Still Present**:

1. **Verify MainActor.run removed**
   ```bash
   grep -n "await MainActor.run" MyTeam/ToolExecutor.swift
   # Should return: (nothing)
   ```

2. **If found, check context**:
   - Only `String` property access? Remove MainActor.run
   - Complex async operation? Keep (unlikely)

3. **Recompile after fix**:
   ```bash
   xcodebuild -scheme MyTeam -configuration Release clean build
   ```

## Required Status Labels

After successful build, verify these exist in build output:

```
✅ Debug BUILD SUCCEEDED
✅ Release BUILD SUCCEEDED
✅ 0 app code warnings
✅ No MainActor overcalls
✅ No duplicate build file warnings
✅ ToolContractValidator compiled
✅ CharacterCatalog helpers present
✅ All policy files in target
```

## Next Phase

After successful build:

1. Commit build reports:
   ```bash
   mkdir -p reports
   git add reports/
   git commit -m "Add Mac build reports Round 116A"
   ```

2. Push to main:
   ```bash
   git push origin main
   ```

3. Next: Manual runtime QA (Round 140A)
   - First launch experience
   - Starter action routing
   - First result activation
   - Character availability

## Troubleshooting

**Build hangs**:
- Press Ctrl+C to interrupt
- Check: `ps aux | grep xcodebuild` for orphaned processes
- Rerun build from clean state

**Xcode cache issues**:
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/MyTeam*
xcodebuild -scheme MyTeam -configuration Debug clean build
```

**File permission errors**:
```bash
chmod +x scripts/*.sh scripts/*.py scripts/*.rb
git add -A
git commit -m "Fix script permissions"
```

---

**Created**: Round 116A  
**Status**: Ready for Mac execution  
**Handoff Goal**: Successful Debug + Release build, no blocking warnings  
