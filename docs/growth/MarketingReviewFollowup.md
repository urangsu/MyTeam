# Marketing Review Follow-up

## Positioning — Accepted

### Core Message
**내 컴퓨터 안의 AI 업무 팀.**

MyTeam은 앱 출시 전용 도구가 아니다. Mac 안에서 사용자의 자연어 요청을 받아, 문서/파일/표/메일/일정/웹자료를 팀원처럼 처리하는 AI 업무 팀이다.

### Target User
사무직 사용자, 1인 창업자, 콘텐츠 제작자, 기획자, 세무/회계 사용자 → 반복 문서 업무가 많은 모든 사람

### Trust Point
**BYOK (Bring Your Own Key) + Local-First**
- API key 없이 로컬 기능 사용 가능
- MyTeam 자체 서버에 파일을 저장하지 않음
- 외부 서비스 연결은 사용자 선택

## Messaging — Modified

### "외부 서버 없음" → Removed
**금지 사유**: 과장. AI 기능은 사용자 provider 필요.

**대체문구**:
```
로컬 중심의 AI 업무 팀.
로컬 파일 처리와 문서 작업은 API key 없이도 가능합니다.
AI 기능은 사용자가 연결한 provider로 확장됩니다.
```

### "회의록 30초" → "회의록 양식과 초안을 빠르게 시작"
**이유**: 실제 회의록 생성은 사용자 입력/편집 과정이 필요함. 초안 생성 속도는 30초이지만, 전체 workflow는 더 길 수 있음.

**수정문구**:
```
회의록·체크리스트·보고서 양식과 초안을 빠르게 시작하세요.
```

## Product Acceptance Checklist

✅ Core killer flow: 회의록 양식 → artifact 생성 → next action  
✅ Default experience: Chiko focused, local-first  
✅ Character roster: Chiko visible, placeholder/DLC hidden  
✅ Privacy: truthful, BYOK-centric  
✅ Connector safety: write operations blocked  

## Marketing Deferred

### Character DLC
- Asset production pending
- Marketing copy: deferred to post-asset completion
- Store listing: no DLC button until assets ready

### Gmail / Naver Integration
- Policy: unavailable/planned
- UI: hidden from Release planner
- Marketing: no mention until stable

### Google Calendar Write
- Policy: blocked
- Marketing: no write guarantees

### StoreKit Purchase
- Policy: demo app scope only
- Marketing: freemium positioning pending production QA
- App Store submission: pending manual review

## Current App Store Copy (Draft)

### App Name
**MyTeam**

### Subtitle
내 컴퓨터 안의 AI 업무 팀

### Short Description
회의록·체크리스트·보고서를 빠르게 시작하세요. 로컬 기능은 API key 없이도 사용할 수 있습니다.

### Long Description
MyTeam은 Mac 안에서 문서 작업을 돕는 AI 업무 팀입니다.

**핵심 기능**
- 회의록 양식 자동 생성 및 요약
- 체크리스트, 보고서 자동 작성
- 오늘 할 일 정리 및 우선순위 분류
- 최근 문서 빠른 재사용

**로컬 중심**
- 로컬 파일 처리는 API key 없이도 가능
- MyTeam 서버에 파일을 저장하지 않음
- 외부 서비스 연결은 사용자 선택

**AI 기능 확장**
- Google Calendar 읽기 (준비 중)
- Gmail 메타데이터 조회 (준비 중)
- 추가 provider 지원 예정

**신뢰할 수 있는 파트너**
- 자체 스킬 + LLM 선택
- 완전 공개 정책
- 사용자 선택의 자유

## Review Status

**Marketing Review**: ACCEPTED  
**Internal Review**: In Progress (Round 76A-95Z)  
**PM Review**: In Progress (Round 76A-95Z)  
**App Store Review**: Deferred to post-manual-QA  

## Action Items

- [ ] App Store metadata finalization (post-Round 96A)
- [ ] Screenshot captions: app = "MyTeam", messaging = "로컬 중심"
- [ ] Privacy Nutrition Label: BYOK data flow diagram
- [ ] Character DLC marketing (post-asset production)
- [ ] Gmail/Naver marketing (post-stabilization)
- [ ] StoreKit marketing (post-production QA)
