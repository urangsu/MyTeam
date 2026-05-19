# Memory Architecture Policy

**Round 244A** — scoped memory foundation

---

## 계층 구조

```
turn → room / agentInRoom → userProfile / procedural / domain → organization(미지원)
```

| Scope | 수명 | 대상 | 자동 저장 |
|---|---|---|---|
| turn | 현재 메시지 | 일회성 컨텍스트 | 저장 안 함 |
| room | 방 유지 기간 | 방별 컨텍스트 | 공개 선호만 |
| agentInRoom | 방 유지 기간 | 에이전트별 컨텍스트 | 공개 선호만 |
| userProfile | 영구 | 출력 스타일/글투/포맷 선호 | 가능 |
| procedural | 영구 | 반복 업무 방식/체크리스트 절차 | 가능 |
| domain | 영구 | 도메인 기준 지식 | 승인 후 |
| organization | 미지원 | — | 항상 차단 |

---

## 원칙

1. **room state ≠ user memory** — 방 컨텍스트와 사용자 기억은 절대 섞지 않는다.
2. **원문 저장 금지** — 파일 내용, sourceText, artifact 전문은 어떤 scope에도 저장할 수 없다. 요약/잘라내기만 허용 (최대 120자).
3. **Cross-room 금지** — 특정 방의 room memory는 다른 방 retrieval에 포함되지 않는다. roomID 필터링은 MemoryRetriever.isRelevant()에서 강제.
4. **credentialLike 하드 블록** — API key / token / password 패턴 감지 시 MemoryStore.add()가 false 반환하고 로그만 남긴다. 승인 경로도 없다.
5. **민감 정보 승인** — businessConfidential / personalSensitive는 pendingReviewCandidates로 이동하고, 사용자가 직접 승인 후 저장.
6. **organization 차단** — 현재 버전에서 organization scope는 저장 불가.

---

## 흐름

```
대화 종료
  ↓
MemoryConsolidator.extractCandidates(Input)
  ↓ keyword/pattern 분류
MemoryScopePolicy.classify(text)
  ↓
  ├─ credentialLike    → isStorageBlocked = true (저장 금지, 경고 candidate만)
  ├─ requiresApproval  → pendingReviewCandidates (사용자 승인 대기)
  └─ autoStorable      → MemoryStore.add(item)

다음 메시지
  ↓
MemoryRetriever.retrieve(Input)
  ↓ priority: room → procedural → userProfile → domain
MemoryContext.promptSummary() → system prompt 주입 (최대 600자)
```

---

## Retrieval Budget

| Priority | Max Items | 대상 |
|---|---|---|
| 1 | 4 | room memory (현재 방만) |
| 2 | 3 | procedural memory |
| 3 | 3 | userProfile memory |
| 4 | 2 | domain memory (도메인 감지 시만) |
| **합계** | **12** | 기본값. 상한 20개. |

---

## 파일 구조

| 파일 | 역할 |
|---|---|
| `MemoryModels.swift` | MemoryScope, MemorySensitivityClass, MemoryItem, MemoryCandidate, MemoryContext 등 |
| `MemoryScopePolicy.swift` | classify(), detectDomain(), canAutoStore() |
| `MemoryStore.swift` | 중앙 저장소. credentialLike/roomID-없는-room 하드 블록 |
| `MemoryConsolidator.swift` | 대화에서 candidate 추출. 원문 저장 금지 |
| `MemoryRetriever.swift` | priority-based retrieval, cross-room 격리 |
