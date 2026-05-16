# Document Creation Core Flow

## 개요

Round 164A-180Z에서 구현된 "문서 만들기" 킬러 워크플로우의 핵심 흐름.

## 아키텍처 계층

```
┌─────────────────────────────────────────────────┐
│  사용자 메시지                                    │
│  "회의록 만들어줘" / "문서 만들기"              │
└──────────────────┬──────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────┐
│  WorkflowOrchestrator.dispatch()                 │
│  (기존 라우팅 파이프라인)                        │
└──────────────────┬──────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────┐
│  DocumentCreationService.detectDocumentCreationIntent()  │
│  "회의록" → DocumentCreationType.meetingMinutes  │
│  "체크리스트" → DocumentCreationType.checklist   │
└──────────────────┬──────────────────────────────┘
                   ↓
           ┌───────┴────────┐
           ↓                ↓
      [API key 있음]  [API key 없음]
           ↓                ↓
    UniversalDocument   DocumentCreationService
    SkillService        .createLocalDocument()
        ↓                ↓
    LLM 호출      LocalDocumentTemplate
        ↓            .generate()
    구조 검증           ↓
        ↓          markdown 생성
    artifact           ↓
    저장           artifact 저장
        ↓                ↓
        └────────┬───────┘
                 ↓
    IndexedArtifact + RecentArtifactIndexEntry
    (ArtifactStore, RecentArtifactIndex)
                 ↓
    ┌────────────────────────────────┐
    │  WorkResultCardView           │
    │  - kind: .meetingMinutes      │
    │  - 아이콘: 📋                  │
    │  - 제목: "회의록 초안"         │
    │  - 인라인: ArtifactCardView    │
    └────────────────────────────────┘
                 ↓
    ┌────────────────────────────────┐
    │  Follow-up Actions             │
    │  (같은 room 내 recent artifact) │
    │  - 요약하기                    │
    │  - 표로 바꾸기                 │
    │  - 체크리스트로 바꾸기         │
    │  - 액션아이템                  │
    └────────────────────────────────┘
```

## 핵심 클래스/함수

### 1. DocumentCreationType enum

```swift
enum DocumentCreationType: String, Codable, CaseIterable {
    case meetingMinutes
    case checklist
    case reportDraft

    var skillType: UniversalDocumentSkillType { ... }
    var title: String { "회의록 초안" / "체크리스트" / "보고서 초안" }
    var description: String { ... }
    var emoji: String { "📋" / "✅" / "📄" }
}
```

**역할**: 문서 타입의 메타데이터와 UniversalDocumentSkillType 매핑

### 2. LocalDocumentTemplate static enum

```swift
enum LocalDocumentTemplate {
    static func generate(for type: DocumentCreationType) -> String {
        switch type {
        case .meetingMinutes: return "## 회의록\n\n..."
        case .checklist: return "# 체크리스트\n\n- [ ] ..."
        case .reportDraft: return "# 보고서 초안\n\n..."
        }
    }
    
    static func generateTitle(for type: DocumentCreationType) -> String {
        // "2026-05-16 회의록", "2026-05-16 체크리스트", etc.
    }
}
```

**역할**: 마크다운 템플릿 생성

### 3. DocumentCreationService

#### detectDocumentCreationIntent(from:) → DocumentCreationType?

```swift
static func detectDocumentCreationIntent(from message: String) -> DocumentCreationType? {
    // "회의록" / "회의 내용" → .meetingMinutes
    // "체크리스트" / "체크" → .checklist
    // "보고서" / "보고" → .reportDraft
}
```

#### createLocalDocument(type:roomID:manager:) → (artifact, resultText)?

```swift
static func createLocalDocument(
    type: DocumentCreationType,
    roomID: UUID,
    manager: AgentWindowManager
) async -> (artifact: IndexedArtifact, resultText: String)? {
    // 1. LocalDocumentTemplate.generate(for: type) → markdown string
    // 2. IndexedArtifact 생성 (workflowID, title, type:.text, etc)
    // 3. ArtifactStore.shared.registerArtifact(artifact)
    // 4. RecentArtifactIndexEntry 생성 + manager.addRecentArtifactIndexEntry()
    // 5. resultText 생성: "# \(type.title) 초안을 만들었습니다..."
    // 6. (artifact, resultText) 반환
}
```

**역할**: 로컬 문서 생성 및 artifact 등록

