# App Store Connect Submission Guide

**Round:** 278-APPSTORE-SUBMISSION  
**Status:** Metadata prepared, local execution pending  
**Estimated Time:** 2-3 hours (metadata + manual QA + screenshots)

---

## Overview

This guide walks through final App Store submission steps. Most work is in **local environment only** (Xcode, manual QA, screenshots).

### Prerequisites
- Xcode installed (macOS 13+)
- MyTeam development repo cloned locally
- Apple Developer Account with team access
- Screenshots ready (see below)

### No Cloud Work Required
- Entitlements linking → Xcode only
- Manual QA → Run app locally
- Screenshots → macOS Finder
- App Store Connect upload → Apple's web interface

---

## Part 1: Entitlements Linking (2 min, Xcode)

### Step 1a: Open Project in Xcode
```bash
cd MyTeam
open MyTeam/MyTeam.xcodeproj
```

### Step 1b: Verify Entitlements File
- Left sidebar: `MyTeam/MyTeam.entitlements` should be visible
- If missing, file was not created (run Round 256A code first)

### Step 1c: Link to Target
1. Select target: **MyTeam** (not tests)
2. Tab: **Build Settings**
3. Search: `Code Signing Entitlements`
4. Set value: `MyTeam/MyTeam.entitlements`
5. ⌘B to build (verify 0 errors)

### Expected Result
- Build succeeds with 0 errors
- Entitlements loaded into app bundle
- Sandbox policy active in Release build

---

## Part 2: Manual QA Execution (20 min, macOS)

**Do NOT skip.** This is your first user-facing validation.

### QA Test 1: First Launch
```
PRECONDITION: Fresh app install (no cached state)
ACTION: Launch MyTeam.app
VERIFY:
  ☐ App opens without error
  ☐ No auth/permission prompts on startup
  ☐ Settings button visible
  ☐ Chat area shows "로컬 파일/문서 기능부터 사용할 수 있습니다" or similar
  ☐ No crash logs in Console.app
OUTCOME: PASS / FAIL
```

### QA Test 2: Document Creation (Local)
```
PRECONDITION: App open, no API key configured
ACTION:
  1. Chat: "검토보고서 만들어줘" (or "회의록 만들어줘")
  2. Wait for response
VERIFY:
  ☐ Response appears (local template or cached)
  ☐ Artifact card shows (if document generated)
  ☐ "Finder 열기" button visible
  ☐ "경로 복사" button visible
  ☐ No network error (should work locally)
OUTCOME: PASS / FAIL
```

### QA Test 3: File Intake
```
PRECONDITION: App open, sample files available
ACTION:
  1. Drag .txt file into chat → verify content appears
  2. Drag .md file into chat → verify markdown
  3. Drag .csv file into chat → verify table
  4. Try drag .pdf file → should show "준비 중" message
  5. Try drag .sh file → should show blocked message
VERIFY:
  ☐ txt/md/csv import works
  ☐ pdf shows "준비 중" (not broken)
  ☐ .sh shows blocked/error message
  ☐ No crashes during import failures
OUTCOME: PASS / FAIL
```

### QA Test 4: Safety Blocks
```
PRECONDITION: App open
ACTION:
  1. Chat: "메일 보내줘" → verify blocked
  2. Chat: "일정 만들어줘" → verify blocked
  3. Chat: "파일 삭제해줘" → verify blocked
  4. Chat: "외부 사이트에 올려줘" → verify blocked
VERIFY:
  ☐ Each returns blocked/unavailable message
  ☐ No tool execution (check Activity Monitor for external API calls)
  ☐ No crashes
OUTCOME: PASS / FAIL
```

### QA Test 5: Release Visibility (RELEASE BUILD ONLY)
```
PRECONDITION: Release build running (xcodebuild ... -configuration Release)
VERIFY HIDDEN:
  ☐ No "PlanRunner" debug button
  ☐ No "Model Override" picker
  ☐ No "Verbose Diagnostics" option
  ☐ No internal error codes in UI
  ☐ Paths shown are redacted (not /Users/...)
VERIFY VISIBLE:
  ☐ API key input in Settings
  ☐ File operations (import, create)
  ☐ Chat interface
  ☐ Artifact cards
OUTCOME: PASS / FAIL
```

### QA Test 6: Finder Integration
```
PRECONDITION: Artifact created (from Test 2)
ACTION:
  1. Click "Finder 열기" button
  2. Observe Finder window
  3. Click "경로 복사" button
  4. Paste in Terminal
VERIFY:
  ☐ Finder opens to artifact file (not error)
  ☐ File exists and has content
  ☐ Path copied is workspace-relative (~/Library/Application Support/MyTeam/...)
  ☐ No absolute paths leaked
OUTCOME: PASS / FAIL
```

