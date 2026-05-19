# Memory Scope Policy

**Round 244A** — heuristic classification rules

---

## Sensitivity Classes

| Class | 저장 방식 | 예시 |
|---|---|---|
| publicPreference | 자동 저장 | "항상 짧게 써줘", "표로 먼저 정리해줘" |
| workPreference | 자동 저장 | "앞으로 보고서는 이렇게", "체크리스트 방식으로" |
| businessConfidential | 승인 필요 | "거래처", "계약 금액", "납품 단가" |
| personalSensitive | 승인 필요 | "주민등록", "병원", "계좌번호" |
| credentialLike | 저장 금지 | "api key", "token", "password", "비밀번호" |

---

## Scope 분류 우선순위

```
credentialLike  →  (.turn, .credentialLike)      ← 즉시 종료
userProfile     →  (.userProfile, .publicPreference)
procedural      →  (.procedural, .workPreference)
businessConfidential → (.room, .businessConfidential)
personalSensitive    → (.room, .personalSensitive)
domain          →  (.domain, .workPreference)
room (default)  →  (.room, .publicPreference)    ← text.count > 20
nil             →  분류 불가, candidate 생성 안 함
```

---

## Keyword Patterns (대표)

### credentialLike
`api key`, `apikey`, `token`, `토큰`, `password`, `비밀번호`, `passwd`, `secret key`, `access token`, `refresh token`, `private key`, `client secret`, `bearer `

### userProfile
`항상`, `앞으로도`, `내 스타일`, `내 글투`, `기억해줘`, `잊지 말고`, `매번`, `모바일 가독성`, `짧게 써`

### procedural
`앞으로 보고서`, `앞으로 문서`, `이런 순서로`, `먼저 표로`, `체크리스트 방식`, `반복 업무`, `매번 이렇게`

### businessConfidential
`거래처`, `계약 금액`, `단가`, `납품`, `구매처`, `공급가`, `협력사`, `이 프로젝트 예산`

### personalSensitive
`주민등록`, `생년월일`, `주소`, `전화번호`, `병원`, `진단`, `계좌번호`, `신용카드`

---

## canAutoStore() 규칙

```swift
if sensitivity.isStorageBlocked { return false }   // credentialLike
if sensitivity.requiresApproval { return false }   // businessConfidential, personalSensitive
if scope == .organization { return false }         // 미지원
return true
```

---

## 구현 파일

`MemoryScopePolicy.swift` — `classify(text:)`, `detectDomain(from:)`, `canAutoStore(sensitivity:scope:)`
