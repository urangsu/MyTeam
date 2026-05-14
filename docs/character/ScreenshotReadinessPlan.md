# App Store Screenshot Readiness Plan

## Overview

This document specifies which screens must be production-ready for App Store submission screenshots, and which should be hidden from user-facing materials.

## Required Screenshots for App Store

### Tier 1: Hero Shots (Mandatory)

These are the critical first impressions users see in App Store search results.

#### 1. First Launch with Killer Flow

**What it Shows**:
- Clean onboarding screen
- Chiko as the default team member
- 4 starter action buttons prominently visible
- "회의록·체크리스트·보고서를 빠르게" messaging

**What it Must Contain**:
- [ ] Chiko character sprite (idle pose)
- [ ] First Launch Banner ("로컬 중심으로 시작")
- [ ] 4 Killer Flow action buttons:
  - 회의록 양식 (Meeting Minutes)
  - 체크리스트 (Checklist)
  - 파일 읽기 (File Reading)
  - 오늘 할 일 (Today's Tasks)
- [ ] Clean empty state (no noise/clutter)
- [ ] Logo or app name visible

**Screen Type**: Portrait or landscape (TBD based on design)  
**Resolution**: 2048x1536px or per App Store guidelines  
**What Should NOT Appear**:
- Coming Soon connectors
- Placeholder characters
- Debug toggles
- Disabled Pro buttons
- Error messages or warnings

---

#### 2. Meeting Minutes Artifact Generated

**What it Shows**:
- First artifact successfully created
- Markdown document with meeting notes
- First Result Actions visible (요약, 표, 체크리스트, Finder)
- Clear product value demonstration

**What it Must Contain**:
- [ ] Artifact card with document title
- [ ] Generated meeting minutes content visible
- [ ] 4 next-step action buttons clearly visible:
  - 방금 만든 문서 요약해줘 (Summarize)
  - 표로 바꿔줘 (Table format)
  - 체크리스트로 바꿔줘 (Checklist format)
  - Finder에서 보기 (Open in Finder)
- [ ] Creation timestamp
- [ ] File saved confirmation

**Screen Type**: Portrait or landscape  
**Resolution**: 2048x1536px  
**What Should NOT Appear**:
- Full file system paths
- Raw file hashes
- Network activity indicators
- Loading spinners or transitional states
- Error dialogs

---

#### 3. Local-Only Mode with Chiko

**What it Shows**:
- App works without API keys
- Chiko is the default team member
- Local features available immediately
- No internet required messaging

**What it Must Contain**:
- [ ] Local-only mode card
- [ ] Available features listed:
  - 회의록/체크리스트 (Meeting Minutes/Checklist)
  - 로컬 파일 읽기 (File Reading)
  - 오늘 할 일 (Today's Tasks)
- [ ] Chiko character visible and ready
- [ ] "API key 없이도 사용 가능" messaging
- [ ] Settings link visible ("AI 기능 활성화하기")

**Screen Type**: Portrait or landscape  
**Resolution**: 2048x1536px  
**What Should NOT Appear**:
- "외부 서버 없음" overclaimed language
- "완전 로컬" 
- "내 기기 안에서만"
- Gmail or Calendar connected state
- Pro purchase prompts

---

#### 4. Chiko Team Member Selection

**What it Shows**:
- Chiko as the primary team member
- Team selection interface clean and focused
- Only production-ready characters visible
- Professional appearance

**What it Must Contain**:
- [ ] Chiko character card with:
  - Character sprite (working pose ideally)
  - Name: 치코
  - Description: 문서와 할 일을 정리하는 기본 팀원
- [ ] Clean UI with no placeholder/coming soon cards
- [ ] Professional layout and typography
- [ ] Dark mode appearance (if applicable)

**Screen Type**: Portrait or landscape  
**Resolution**: 2048x1536px  
**What Should NOT Appear**:
- Placeholder character cards (Sena, Kai, Yuna with no sprites)
- "Coming Soon" labels
- Locked/disabled DLC buttons
- Unfinished character gallery
- Debug character list

---

### Tier 2: Supporting Shots (Recommended)

These provide context and depth to the hero shots.

#### 5. Document Summarization

**What it Shows**:
- AI capability demonstrated with local document
- Summary generation workflow
- Clear before/after value

#### 6. Task Briefing

**What it Shows**:
- Daily task aggregation
- "오늘 할 일" feature in action
- Local schedule reading

#### 7. Settings/Configuration

**What it Shows**:
- Clean settings interface
- API key optional (not required)
- No overclaimed privacy language

---

## Screens to HIDE from Marketing

### Never Show in Screenshots

#### 1. Coming Soon Connectors
- Do NOT screenshot Google Calendar "준비 중"
- Do NOT show Gmail metadata "계획 중"
- Do NOT display Naver/미구현 connectors
- **Why**: Misleads users into thinking features exist

#### 2. Placeholder Characters
- Do NOT include Sena, Kai, Yuna with placeholder sprites
- Do NOT show "추가 캐릭터 준비 중" cards
- Do NOT display locked DLC UI
- **Why**: Visual confusion, incomplete product perception

#### 3. Disabled Pro Buttons
- Do NOT screenshot "Pro 구독 준비 중" button
- Do NOT show disabled StoreKit purchase UI
- Do NOT display paywall that doesn't work
- **Why**: User frustration, broken trust

#### 4. Debug UI
- Do NOT include debug toggles visible
- Do NOT show model selection if not user-facing
- Do NOT display verbose diagnostics
- Do NOT show feature flags/settings

#### 5. Raw System Paths
- Do NOT show full file paths: `/Users/su/Desktop/...`
- Do NOT display file hashes or technical IDs
- Do NOT expose directory structure
- **Why**: Privacy, unprofessional appearance

#### 6. Error States
- Do NOT screenshot network errors
- Do NOT show "connector unavailable" messages
- Do NOT display file not found dialogs
- Do NOT screenshot OAuth failures
- **Why**: Negative first impression

#### 7. Placeholder Sprites
- Do NOT use placeholder character images in Release
- Do NOT show "leo_placeholder" visual
- Do NOT display missing sprite fallback UI
- **Why**: App Store review rejection risk

---

## Screenshot Capture Workflow

### 1. Prepare Release Build
```bash
xcodebuild -project MyTeam/MyTeam.xcodeproj \
  -scheme MyTeam \
  -configuration Release \
  build
```

### 2. Verify Clean State
- [ ] No debug toggles visible
- [ ] All character placeholders hidden
- [ ] Disabled buttons not visible
- [ ] No network activity indicators
- [ ] Dark/light mode consistent

### 3. Capture Hero Shots
- [ ] First Launch with Killer Flow
- [ ] Meeting Minutes Artifact
- [ ] Local-Only Mode
- [ ] Team Member Selection

### 4. Resolution & Framing
- [ ] Screenshot at 2048x1536px (if possible)
- [ ] Portrait and landscape both captured
- [ ] UI fully visible (no clipping)
- [ ] Safe margins maintained
- [ ] Retina display quality verified

### 5. Post-Processing
- [ ] Add captions/overlays (if desired, but optional)
- [ ] Verify text readability
- [ ] Check for blurriness or artifacts
- [ ] Match App Store brand guidelines

---

## Release Policy Enforcement

### Before Taking Screenshots

Run diagnostic check:

```swift
// In RuntimeDiagnosticsService or manual QA:
✅ characterPlaceholderHiddenInRelease == true
✅ characterDLCVisibleInRelease == false
✅ disabledProButtonHidden == true
✅ debugToggleHidden == true
✅ connectorPlannedHiddenRelease == true
✅ chikoDefaultCharacterEnabled == true
```

### Build Configuration

Ensure Release mode:
```swift
#if DEBUG
// Debug-only UI visible
#else
// All placeholder/coming-soon hidden
// Disabled buttons filtered
#endif
```

---

## Screenshot Schedule

| Phase | Timeline | Owner | Status |
|-------|----------|-------|--------|
| Design hero shots | By Round 61A-75H | Design Team | Pending |
| Chiko asset finalization | By Round 61A-75H | Design Team | Pending |
| Screenshot capture | By Round 76A | Product Team | Pending |
| App Store copy pairing | Before submission | Marketing | Pending |
| Screenshot localization | Before multi-region launch | L10N Team | Deferred |

---

## Accessibility in Screenshots

- [ ] Text contrast meets WCAG AA standard
- [ ] Color not only differentiator (icons/labels too)
- [ ] Screenshot descriptions written for screen readers
- [ ] Keyboard UI elements visible

---

## App Store Compliance

**Important**: App Store reviewers will examine screenshots for:
- **Completeness**: Don't promise features not visible/functional
- **Accuracy**: Screenshots match actual app behavior
- **Policy**: No overclaimed privacy/data handling
- **Professional**: No debug/placeholder UI

---

**Last Updated**: 2026-05-15  
**Status**: Planning  
**Owner**: Product & Marketing Team  
**Next Review**: Before Round 76A Screenshot Capture
