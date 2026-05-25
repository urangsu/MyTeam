# App Store Connect Field Mapping

**Purpose**: Ready-to-copy metadata values for App Store Connect submission form  
**Last Updated**: 2026-05-25  
**Status**: Ready for submission

---

## Instructions

1. Log in to [App Store Connect](https://appstoreconnect.apple.com/)
2. Select your app (MyTeam)
3. Navigate to **Prepare for Submission** tab
4. Fill each field exactly as shown below
5. Mark each as complete when done

---

## Required Fields (All Languages)

### English (Primary)

#### 1. App Name
**Field**: "App Name" (max 30 characters)
**Value**: 
```
MyTeam
```

#### 2. Subtitle
**Field**: "Subtitle" (max 30 characters)
**Value**: 
```
Create documents faster with AI
```

#### 3. Description
**Field**: "Description" (max 4000 characters)
**Value**: 
```
MyTeam is your AI work team inside your Mac. Create meeting minutes, checklists, and reports quickly. Organize files, analyze documents, and manage your daily tasks.

**Core Features:**
• Document generation - Meeting minutes, checklists, reports from templates
• File organization - Drag files to analyze and organize
• Today's briefing - Local schedule and task list
• Artifact reuse - Quick access to previously created documents
• Local-first - No API key needed for core features. Data stays on your Mac
• Flexible AI - Connect your own Claude, OpenAI, or Gemini API key

**What you control:**
• Documents are saved locally (~/Library/Application Support/MyTeam/)
• API keys stored in macOS Keychain (encrypted, never logged)
• No automatic actions - emails, calendar events, file deletion blocked
• Explicit file selection only - no auto-watch or auto-upload
• You delete files, you delete them (no auto-cleanup)

**Privacy first:**
- Local features work without internet or API keys
- AI features only use text you explicitly request analysis for
- Google Calendar integration (read-only, if enabled)
- No tracking, no analytics, no crash reporters
- Full privacy policy in app

**System Requirements:**
macOS 12.0 or later, Apple Silicon or Intel

Version 1.0: Initial release with local documents, file management, and optional AI assistance
```

#### 4. Keywords
**Field**: "Keywords" (10 items, max 100 chars per item)
**Value** (copy as comma-separated):
```
AI assistant, meeting minutes, productivity, task management, document creation, file organization, checklist, report generator, AI writing tool, Mac productivity
```

#### 5. Support URL
**Field**: "Support URL"
**Value**:
```
https://github.com/urangsu/MyTeam
```

#### 6. Privacy Policy URL
**Field**: "Privacy Policy URL" (must be externally hosted)
**Value**:
```
https://github.com/urangsu/MyTeam/blob/main/docs/PrivacyPolicy.md
```

(Note: You may need to host this on a personal website if GitHub URLs are not accepted. Alternative: Create a docs site or use GitHub Pages)

---

### Korean (Secondary Language)

#### 1. App Name (Korean)
```
MyTeam - AI 업무 팀
```

#### 2. Subtitle (Korean)
```
회의록·체크리스트·보고서를 빠르게
```

#### 3. Description (Korean)
```
내 컴퓨터 안의 AI 업무 팀. MyTeam은 회의록, 체크리스트, 보고서 초안을 빠르게 만들고 파일을 정리하는 macOS 업무 보조 앱입니다.

**핵심 기능:**
• 문서 생성 - 회의록, 체크리스트, 보고서 템플릿으로 빠르게 작성
• 파일 정리 - 파일을 드래그해서 분석 및 정리
• 오늘 할 일 - 로컬 일정 및 할 일 목록
• 최근 문서 재사용 - 이전에 만든 문서를 빠르게 접근
• 로컬 우선 처리 - API 키 없이 로컬 기능 사용. 내 Mac에서만 처리
• AI 선택 가능 - Claude, OpenAI, Gemini API 키를 직접 연결하여 사용

**당신이 통제합니다:**
• 문서는 로컬에만 저장 (~/Library/Application Support/MyTeam/)
• API 키는 macOS Keychain에 저장 (암호화, 로그 없음)
• 자동 실행 없음 - 메일 발송, 일정 생성, 파일 삭제 차단
• 명시적 파일 선택만 - 자동 감시나 자동 업로드 없음
• 파일 삭제는 사용자가 직접 - 자동 정리 없음

**개인정보 보호:**
- 로컬 기능은 인터넷이나 API 키 없이 작동
- AI 기능은 사용자가 명시적으로 분석을 요청한 텍스트만 전송
- Google 캘린더 통합 (읽기 전용, 선택사항)
- 추적 없음, 분석 없음, 크래시 리포터 없음
- 전체 개인정보 보호정책은 앱에 포함

**시스템 요구사항:**
macOS 12.0 이상, Apple Silicon 또는 Intel

버전 1.0: 로컬 문서, 파일 관리 및 선택적 AI 지원 포함 초기 출시
```

#### 4. Keywords (Korean)
```
AI어시스턴트, 회의록, 생산성, 할일관리, 문서생성, 파일정리, 체크리스트, 보고서생성, AI작성도구, 업무효율화
```

---

## Metadata Section: App Information

### Age Rating
**Field**: "Age Rating"
**Value**: `4+` (No restricted content)

### Category
**Field**: "Primary Category"
**Value**: `Productivity`

**Field**: "Secondary Category" (optional)
**Value**: `Utilities`

### Content Rights
**Field**: "Content Rights"
**Value**: `○ This app does not contain any of the following...` (select if applicable)

---

## Metadata Section: Pricing & Availability

### Pricing Tier
**Field**: "Pricing Tier"
**Value**: `Free`

### Availability
**Field**: "Availability"
**Value**: `All current and future territories` 
(or select specific regions if preferred)

### Release Date
**Field**: "Automatic Release" or "Manual Release"
**Value**: Choose based on your schedule

---

## Metadata Section: Privacy

### Privacy Nutrition Label

**All sections must be filled before submission:**

#### Data Collected (should show "Data NOT Collected")
- [ ] Contact Info: Not collected
- [ ] Health & Fitness: Not collected
- [ ] Financial Info: Not collected
- [ ] Location: Not collected
- [ ] Sensitive Info: Not collected
- [ ] Contacts: Not collected
- [ ] User ID: Not collected
- [ ] Device ID: Not collected
- [ ] Product Interaction: Not collected
- [ ] Search History: Not collected
- [ ] Browser History: Not collected
- [ ] Diagnostics: Not collected
- [ ] Precise Location: Not collected

#### Network Activity (Required)
**Link Purposes:**
```
✓ Claude API - For optional AI features only
✓ Google Calendar - For optional calendar integration (read-only)
- No tracking or advertisement
- No third-party SDKs
```

#### Tracking
- [ ] Tracking Enabled: **NOT selected** (we don't track)

#### Data Linked to User
- Data NOT linked to user identity

#### Data Shared with Third Parties
- Data NOT shared with third parties (only API providers user explicitly chooses)

#### Data Retention
- Data retained only as long as needed for service provision

---

## Screenshots

### Required Resolutions
- **1280 × 800** (required, landscape)
- **1920 × 1200** (optional, 5K display)

### File Format
- PNG or JPG
- RGB color space (not CMYK)

### Recommended Screenshots (3-5 per language)

**Screenshot 1: Main Workflow**
- Filename: `myteam-en-1280x800-1.png` (English) / `myteam-ko-1280x800-1.png` (Korean)
- Shows: Chat interface + artifact card
- Caption (optional): "Create documents with AI"

**Screenshot 2: File Organization**
- Filename: `myteam-en-1280x800-2.png` / `myteam-ko-1280x800-2.png`
- Shows: File import + analysis
- Caption: "Drag files to organize"

**Screenshot 3: Settings & Features**
- Filename: `myteam-en-1280x800-3.png` / `myteam-ko-1280x800-3.png`
- Shows: Settings view with API key option
- Caption: "Local features + optional AI"

---

## Build Information

### Version Number
**Field**: "Version"
**Value**: `1.0.0` (or next version number)

### Build Number
**Field**: "Build"
**Value**: `1` (increment for each submission attempt)

### Minimum OS Requirement
**Field**: "macOS"
**Value**: `12.0 or later`

---

## Submit for Review

### Pre-Submission Checklist
- [ ] All required fields completed
- [ ] Screenshots uploaded (3-5 per language)
- [ ] Privacy Nutrition Label filled
- [ ] Build number incremented
- [ ] Version number correct
- [ ] App includes privacy policy
- [ ] Entitlements linked in Xcode

### Compliance Questions
1. **"Does your app use encryption?"** 
   - Answer: `No` (network encryption is transparent HTTPS)

2. **"Does your app contain, require, or use cryptography or encryption?"**
   - Answer: `No`

3. **"Do you have Export Compliance approval from Apple?"**
   - Answer: `No` (if app uses only standard TLS)

### Click "Submit for Review"
- Estimated review time: 24-48 hours
- You'll receive email notifications

---

## After Submission

### Monitoring
1. Check App Store Connect regularly for review status
2. Check email for review results
3. If rejected, address feedback and resubmit

### If Approved
- App appears on App Store
- Share with users
- Monitor ratings and feedback
- Plan next update cycle

---

## Troubleshooting

### Common Issues

**Issue**: "Privacy Policy URL not accessible"
- **Solution**: Host on personal website or GitHub Pages (ensure publicly accessible)

**Issue**: "Entitlements mismatch"
- **Solution**: Verify MyTeam.entitlements is linked in Xcode Build Settings

**Issue**: "Screenshot resolution incorrect"
- **Solution**: Re-capture at exactly 1280×800 (not 1280×799 or 1280×801)

**Issue**: "Build rejected - MainActor warnings"
- **Solution**: Rebuild in Release mode, verify 0 warnings

---

## Files Reference

| Document | Purpose |
|----------|---------|
| `docs/PrivacyPolicy.md` | Full privacy policy (copy & host externally) |
| `docs/AppStoreConnectSubmissionGuide.md` | Complete submission walkthrough |
| `docs/AppStorePackagingChecklist.md` | Technical compliance verification |
| `docs/AppStoreMetadataDraft.md` | Detailed metadata descriptions |
| `MyTeam/MyTeam.entitlements` | Sandbox configuration |
| `MyTeam/PrivacyInfo.xcprivacy` | Privacy manifest |

---

**Submission Status**: Ready for local execution  
**Last Verified**: 2026-05-25 (23/23 cloud checks PASS)