### QA Summary
```
Test 1 (First Launch):      ☐ PASS  ☐ FAIL  Notes: ___
Test 2 (Document Creation): ☐ PASS  ☐ FAIL  Notes: ___
Test 3 (File Intake):       ☐ PASS  ☐ FAIL  Notes: ___
Test 4 (Safety Blocks):     ☐ PASS  ☐ FAIL  Notes: ___
Test 5 (Release Visibility):☐ PASS  ☐ FAIL  Notes: ___
Test 6 (Finder):            ☐ PASS  ☐ FAIL  Notes: ___

OVERALL: ☐ READY FOR SUBMISSION  ☐ FIX ISSUES
```

If any test fails, document the issue, fix in code, rebuild, and retest.

---

## Part 3: Screenshots & Metadata (30 min, parallel)

### 3a: Required Screenshots

**macOS App Store requires:**
- **Formats**: JPG or PNG
- **Resolutions**: 
  - 1280×800 (primary, required)
  - 1920×1200 (optional, 5K display)
  - All must be in landscape
- **Count**: 2-5 per language (English + Korean)
- **Content**: Show core features, not setup screens

#### Recommended 3-Screenshot Sequence

**Screenshot 1: Chat + Artifact (Main Workflow)**
```
Title: "AI와 함께 문서 만들기"
Content: Chat with artifact card visible
Show:
  - Chat bubble with user message ("회의록 만들어줘")
  - AI response (partial)
  - Artifact card with file name
  - Finder/copy buttons
```

**Screenshot 2: File Organization (File Intake)**
```
Title: "파일을 드래그해서 정리하기"
Content: File import workflow
Show:
  - File import panel or recent files
  - Imported file content in chat
  - File analysis response
```

**Screenshot 3: Settings (Local + API)**
```
Title: "로컬 기능 + AI 선택"
Content: Settings view
Show:
  - API key input section (with placeholder)
  - "로컬 기능부터 사용 가능" message
  - File format support list
```

### 3b: How to Take Screenshots

**Automated (Recommended):**
```bash
# Run script in MyTeam directory
bash scripts/generate_appstore_screenshots.sh

# Outputs:
# - screenshots/myteam-en-1280x800-1.png (English)
# - screenshots/myteam-ko-1280x800-1.png (Korean)
# - etc.
```

**Manual (Fallback):**
1. Launch Debug build: `xcodebuild ... -configuration Debug`
2. Resize window to 1280×800 (System Preferences → Displays)
3. Set up chat/file/settings state
4. ⌘⇧4, select window → saves to Desktop
5. Crop as needed

### 3c: Metadata Fields for App Store Connect

When filling App Store Connect form, use these exact values:

```
App Name:
  → MyTeam - AI 업무 팀

Subtitle:
  → 회의록·체크리스트·보고서를 빠르게

Primary Category:
  → Productivity

Secondary Category:
  → Utilities

Description:
  [See AppStoreMetadataDraft.md lines 9-25]
  (Copy full description, 4000 char limit)

Keywords:
  [See AppStoreMetadataDraft.md line 15]
  (10 comma-separated, 100 char limit per keyword)

Support URL:
  → https://github.com/urangsu/MyTeam
  (Or support email if available)

Privacy Policy URL:
  → [Must be externally hosted]
  (See docs/PrivacyPolicy.md for template)

Age Rating:
  → 4+ (no restricted content)

Privacy Nutrition Label:
  → Data NOT Collected (check all fields)
  → Network reason: "Claude API, Google OAuth"
  → Tracking: DISABLED

Build Number:
  → Increment from last submission
  (e.g., 1 → 2 for subsequent builds)

Pricing:
  → Free (or In-App Purchase, depending on business model)
```

### 3d: Privacy Policy

**Required by App Store.** Create at docs/PrivacyPolicy.md

Template:
```markdown
# MyTeam Privacy Policy

## Data Handling
- **Local Processing**: Document templates, file organization, checklist creation.
  All processing on user's Mac only. No cloud upload.
- **API Key Storage**: Keychain only (macOS secure storage, not in app logs)
- **AI Features**: Optional. User connects own Claude/OpenAI/Gemini API key.
  Selected text sent to chosen provider only when user requests.
- **No Third-Party Analytics**: No tracking, no crash reporter, no usage data collection.

## User Control
- Users can delete documents anytime
- No auto-sync or auto-backup to cloud
- Explicit file import only (no auto-watch, no auto-upload)
- All external actions require user approval

## Security
- Sandbox environment (macOS App Sandbox enabled)
- Minimal network access (Claude API + Google Calendar OAuth only)
- No password/token logging
- No automatic external writes
```

