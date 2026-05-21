# Accounting-Tax Skill Policy

**Date:** Round 266A-275Z  
**Status:** Active Governance Policy  
**Skill ID:** `korean.accounting-tax`  
**Classification:** assistOnly  

## Overview

The accounting-tax skill provides **educational guidance only**—calculation methods, tax rate references, and worked examples. It **never provides professional tax advice**, never executes tax filings, and always includes a legal disclaimer.

## Governance Classification

| Attribute | Value |
|-----------|-------|
| Skill ID | `korean.accounting-tax` |
| Feature Availability | `.assistOnly` (via SkillAvailabilityResolver) |
| Allowed Tool Scope | `.chatBasic` (read-only, no external writes) |
| Banned Permissions | `sendsMessage`, `makesReservation`, `handlesPayment` |
| Rendering | `AccountingTaxSummaryCardView` (dedicated card, hardcoded in SkillResultRendererView) |
| Validation Level | Governance-critical (policy-enforced at compile time) |

## Legal Disclaimer (Immutable)

**Korean Text (exact):**
```
세무·회계 판단은 실제 증빙과 계약 구조에 따라 달라질 수 있으므로 전문가 확인이 필요합니다.
```

**English Translation:**
```
Tax and accounting determinations vary based on actual supporting documents and contract structure, 
so professional verification is required.
```

**Location:** 
- Skill manifest promptTemplate (line: see BuiltInKoreanSkills.swift)
- AccountingTaxSummaryCardView view (line: code comment "Always visible — legal disclaimer (non-collapsible...)")
- User sees disclaimer in both LLM output AND rendered card

**Enforcement:** Disclaimer must appear in:
1. **Skill Prompt** — included in KSkillAssistRuntime.formatMarkdown() output as required section
2. **Card View** — rendered in AccountingTaxSummaryCardView, never collapsible

## Skill Manifest (BuiltInKoreanSkills.accounting-tax)

```swift
static let accountingTaxSkill = SkillManifest(
    id: "korean.accounting-tax",
    name: "세금·세무 계산 참고",
    description: "한국 세금·세무 계산에 대한 참고 정보를 제공합니다. 전문가 의견이 필요한 상황입니다.",
    category: .korean,
    allowedScopes: [.chatBasic],
    permissions: [], // Empty: no external I/O, no sendsMessage/makesReservation/handlesPayment
    riskLevel: .safeReadOnly,
    promptTemplate: """
사용자가 한국 세금·세무 계산 참고 정보를 요청했습니다. 해당 세금의 종류, 세율, 계산 방법, 참고용 계산 결과를 안내하세요. 
반드시 '세무·회계 판단은 실제 증빙과 계약 구조에 따라 달라질 수 있으므로 전문가 확인이 필요합니다'라는 면책 조항을 포함하세요.
""",
    notes: []
)
```

**Key Design:**
- `allowedScopes: [.chatBasic]` — read-only, no external APIs
- `permissions: []` — no external writes allowed (empty list enforces this)
- `riskLevel: .safeReadOnly` — classified as safe read-only operation
- `promptTemplate` includes exact disclaimer text (면책 조항)

## Skill Rendering (AccountingTaxSummaryCardView)

**File:** `MyTeam/AccountingTaxSummaryCardView.swift`

**Code:**
```swift
struct AccountingTaxSummaryCardView: View {
    let text: String
    let isDarkMode: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.title2)
                    .foregroundColor(.cyan)
                Text("세금·세무 계산 참고")
                    .font(.headline)
            }
            
            // Disclaimer (always visible, never collapsible)
            // MARK: - Always visible — legal disclaimer (non-collapsible; removing or wrapping in DisclosureGroup is prohibited)
            disclaimerBox()
            
            // Content
            MarkdownTextView(markdown: text, isDarkMode: isDarkMode)
        }
        .padding()
        .background(isDarkMode ? Color.gray.opacity(0.2) : Color.white)
        .cornerRadius(8)
    }
    
    private func disclaimerBox() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("주의")
                    .font(.headline)
            }
            Text("세무·회계 판단은 실제 증빙과 계약 구조에 따라 달라질 수 있으므로 전문가 확인이 필요합니다.")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(6)
    }
}
```

**Critical Comment:**
```swift
// MARK: - Always visible — legal disclaimer (non-collapsible; removing or wrapping in DisclosureGroup is prohibited)
```

This comment enforces the policy: the disclaimer is **never inside a DisclosureGroup** or any collapsible container. It must always be visible to the user.

## User Guidance Examples

### Example 1: Simple Tax Rate Inquiry

**User:** "양도세율이 얼마야?"

**Expected Output (KSkillAssistRuntime.formatMarkdown):**
```
## 양도세 세율 정보

양도세(資産譲渡稅)는 부동산, 주식 등의 자산을 팔 때 발생하는 세금입니다.
부동산 양도세는 다음과 같이 계산됩니다.

### 준비 체크리스트
☐ 매매 계약서 확인 (계약일, 취득일, 매매가)
☐ 실제 개인 소유 여부 확인

### 필요한 입력
▸ 자산 종류 (부동산, 주식 등)
▸ 취득가격과 매매가격
▸ 보유 기간

### 다음에 할 일
1. 국세청 홈택스 방문
2. "양도소득세" 신청 메뉴 선택
3. 자산 정보 및 취득가 입력
4. 계산 결과 확인

### 직접 진행이 필요한 작업
⚠️ 세무신고: 지정된 납부기한 전에 직접 신고 및 납부
⚠️ 특별공제 신청: 보유 기간에 따른 공제 자격 본인 확인

---

**⚠️ 중요 면책사항**
세무·회계 판단은 실제 증빙과 계약 구조에 따라 달라질 수 있으므로 전문가 확인이 필요합니다.
```

