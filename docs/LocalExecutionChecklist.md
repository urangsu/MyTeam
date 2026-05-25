# Local Execution Checklist for App Store Submission

**Purpose**: Quick reference for macOS-only steps  
**Estimated Time**: 2-3 hours total  
**Status**: Cloud prep complete, local execution ready

---

## 🚀 Quick Start

```bash
# After cloning repo on Mac
cd MyTeam

# Step 1: Open in Xcode
open MyTeam/MyTeam.xcodeproj

# Step 2: Link entitlements (see instructions below)
# Step 3: Build Release
xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam \
  -configuration Release build

# Step 4: Run app and execute 6 QA tests (manual)
# Step 5: Capture screenshots (manual)
# Step 6: Upload to App Store Connect (web)
```

---

## Phase 1: Entitlements Linking (2 minutes, Xcode)

### Step 1a: Open Project
```bash
open MyTeam/MyTeam.xcodeproj
```

### Step 1b: Select Target
- Left sidebar: Select **MyTeam** target (blue app icon)
- Not MyTeamTests

### Step 1c: Build Settings Tab
1. Click **Build Settings** tab
2. Search box: Type `Code Signing`
3. Look for: **Code Signing Entitlements**

### Step 1d: Set Entitlements File
1. Double-click the value field
2. Type: `MyTeam/MyTeam.entitlements`
3. Press Enter
4. Xcode should autocomplete

### Step 1e: Verify
1. ⌘B to build
2. Should see: `Build Succeeded`
3. 0 errors
4. Save project (⌘S)

### ❌ Troubleshooting
- **File not found**: Verify path is exactly `MyTeam/MyTeam.entitlements`
- **Build still fails**: Check Xcode Console for specific error
- **Restart Xcode**: If path not auto-completing

---

## Phase 2: Release Build (10 minutes, Terminal)

### Step 2a: Build Release
```bash
cd MyTeam
xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam \
  -configuration Release build
```

### Step 2b: Verify Success
```
BUILD SUCCEEDED
0 errors
0 warnings
```

### Step 2c: Locate Artifact
```bash
# App built at:
~/Library/Developer/Xcode/DerivedData/MyTeam-*/Build/Products/Release/MyTeam.app

# Or use xcodebuild to show path:
xcodebuild -showBuildSettings -configuration Release | grep CONFIGURATION_BUILD_DIR
```

### ❌ Troubleshooting
- **Swift warnings**: Ignore if < 5 warnings (non-blocking)
- **Linker errors**: Check dependencies in Xcode
- **Out of disk**: Free up space, rebuild

---

## Phase 3: Manual QA Tests (20 minutes)

### Test Environment Setup
```bash
# Launch Release app (from build above)
# Or drag ~/Library/.../MyTeam.app to Applications folder
# Then launch normally

# If debugging needed, use:
open ~/Library/Developer/Xcode/DerivedData/MyTeam-*/Build/Products/Release/MyTeam.app
```

### ✅ Test 1: First Launch (2 min)

**Precondition**: Fresh app install (no API key set)

**Verify**:
- [ ] App opens without error dialog
- [ ] No crash on startup
- [ ] Chat view visible
- [ ] Settings button accessible
- [ ] Message appears: "로컬 파일/문서 기능부터 사용할 수 있습니다" or similar

**Result**: ☐ PASS  ☐ FAIL

---

### ✅ Test 2: Document Creation (3 min)

**Precondition**: App open, no API key needed

**Action**:
1. Type in chat: `"검토보고서 만들어줘"` (or `"회의록"`)
2. Press Enter
3. Wait for response (should use local template)

**Verify**:
- [ ] Response appears (not network error)
- [ ] Artifact card shows below response
- [ ] File name visible (e.g., "검토보고서-20260525-0001.md")
- [ ] "Finder 열기" button visible
- [ ] "경로 복사" button visible

**Result**: ☐ PASS  ☐ FAIL

---

### ✅ Test 3: Finder Integration (3 min)

**Precondition**: Artifact created from Test 2

**Action**:
1. Click "Finder 열기" button
2. Observe Finder window
3. Click "경로 복사" button
4. Open Terminal, type `echo ` and paste

**Verify**:
- [ ] Finder opens to artifact file (not error)
- [ ] File exists and has content
- [ ] Path is workspace-relative: `~/Library/Application Support/MyTeam/...`
- [ ] NOT absolute path like `/Users/...`