## 데이터 흐름 (API 없는 경우)

### 1. Artifact 생성
```swift
let artifact = IndexedArtifact(
    id: UUID().uuidString,
    workflowID: UUID().uuidString,
    title: "2026-05-16 회의록",
    type: .text,
    filename: "2026-05-16_회의록.md",
    relativePath: "2026-05-16_회의록.md",
    preview: "## 회의록\n\n### 참석자\n- ...",
    createdAt: ISO8601DateFormatter().string(from: Date()),
    contentHash: StableContentHash.sha256Hex(template),
    fileSizeBytes: Int64(template.count),
    roomID: roomID.uuidString
)
```

### 2. ArtifactStore 등록
```swift
await ArtifactStore.shared.registerArtifact(artifact)
// → Workspace에 artifact 파일 저장
// → ArtifactIndex 업데이트
```

### 3. RecentArtifactIndexEntry 등록
```swift
let entry = RecentArtifactIndexEntry(
    artifactID: artifact.id,
    roomID: roomID,
    filename: "2026-05-16_회의록.md",
    artifactType: "text",
    createdAt: Date(),
    contentHash: contentHash,
    fileSizeBytes: Int64(template.count)
)
await MainActor.run {
    manager.addRecentArtifactIndexEntry(entry)
}
// → RecentArtifactIndex에 room-scoped 추적 저장
```

## Room-Scoped Artifact 보장

### 핵심 원칙
- artifact가 생성된 **room에서만** 후속 작업 가능
- 다른 room에서는 "방금 만든 문서" 추적 불가
- RecentArtifactIndexEntry(roomID:)로 room-scoped lookup

### 구현
```swift
// Follow-up action에서 recent artifact 조회
let recentArtifacts = manager.recentArtifactIndexEntries(for: roomID)
// → 해당 roomID 내 최근 10개만 반환

// 다른 room에서 같은 artifact 참조 불가
let entry = manager.recentArtifactIndexEntry(for: artifactID, in: roomID)
// → 같은 roomID에 속하는 entry만 반환
```

## WorkResultCardView와의 통합

### 문서 종류별 표시

```swift
enum WorkResultKind {
    case meetingMinutes
    case checklist
    case reportDraft
    case generic
    
    var title: String {
        case .meetingMinutes: "회의록 초안"
        case .checklist: "체크리스트"
        case .reportDraft: "보고서 초안"
    }
    
    var iconName: String {
        case .meetingMinutes: "doc.text"
        case .checklist: "checkmark.circle"
        case .reportDraft: "text.document"
    }
    
    var accentColor: Color {
        case .meetingMinutes: .blue
        case .checklist: .green
        case .reportDraft: .orange
    }
}
```

### CardView 헤더
```swift
if kind != .generic {
    HStack(spacing: 6) {
        Image(systemName: kind.iconName)
        Text(kind.title)
    }
    .foregroundColor(kind.accentColor)
} else {
    // 에이전트 이름 + 아바타 표시
}
```

## 테스트 케이스 (RouterBurnInSuite)

### Case 1: 문서 만들기 Hub
```swift
"문서 만들기" → universalDocument, documentCreationHub hint
```

### Case 2-4: 각 문서 타입
```swift
"회의록 만들어줘" → korean.meeting-minutes
"체크리스트 만들어줘" → korean.checklist
"보고서 초안 만들어줘" → korean.report-draft
```

### Case 5-8: 후속 작업
```swift
"방금 만든 문서 요약해줘" → korean.document-summary, recentArtifactRef=true
"방금 만든 문서 표로 바꿔줘" → korean.document-table-summary, recentArtifactRef=true
"방금 만든 문서 체크리스트로 바꿔줘" → korean.checklist, recentArtifactRef=true
"방금 만든 문서 액션아이템 뽑아줘" → korean.action-items, recentArtifactRef=true
```

## 다음 단계 (Round 165+)

1. **Hub UI 개선**: StarterActionStripView에 "문서 만들기" 액션 추가
2. **AI 고도화**: 문서 생성 시 인풋 가이드 (예: "회의 날짜, 참석자 명시")
3. **Follow-up 확장**: "방금 문서"를 기반으로 여러 파생 작업
4. **공유 기능**: 생성된 문서를 다른 팀원과 공유
5. **템플릿 확장**: 사용자 정의 템플릿 저장 및 재사용
