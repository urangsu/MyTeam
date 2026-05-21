# KSkills Assist Runtime Policy

**Round:** 249A-KSKILLS-ASSIST / 250A-255Z UX  
**Status:** 구현 완료 (cloud + local, 2026-05-21)

---

## 정책 요약

KSkillAssistRuntime은 다음 원칙에 따라 동작한다:

1. **절대 금지 (Hard Blocked)**: 자동 예매·결제·로그인·투자매수·법률자문 확정
2. **항상 표시**: hardBlockedActions 섹션은 응답 카드에서 절대 숨기지 않는다
3. **가상 API 조회 금지**: "현재 시세 조회 중..." / "DART 검색 결과:" 등 실제 조회한 척 금지
4. **체크리스트 우선**: 모든 응답은 사용자가 직접 취해야 할 단계 목록을 제공한다
5. **로컬 처리 전용**: 외부 API 연결 없이 LLM 지식과 사용자 입력으로만 동작

---

## 지원 인텐트 (11개)

| Intent | skillID | 차단 항목 |
|--------|---------|----------|
| KTX/SRT 예매 도우미 | `korean.ktx-booking` | 자동 로그인, 자동 예매 확정, 결제 정보, 캡차 우회 |
| 장소·예약 준비 | `korean.map-place` / `korean.reservation-preparation` | 자동 예약 확정, 결제 정보, 개인정보 제출 |
| 주가 정보 | `korean.stock-info` | 매수/매도 확정 추천, 수익 보장, 투자자문 확정 |
| DART 공시 | `korean.dart` | 실제 DART API 조회한 척, 투자자문 확정 |
| 뉴스 리서치 | `korean.naver-news` | 실시간 검색 결과 꾸며내기, 원문 없는 기사 인용 |
| 블로그 리서치 | `korean.naver-blog-research` | 순위·최신성 꾸며내기, 원문 없는 후기 생성 |
| 법령·정부정보 | `korean.law-search` | 법률 자문 확정, 최신 법령 조회한 척, 판례 꾸며내기 |
| 장학금·복지급여 | `korean.scholarship` | 지원 가능 여부 확정, 최신 공고 단정 |
| 사무 검토 | `korean.office-review-assist` | 원본 파일 자동 수정, 외부 업로드 |
| 파일·이미지 | `korean.file-image-assist` | 파일 외부 업로드, 자동 삭제 |

---

## UX 렌더링 규칙

- `SkillResultRendererView` → `KSkillAssistRuntime.isAssistSkillID()` → `KSkillAssistCardView`
- 체크리스트: 녹색 checkbox 아이콘
- 필요한 정보: 파란색 info 박스
- 다음 단계: 번호 목록
- **직접 대신하지 않는 항목**: 빨간 경고 박스 (항상 표시, DisclosureGroup 사용 금지)

---

## 변경 이력

| Date | Round | Change |
|------|-------|--------|
| 2026-05-21 | 249A | KSkillAssistRuntime 최초 구현 (11 intents) |
| 2026-05-21 | 250A-255Z | KSkillAssistCardView (structured rendering), RouterBurnInSuite (7 cases) |
