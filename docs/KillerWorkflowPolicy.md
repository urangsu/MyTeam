# Killer Workflow Policy

## 개요

MyTeam의 "킬러 워크플로우(Killer Workflow)"는 일상 업무를 **한 번의 상호작용으로 완결**하는 핵심 기능이다. Round 164A-180Z에서 "**문서 만들기**"를 첫 번째 킬러 워크플로우로 완성한다.

## 킬러 워크플로우 설계 원칙

### 1. 순간적 가치 (Instant Value)
- 사용자가 메시지 입력 직후 즉시 결과를 받는다
- API key 유무와 관계없이 로컬 템플릿으로 기본값을 생성한다
- "연결 대기", "초기화", "인증" 흐름 없음

### 2. 명확한 결과물 (Clear Output)
- 텍스트/이미지/파일이 아닌 **structured 문서**를 생성
- WorkResultCardView에서 문서 유형별로 다른 아이콘/제목으로 표시
- 같은 방(room) 내에서 follow-up actions 가능

### 3. 일회용 아님 (Repeatable)
- 생성된 문서를 방금 만든 것으로 추적 가능
- "요약하기", "표로 바꾸기", "체크리스트로 바꾸기", "액션아이템" 등 후속 작업 가능
- 같은 room 내 artifact만 참조 (보안, 혼동 방지)

## 문서 만들기 워크플로우 구조

### 진입점
```
사용자 메시지: "문서 만들기"
  ↓
DocumentCreationService.detectDocumentCreationIntent()
  ↓ (intent detected)
UniversalDocumentSkillService (hub 모드)
```

### 3가지 문서 타입

| 타입 | 설명 | 용도 | 아이콘 |
|------|------|------|--------|
| **회의록** (meetingMinutes) | 회의 내용 정리 | 회의 후 기록 | 📋 doc.text |
| **체크리스트** (checklist) | 업무 준비 항목 | 진행 상황 추적 | ✅ checkmark.circle |
| **보고서 초안** (reportDraft) | 목적 + 핵심 내용 | 보고 및 공유 | 📄 text.document |

### 로컬 Fallback 보장

API key가 없을 때:
```swift
LocalDocumentTemplate.generate(for: .meetingMinutes)
→ "## 회의록\n\n### 참석자\n- \n\n### 논의 사항\n..."
```

생성된 문서:
- 마크다운 형식 (구조화)
- ArtifactStore에 저장
- RecentArtifactIndexEntry로 room-scoped 추적
- WorkResultCardView에 표시
- 같은 방 내 follow-up actions 가능

## 구현 파일 구조

```
DocumentCreationType.swift        ← enum 정의 (meetingMinutes/checklist/reportDraft)
DocumentCreationService.swift     ← 로컬 생성 + artifact 등록
LocalDocumentTemplate.swift       ← markdown 템플릿 생성
WorkResultKind.swift             ← 문서 유형별 UI 표현
```

## 사용자 경험 흐름

### Scenario 1: 회의록 만들기 (API 있음)
```
사용자: "회의록 만들어줘"
→ UniversalDocumentSkillService 호출
→ LLM이 구조화된 회의록 생성
→ WorkResultCardView (아이콘: 📋, 제목: "회의록 초안")
→ 후속: "요약하기", "표로 바꾸기" 등
```

### Scenario 2: 체크리스트 만들기 (API 없음)
```
사용자: "업무 준비 체크리스트 만들어줘"
→ DocumentCreationService.createLocalDocument(.checklist)
→ LocalDocumentTemplate.generateChecklist() 호출
→ markdown 템플릿 저장 (artifact)
→ WorkResultCardView (아이콘: ✅, 제목: "체크리스트")
→ 후속: "수정하기", "필수 항목 정리" 등
```

## 확장 가능성 (Future)

### Round 165+: 추가 문서 타입
- 회의 녹음 → 회의록 자동 생성
- 이메일 → 요약
- 웹 페이지 → 정보 추출

### Round 166+: 협업 강화
- 문서 공유 (팀 내)
- 댓글 및 수정 제안
- 버전 관리

### Round 167+: AI 고도화
- 기존 문서 분석 후 업데이트
- 템플릿 커스터마이징
- 스타일 가이드 적용
