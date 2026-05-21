# Skill Result Rendering Policy

**Date:** Round 266A-275Z  
**Status:** Active Governance Policy

## Overview

Skill result rendering follows a **strict priority cascade**:
1. **Hardcoded dedicated cards** (spell-check, privacy-terms, diagnostics, accounting-tax)
2. **K-skill assistOnly catch-all** (KSkillAssistCardView for korean.* assistOnly skills)
3. **Generic fallback** (WorkResultCardView with markdown)

This ensures governance-critical skills (accounting-tax, privacy-terms) are never rendered as generic cards, and assistOnly K-skills receive purpose-built formatting.

## Rendering Priority (SkillResultRendererView)

### Level 1: Hardcoded Dedicated Cards

These skills **always** render with dedicated views, even if they output markdown:

```swift
switch skillID {
case "korean.spell-check":
    SpellCheckResultCardView(text: text, isDarkMode: isDarkMode)
case "korean.privacy-terms":
    PrivacyTermsCardView(text: text, isDarkMode: isDarkMode)
case "korean.diagnostics":
    DiagnosticsResultCardView(text: text, isDarkMode: isDarkMode)
case "korean.accounting-tax":
    AccountingTaxSummaryCardView(text: text, isDarkMode: isDarkMode)
```

**Why:** These skills have policy-critical output (legal disclaimers, tax warnings, personal data guidance). Generic rendering would hide essential warnings.

### Level 2: AssistOnly K-Skills Catch-All

If skillID matches `KSkillAssistRuntime.isAssistSkillID(skillID)`:

```swift
case _ where KSkillAssistRuntime.isAssistSkillID(skillID ?? ""):
    KSkillAssistCardView(text: text, skillID: skillID ?? "", isDarkMode: isDarkMode)
```

**Coverage:** korean.dart, korean.law-search, korean.naver-news, korean.ktx-booking, korean.map-place, korean.scholarship, etc.

**Why:** AssistOnly skills produce structured sections (checklist, required inputs, next actions, blocked actions). KSkillAssistCardView parses and renders these sections as purpose-built UI, not generic markdown blobs.

### Level 3: Generic Fallback

All other skills (local character count, workspace docs, etc.):

```swift
default:
    WorkResultCardView(text: text, isDarkMode: isDarkMode)
```

## Rendering Path Example: korean.accounting-tax

**Input:** SkillResultRendererView receives:
```
skillID: "korean.accounting-tax"
text: "## 양도세 계산\n\n...[markdown with sections]..."
isDarkMode: false
```

**Dispatch:**
```
switch skillID {
case "korean.accounting-tax":
    → AccountingTaxSummaryCardView(text:, isDarkMode:)
    ✓ Reaches dedicated card
```

**Result:** Rendered with:
- Accounting-specific styling
- Required disclaimer: "세무·회계 판단은 실제 증빙과 계약 구조에 따라 달라질 수 있으므로 전문가 확인이 필요합니다." (always visible)
- Policy-enforced layout (non-collapsible disclaimer)

---

## Rendering Path Example: korean.naver-news (assistOnly catch-all)

**Input:** SkillResultRendererView receives:
```
skillID: "korean.naver-news"
text: "## 뉴스 검색 안내\n\n### 준비 체크리스트\n☐ ..."
isDarkMode: false
```

**Dispatch:**
```
switch skillID {
case "korean.spell-check": ... (skip)
case "korean.privacy-terms": ... (skip)
case "korean.diagnostics": ... (skip)
case "korean.accounting-tax": ... (skip)
case _ where KSkillAssistRuntime.isAssistSkillID("korean.naver-news"):
    → KSkillAssistCardView(text:, skillID:, isDarkMode:)
    ✓ Reaches assistOnly catch-all
```

