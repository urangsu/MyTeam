# KTX/SRT 예매 Assist Safety Policy

**Round:** 249A-KSKILLS-ASSIST  
**Status:** 구현 완료 (cloud + local, 2026-05-21)

---

## 핵심 안전 원칙

KTX/SRT 예매 도우미(`korean.ktx-booking`)는 다음 4가지를 **절대 수행하지 않는다**:

### 1. 자동 로그인 대행 금지
- Korail / SRT 계정 로그인을 대신 수행하지 않는다
- 아이디/비밀번호를 요청하거나 저장하지 않는다
- OTP, 캡차, 생체인증 우회를 시도하지 않는다

### 2. 자동 좌석 예매 확정 금지
- 사용자 대신 좌석을 선택하거나 예약 버튼을 누르지 않는다
- 대기표 신청, 취소표 알림을 자동 실행하지 않는다
- 예매 결과를 꾸며내거나 "예매 완료" 상태를 가정하지 않는다

### 3. 결제 정보 처리 금지
- 카드 번호, 계좌, 포인트 잔액을 요청하거나 처리하지 않는다
- 결제 승인, 취소, 환불을 대신 처리하지 않는다

### 4. 캡차 우회 금지
- 자동 캡차 풀기, 봇 우회 시도를 하지 않는다

---

## 실제 제공 기능

| 제공 | 미제공 |
|------|--------|
| 예매 전 체크리스트 작성 | 실시간 잔여 좌석 조회 |
| 출발·도착역, 날짜, 시간 조건 정리 | 자동 예매 실행 |
| 할인·특가 조건 안내 | 결제 대행 |
| 환불·변경 규정 요약 | 로그인 대행 |
| 코레일/SRT 앱 접속 안내 | - |

---

## 기술 구현

```swift
// KSkillAssistRuntime.buildAssistResponse(intent: .ktxBookingAssist, ...)
hardBlockedActions: [
    "자동 로그인 대행",
    "자동 좌석 예매 확정",
    "결제 정보 처리",
    "캡차 우회"
]
```

- `ToolContractValidator.validateKTXNoAutoBookingPolicy()` 가 이 목록을 런타임 검증
- `KSkillAssistCardView`의 빨간 경고 박스에 항상 표시 (절대 숨기지 않음)

---

## 관련 파일

- `MyTeam/KSkillAssistRuntime.swift` — `.ktxBookingAssist` case
- `MyTeam/KSkillAssistCardView.swift` — 카드 렌더링 (hardBlockedSection)
- `MyTeam/SkillAvailabilityResolver.swift` — `"korean.ktx-booking"` → `.assistOnly`
- `MyTeam/ToolContractValidator.swift` — `validateKTXNoAutoBookingPolicy`
