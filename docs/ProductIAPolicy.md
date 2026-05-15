# Product IA Policy (정보 아키텍처 정책)

> Round 137A-145Z 제정.

## 핵심 원칙

1. **방(워크룸) = 독립된 작업 공간** — artifact, 대화, 상태가 방별로 격리됨
2. **에이전트 = 팀원** — 사용자가 직접 전환하지 않아도 자동 배정
3. **용어 통일** — 내부/외부 모두 TerminologyPolicy.md 따름
4. **3개 주요 액션** — 파일 맡기기 / 문서 만들기 / 오늘 정리하기

## 화면 구조

### TeamStatusView (팀 협업 패널)
- 탭 0: 팀 협업 중 (에이전트 상태 + 현재 작업 + 주요 액션 + 워크플로우 중단)
- 탭 1: 팀 워크룸 (로그 뷰 + 워크룸 목록)
- 예약 작업 팝업: 단일 entry point

### AgentChatView (개인 에이전트 대화창)
- 사이드바: "대화" 헤더 + 대화 목록 (에이전트 전환 switcher 제거됨)
- 메인: 메시지 + artifact 카드 (room-scoped)

## 금지 사항

- 에이전트 전환 switcher를 사이드바 하단에 추가하지 않음
- FirstLaunchBannerView + LocalOnlyModeCardView 동시 표시 금지
- API key 안내를 팀 협업 surface에 노출하지 않음

## Starter Action 3 Primary

| 액션 | 내부 ID | 경로 |
|---|---|---|
| 파일 맡기기 | `starter_file_handoff` | fileIntake |
| 문서 만들기 | `starter_document_create` | universalDocument |
| 오늘 정리하기 | `starter_today_organize` | localBriefing |
