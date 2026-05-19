# Memory Privacy Policy

**Round 244A** — 사용자 기억 보호 원칙

---

## 절대 저장 금지

| 항목 | 이유 |
|---|---|
| API key / token / password | credentialLike 하드 블록 |
| 파일 원문 / sourceText | 원문 그대로 memory에 저장 금지 |
| Artifact 전문 내용 | artifact 제목만 허용 |
| 다른 방 room memory | roomID 필터링으로 격리 |
| organization scope | 현재 버전 미지원, 항상 차단 |

---

## 승인 없이 자동 저장 금지

| 항목 | 처리 |
|---|---|
| businessConfidential (거래처/금액/계약 조건) | pendingReviewCandidates → 사용자 승인 |
| personalSensitive (개인정보/의료/법적) | pendingReviewCandidates → 사용자 승인 |
| domain memory | 자동 저장 안 함, 별도 승인 필요 |

---

## 저장 가능 항목

| 항목 | 조건 |
|---|---|
| 출력 스타일 선호 (publicPreference) | 자동 저장 가능 |
| 업무 방식 (workPreference) | 자동 저장 가능 |
| 방 컨텍스트 (room, publicPreference) | 자동 저장 가능 |

---

## 사용자 권리

- 모든 저장된 기억은 사용자가 **조회/수정/삭제** 가능해야 한다.
- 민감 정보는 저장 전 **명시적 승인**을 받아야 한다.
- 승인 옵션: `rememberForThisRoom` / `rememberAlways` / `doNotRemember`
- 자동 추출된 기억은 `isAutoExtracted = true`로 표시한다.

---

## 기술 보호 장치

1. **MemoryStore.add()**: credentialLike → `return false` (로그만)
2. **MemoryStore.add()**: room scope without roomID → `return false`
3. **MemoryStore.add()**: requiresApproval && !isUserApproved → `pendingReviewCandidates.append()`
4. **MemoryConsolidator.truncateForMemory()**: 원문 120자 이상 잘라냄
5. **MemoryRetriever.isRelevant()**: 다른 방 room memory 필터링
6. **MemoryRetriever.isRelevant()**: 만료 항목 제외, 미승인 민감 항목 제외

---

## 감사 필드

`MemoryItem`은 다음 감사 필드를 포함한다:
- `sourceRoomID` — 출처 방
- `sourceMessageID` — 출처 메시지
- `isAutoExtracted` — heuristic/LLM 자동 추출 여부
- `isUserApproved` — 사용자 직접 승인 여부
- `createdAt`, `updatedAt`, `lastUsedAt`
