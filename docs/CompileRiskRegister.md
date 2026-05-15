# Compile Risk Register

## Scope
Cloud-added code that requires Mac xcodebuild confirmation before Release submission.

## High Risk — Must Verify on Mac

### CharacterAssetManifest.swift
**Risk**:
- New Swift file may be missing from Xcode target
- Sendable/Codable conformance compile mismatch possible
- Enum cases may not match actual Character types

**Mac check**:
- ✅ pbxproj: PBXFileReference + PBXBuildFile + PBXSourcesBuildPhase
- ✅ Debug xcodebuild: BuildSucceeded
- ✅ Release xcodebuild: BuildSucceeded
- ✅ Type check: CharacterAssetManifest used by CharacterCatalog

### ReleaseVisibleCharacterPolicy.swift
**Risk**:
- New Swift file may be missing from target
- Static method calls may fail if called before definitions
- CharacterAssetManifest type conformance

**Mac check**:
- ✅ pbxproj target audit
- ✅ Debug/Release xcodebuild
- ✅ isVisibleInRelease() / isPurchasableInRelease() call sites

### ProductSurfacePolicy (new/Round 116C)
**Risk**:
- If added with compile errors, blocks all builds
- FeatureFlags mismatch possible

**Mac check**:
- ✅ Static enum syntax
- ✅ Bool property initialization
- ✅ No circular imports

### CharacterCatalog helpers
**Risk**:
- Character / CharacterDLC property mismatch (.id vs .characterID)
- CharacterGalleryView expects different API shape
- Filter methods return type mismatch

**Mac check**:
- ✅ assetManifest(for:) call sites
- ✅ isVisibleInRelease() / isPurchasableInRelease() usage
- ✅ releaseVisibleCharacters() / releasePurchasableCharacters() return types

### ToolContractValidator enhancements
**Risk**:
- Validation issue type duplication
- Existing severity enum mismatch
- New validators may not be invoked from validate()
- CharacterCatalog / ReleaseVisibleCharacterPolicy dependency compile failure

**Mac check**:
- ✅ ToolContractValidationIssue.Severity enum
- ✅ All 7 validators called in validate()
- ✅ Type references to CharacterCatalog, ReleaseVisibleCharacterPolicy

### RuntimeDiagnosticsService fields (Round 96C-115Z)
**Risk**:
- Added 19 fields may not be initialized everywhere
- Snapshot creation code may have type mismatches
- Release / debug visibility mismatch

**Mac check**:
- ✅ All fields initialized in snapshot creation
- ✅ No uninitialized property access
- ✅ String literals match accepted values

## Medium Risk — Recommend Manual Review

### PolicyFixtureMatrix content
**Risk**:
- Hardcoded strings may not match actual route/capability enum values

**Mac check**:
- ✅ Compare matrix strings to router case names
- ✅ Compare capability names to ConnectorCapability enum

### Mac scripts (pbxproj_target_audit.py, mac_register_round116_files.rb)
**Risk**:
- Python/Ruby environment variations
- xcodeproj gem availability
- pbxproj format parsing differences

**Mac check**:
- ✅ Python3 available
- ✅ xcodeproj gem installed (optional, but recommended)
- ✅ Script runs without errors

### cloud_preflight report generation
**Risk**:
- reports/ directory may not exist
- Report file permissions

**Mac check**:
- ✅ mkdir -p reports succeeds
- ✅ Files are writable

## Low Risk — Documentation Only

### CompileRiskRegister (this file)
- Documentation only, no execution

### CloudCompletionReport
- Status documentation, no execution

### PolicyFixtureMatrix
- Reference documentation, no execution

## Required Mac Commands

See `docs/MacLocalBuildHandoff.md` for exact sequence.

## Success Criteria

**All High Risk checks pass on Mac**:
- ✅ All new .swift files in pbxproj target
- ✅ Debug BUILD SUCCEEDED
- ✅ Release BUILD SUCCEEDED
- ✅ 0 app code warnings
- ✅ No duplicate build file warnings
- ✅ ToolExecutor Swift 6 warning resolved (if any)

**Medium Risk cleared**:
- ✅ PolicyFixtureMatrix strings match router/capability enums
- ✅ Scripts run without permission errors
- ✅ reports/ directory exists and files generated

## Escalation Path

If Mac build fails:
1. Check pbxproj_target_audit.md for missing files
2. Run mac_register_round116_files.rb to auto-register (if available)
3. Refer to MacBuildFailurePlaybook.md for error patterns
4. Document in CloudCompletionReport.md under "Mac build failures"

## Next Phase

Round 136A (Mac Local):
- Execute pbxproj_target_audit.py
- Run mac_register_round116_files.rb if available
- Execute xcodebuild with this register as reference
- Update CloudCompletionReport with actual results
