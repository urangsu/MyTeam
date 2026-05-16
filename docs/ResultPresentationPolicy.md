# Result Presentation Policy

> Round 146A-152Z에서 도입. 업무 결과물과 대화 메시지의 시각적 분리 정책.

## 원칙

1. **업무 결과물은 카드, 대화는 말풍선** — 긴 어시스턴트 응답(500자+ 또는 마크다운 헤더/표 포함)은 `WorkResultCardView`로 렌더링한다.
2. **어시스턴트 버블 확장** — 일반 어시스턴트 메시지의 maxWidth를 260px에서 480px로 확장한다. 사용자 메시지는 260px 유지.
3. **접기/펼치기** — 500자 초과 결과는 기본 300자 미리보기 + "더 보기" 토글.
4. **아바타 제거** — WorkResultCardView에서는 에이전트 아바타 없이 색상 점 + 이름만 표시.

## 판정 기준 (`shouldRenderAsWorkResult`)

- `isUser == true` → 항상 false (사용자 메시지는 항상 말풍선)
- `text.count >= 500` → true
- 마크다운 헤더 포함 (`# `, `## `, `### `) → true
- 마크다운 표 포함 (`|---`, `| ---`) → true
- 그 외 → false (일반 말풍선)

## ChatLog.artifactIDs

- 메시지가 artifact를 생성하면 `artifactIDs` 배열에 해당 artifact ID를 추가한다.
- 기본값 `[]` — 기존 데이터 디코딩에 영향 없음.

## ArtifactCardView 상태 텍스트

| 이전 | 이후 |
|---|---|
| "메타데이터만" | "파일 정보만 저장됨" |
| "경로 오류" | "파일을 열 수 없음" |
| "파일 상태가 바뀌었습니다" | (유지) |

## 검증

- `WorkResultCardView.shouldRenderAsWorkResult()` 정적 메서드로 판정
- `RuntimeDiagnosticsSnapshot.workResultCardAvailable`
- `RuntimeDiagnosticsSnapshot.longAssistantResultEscapesBubble`
- `RuntimeDiagnosticsSnapshot.chatLogArtifactIDsAvailable`
- `RuntimeDiagnosticsSnapshot.artifactStatusCopyUserFriendly`
- `ToolContractValidator.validateWorkResultPresentationPolicy()`
- `ToolContractValidator.validateArtifactStatusCopyPolicy()`