**Result**: ☐ PASS  ☐ FAIL

---

### ✅ Test 4: File Intake (4 min)

**Precondition**: App open, sample files available

**Action**:
1. Create test files:
   ```bash
   echo "Hello world" > ~/Desktop/test.txt
   echo "# Markdown\nSome content" > ~/Desktop/test.md
   ```

2. In chat: Drag `test.txt` into chat window
3. Verify content appears
4. Drag `test.md` into chat
5. Verify markdown renders
6. Try drag `.app` or `.sh` file → should show error

**Verify**:
- [ ] .txt import succeeds
- [ ] .md import succeeds  
- [ ] .csv support (if available)
- [ ] .pdf shows "준비 중" (not broken)
- [ ] .sh/.app shows blocked message
- [ ] No crashes during failed imports

**Result**: ☐ PASS  ☐ FAIL

---

### ✅ Test 5: Safety Blocks (3 min)

**Precondition**: App open

**Action**:
1. Type: `"메일 보내줘 hello world"`
2. Observe response
3. Type: `"일정 만들어줘"`
4. Type: `"파일 삭제해줘"`

**Verify**:
- [ ] Email request → shows blocked message
- [ ] Calendar request → shows blocked message
- [ ] Delete request → shows blocked message
- [ ] No actual emails sent (check Mail.app)
- [ ] No actual calendar events created
- [ ] No network calls attempted

**Result**: ☐ PASS  ☐ FAIL

---

### ✅ Test 6: Release Visibility (3 min)

**Precondition**: Release build running (not Debug)

**Verify HIDDEN**:
- [ ] No "PlanRunner" debug button
- [ ] No "Model Override" picker
- [ ] No "Verbose Diagnostics" button
- [ ] No internal error codes visible
- [ ] No full file paths (use `/Library/...` not `/Users/...`)

**Verify VISIBLE**:
- [ ] API key input in Settings
- [ ] File operations (import, create)
- [ ] Chat interface
- [ ] Artifact cards

**Result**: ☐ PASS  ☐ FAIL

---

### QA Summary
```
Test 1 (First Launch):      ☐ PASS  ☐ FAIL
Test 2 (Document):          ☐ PASS  ☐ FAIL
Test 3 (Finder):            ☐ PASS  ☐ FAIL
Test 4 (File Intake):       ☐ PASS  ☐ FAIL
Test 5 (Safety Blocks):     ☐ PASS  ☐ FAIL
Test 6 (Release Visibility):☐ PASS  ☐ FAIL

OVERALL: ☐ ALL PASS (proceed to screenshots)
         ☐ SOME FAIL (fix and retest)
```

---

## Phase 4: Screenshots (30 minutes)

### Screenshot Setup
```bash
# Resize window to exactly 1280×800
# System Settings > Displays > Resolution (if available)

# Or use Compressor:
# Window > Zoom (hold ⌘ + green button)
```

### Screenshot 1: Chat + Artifact
1. Position window at 1280×800
2. Type test message: `"검토보고서 만들어줘"`
3. Wait for response with artifact card
4. Press ⌘⇧4 to screenshot
5. Select window
6. Save to Desktop

**Rename**:
```bash
mv ~/Desktop/Screenshot\ 2026-05-25\ at\ ...png ~/MyTeam/screenshots/myteam-en-1280x800-1.png
cp ~/MyTeam/screenshots/myteam-en-1280x800-1.png ~/MyTeam/screenshots/myteam-ko-1280x800-1.png
```

**Annotation** (optional, in Preview.app):
- Add caption: "Create documents with AI"
- Or in App Store Connect

---

### Screenshot 2: File Import
1. In chat: Show file import action
2. Drag a .txt or .md file visible
3. Press ⌘⇧4, select window
4. Save and rename:
   ```bash
   # myteam-en-1280x800-2.png
   # myteam-ko-1280x800-2.png
   ```

---

### Screenshot 3: Settings
1. Click Settings button
2. Show Settings view with API key input
3. Show file format support list
4. Press ⌘⇧4, select window
5. Save and rename:
   ```bash
   # myteam-en-1280x800-3.png
   # myteam-ko-1280x800-3.png
   ```

---

### Screenshot Quality Checklist
```
For each screenshot:
  ☐ Size exactly 1280×800 (not 1280×799)
  ☐ Format: PNG (not JPG for first upload)
  ☐ No private data visible
  ☐ No error messages
  ☐ Clean UI state (no notifications)
  ☐ Named pattern: myteam-{lang}-1280x800-{n}.png
```

