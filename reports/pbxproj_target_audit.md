# pbxproj Target Audit Report

## Summary
**Total Files**: 15
**Present**: 1
**Missing**: 14

## File Status

### ✅ Present
- Color+Hex.swift

### ⚠️ Missing
- FirstLaunchState.swift
- FirstLaunchStateProvider.swift
- FirstLaunchBannerView.swift
- LocalOnlyModeCardView.swift
- RuntimeCapabilityMode.swift
- StarterAction.swift
- StarterActionDispatcher.swift
- StarterActionStripView.swift
- CharacterAssetManifest.swift
- ReleaseVisibleCharacterPolicy.swift
- ProductSurfacePolicy.swift
- ConnectorSurfacePolicy.swift
- FirstResultActionPolicy.swift
- StarterActionPolicy.swift

**Action**: Run `mac_register_round116_files.rb` to auto-register

## Next Steps
1. If missing files detected, run: `scripts/mac_register_round116_files.rb`
2. Verify pbxproj changes: `git diff MyTeam.xcodeproj/project.pbxproj`
3. Run xcodebuild Debug: `scripts/mac_merge_build_round116.sh`
