# Content Draft Assistant Policy

> Round 236. MyTeam의 블로그/콘텐츠 글쓰기 기능은 핵심 제품 포지션이 아니라 보조 워크플로우다.

## Positioning

MyTeam의 핵심은 Mac 안에서 자연어 요청을 받아 문서, 파일, 표, 정리 작업을 처리하는 AI 업무 워크룸이다.

콘텐츠 초안 보조 기능은 이 핵심 루프 안에서 동작한다.

```
자연어 요청
  → 워크룸에서 처리
  → 초안/문서 artifact 생성
  → 사용자가 검토하고 후속 작업
```

## UI Rules

- WorkroomHomeView의 핵심 CTA는 문서 만들기, 파일 맡기기, 오늘 정리하기를 유지한다.
- 콘텐츠 초안 보조 기능은 방 템플릿, 우클릭 메뉴, `/blog-source` shortcut으로 제공한다.
- 사용자-facing 문구는 "블로그 글쓰기 최적화"보다 "콘텐츠 초안 보조"를 우선한다.
- `blogWriting` enum case는 저장 호환성을 위해 유지하지만 제품 문구에서는 메인 기능처럼 보이지 않게 한다.

## Scope

V1에 포함:

- 공개 글 URL을 참고 정보로 분석
- 글투, 제목 패턴, 표현 메모, CTA 패턴 저장
- SEO 체크리스트와 초안 출력 형식 주입
- room-scoped context 유지

V1에서 제외:

- 사이트 전체 크롤링
- RSS/sitemap 자동 확장
- JS 렌더링 페이지 분석
- 전용 프로필 편집 화면

## Acceptance

- 팀 워크룸과 개인 대화의 메시지, artifact, LLM context가 섞이지 않는다.
- 콘텐츠 초안 기능은 핵심 업무 CTA보다 우선 노출되지 않는다.
- `/blog-source`는 power user shortcut으로 유지하되, 빈 입력과 실패 상황은 사용자 언어로 안내한다.