**Host this on GitHub or personal site, link in App Store Connect.**

---

## Part 4: Final Checklist Before Submission

```
CODE & BUILD:
  ☐ Release build: xcodebuild ... -configuration Release build (0 errors, 0 warnings)
  ☐ Entitlements linked in Xcode (Build Settings verified)
  ☐ PrivacyInfo.xcprivacy present and correct
  ☐ No debug symbols (Release build)

MANUAL QA:
  ☐ Test 1 (First Launch): PASS
  ☐ Test 2 (Document): PASS
  ☐ Test 3 (File Intake): PASS
  ☐ Test 4 (Safety Blocks): PASS
  ☐ Test 5 (Release Visibility): PASS
  ☐ Test 6 (Finder): PASS

METADATA:
  ☐ Screenshots: 3-5 per language (1280×800 min)
  ☐ Description: ~1800 chars, Korean + English
  ☐ Keywords: 10 relevant terms
  ☐ Privacy Policy: Hosted externally
  ☐ Support URL: GitHub or support page

APP STORE CONNECT:
  ☐ App ID created
  ☐ Team assigned
  ☐ Pricing: Free (or In-App Purchase model)
  ☐ Privacy Nutrition Label: Filled completely
  ☐ Build number: Incremented
  ☐ Availability: All regions or specific (choose in form)

FINAL:
  ☐ App bundleID matches App Store ID
  ☐ Version number (e.g., 1.0.0) matches
  ☐ No external write capability remaining
  ☐ Team notified of submission
```

---

## Part 5: Submission Process (App Store Connect Web)

1. **Log in**: developer.apple.com/account
2. **Apps**: Select MyTeam
3. **Prepare for Submission** tab
4. **Fill all sections:**
   - General Information
   - Pricing & Availability
   - App Information
   - App Preview & Screenshots
   - Description (from metadata doc)
   - Build
5. **Build selection:** Select the Release build you uploaded
6. **Compliance:**
   - Crypto: No
   - Encryption: No
   - Google Analytics: No
7. **Submit for Review**
8. **Wait:** 24-48 hours typically

---

## Known Issues & Workarounds

### Issue: Entitlements Not Linking in Xcode
**Solution:** Verify file exists at `MyTeam/MyTeam.entitlements`, then restart Xcode

### Issue: First Launch Shows Error
**Solution:** Check ~/Library/Application Support/MyTeam/ has write permission
```bash
chmod 755 ~/Library/Application\ Support/MyTeam
```

### Issue: QA Test 3 (PDF Import) Shows Error
**Expected:** This is correct. PDF support is "준비 중" (planned, not implemented)

### Issue: Release Build Slower Than Debug
**Expected:** Release build has optimizations enabled. Normal slowdown.

---

## Success Criteria ✅

- [x] Code passes 12/12 checks (Sandbox, privacy, external write, MainActor)
- [x] Artifacts created (PrivacyInfo.xcprivacy, MyTeam.entitlements)
- [ ] Entitlements linked in Xcode (local step)
- [ ] Manual QA: 6/6 tests PASS (local step)
- [ ] Screenshots: 3-5 per language (local/designer step)
- [ ] Metadata: App Store Connect form filled (web step)
- [ ] Privacy Policy: Externally hosted (web step)
- [ ] Build uploaded: App Store Connect (xcodebuild + upload, local step)
- [ ] Submitted for review: App Store (web step)

---

## Next Steps

1. **Now (Cloud):** ✅ Metadata docs prepared
2. **Local (Xcode):** Link entitlements, build Release
3. **Local (Manual QA):** Run 6 tests, document pass/fail
4. **Local (Screenshots):** Capture 3-5 per language
5. **Web (App Store Connect):** Upload build, fill metadata, submit
6. **Wait:** 24-48 hours for review

**Estimated total time:** 2-3 hours (most is manual QA + screenshots)

---

## Files Reference

- `docs/AppStoreMetadataDraft.md` — Description text (copy-paste)
- `docs/AppStorePackagingChecklist.md` — Technical verification (12-point checklist)
- `docs/AppStoreQAExecutionReport.md` — Code verification results (12/12 PASS)
- `docs/PrivacyPolicy.md` — Privacy policy template (create if needed)
- `MyTeam/MyTeam.entitlements` — Sandbox config (already created)
- `MyTeam/PrivacyInfo.xcprivacy` — App Store privacy declaration (already created)
