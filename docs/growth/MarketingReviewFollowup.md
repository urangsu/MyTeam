# MarketingReviewFollowup
**Round 76A-95Z 이후 마케팅 copy 후속 조치**
**작성일**: 2026-05-15
**기준**: MarketingReviewAcceptanceMatrix.md v1.0 → Round 76 감사 완료 후

---

## 1. Round 76 감사에서 확인된 사항

### 1.1 금지 표현 제거 완료

아래 표현들이 Swift 소스에서 전부 제거 또는 교체되었다:

| 제거된 표현 | 발견 위치 | 교체 표현 |
|---|---|---|
| "완전 로컬로 계산한다" | `BuiltInKoreanSkills.swift` L101 | "로컬에서 계산한다" |
| "완전 로컬로 계산하세요" | `BuiltInKoreanSkills.swift` L109 | "기기 내에서 계산하세요" |
| "완전 로컬 처리" | `RouterBurnInSuite.swift` notes | "로컬 처리 (기기 내 계산)" |
| "완전 로컬 처리" | `DEVLOG.md` | "기기 내 로컬 처리" |

### 1.2 승인된 표현 (TruthfulPrivacyCopyPolicy 기준)

이 표현들은 마케팅 copy에서 사용 가능하다:

- ✅ "로컬 중심으로 작동합니다"
- ✅ "MyTeam 자체 서버에 파일을 저장하지 않습니다"
- ✅ "API key 없이도 사용할 수 있습니다"
- ✅ "사용자 provider로 확장할 수 있습니다"
- ✅ "AI 기능은 사용자가 선택한 provider를 통해 동작합니다"

---

## 2. App Store 마케팅 copy 후속 액션

### 2.1 완료된 항목

| 항목 | 상태 |
|---|---|
| Privacy 금지 표현 Swift 소스 제거 | ✅ |
| AppStoreMetadataDraft.md 초안 존재 | ✅ |
| PrivacyNutritionDraft.md 초안 존재 | ✅ |
| TruthfulPrivacyCopyPolicy.md 정책 정의 | ✅ |
| MarketingReviewAcceptanceMatrix.md 기준 정립 | ✅ |

### 2.2 남은 항목

| 항목 | 우선순위 | 담당 |
|---|---|---|
| App Store 스크린샷 캡처 (치코 기반) | P0 — Round 96A | Visual Asset |
| App Store 설명문 최종 교정 | P1 | Copy Review |
| 네이버 SEO 랜딩 페이지 — 금지 표현 검토 | P2 | SEO |
| 마케팅 소재(배너/SNS) Privacy 표현 검토 | P2 | Design |

---

## 3. 캐릭터 노출 기준 마케팅 적용

### 3.1 v1.0 출시 시 노출 가능 캐릭터

- **치코** (기본 캐릭터) — App Store 스크린샷, 랜딩 페이지, SNS에 노출 가능
- 기타 캐릭터 — DLC 준비 전 `isComingSoon` 처리 → "Coming Soon" 표시만 허용

### 3.2 DLC 마케팅 규칙

- DLC 구매 버튼: `ReleaseVisibleCharacterPolicy.isDLCPurchasable` = true인 캐릭터만 노출
- v1.0 기준: 구매 가능 캐릭터 0명 → DLC 구매 CTA 없음
- Coming Soon 예고 컨텐츠는 허용 (구체적 출시일 약속 금지)

---

## 4. Privacy 마케팅 가이드라인 요약

### 4.1 AI 기능 설명 시

```
❌ "AI가 내 기기에서만 실행됩니다"
❌ "서버에 데이터가 가지 않습니다"
✅ "AI 기능은 사용자가 선택한 provider API를 통해 처리됩니다"
✅ "파일은 MyTeam 자체 서버에 저장되지 않습니다"
```

### 4.2 로컬 기능 설명 시

```
❌ "완전 로컬 AI"
❌ "모든 기능이 오프라인에서 작동"
✅ "글자 수 계산, 맞춤법 검사는 기기 내에서 처리됩니다"
✅ "인터넷 없이도 사용 가능한 기능: 글자 수, 맞춤법, 텍스트 변환"
```

---

## 5. 다음 마케팅 마일스톤

| 마일스톤 | 조건 | 예상 시기 |
|---|---|---|
| App Store 스크린샷 업로드 | 치코 모든 스프라이트 완성 (Round 96A) | Round 96A 완료 후 |
| DLC 캐릭터 예고 공개 | 1개 캐릭터 이상 DLC 준비 완료 | TBD |
| 랜딩 페이지 오픈 | v1.0 App Store 심사 통과 후 | TBD |

---

*이 문서는 마케팅 copy 가이드라인 준수 추적 문서입니다. 실제 광고 집행 전 법무/마케팅 팀 교차 검토 필요.*
