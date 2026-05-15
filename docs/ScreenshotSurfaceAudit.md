# Screenshot Surface Audit

## App Store Screenshots — Safe To Show

### Screenshot 1: First Launch
**Content**: Empty state + FirstLaunchBannerView  
**Safe**: ✅ Yes
- Shows "로컬 기능은 API key 없이도 사용할 수 있습니다"
- Chiko visible
- No debug info
- No API key field visible (optional)

### Screenshot 2: Starter Actions
**Content**: Starter action buttons (4 buttons)  
**Safe**: ✅ Yes
- "회의록 양식", "체크리스트", "파일 읽기", "오늘 할 일"
- Clear, user-friendly
- Chiko supporting
- No technical jargon

### Screenshot 3: First Result Artifact
**Content**: Meeting minutes draft + FirstResultActionStripView  
**Safe**: ✅ Yes
- Artifact content
- 4 next-step buttons: "요약하기", "표로 바꾸기", "체크리스트로 바꿔줘", "Finder에서 보기"
- Chiko idle/thinking sprite visible
- Professional document appearance

### Screenshot 4: Artifact Transformation
**Content**: Checklist version of same artifact  
**Safe**: ✅ Yes
- Shows transformation workflow
- Checklist UI clear
- No API key, token, or technical details
- Chiko confident/success sprite

### Screenshot 5: Settings + Local Mode
**Content**: SettingsView with LocalOnlyModeCardView  
**Safe**: ✅ Yes
- LocalOnlyModeCardView visible
- List of available features
- No passwords, API keys, or private data
- Optional API key section clearly marked optional

## Do Not Show

### Screenshot ❌: Connector Center
**Reason**: Planned/blocked connectors visible, may confuse users
- Gmail (planned)
- Naver (planned)
- Calendar write (blocked)
Should be hidden until stable/stable

**Solution**: Show "Coming soon" placeholder, not full connector list

### Screenshot ❌: Debug Diagnostics
**Reason**: Technical noise, low user value
- RuntimeDiagnosticsService snapshot
- ToolContractValidator output
- RouteResolver trace
- Action log JSON

**Solution**: Disable debug panel in Release build

### Screenshot ❌: Placeholder Characters
**Reason**: Confuses users, suggests incomplete product
- Skeleton/placeholder roster entries
- "Coming soon" badges on characters
- DLC purchase disabled button

**Solution**: ReleaseVisibleCharacterPolicy hides these automatically

### Screenshot ❌: Disabled Pro Button
**Reason**: Negative messaging, not ready for monetization
- Grayed-out "Pro" or "Premium" button
- Paywall modal (if tapped)
- In-app purchase disabled message

**Solution**: Hide entirely until revenue model finalized

### Screenshot ❌: Raw File Paths
**Reason**: Security concern, low user value
- /Users/.../.../filename.pdf
- ~/.config/MyTeam/...
- Workspace relative paths in UI

**Solution**: Show file names only, not full paths

### Screenshot ❌: Raw Log/Trace
**Reason**: Technical noise
- Action log entries
- Route trace
- Tool execution trace
- Token count

**Solution**: Hide all debug output from Release UI

### Screenshot ❌: Coming Soon Connectors
**Reason**: Premature expectations
- "Gmail" with "Coming soon" badge
- "Naver Mail" with "Coming soon" badge
- Calendar write modal

**Solution**: Don't show connectors until at least beta-ready

### Screenshot ❌: StoreKit Debug Info
**Reason**: May show invalid product SKU or price
- "PRO" product
- "$9.99/month" (if not properly configured)
- Transaction modal

**Solution**: Hide StoreKit entirely until production testing

## Planned Captures

### Capture Plan
Round 96A (Mac Local manual QA) — after build verification:

1. **First Launch** — shows LocalOnlyModeCardView, Chiko idle
2. **Starter Actions** — all 4 buttons clearly visible
3. **First Artifact** — meeting minutes, professional appearance
4. **First Result Actions** — transformation options
5. **Settings** — LocalOnlyModeCardView, optional API key
6. **Artifact in Finder** — shows workspace file in Finder

### Capture Tools
- Macbook Pro screenshot (⌘+Shift+4)
- Crop to standard App Store screenshot dimensions (1080×1440 or equivalent)
- Ensure Retina/2x scaling (no pixel artifacts)

### Caption Strategy
- "Build your meeting minutes instantly"
- "Transform documents in seconds"
- "Works offline, no setup required"
- "Organize your work locally"

## Messaging Alignment

**Do**: Feature-focused, outcome-oriented  
```
✅ "Create meeting minutes from voice/text"
✅ "Organize checklists instantly"
✅ "Work offline, no account needed"
```

**Don't**: Technical, infrastructure-focused  
```
❌ "Local embedding model"
❌ "Zero external API calls"
❌ "macOS 26.2+ required"
❌ "Artifact hash verification"
```

## Privacy Label Alignment

App Store Privacy Nutrition Label:
- Data Linked to User ID: No
- Data Used to Track You: No
- Health & Fitness: No
- Financial Info: No
- Location: No
- Sensitive Info: No
- Contacts: No
- User ID: No
- Device ID: No
- Purchases: No (Pro/Premium deferred)
- Other: Per-provider (user choice)

**Screenshot consistency**: Must not show data collection, ads, or tracking.

## Accessibility Compliance

- Chiko sprite: should be accompanied by text description (alt text)
- Buttons: labels must be readable (not just emoji)
- Colors: sufficient contrast for accessibility

## Status

✅ Safe screenshots identified  
✅ Do-not-show list compiled  
❌ Actual captures: pending Round 96A  
❌ Final approval: pending App Store review  

## Next Phase

Round 96A manual QA:
1. Capture all screenshots above
2. Apply captions
3. Review for privacy/messaging consistency
4. Submit for App Store marketing review
5. Iterate based on feedback
