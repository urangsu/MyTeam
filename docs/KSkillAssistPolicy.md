# K-Skill Assist-Only Policy

**Date:** Round 266A-275Z  
**Status:** Active Governance Policy

## Overview

K-skills classified as `assistOnly` are constrained to explain, summarize, prepare, and guide. They **never execute external writes** (booking, payment, deletion, email, calendar, upload, file modification).

## Governed Skills (12 Total)

| Skill ID | Classification | Governed By |
|----------|----------------|-------------|
| `korean.dart` | assistOnly | SkillAvailabilityResolver.availability() |
| `korean.law-search` | assistOnly | SkillAvailabilityResolver.availability() |
| `korean.naver-news` | assistOnly | SkillAvailabilityResolver.availability() |
| `korean.naver-blog-research` | assistOnly | SkillAvailabilityResolver.availability() |
| `korean.ktx-booking` | assistOnly | SkillAvailabilityResolver.availability() |
| `korean.map-place` | assistOnly | SkillAvailabilityResolver.availability() |
| `korean.reservation-preparation` | assistOnly | SkillAvailabilityResolver.availability() |
| `korean.stock-info` | assistOnly | SkillAvailabilityResolver.availability() |
| `korean.scholarship` | assistOnly | SkillAvailabilityResolver.availability() |
| `korean.office-review-assist` | assistOnly | SkillAvailabilityResolver.availability() |
| `korean.file-image-assist` | assistOnly | SkillAvailabilityResolver.availability() |
| `korean.accounting-tax` | assistOnly | SkillAvailabilityResolver.availability() |

## Validation Gates

### 1. ToolContractValidator.validateAssistOnlyNeverExecutesExternalWrite()

**Purpose:** Block compiletime if any assistOnly skill has banned permissions.

**Banned Permissions:**
- `SkillPermission.sendsMessage`
- `SkillPermission.makesReservation`
- `SkillPermission.handlesPayment`
- (and any I/O write operations in manifest)

**Enforcement:**
```
For each skill in enabledSkills:
  If skill.id in assistOnlySkillIDs:
    Assert skill.permissions does not contain sendsMessage
    Assert skill.permissions does not contain makesReservation
    Assert skill.permissions does not contain handlesPayment
```

**Failure Mode:** Reports policy violation; prevents skill from being enabled.

### 2. RuntimeDiagnosticsService.assistOnlyGovernanceEnabled

**Purpose:** Runtime diagnostic that confirms assistOnly list populated.

**Check:**
```
assistOnlySkillIDs.count >= 11
```

**Default:** true (computed from SkillAvailabilityResolver)

### 3. ToolContractValidator.validateNoExternalExecutionFromAssistSkills()

**Purpose:** Ensure assistOnly skills route only to markdown generation, never to external APIs.

**Enforcement:**
```
For each assistOnly skill:
  Confirm KSkillAssistIntent maps skill → formatMarkdown() path
  Confirm no direct API execution (DART, law-search, booking APIs all blocked)
```

## Response Format (KSkillAssistRuntime.formatMarkdown)

All assistOnly skill responses **must** include these sections in Korean:

### Header
```
## [Intent-Specific Title]
[Explanation message]
```

### Four Structured Sections (always present)

1. **준비 체크리스트** (`☐ item` bullets)
   - Verification items user must check before proceeding
   
2. **필요한 입력** (`▸ item` bullets)
   - Required information from user to proceed
   
3. **다음에 할 일** (numbered `1. step` bullets)
   - Step-by-step actions user takes (not AI)
   
4. **직접 진행이 필요한 작업** (`⚠️ item` bullets)
   - Actions AI cannot perform (always visible, never collapsible)

**Example:** See `docs/KSkillAssistPolicy.md#Example-Response` below.

## KSkillAssistCardView Rendering

When `SkillResultRendererView` detects assistOnly skill ID:
1. Route to `KSkillAssistCardView(text:, skillID:, isDarkMode:)`
2. Parse all 4 sections from markdown
3. Render with skill-specific icon + teal/cyan header
4. **Critical:** Hard-blocked actions section never inside `DisclosureGroup` (always visible)

## Lifecycle

- **Availability Decision:** `SkillAvailabilityResolver.availability(for:)` returns `.assistOnly`
- **LLM Prompt:** Skill manifest includes exact user guidance in promptTemplate
- **Runtime:** `KSkillAssistRuntime.formatMarkdown()` produces structured sections
- **Rendering:** `SkillResultRendererView` dispatches to `KSkillAssistCardView`
- **Validation:** `ToolContractValidator` confirms no external writes

## Example Response

**Intent:** korean.ktx-booking  
**User Message:** "KTX 예매하는 방법 알려줘"

**Output Structure (from KSkillAssistRuntime.formatMarkdown):**

```
## KTX/SRT 예매 준비

KTX와 SRT는 공식 홈페이지(www.letskorail.com) 또는 앱을 통해 예매합니다. 
자동 예매는 지원하지 않으나, 예매 전 확인 사항과 체크리스트를 정리해드릴 수 있습니다.

### 준비 체크리스트
☐ 출발역/도착역 결정
☐ 탈승 예정 날짜와 시간 확인
☐ 예매 가능한 회원 정보 확인

### 필요한 입력
▸ 출발역 이름
▸ 도착역 이름
▸ 예매 예정 날짜

### 다음에 할 일
1. www.letskorail.com 방문 또는 앱 실행
2. 로그인
3. 출발지/도착지/날짜 입력
4. 열차 선택 및 좌석 예약

### 직접 진행이 필요한 작업
⚠️ 결제: 신용카드, 계좌이체 등 본인 선택으로 진행
⚠️ 예매 최종 확정: 웹사이트/앱에서 직접 클릭하여 예약
```

## Enforcement Timeline

- **Build:** Validators run at compile-time; build fails if assistOnly skill has banned permissions
- **Runtime:** Diagnostics confirm policy state; used by QA to verify governance
- **Render:** CardView enforces hard-blocked actions always visible (never collapsible)

## Future Additions

When new assistOnly skills are added:
1. Add skill ID to `SkillAvailabilityResolver` switch/case
2. Add skill ID to `assistOnlySkillIDs` set (auto-computed)
3. Add intent mapping in `KSkillAssistIntent` enum (if supporting dedicated card)
4. Ensure promptTemplate includes exact user guidance + section headers
5. Run validators; build will reject if policy violated
