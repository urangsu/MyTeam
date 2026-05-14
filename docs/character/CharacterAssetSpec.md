# Character Asset Specification

## Overview

This document defines the visual and technical requirements for all MyTeam character assets.

## Required Asset Set Per Character

Every production-ready character must include:

- **Idle Sprite**: Default neutral state, character at rest or thinking
- **Working Sprite**: Character actively processing or responding
- **Success Sprite**: Character happy/completed state after successful task
- **Thinking Sprite**: Character in thought process (optional but recommended)
- **Small Icon**: 64x64 or 128x128 for character roster/gallery UI
- **App Store Screenshot Pose**: Optimized pose for marketing materials

## Technical Format Requirements

### Image Format
- **Primary**: PNG with transparent background (RGBA)
- **Fallback**: WebP for web contexts (not used in macOS app currently)
- **Color Space**: sRGB or Display P3
- **Transparency**: Full alpha channel support

### Size Specification

- **1x Scale**: Reference size for macOS app (typical screen density)
- **2x Scale**: For retina displays and future-proofing
- **Minimum Size**: 256x256px (sprite) / 64x64px (icon)
- **Recommended Size**: 512x512px (sprite) / 128x128px (icon)
- **Maximum Size**: 2048x2048px per asset (file size optimization)

### Layout Consistency

- **Baseline Alignment**: All sprites must align to same baseline for consistent team lineup
- **Canvas Padding**: Minimum 10% canvas padding on all sides for safe area
- **No Text Baking**: Never embed text or labels in character images
- **Shadow/Glow**: Consistent lighting direction across all character poses

## Style Direction

### Visual Tone
- **Friendly but work-focused**: Approachable personality without cartoon childishness
- **Professional context**: Fits macOS productivity app ecosystem
- **Neutral color palette**: Adaptable to dark/light mode
- **Consistent line weight**: If outline style, maintain consistent stroke width

### Design Principles
- **Readable at small size**: Must remain identifiable at 64x64px icon size
- **Scalable design**: Works at all specified sizes without aliasing
- **Unique silhouette**: Easily distinguishable from other team members
- **Expression clarity**: Facial expressions clear even at small scale

### Dark/Light Mode Support
- **High contrast**: Legible against both white and black backgrounds
- **No color dependency**: Characters should read even in grayscale
- **Tinted backgrounds** optional: Semi-transparent backing color can help contrast

## Chiko Requirements (Priority: v1.0)

Chiko must be complete first as the default team member:

- **Idle**: Character at rest, friendly expression, ready to help
- **Working**: Character focused, possibly typing or processing
- **Success**: Character happy, thumbs up or celebration pose
- **Small Icon**: Chiko's face or profile for UI
- **App Store Pose**: Chiko in prime working position for hero shot

### Chiko Character Brief
- **Role**: Document and task organization specialist
- **Personality**: Helpful, organized, efficient
- **Visual**: Modern, approachable, professional
- **Color Accent**: Based on CharacterCatalog.swift (check `chiko.color`)

## Future Characters (After Chiko)

The following characters are planned but visual assets are deferred:

| Character | Role | Asset Status | DLC Status |
|-----------|------|--------------|-----------|
| Sena | App Launch PM | Hidden in Release | Not purchasable |
| Kai | Code Review Architect | Hidden in Release | Not purchasable |
| Yuna | Content Strategist | Hidden in Release | Not purchasable |
| Others | Various roles | Deferred | Deferred |

**Policy**: No character is shown in Release or marked purchasable until all assets are production-ready.

## Asset Delivery Format

### File Naming Convention
```
{character_name}_{pose}_{scale}.png
```

Examples:
- `chiko_idle_1x.png`
- `chiko_idle_2x.png`
- `chiko_working_1x.png`
- `chiko_success_2x.png`
- `chiko_icon_128x128.png`
- `chiko_appstore_hero.png`

### Directory Structure
```
assets/characters/
├── chiko/
│   ├── sprite/
│   │   ├── chiko_idle_1x.png
│   │   ├── chiko_idle_2x.png
│   │   ├── chiko_working_1x.png
│   │   ├── chiko_working_2x.png
│   │   ├── chiko_success_1x.png
│   │   ├── chiko_success_2x.png
│   │   └── chiko_thinking_1x.png (optional)
│   ├── icon/
│   │   ├── chiko_icon_64x64.png
│   │   └── chiko_icon_128x128.png
│   └── marketing/
│       └── chiko_appstore_hero.png
├── sena/ (hidden until ready)
├── kai/ (hidden until ready)
└── yuna/ (hidden until ready)
```

## Quality Checklist

Before considering a character asset production-ready:

- [ ] All required poses created (idle, working, success minimum)
- [ ] All sizes provided (1x, 2x, icon, app store)
- [ ] Baseline alignment verified with other team members
- [ ] Dark and light mode contrast verified
- [ ] 64x64px size legibility confirmed
- [ ] No transparency issues or anti-aliasing artifacts
- [ ] File sizes optimized (PNG compression applied)
- [ ] Named correctly per convention
- [ ] Stored in correct directory structure
- [ ] Asset loading verified in CharacterGalleryView
- [ ] No broken image fallbacks during load
- [ ] Marketing pose approved by design/product team

## Integration with Code

Assets are referenced in:

- **CharacterCatalog.swift**: Asset paths and metadata
- **SpriteAgentView.swift**: Sprite rendering logic
- **CharacterGalleryView.swift**: Character display and selection
- **Character.swift**: Character model with asset bindings

When adding new assets, update these files in order:
1. Add files to `/assets/characters/` directory
2. Update CharacterCatalog with asset paths
3. Test in CharacterGalleryView
4. Add to DLC gating policy if applicable

## Release Policy

### v1.0 (Current)
- Only Chiko assets visible
- Chiko must have all required poses
- No character DLC buttons visible

### v1.1+ (Planned)
- Add 2-3 additional character assets
- Test DLC purchase flow
- Evaluate visual consistency across team

---

**Last Updated**: 2026-05-15
**Status**: Active
**Owner**: Design & Product Team
