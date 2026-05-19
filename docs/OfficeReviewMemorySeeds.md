# Office Review — Memory Seeds

**Round 244A** — 사무실 검토용 초기 memory seed 예시

이 문서는 memory 시스템이 올바르게 동작하는지 검토할 때 사용하는 테스트 시나리오 모음이다.

---

## Seed 1: 업무 방식 (procedural)

**입력:** "앞으로 보고서는 표로 먼저 정리해줘"
**기대 scope:** procedural
**기대 sensitivity:** workPreference
**자동 저장:** 가능
**검증:** MemoryConsolidator → procedural candidate 생성, confidence ≥ 0.6

---

## Seed 2: 방 컨텍스트 (room)

**입력:** "이 방에서는 예산 검토만 할 거야"
**기대 scope:** room
**기대 sensitivity:** publicPreference
**자동 저장:** 가능 (이 방에서만)
**검증:** roomID 필수, 다른 방 retrieval에서 제외됨

---

## Seed 3: 사용자 선호 (userProfile)

**입력:** "내 블로그 글은 모바일 가독성 좋게 써줘"
**기대 scope:** userProfile
**기대 sensitivity:** publicPreference
**자동 저장:** 가능 (전역)
**검증:** userProfileMemories에 저장, 모든 방 retrieval에서 사용 가능

---

## Seed 4: 계약 당사자 (businessConfidential)

**입력:** "이 계약서 갑은 A사야"
**기대 scope:** room
**기대 sensitivity:** businessConfidential
**자동 저장:** 금지 — 사용자 승인 필요
**검증:** pendingReviewCandidates에 추가, 승인 없이 MemoryStore에 저장 안 됨

---

## Seed 5: API key (credentialLike)

**입력:** "내 API 키는 sk-abc123xxx야 기억해"
**기대 scope:** turn (저장 금지 신호)
**기대 sensitivity:** credentialLike
**자동 저장:** 항상 금지
**검증:** MemoryStore.add() → false 반환, pendingReview에도 추가 안 됨, [BLOCKED] content만 생성

---

## Seed 6: 거래처 전역 저장 요청 (승인 필요)

**입력:** "이 거래처 정보는 모든 방에서 기억해줘"
**기대 scope:** room (businessConfidential이 있으면 전역 자동 승격 금지)
**기대 sensitivity:** businessConfidential
**자동 저장:** 금지 — 사용자 승인 필요
**검증:** pendingReviewCandidates로 이동, 사용자가 rememberAlways 선택 시에만 userProfile로 승격

---

## 검증 체크리스트

- [ ] Seed 1: proceduralMemories에 항목 추가됨
- [ ] Seed 2: memoriesByRoom[roomID]에 항목 추가됨
- [ ] Seed 3: userProfileMemories에 항목 추가됨
- [ ] Seed 4: pendingReviewCandidates에 항목 추가됨, MemoryStore에 없음
- [ ] Seed 5: MemoryStore.add() false, pendingReview 없음
- [ ] Seed 6: pendingReviewCandidates에 추가됨
- [ ] MemoryRetriever: Seed 2의 room memory가 다른 방 입력에서 제외됨
- [ ] MemoryContext.promptSummary() 600자 이하로 system prompt 생성됨
