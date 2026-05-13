# App Store Packaging Checklist

> Round 40A-40D — Mac App Store 제출 전 최종 하드닝
> sandbox / entitlement / privacy policy / 첫 실행 / 에러 처리 재점검

---

## 1. Sandbox Policy

**Status**: code-reviewed / build-confirmed / manual QA pending

### Sandbox Enabled
- [x] App Sandbox enabled in entitlements
- [x] no arbitrary external file access
- [x] workspace directory only (~/Library/Application Support/MyTeam/)
- [x] no /tmp, /var, system directories

### File Access Scoping
- [x] ArtifactStore workspace-relative path only
- [x] external path traversal (../) blocked
- [x] absolute path read-only, no storage
- [x] Finder open → workspace path only
- [x] path copy → user action only (不 automatic)
- [x] file intake read failure → graceful error (no crash)

### Destructive Action Policy
- [x] file delete: blocked entirely
- [x] file move: blocked
- [x] file rename: blocked
- [x] auto-cleanup: dry-run only
- [x] user confirmation required for any workspace cleanup

---

## 2. Entitlements & Capability Declarations

**Status**: code-reviewed / build-confirmed

### Current Entitlements
```
com.apple.security.app-sandbox = YES
com.apple.security.files.user-selected.read-write = YES
com.apple.security.network.client = YES
com.apple.security.temporary-exception.sbpl = (Calendar OAuth specific)
```

### Network Access Reason
- Google Calendar OAuth (read-only)
- No other external network services

### File Access Declaration
- workspace directory (read/write)
- user-selected documents (file picker only)
- no system/app directories

### No Unnecessary Entitlements
- [x] no `com.apple.security.automation.with-user-interaction`
- [x] no `com.apple.security.cs.disable-library-validation`
- [x] no camera/microphone/location entitlements

---

## 3. Privacy & Data Collection Policy

**Status**: code-reviewed / build-confirmed

### Data Handling
- [x] no raw action log input in diagnostics
- [x] no sourceText persistence across sessions
- [x] no API token / auth code / password in logs
- [x] no user workspace file content in logs (metadata only)
- [x] memory write guard: active

### Release Build Diagnostics
Show (Release-safe):
- Tool layer status (enabled/disabled)
- Artifact availability (count only, no content)
- Memory guard status (active/inactive)
- External write policy status
- Connector limitation status
- Last workflow status (success/failure, no details)

Hide (Release suppression):
- raw route trace
- tool input summary
- sourceText
- full file paths
- model IDs / model selection history
- connector API internals
- internal error codes
- debug-only buttons (PlanRunner, model picker, model override)

### AI / Model Policy
- [x] Release model pinned (Claude 3.5 Sonnet or fallback)
- [x] model override: hidden in Release
- [x] dynamic model discovery: disabled in Release
- [x] API key missing state: handled gracefully with user guidance

### Privacy Manifest
- [x] PrivacyInfo.xcprivacy present
- [x] NSLocalNetworkUsageDescription: "Not used"
- [x] NSBonjourServiceTypes: empty
- [x] Network reason: Calendar OAuth
- [x] Data collection: Diagnostics (anonymized, no PII)
- [x] No third-party SDKs with tracking

---

## 4. External Connectors & Capabilities

**Status**: code-reviewed / deferred (live OAuth QA separate)

### Google Calendar
- [x] read-only status confirmed
- [x] OAuth scope minimal (calendar.readonly)
- [x] OAuth client ID: deferred until Desktop Client setup
- [x] live QA: separate from App Store submission

### Gmail API
- [x] NOT implemented
- [x] label: "준비 중" or "연결 예정" (not "connected")
- [x] must not appear as functional to user
- [x] no misleading UI

### Calendar Write
- [x] NOT implemented
- [x] blocked in capability policy
- [x] user message: "일정 추가는 준비 중입니다"

### Other External Services
- [x] no mail send capability
- [x] no external upload capability
- [x] no auto-login
- [x] no destructive external actions

---

## 5. StoreKit & In-App Purchase

