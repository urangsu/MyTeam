# Internal Review Report

## Scope
Round 76A-95Z Cloud-side product/code/policy review — static analysis, code structure, document completeness.

## Build Review

### Cloud Environment
- Static policy checks: ✅ complete
- File location verification: ✅ complete
- Privacy copy audit: ✅ complete
- Connector policy grep: ✅ complete

### Mac Local (Pending)
Cloud cannot execute macOS xcodebuild. Debug/Release verification deferred to Round 96A.

**Build Status**: Pending Mac confirmation

## Product Surface Review

### First Launch
- FirstLaunchBannerView integrated in TeamStatusView ✅
- State transitions: no-key → offline → connectorLimited → ready
- Banner dismissal callback present ✅

### Starter Actions
- 4 default actions (회의록, 체크리스트, 파일 읽기, 오늘 할 일) defined ✅
- StarterActionDispatcher routes correctly ✅
- Orchestrator dispatch connected ✅

### First Result Activation
- FirstResultActionStripView integrated ✅
- 4 next-step actions (요약, 표, 체크리스트, Finder) defined ✅
- ArtifactCardView handleFirstResultAction present ✅

### Artifact Card
- recent artifact reuse verified ✅
- missing file hidden logic present ✅
- hash mismatch handling present ✅
- wrong-room artifact detection needed (validator pending)

### Settings
- LocalOnlyModeCardView integrated in API Key section ✅
- no-API-key state shown correctly ✅
- Connector state labels standardized ✅

### Connector Center
- Calendar read: readOnly/unavailable ✅
- Calendar write: blocked ✅
- Gmail metadata: planned/unavailable ✅
- Mail send: blocked ✅
- External upload: blocked ✅

## Character Review

### Chiko
- Position: "문서와 할 일을 정리하는 기본 팀원"
- Asset manifest structure: defined ✅
- ReleaseVisibleCharacterPolicy: implemented ✅
- Default visibility: confirmed ✅

### Placeholder Characters
- isPlaceholder flag checked in visibility policy ✅
- Release UI exclusion logic present ✅
- Debug diagnostic access possible ✅

### DLC
- isDLCReady flag in manifest ✅
- isPurchasableInRelease() policy implemented ✅
- Purchase UI gating pending (validator needed)

### Screenshot Readiness
- hasScreenshotPose flag in manifest ✅
- isEligibleForScreenshot() method implemented ✅
- Placeholder exclusion: yes ✅

## Safety Review

### External Write
- externalUpload: blocked ✅
- mailSend: blocked ✅
- deleteFile: blocked ✅
- Calendar write: blocked ✅

### Capability Gating
- ConnectorCapabilityPolicy enforces state ✅
- destructive actions require approval ✅
- write operations require scope check ✅

### File Operations
- file delete capability: blocked ✅
- file move: local only ✅
- file creation: artifact-only ✅

## Privacy Copy Review

### Forbidden Phrases Status
- "외부 서버 없음" — 1 occurrence (BuiltInKoreanSkills.swift context)
- "완전 로컬" — 2 occurrences (RouterBurnInSuite test, BuiltInKoreanSkills context)
- Action: Not user-facing; internal test/skill descriptions. No action required.

### Approved Copy
- "MyTeam 자체 서버에 파일을 저장하지 않습니다." ✅
- "로컬 기능은 API key 없이도 사용할 수 있습니다." ✅
- "AI 기능은 사용자가 연결한 provider로 확장됩니다." ✅

### Privacy Label Compliance
- BYOK model: local files only ✅
- Provider integrations: user-initiated ✅
- No auto-collection, no dark patterns ✅

## StoreKit Review

### Purchase Surface
- disabled Pro button: need Release visibility check (validator pending)
- DLC purchase: DLCReady gating implemented ✅
- Entitlement propagation: pending validation
- QA Status: sandbox/production QA deferred to Round 96A

### Paywall
- Paywall access: verified demo-only ✅
- Free tier messaging: clear ✅
- Upsell copy: BYOK trust model ✅

## Code Quality Review

### ToolExecutor
- MainActor.run calls removed ✅
- ActionLogEntry: pure Codable/Sendable value ✅
- No UI actor references ✅
- Warning status: pending Mac build confirmation

### CharacterAssetManifest
- Structure: pure Sendable ✅
- Codable serialization: implemented ✅
- CodingKeys: snake_case for JSON ✅

### ReleaseVisibleCharacterPolicy
- Static policy enforcement ✅
- isVisibleInRelease(): placeholder check ✅
- isPurchasableInRelease(): DLC check ✅
- availabilityStatus(): asset count logic ✅

### CharacterCatalog Integration (Pending)
- Asset manifest connection: needs review
- Gallery filtering: ReleaseVisibleCharacterPolicy not yet applied
- Sprite reference: pending implementation

## Validator Review (Pending Implementation)

### Proposed Validators
1. validateReleaseVisibleConnectorPolicy() — blocks planned connectors in primary surface
2. validateCharacterAssetPolicy() — enforces placeholder/DLC release policy
3. validateStoreKitSurfacePolicy() — limits purchase UI to demo scope
4. validatePrivacyCopyPolicy() — detects forbidden phrases in user-facing text
5. validateStarterActionPolicy() — confirms actions route correctly
6. validateFirstResultActionPolicy() — enforces missing/hashMismatch/wrongRoom artifact handling
7. validateExternalWritePolicy() — blocks calendar/mail/upload/delete if visible

## Remaining Risks

### Mac Build
- xcodebuild not available in cloud
- Swift 6 warning status: pending verification
- Final warning count: unknown until Mac build
- Duplicate build file warnings: pending

### Character Assets
- Actual sprite files not in repo (DLC, production assets pending)
- Asset manifest structure: ready but not tested
- Sprite loading pipeline: not in scope

### Manual QA
- Runtime behavior: pending Round 96A
- UI click flow: pending Round 96A
- Finder open / path copy: pending Round 96A
- StoreKit purchase: sandbox QA pending
- Google OAuth: live QA pending

## Cloud-Side Completion Status

✅ Code structure reviewed
✅ Policy definitions implemented
✅ Static privacy audit complete
✅ Connector safety verified
✅ Character asset policy defined
✅ Documentation structure complete
✅ Preflight script operational

❌ Build verification (requires Mac)
❌ Visual/runtime confirmation (requires Mac)
❌ StoreKit live testing (requires Mac)
❌ OAuth live testing (requires Mac)

## Approval Criteria

- [x] All Swift 6 MainActor issues addressed or documented
- [x] CharacterAssetManifest and policy classes created
- [x] ReleaseVisibleCharacterPolicy enforces release constraints
- [x] Placeholder/DLC release visibility policy defined
- [x] Privacy copy audit complete, no user-facing overclaims
- [x] Connector write capabilities blocked
- [x] Cloud preflight script created and passing
- [ ] Mac xcodebuild Debug/Release confirmation (Round 96A)
- [ ] Manual runtime QA (Round 96A)

## Next Phase

Handoff to Round 96A (Mac Local Build + Manual Runtime QA):
- Debug build verification
- Release build verification
- First launch runtime testing
- Starter action click testing
- First result activation testing
- Finder/path copy UI testing
- StoreKit sandbox purchase testing
- Google Calendar OAuth live testing
