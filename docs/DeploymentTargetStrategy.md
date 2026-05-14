# Deployment Target & Build Configuration Strategy

## Overview

This document specifies deployment targets, copyright strings, permission copy, and build configuration settings for MyTeam v1.0 and beyond.

---

## macOS Deployment Target

### Current Setting
```
MACOSX_DEPLOYMENT_TARGET = 26.2
```

### Rationale
- **26.2** supports the latest macOS versions (Sequoia and newer)
- MyTeam uses modern SwiftUI APIs (SwiftUI 2024 features)
- No legacy OS 10.x or 11.x support required
- App Store distribution for macOS 12.0+ per AppStoreMetadataDraft.md

### Architecture Support
- **Apple Silicon** (arm64) — primary
- **Intel** (x86_64) — Universal Binary support
- Both architectures included in release build

---

## Copyright String

### Current Setting
```
INFOPLIST_KEY_NSHumanReadableCopyright = ""  // EMPTY — TO BE UPDATED
```

### Recommended Setting
```
INFOPLIST_KEY_NSHumanReadableCopyright = "© 2026 MyTeam. All rights reserved."
```

Or with ownership detail:
```
INFOPLIST_KEY_NSHumanReadableCopyright = "© 2026 [Developer/Company Name]. All rights reserved."
```

### Notes
- Used in About dialog / App Store metadata
- Should match privacy policy attribution
- Version line (1.0) managed separately in build settings

---

## Version & Build Numbers

### Current Strategy
- **Version (CFBundleShortVersionString)**: 1.0
- **Build (CFBundleVersion)**: Auto-increment per Xcode build

### Visibility
- Shown in About dialog (AppKit NSApp.appVersion)
- Shown in App Store product page
- Not displayed in UI except diagnostics

---

## Permissions & Permission Copy

### Declared Permissions (Info.plist)

#### 1. File Access (NSOpenPanel / NSSavePanel)
- **Scope**: User-selected files only (sandbox-safe)
- **Copy**: "읽기용 파일을 선택하세요"
- **Implementation**: FileImporter, FilePicker

#### 2. Keyboard (Full Disk Access) — NOT USED
- **Status**: Not required (no background monitoring)
- **Decision**: Deferred to future version if needed

#### 3. Microphone (Audio Input) — TTS Fallback Only
- **Scope**: Optional, only when TTS service unavailable
- **Copy**: "음성 합성이 불가능할 때만 사용됩니다"
- **Fallback**: Qwen3TTSService unavailable → system TTS request

#### 4. Pasteboard Access
- **Scope**: Copy path / Copy artifact content
- **Copy**: "경로와 문서 내용을 복사합니다"

#### 5. Finder Integration
- **Scope**: Open file in Finder (NSWorkspace.shared.selectFile)
- **Copy**: "문서 위치를 Finder에서 표시합니다"

### Restricted Permissions — NOT USED
- ❌ Camera / Webcam — not used
- ❌ Location — not used
- ❌ Calendar write — never auto-execute
- ❌ Mail send — never auto-execute
- ❌ Spotlight indexing — not used

---

## Permission Copy Implementation

### Location: Code Copy in UI

#### FirstLaunchBannerView
```swift
"로컬 기능은 API key 없이 사용할 수 있습니다. AI 기능은 설정에서 API key를 연결해 확장하세요."
```

#### AssistantConnectorCenterView (Calendar)
```swift
"일정 생성/수정은 자동 실행하지 않습니다."
```

#### FileImportDialog
```swift
"읽기용 파일을 선택하세요. MyTeam은 선택한 파일만 읽습니다."
```

#### ArtifactCardView (Copy Path)
```swift
"문서 위치를 복사했습니다."
```

---

## Build Configuration Checklist

### Debug Build (`xcodebuild -configuration Debug`)
- [ ] SWIFT_ACTIVE_COMPILATION_CONDITIONS includes `DEBUG`
- [ ] ENABLE_TESTABILITY = YES
- [ ] COPY_PHASE_STRIP = NO
- [ ] GCC_OPTIMIZATION_LEVEL = 0
- [ ] Warnings as errors: NO (allow warnings)
- [ ] Runtime diagnostics: ENABLED (verbose)
- [ ] Debug toggles: VISIBLE
- [ ] PlanRunner feature flag: may be ON/OFF

### Release Build (`xcodebuild -configuration Release`)
- [ ] SWIFT_ACTIVE_COMPILATION_CONDITIONS empty
- [ ] DEBUG checks filtered (disabled)
- [ ] COPY_PHASE_STRIP = YES
- [ ] GCC_OPTIMIZATION_LEVEL = 3 (optimize for speed)
- [ ] STRIP_INSTALLED_PRODUCT = YES
- [ ] Warnings as errors: YES (enforce 0 warnings)
- [ ] Debug toggles: HIDDEN
- [ ] Runtime diagnostics: MINIMAL (errors only)
- [ ] All character placeholders: HIDDEN
- [ ] DLC buttons: only for ready characters
- [ ] Coming Soon labels: HIDDEN
- [ ] PlanRunner feature flag: FALSE

---

## Swift Compiler Warnings

### Swift 6 Warning Audit

#### Current Status
- ToolExecutor.swift: Investigated, _modifying_ parameter logic valid
- No breaking language-level warnings in Xcode 26.3

#### Policy
- Swift 6 full concurrency checks: ENABLED in Release
- Fix warnings where possible, document exceptions in code comments
- No `@preconcurrency` without explicit reason

---

## App Store Submission Requirements

### Metadata
- [ ] Copyright string filled in Info.plist
- [ ] App name: "MyTeam - AI 업무 팀"
- [ ] Subtitle: "회의록·체크리스트·보고서를 빠르게"
- [ ] Version: 1.0
- [ ] Build number: Auto (e.g., 1)

### Permissions & Privacy
- [ ] App Privacy form completed
- [ ] Data categories accurate (file access, optional microphone)
- [ ] Tracking transparency: Not used
- [ ] Signature: Developer account

### Content Rating
- [ ] Rated for 4+ years (no adult content)
- [ ] No violence, explicit content, etc.

---

## Deployment Timeline

| Phase | Milestone | Target Date |
|-------|-----------|-------------|
| v1.0 | Deployment target finalized | 2026-05-15 |
| v1.0 | Copyright & build config confirmed | 2026-05-15 |
| v1.0 | App Store submission ready | 2026-05-15 |
| v1.0 | TestFlight beta (if desired) | 2026-05-16 |
| v1.0 | App Store public release | 2026-05-17+ |

---

**Last Updated**: 2026-05-15  
**Owner**: Build & Release Team  
**Status**: Active  
