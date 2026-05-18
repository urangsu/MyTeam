# Connector Readiness Plan
**기준**: Round 236 | 2026-05-17  
**원칙**: read-only부터 단계적 테스트. write는 구현하지 않는다.

---

## 원칙 요약

| 원칙 | 내용 |
|------|------|
| Read-only 우선 | 읽기 기능부터 안전하게 구현하고 테스트한다 |
| Write 차단 | 메일 발송, 캘린더 생성/수정/삭제, 파일 삭제는 구현하지 않는다 |
| 연결 상태 투명 | 토큰 없음/만료/미연결 상태를 사용자에게 명확하게 표시한다 |
| 승인 필요 읽기 | 메일 본문 읽기 등 민감 정보는 사용자 승인 후 진행한다 |
| 사용자 친화 문구 | "IMAP 기반 read-only 검토 중" 같은 개발 문구는 사용자 화면에 노출 금지 |

---

## Google Calendar

### 현재 상태
- ❌ OAuth client ID 미설정
- ❌ read-only skeleton 없음
- 🚫 write (일정 생성/수정/삭제) — 구현하지 않음

### 단계별 구현 계획

| 단계 | 내용 | 조건 |
|------|------|------|
| 1. Settings UI | "Google 연결" 버튼 + 연결 상태 표시 | OAuth client ID 확보 후 |
| 2. OAuth flow | read-only scope 요청 (`.readonly`) | client ID 있을 때 |
| 3. Token 저장 | Keychain에 저장 (UserDefaults 금지) | OAuth 완료 후 |
| 4. 일정 목록 읽기 | 오늘/이번 주 일정 조회 | Token 있을 때 |
| 5. 일정 표시 | AgentChatView 또는 WorkroomHome에 카드 표시 | read 완료 후 |

### 사용자-facing 상태 메시지

| 상태 | 표시 문구 |
|------|----------|
| 미연결 | "Google 캘린더를 연결하면 오늘 일정을 확인할 수 있어요." |
| 토큰 만료 | "Google 연결이 끊어진 것 같아요. 다시 연결해드릴까요?" |
| 읽기 가능 | "오늘 일정 {N}건을 가져왔어요." |
| 쓰기 요청 | "일정 만들기는 현재 지원하지 않아요. 읽기만 가능해요." |

### 차단 항목 (구현 금지)
- `calendar.events.insert`
- `calendar.events.update`
- `calendar.events.delete`
- `calendar.events.patch`

---

## Gmail

### 현재 상태
- ❌ OAuth client ID 미설정
- ❌ metadata read skeleton 없음
- 🚫 메일 발송 (send) — 구현하지 않음

### 단계별 구현 계획

| 단계 | 내용 | 조건 |
|------|------|------|
| 1. Metadata read | 제목, 발신자, 날짜만 조회 (본문 없음) | OAuth read scope |
| 2. 본문 read | 승인 후 진행 (단일 메일, 민감 정보 주의) | 사용자 명시 승인 |
| 3. 첨부 파일 | 지원하지 않음 | — |
| 4. 발송 | 구현하지 않음 | 🚫 |

### 사용자-facing 상태 메시지

| 상태 | 표시 문구 |
|------|----------|
| 미연결 | "Gmail을 연결하면 중요 메일을 확인할 수 있어요." |
| 본문 읽기 요청 | "이 메일 내용을 읽으려면 확인이 필요해요. 진행할까요?" |
| 발송 요청 | "메일 보내기는 현재 지원하지 않아요." |

### 차단 항목 (구현 금지)
- `gmail.send`
- `gmail.modify` (레이블 수정)
- `gmail.compose`
- 첨부 파일 다운로드 (자동)

---

## Naver (메일/캘린더)

### 현재 상태
- ❌ 미구현
- 📌 primary UI 숨김 (출시 계획 없음)

### 계획
- Google OAuth 안정화 이후 검토
- 현재 사용자 화면에 "준비 중" 노출 금지

---

## 공통 규칙

```
ConnectorGuard.evaluate(capability:):
  .sendEmail → blocked
  .createCalendarEvent → blocked
  .modifyCalendarEvent → blocked
  .deleteItem → blocked
  .readCalendar → requiresOAuth (read-only scope)
  .readMailMetadata → requiresOAuth
  .readMailBody → requiresApproval
```

### 사용자 화면 노출 금지 문구

- "IMAP 기반 read-only 검토 중"
- "rate limit 쿨다운"
- "API key 만료"
- "OAuth scope 오류"
- 기술 에러 코드 (4xx, 5xx)

---

*Connector 실제 OAuth 테스트는 수동 QA 단계. 현재 skeleton 미완.*