**Status**: code-reviewed / build-confirmed / manual QA pending

### Current Status
- [x] StoreKit framework linked (but not active in this round)
- [x] entitlement present and unchanged
- [x] no implementation changes this round
- [x] purchase QA: deferred (separate from App Store submission)

### Restrictions
- [x] no auto-purchase logic
- [x] no purchase without user action
- [x] no paywall gating active
- [x] purchase flow tested separately before launch

---

## 6. File & Artifact Management

**Status**: code-reviewed / build-confirmed / manual QA pending

### Workspace Path Policy
- [x] all artifact paths relative to ~/Library/Application Support/MyTeam/
- [x] ArtifactStore.normalized(relativePath:) applied to all new paths
- [x] no absolute path storage (legacy entries migrated)
- [x] path validation on load (invalid paths skipped)

### File Intake Policy
- [x] txt, md, csv: ready (display in settings)
- [x] pdf, docx, xlsx, pptx: labeled "준비 중" (not functional)
- [x] sh, app, pkg, exe: blocked entirely
- [x] file read failure: clear user message, no stack trace

### Artifact Persistence
- [x] workspace registration confirmed (not external)
- [x] filename sanitization (no special chars)
- [x] Finder open via workspace URL (not hardcoded path)
- [x] no empty file (0-byte) artifacts

### Cleanup Policy
- [x] dry-run only (no automatic deletion)
- [x] RecentArtifactIndex compaction: safe removal of stale entries
- [x] user confirmation: required for any cleanup

---

## 7. Runtime Safety & Error Handling

**Status**: code-reviewed / build-confirmed / manual QA pending

### First Launch State
User sees:
```
"설정에서 API 키를 연결하거나, 로컬 파일/문서 기능부터 사용할 수 있습니다."
(Connect API key in Settings, or start with local file/document features)
```

Implementation:
- [x] AIService.evaluateAPIKeyAvailability() called early
- [x] no LLM call without valid key
- [x] SettingsView shows API key input
- [x] local file operations work without API key

### No Network State
User sees:
```
"네트워크 연결이 없어 AI 응답은 제한됩니다. 로컬 파일/문서 기능은 계속 사용할 수 있습니다."
(No network: AI features limited. File/document work continues.)
```

Implementation:
- [x] network status checked before LLM call
- [x] graceful fallback to local-only mode
- [x] no crash on network timeout
- [x] retry UI optional (not forced)

### Google OAuth Not Configured
User sees:
```
"Google 캘린더 연결 준비 중입니다."
(Google Calendar integration in development)
```

NOT shown:
- [x] complex OAuth flow to general users
- [x] "missing credentials" error
- [x] developer-facing setup instructions
- [x] broken/red state indicators

### Missing Model or TTS
User sees:
```
"AI 응답 생성 중..." (with graceful fallback or silent disable)
```

NOT shown:
- [x] model ID or version
- [x] TTS engine name
- [x] codec/format details
- [x] download progress if model unavailable

---

## 8. Blocked Operations (must not execute)

**Status**: code-reviewed / build-confirmed

### Email / External Write
- [x] "메일 보내줘" → blocked with message
- [x] no mail body draft
- [x] no mailto: URL triggered
- [x] ToolExecutor returns .blocked status

### Calendar / External Events
- [x] "일정 만들어줘" → blocked
- [x] "캘린더에 추가해줘" → blocked
- [x] "예약 잡아줘" → blocked
- [x] no calendar API call attempted

### File System Destructive
- [x] "파일 삭제해줘" → blocked
- [x] "폴더 비워줘" → blocked
- [x] "정렬해줘" (move/organize) → blocked
- [x] no automatic cleanup

### External Upload
- [x] "외부 사이트에 올려줘" → blocked
- [x] no HTTP POST to unknown domains
- [x] no S3/Drive/Box integration attempted

### Auto-Approval Actions
- [x] requiresApproval capability: NOT executed automatically
- [x] no auto-login with stored credentials
- [x] no silent signature on documents
- [x] no unconfirmed scheduled tasks

---

