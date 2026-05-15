# Character Roster Plan

## Overview

This document defines which characters are visible at each product stage and the policies governing character visibility, DLC, and role adoption.

## v1.0 Visible Characters

### Chiko (Production-Ready)

**Status**: Visible in Release  
**Visual Status**: Full asset set available  
**DLC Status**: Not purchasable (built-in default)

- **ID**: `char.builtin.chiko`
- **Role**: Document and task organization specialist
- **Primary Use Cases**:
  - Meeting minutes generation
  - Checklist creation
  - Task briefing
  - Document summarization
  - File organization
- **Default Character**: Yes (always shown first)
- **Skill Set**: 
  - korean.naver-blog-research
  - (future: document analysis, task intelligence)

**Visual Appearance**:
- Sprite: Available (placeholder currently, full asset pending)
- Icon: Available for UI
- Expression: Friendly, professional, approachable
- Color Accent**: Primary (see CharacterCatalog.swift)

**Positioning**:
```swift
name: "치코",
subtitle: "문서와 할 일을 정리하는 기본 팀원",
description: "회의록, 체크리스트, 오늘 할 일 정리에 강합니다."
```

---

## Hidden Characters (Deferred to Future Releases)

### Sena (App Launch PM)

**Status**: Hidden in Release  
**Visual Status**: Placeholder sprite in code (NOT shown to users)  
**DLC Status**: Not purchasable yet

- **ID**: `char.premium.sena`
- **Role**: Application launch PM
- **Primary Workflows**:
  - App Store submission checklist
  - Privacy policy & terms drafting
  - Onboarding copy creation
  - Revenue & monetization planning
  - Marketing copy review
- **Intended Product ID**: ProductIDCatalog.Character.sena
- **Intended Price**: ₩3,900

**Status in Release Policy**:
- Premium character marked `isPremium: true`
- Premium character marked `isComingSoon: true`
- Hidden in CharacterGalleryView Release mode
- DLC purchase button NOT visible

**Visibility Gates**:
- `CharacterGalleryView`: Filtered in Release
- `SettingsView`: Deferred Premium tab
- `ProductIDCatalog`: Listed but gated
- `CharacterDLC`: Deferred until assets ready

---

### Kai (Code Review Architect)

**Status**: Hidden in Release  
**Visual Status**: Placeholder sprite (NOT shown to users)  
**DLC Status**: Not purchasable yet

- **ID**: `char.premium.kai`
- **Role**: Code review & architecture specialist
- **Primary Workflows**:
  - Code review feedback generation
  - Architecture assessment
  - Performance bottleneck identification
  - Swift/macOS quality guidance
  - Technical debt analysis
- **Intended Product ID**: ProductIDCatalog.Character.kai
- **Intended Price**: ₩3,900

**Status in Release Policy**: Same as Sena (hidden, not purchasable)

---

### Yuna (Content Strategist)

**Status**: Hidden in Release  
**Visual Status**: Placeholder sprite (NOT shown to users)  
**DLC Status**: Not purchasable yet

- **ID**: `char.premium.yuna`
- **Role**: Content strategy & SEO specialist
- **Primary Workflows**:
  - Naver Blog content planning
  - SEO keyword strategy
  - Thumbnail copy optimization
  - Content calendar management
  - Publishing rhythm guidance
- **Intended Product ID**: ProductIDCatalog.Character.yuna
- **Intended Price**: ₩3,900

**Status in Release Policy**: Same as Sena and Kai (hidden, not purchasable)

---

## DLC Gate Policy

### Current Release: No DLC Active

**Rule**: No character is purchasable until **all conditions** are met:

1. ✅ Production sprite asset available (idle, working, success, icon)
2. ✅ Role-specific workflows implemented in app
3. ✅ App Store screenshot visual asset ready
4. ✅ DLC product ID tested in StoreKit sandbox
5. ✅ In-app purchase flow verified end-to-end
6. ✅ Restore purchase verified for all platforms

**Current Status**:
- Chiko: Condition 1-6 pending (full asset production)
- Sena: Condition 1-6 not met
- Kai: Condition 1-6 not met
- Yuna: Condition 1-6 not met

### Hidden in Release

Characters not meeting all 6 conditions:

- **CharacterGalleryView**: Filtered from `CharacterCatalog.all` in Release
- **SettingsView**: Premium characters tab not visible
- **DLC Buttons**: Never shown for incomplete characters
- **ProductID**: Listed in code but gated in purchase flow

### Code Pattern

```swift
#if DEBUG
let visibleCharacters = CharacterCatalog.all
#else
let visibleCharacters = CharacterCatalog.builtIn + 
                        CharacterCatalog.premium.filter { $0.isProductionReady }
#endif
```

---

## Character Adoption Workflow

### Phase 1: Asset Production
- [ ] Chiko sprite set finalized
- [ ] Baseline alignment verified
- [ ] Dark/light mode testing complete
- [ ] App Store hero pose approved

### Phase 2: Role Implementation (Sena Example)
- [ ] Sena-specific prompt persona finalized
- [ ] App Store specific tool workflows
- [ ] Privacy terms skill fully implemented
- [ ] Checklist & submission tool linked
- [ ] Agent personality tested in sandbox

### Phase 3: DLC & Store

- [ ] ProductIDCatalog entry verified
- [ ] StoreKit sandbox purchase tested
- [ ] Restore purchase verified
- [ ] App Store metadata uploaded
- [ ] Price set and approved

### Phase 4: Release

- [ ] Asset filtering tested in Release build
- [ ] DLC purchase button gated correctly
- [ ] No placeholder sprites visible
- [ ] Character team screen visually polished
- [ ] Manual QA passed

---

## Built-in vs. Premium

### Built-in Characters
- Always visible
- No purchase required
- Included in app bundle
- Default experience

### Premium Characters (DLC)
- Hidden until assets ready
- Purchase required to unlock
- Downloaded post-purchase
- Optional advanced roles

---

## Future Expansion (v1.1+)

### Candidate Characters
```
| Name | Role | Status |
|------|------|--------|
| Others (TBD) | Various | Planning phase |
| ... | ... | ... |
```

When adding new characters:

1. Create character entry in CharacterCatalog
2. Design sprite asset set (see CharacterAssetSpec.md)
3. Implement role-specific workflows
4. Test in DEBUG mode first
5. Gate in Release mode until ready
6. Follow 6-condition DLC gate policy

---

## Policy Exceptions

**None**: All characters must meet all 6 DLC conditions before Release visibility.

**Rationale**: 
- Placeholders confuse users
- Incomplete DLC disappoints
- Consistency across team is visual/UX requirement
- Better to be hidden and surprise-launch than show broken state

---

## Testing Checklist

Before marking any character `isProductionReady = true`:

- [ ] CharacterGalleryView shows character correctly
- [ ] Character responds to Chiko prompts (no errors)
- [ ] Sprite does not have aliasing/quality issues at all sizes
- [ ] Dark mode contrast verified
- [ ] Light mode contrast verified
- [ ] Character roster screen visually balanced
- [ ] No broken placeholder references
- [ ] StoreKit purchase flow (if DLC)
- [ ] Restore purchase (if DLC)
- [ ] Asset filenames match code references
- [ ] Directory structure clean and organized

---

**Last Updated**: 2026-05-15  
**Status**: Active  
**Owner**: Product & Design Team