---

## Phase 5: App Store Connect Upload (15 minutes, Web)

### 5a: Prepare Files
```bash
# Verify screenshots ready
ls ~/MyTeam/screenshots/
# Should show:
#  myteam-en-1280x800-1.png
#  myteam-ko-1280x800-1.png
#  myteam-en-1280x800-2.png
#  myteam-ko-1280x800-2.png
#  myteam-en-1280x800-3.png
#  myteam-ko-1280x800-3.png
```

### 5b: Log In
1. Open https://appstoreconnect.apple.com/
2. Sign in with Apple Developer account
3. Select your team

### 5c: Create App (if first time)
1. Click "My Apps"
2. Click "+" button
3. Fill:
   - App Name: `MyTeam - AI 업무 팀`
   - SKU: `myteam-001`
   - Bundle ID: match your Xcode build

### 5d: Fill Metadata
1. Tab: **App Information**
2. Fill all fields (see `AppStoreConnectFieldMapping.md` for exact values)
3. Tab: **Pricing & Availability**
4. Set: `Free`
5. Tab: **Privacy**
6. Fill Privacy Nutrition Label (all required fields)

### 5e: Upload Screenshots
1. Tab: **App Preview & Screenshots**
2. Language: Select **English** first
3. Upload: 1280×800 screenshots in order
4. Add optional captions
5. Click **+** to add Korean versions
6. Language: **Korean**
7. Upload Korean screenshots

### 5f: Upload Build
1. From Xcode: **Window > Organizer**
2. Select app version
3. Click **Distribute App**
4. Follow wizard to upload to App Store Connect
5. Or: Use **TestFlight** first for internal testing

### 5g: Submit for Review
1. Review all fields
2. Click **Submit for Review**
3. App will be reviewed by Apple (24-48 hours typically)

---

## ❌ Troubleshooting

### "Screenshots size incorrect"
- Verify exactly 1280×800 (not 1279×799)
- Use `identify` to check: `identify screenshot.png`
- Re-capture if needed

### "Build upload failed"
- Verify build number incremented
- Check Xcode Organizer for upload errors
- Try again or contact Apple Support

### "Privacy Policy URL not accessible"
- Host on personal website (GitHub Pages, etc.)
- Ensure publicly accessible (no auth)
- Test in browser before submitting

### "Entitlements mismatch"
- Verify path in Xcode: `MyTeam/MyTeam.entitlements`
- Rebuild (⌘B) after changing
- Check Build Log for errors

---

## ✅ Final Verification

Before clicking "Submit for Review":

```
CODE:
  ☐ Release build: BUILD SUCCEEDED, 0 errors
  ☐ Entitlements linked in Xcode
  ☐ PrivacyInfo.xcprivacy present

QA:
  ☐ Test 1-6: All PASS
  ☐ No crashes observed
  ☐ No network errors

METADATA:
  ☐ App Name: "MyTeam - AI 업무 팀" (EN: "MyTeam")
  ☐ Subtitle: Filled
  ☐ Description: Filled (4000 chars max)
  ☐ Keywords: 10 items filled
  ☐ Privacy Policy URL: Accessible
  ☐ Screenshots: 3-5 per language, 1280×800

STORE:
  ☐ Privacy Nutrition Label: Complete
  ☐ Version Number: 1.0.0
  ☐ Build Number: 1
  ☐ Category: Productivity
  ☐ Age Rating: 4+
  ☐ All required fields: Filled

READY TO SUBMIT: ☐ YES  ☐ NO (fix issues)
```

---

## After Submission

1. **Check Status**: App Store Connect → App Status
2. **Monitor Email**: Apple sends review updates
3. **If Approved**: Share on social media, GitHub
4. **If Rejected**: Address feedback and resubmit

---

## Time Estimate

| Phase | Duration | Notes |
|-------|----------|-------|
| Entitlements | 2 min | Xcode setup |
| Release Build | 10 min | Compile time varies |
| Manual QA | 20 min | 6 tests |
| Screenshots | 30 min | Capture + naming |
| Upload | 15 min | Web + build upload |
| **Total** | **77 min** | ~1.5 hours |

---

**Status**: Ready for local execution  
**Last Updated**: 2026-05-25  
**Next Step**: Execute Phase 1 (Entitlements linking) on macOS