## 9. Startup & Termination Safety

**Status**: code-reviewed / build-confirmed

### App Launch
- [x] RecentArtifactIndex decode failure → empty index, app continues
- [x] ArtifactStore index decode failure → safe fallback
- [x] API key missing → no-key state, local features enabled
- [x] TTS model missing → TTS disabled or audio fallback
- [x] no force unwrap, try!, fatalError

### App Termination
- [x] TTS task cancellation (Qwen3TTSService)
- [x] audio playback stop (AudioPlaybackService)
- [x] active workflow task cancellation
- [x] pending network requests abort
- [x] graceful shutdown, no hanging processes

### Crash Prevention
- [x] MainActor isolation fixed (all 6 warnings resolved)
- [x] no deadlock in concurrent task cancellation
- [x] no nil-coalescing crash in diagnostics
- [x] no index out of bounds in artifact compaction

---

## 10. Manual QA Checklist (Before Submission)

**Status**: manual QA pending

### First Launch
- [ ] App starts fresh (no artifacts)
- [ ] Settings view opens, API key field visible
- [ ] "로컬 파일/문서 기능부터 사용할 수 있습니다" message clear
- [ ] no error dialogs

### Artifact Workflow
- [ ] Create document artifact (e.g., "검토보고서 만들어줘")
- [ ] Artifact appears in ArtifactCard
- [ ] Finder open: correct file opens
- [ ] Path copy: pasteboard contains workspace-relative path
- [ ] Recent artifact reuse: works correctly next message

### File Intake
- [ ] Text file import: works
- [ ] Markdown import: works
- [ ] CSV import: works
- [ ] PDF, DOCX, XLSX: labeled "준비 중" (not functional)
- [ ] App/shell file import: blocked

### Safety Operations
- [ ] "메일 보내줘" → blocked message only
- [ ] "일정 만들어줘" → blocked message only
- [ ] "파일 삭제해줘" → blocked message only
- [ ] "외부 사이트에 올려줘" → blocked message only
- [ ] no tool execution, no crashes

### Release Visibility
- [ ] Debug toggles hidden (no PlanRunner button)
- [ ] Model override hidden (no model picker)
- [ ] Verbose diagnostics hidden
- [ ] RuntimeDiagnosticsService Release-only view correct
- [ ] SettingsView shows appropriate Release info

### Multi-Room Isolation
- [ ] Room A long workflow starts
- [ ] Room B quick action executes
- [ ] Room A continues independently (not cancelled)
- [ ] Room B completes normally

---

## 11. Before Final Submission

**Status**: manual QA pending

- [ ] Release build: xcodebuild ... -configuration Release build (0 app code warnings)
- [ ] App Store Connect metadata: all fields complete
- [ ] Privacy nutrition label: reviewed and accurate
- [ ] Screenshots & description: reviewed
- [ ] Version number & build number: incremented
- [ ] Entitlements: unchanged from last review
- [ ] PrivacyInfo.xcprivacy: all required declarations present
- [ ] External write: confirmed blocked
- [ ] OAuth scopes: minimal (calendar.readonly only)
- [ ] no auto-approval, no auto-login, no auto-upload
- [ ] team members notified of submission status

---

## Success Criteria ✅

✅ Sandbox policy: tight, workspace-only file access  
✅ Entitlements: minimal, no unnecessary permissions  
✅ Privacy: no tokens/auth/raw logs, diagnostics minimized  
✅ External write: completely blocked (mail/calendar/delete/upload)  
✅ First launch: clear guidance on API key + local features  
✅ No-key state: graceful fallback, no crashes  
✅ Network error: graceful handling, local features continue  
✅ Release visibility: debug UI hidden, verbose logs suppressed  
✅ App code warnings: 0 (all 6 MainActor issues resolved)  
✅ Startup/termination: safe, no deadlocks or crashes  
⏳ Manual QA: pending (first-launch, Finder, file intake, multi-room, artifact reuse)  
✅ Build-ready: YES  
⏳ Submission-ready: NOT YET — manual QA required before submission