**Result:** KSkillAssistCardView:
1. Parses text for "준비 체크리스트", "필요한 입력", "다음에 할 일", "직접 진행이 필요한 작업" sections
2. Renders checklist as `☐ item` bullets (green)
3. Renders required inputs as `▸ item` bullets (blue info box)
4. Renders next actions as `1. step` numbered list
5. Renders hard-blocked actions with `⚠️` prefix (red, always visible)

---

## Rendering Path Example: local-character-count (generic fallback)

**Input:** SkillResultRendererView receives:
```
skillID: "local.character-count"
text: "## 문자 수 분석\n\n총 3,425자입니다."
isDarkMode: false
```

**Dispatch:**
```
switch skillID {
case "korean.spell-check": ... (skip)
case "korean.privacy-terms": ... (skip)
case "korean.diagnostics": ... (skip)
case "korean.accounting-tax": ... (skip)
case _ where KSkillAssistRuntime.isAssistSkillID("local.character-count"):
    // false — local.character-count not in assistOnly list
    (skip)
default:
    → WorkResultCardView(text:, isDarkMode:)
    ✓ Reaches generic fallback
```

**Result:** Markdown rendered as generic card (simple).

---

## Validation Gates

### RuntimeDiagnosticsService.skillRendererPriorityStable

**Purpose:** Confirm hardcoded cases precede catch-all in SkillResultRendererView.

**Check:**
```
Read SkillResultRendererView.swift
Confirm switch statement order:
  1. case "korean.spell-check": ... (hardcoded)
  2. case "korean.privacy-terms": ... (hardcoded)
  3. case "korean.diagnostics": ... (hardcoded)
  4. case "korean.accounting-tax": ... (hardcoded)
  5. case _ where KSkillAssistRuntime.isAssistSkillID(...): ... (catch-all)
  6. default: ... (fallback)
```

**Failure Mode:** If catch-all appears before hardcoded cases, accounting-tax would dispatch to KSkillAssistCardView instead of AccountingTaxSummaryCardView. Diagnostics service flags this as unstable.

### ToolContractValidator.validateSkillRendererPriority()

**Purpose:** Ensure renderer dispatch is governance-safe.

**Enforcement:**
```
confirm(accounting-tax has dedicated card)
confirm(privacy-terms has dedicated card)
confirm(spell-check has dedicated card)
confirm(diagnostics has dedicated card)
confirm(assistOnly dispatch precedes generic fallback)
```

## Switch Statement Order (Immutable)

The order is **critical** and must not be rearranged:

1. **Hardcoded cases first** (4 cases)
   - `case "korean.spell-check"`
   - `case "korean.privacy-terms"`
   - `case "korean.diagnostics"`
   - `case "korean.accounting-tax"`

2. **AssistOnly catch-all** (1 case)
   - `case _ where KSkillAssistRuntime.isAssistSkillID(...)`

3. **Generic fallback** (1 case)
   - `default`

**Violation:** If this order is broken, governance policy fails (accounting-tax could fall through to generic rendering).

## Adding New Dedicated Cards

When a new skill requires dedicated rendering:

1. Create SwiftUI view (e.g., `NewSkillResultCardView.swift`)
2. Register in pbxproj
3. **Add hardcoded case to SkillResultRendererView BEFORE the catch-all:**
   ```swift
   case "new.skill-id":
       NewSkillResultCardView(text: text, isDarkMode: isDarkMode)
   ```
4. Update RuntimeDiagnosticsService: add to `dedicatedSkillCardsReachable` check
5. Update ToolContractValidator: add validator for new skill's policy
6. Build and test: confirm new skill renders with dedicated view, not catch-all or generic

## Future Changes

- Do NOT rearrange switch statement order
- Do NOT add catch-alls before hardcoded cases
- Do NOT move dedicated cards to bottom
- When removing a skill: remove case, update diagnostics, update validators

Violations of these rules indicate accidental regression and should be caught by:
- ToolContractValidator.validateSkillRendererPriority()
- Code review (switch statement order visually checked)