### Example 2: Calculation Verification

**User:** "3억에 샀던 집을 5억에 팔았어. 양도세가 얼마나 돼?"

**Expected Output:**
```
## 양도세 참고 계산

기본 계산 공식: 
(매매가 - 취득가 - 필요경비) × 세율 = 양도세

매매가: 5억 원
취득가: 3억 원
차익: 2억 원
(참고: 필요경비 약 5% 가정 시 차익은 약 1.9억 원)

추정 세율:
- 9년 이상 보유 개인: 약 20% ~ 25%
- 추정 양도세: 약 3,800만 원 ~ 4,750만 원

### 준비 체크리스트
☐ 실제 취득가 증빙서류 (계약서, 등기부등본)
☐ 보유 기간 계산 (매매일 ≠ 신고일)
☐ 감가상각 여부 확인 (아파트는 없음)

### 필요한 입력
▸ 정확한 계약일
▸ 실제 취득 시 필요경비 증거
▸ 임대료 수입 여부

### 다음에 할 일
1. 세무사 상담 예약
2. 취득가 증빙서류 준비
3. 세무사와 함께 신고서 작성
4. 온라인 신고 또는 세무서 방문

### 직접 진행이 필요한 작업
⚠️ 세무신고: 반드시 세무사 또는 전문가와 함께 진행
⚠️ 납부: 납부기한 내 정부포탈(국세청) 또는 은행 납부

---

**⚠️ 중요 면책사항**
세무·회계 판단은 실제 증빙과 계약 구조에 따라 달라질 수 있으므로 전문가 확인이 필요합니다.
```

## Validation Gates

### 1. ToolContractValidator.validateAssistOnlyNeverExecutesExternalWrite()

**Check:** korean.accounting-tax must not have banned permissions.

```swift
let skill = getSkill("korean.accounting-tax")
assert(!skill.permissions.contains(.sendsMessage))
assert(!skill.permissions.contains(.makesReservation))
assert(!skill.permissions.contains(.handlesPayment))
```

**Failure:** Build rejects skill if any banned permission present.

### 2. ToolContractValidator.validateAccountingTaxDisclaimerAlwaysVisible()

**Check:** Disclaimer text present in file and never collapsible.

```swift
let fileContent = readFile("MyTeam/AccountingTaxSummaryCardView.swift")
assert(fileContent.contains("면책"))
assert(fileContent.contains("전문가 확인"))
assert(!fileContent.contains("DisclosureGroup { ... disclaimerBox")) // Not collapsible
```

**Failure:** Build reports missing or collapsible disclaimer.

### 3. RuntimeDiagnosticsService.accountingTaxDisclaimerAlwaysVisible

**Check:** File exists and contains disclaimer.

```
accountingTaxDisclaimerAlwaysVisible = 
  fileExists("AccountingTaxSummaryCardView.swift") &&
  fileContent.contains("면책사항") &&
  fileContent.contains("항상 표시")
```

### 4. ToolContractValidator.validateSkillRendererPriority()

**Check:** accounting-tax has dedicated card in SkillResultRendererView.

```swift
let rendererContent = readFile("MyTeam/SkillResultRendererView.swift")
assert(rendererContent.contains("""
    case "korean.accounting-tax":
        AccountingTaxSummaryCardView(...)
"""))
```

**Failure:** If hardcoded case missing, accounting-tax falls through to generic rendering (governance failure).

## Future Changes (Restricted)

- ✅ Add more example user messages to promptTemplate
- ✅ Localize disclaimer to additional languages (always include exact Korean disclaimer + translation)
- ❌ Remove disclaimer or make it collapsible
- ❌ Add sendsMessage or makesReservation permissions
- ❌ Change rendering from AccountingTaxSummaryCardView to generic card
- ❌ Move disclaimer text to optional/collapsible section

Any violation of the "restricted" items requires governance review.

## Policy Compliance Checklist

Before releasing accounting-tax skill to users:

- [ ] Skill manifest includes exact Korean disclaimer in promptTemplate
- [ ] AccountingTaxSummaryCardView renders disclaimer in warning box
- [ ] Disclaimer never inside DisclosureGroup or collapsible container
- [ ] Code comment "Always visible — legal disclaimer (non-collapsible...)" present
- [ ] SkillResultRendererView has hardcoded case for korean.accounting-tax BEFORE catch-all
- [ ] ToolContractValidator includes validateAccountingTaxDisclaimerAlwaysVisible()
- [ ] RuntimeDiagnosticsService.accountingTaxDisclaimerAlwaysVisible computes correctly
- [ ] RouterBurnInSuite includes test case: "세금 계산 도와줘" → korean.accounting-tax
- [ ] Build succeeds with 0 warnings (xcodebuild check)
- [ ] QA manual test: ask "양도세 계산해줘" → confirm disclaimer visible in output
