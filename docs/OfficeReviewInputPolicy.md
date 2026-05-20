# Office Review Input Policy

**Round 243A-OBSERVE** — 사무 검토 입력 정책

---

## 지원 입력 타입

| 타입 | 상태 |
|---|---|
| PDF | 지원 |
| CSV / 스프레드시트 | 지원 |
| 텍스트 (.txt, .md) | 지원 |
| 붙여넣기 표 | 지원 |
| 코드 파일 | 지원 |
| 이미지 | 계획 (다음 라운드) |
| Word (.docx) | 계획 |
| 프레젠테이션 (.pptx) | 계획 |

---

## 사무 검토 Skill 목록

| Skill ID | 이름 | 주요 입력 |
|---|---|---|
| office-review.accounting-consistency | 계정과목 정합성 검토 | CSV, PDF, 텍스트 |
| office-review.vendor-name-mismatch | 거래처명 불일치 검토 | CSV, PDF |
| office-review.budget-actual-analysis | 예산/실적 차이 분석 | CSV, PDF |
| office-review.invoice-description-anomaly | 전표 설명 이상치 찾기 | CSV, PDF |
| office-review.tax-invoice-comparison | 세금계산서/거래명세서 비교 | PDF, CSV |
| office-review.contract-checklist | 계약서 체크리스트 | PDF, Word, 텍스트 |
| office-review.meeting-action-items | 회의록 액션아이템 추출 | 텍스트, 마크다운, PDF |
| office-review.filename-organization | 파일명 정리 | 텍스트, 마크다운 |
| office-review.report-tone-polish | 보고서 말투 정리 | 텍스트, 마크다운, Word |

---

## 결과 카드 구조

```
ReviewResultCard
├── summary        검토 요약 (1-2줄)
├── issues[]       발견 이슈 (severity: critical/warning/info)
│   ├── description   이슈 내용
│   └── evidence      근거 (파일의 어느 부분인지)
├── recommendedActions[]  권장 조치
└── nextActions[]         다음 액션
```

---

## Skill 선택 로직

자연어 메시지에서 키워드 감지 → OfficeReviewInputPolicy.suggestSkill()

예:
- "계정과목" → accountingConsistency
- "거래처" → vendorNameMismatch
- "예산" + "실적" → budgetActualAnalysis
- "계약서" → contractChecklist
- "회의록" → meetingActionItems

---

## 제약

- 외부 write 없음 — 결과는 artifact로만 생성
- 파일 원문 저장 금지 — 검토 결과와 요약만 보존
- 민감 정보(계좌/개인정보) 감지 시 사용자 경고
