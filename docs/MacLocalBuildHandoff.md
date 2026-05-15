# Mac Local Build Handoff — Round 96A

## Overview
Cloud round (76A-95Z) complete. All code/policy/document work ready for Mac verification and manual QA.

## Prerequisite: Cloud Work Completion
✅ ToolExecutor MainActor.run calls removed  
✅ CharacterAssetManifest / ReleaseVisibleCharacterPolicy added  
✅ Privacy copy audit complete  
✅ Cloud preflight script passing  
✅ All static policy checks passing  

## Mac Local Tasks

### Task 1: Fetch Latest Branch
```bash
cd ~/Desktop/MyTeam
git fetch origin
git checkout main
git pull origin main
```

### Task 2: Xcode Project Verification
```bash
# Verify project opens without errors
open MyTeam/MyTeam.xcodeproj

# Check for missing references
# (Xcode → Product → Analyze)
```

### Task 3: Build — Debug Configuration

```bash
xcodebuild \
  -project MyTeam/MyTeam.xcodeproj \
  -scheme MyTeam \
  -configuration Debug \
  build
```

**Expected Output**:
```
Build complete!

Build settings from command line:
...
** BUILD SUCCEEDED **
```

**Check**:
- [ ] `** BUILD SUCCEEDED **` present
- [ ] Build time noted (typically 30-60 sec)
- [ ] App code warning count: ____
- [ ] Duplicate build file warning count: ____
- [ ] ToolExecutor Swift 6 warning status: ✅ Resolved / ⚠️ Still Present

### Task 4: Build — Release Configuration

```bash
xcodebuild \
  -project MyTeam/MyTeam.xcodeproj \
  -scheme MyTeam \
  -configuration Release \
  build
```

**Expected Output**:
```
Build complete!

Build settings from command line:
...
** BUILD SUCCEEDED **
```

**Check**:
- [ ] `** BUILD SUCCEEDED **` present
- [ ] Build time noted (typically 1-2 min, slower than Debug)
- [ ] App code warning count: ____
- [ ] Duplicate build file warning count: ____
- [ ] Swift 6 warnings: ____

### Task 5: Verify File Locations

```bash
ls -1 MyTeam/MyTeam/ | grep -E "(FirstLaunch|LocalOnly|StarterAction|CharacterAsset|ReleaseVisible)"
```

**Expected Output**:
```
CharacterAssetManifest.swift
FirstLaunchBannerView.swift
LocalOnlyModeCardView.swift
ReleaseVisibleCharacterPolicy.swift
StarterActionDispatcher.swift
StarterActionStripView.swift
```

### Task 6: Launch App (Debug Build)

```bash
# Build and run in simulator/device
xcodebuild \
  -project MyTeam/MyTeam.xcodeproj \
  -scheme MyTeam \
  -configuration Debug \
  -destination 'platform=macOS' \
  build
```

Or manually from Xcode:
- Product → Scheme → MyTeam
- Product → Destination → My Mac
- Product → Run (⌘R)

**Manual QA Checklist**:
- [ ] App launches without crash
- [ ] First launch screen visible (no API key state)
- [ ] FirstLaunchBannerView visible with correct message
- [ ] Starter action buttons visible and clickable
  - [ ] "회의록 양식 만들어" works
  - [ ] "체크리스트 만들어" works
  - [ ] "파일 읽기" shows file picker
  - [ ] "오늘 할 일 뭐야" works
- [ ] First artifact generates in < 90 seconds
- [ ] FirstResultActionStripView visible with 4 buttons
- [ ] First result actions work
  - [ ] "요약하기" transforms artifact
  - [ ] "표로 바꾸기" transforms artifact
  - [ ] "체크리스트로 바꿔줘" transforms artifact
  - [ ] "Finder에서 보기" opens file in Finder
- [ ] Settings → LocalOnlyModeCardView visible when no API key
- [ ] Finder integration works (path copy, reveal)
- [ ] No placeholder characters visible
- [ ] No Pro/Premium button visible
- [ ] No Gmail/Naver/Calendar write visible
- [ ] Character (Chiko) visible and responsive

## Not Included in This Handoff

### Out of Scope for Round 96A
❌ StoreKit production purchase QA  
❌ Google Calendar live OAuth testing  
❌ Archive / export build  
❌ App Store submission test flight  
❌ Character DLC asset production  
❌ Performance profiling  

### Deferred to Round 97+
❌ Full automation test suite  
❌ A/B testing configuration  
❌ Analytics event tracking  
❌ Sentry/crash reporting  

## Known Issues / Limitations

### Deployment Target
- Current: macOS 26.2
- Investigation pending: may lower to 15+ if feasible
- See `docs/DeploymentTargetStrategy.md`

### ToolExecutor Swift 6 Warning
- Status: MainActor.run calls removed
- Expected: warning should be gone
- If still present: check Xcode build log, file `docs/ReleaseWarningAudit.md`

### Character Assets
- Sprites: placeholder assets only (production assets pending)
- Manifest: defined but not fully integrated into CharacterCatalog
- Impact: no visual character change, but policy structure ready

## Build Verification Checklist

- [ ] Debug build: BUILD SUCCEEDED
- [ ] Release build: BUILD SUCCEEDED
- [ ] App code warnings < 5
- [ ] No duplicate build file warnings
- [ ] ToolExecutor Swift 6 warning resolved
- [ ] All Swift files compile without syntax errors
- [ ] No references to undefined symbols
- [ ] Project target includes all new Swift files:
  - CharacterAssetManifest.swift
  - ReleaseVisibleCharacterPolicy.swift

## Go/No-Go Decision

### Go to Round 97A if:
✅ Debug build succeeds  
✅ Release build succeeds  
✅ First artifact generates in < 90s  
✅ Starter actions work  
✅ First result actions work  
✅ Finder integration works  
✅ No placeholder characters visible  
✅ No Pro/Premium button visible  
✅ No external write tools visible  

### No-Go if:
❌ Debug build fails  
❌ Release build fails  
❌ Artifact generation > 2 minutes  
❌ Starter actions error  
❌ Placeholder character visible in Release  
❌ Pro/Premium button visible  
❌ External write tool visible  

## Output to Report

After completing all builds and manual QA:

1. **Build Summary**
   - Debug BUILD SUCCEEDED / FAILED
   - Release BUILD SUCCEEDED / FAILED
   - App code warning count
   - Duplicate build file warning count
   - ToolExecutor Swift 6 warning: resolved / still present

2. **Manual QA Summary**
   - First launch flow: working / issues noted
   - Starter actions: all 4 working / issues noted
   - First result actions: all 4 working / issues noted
   - Finder integration: working / issues noted
   - Character visibility: correct (no placeholder/DLC) / issues noted
   - Paywall visibility: hidden / visible (issue)

3. **File Verification**
   - CharacterAssetManifest.swift: present / missing
   - ReleaseVisibleCharacterPolicy.swift: present / missing
   - All 4 starter action files: present / missing

4. **Issues Found**
   - None / list of issues with severity

5. **Approval**
   - Ready for Round 97A: Yes / No
   - If No: specific blockers

## Questions?

Refer to:
- `docs/InternalReviewReport.md` — full policy review
- `docs/DeploymentTargetStrategy.md` — build configuration
- `docs/ScreenshotSurfaceAudit.md` — UI verification
- `docs/ReleaseWarningAudit.md` — warning catalog
