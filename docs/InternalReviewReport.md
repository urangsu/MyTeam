# MyTeam Internal Review Report
**Round 76A-95Z Character Asset Pipeline + Release Gate Audit**
**작성일**: 2026-05-15
**버전**: v1.0 (Round 76A-95Z 완료 기준)
**작성**: DALGRACSTUDIO 내부 리뷰

---

## 1. 리뷰 범위

이 문서는 Round 76A-95Z 전체 작업을 대상으로 다음 항목을 검토한다:

1. Character Asset Pipeline 구현 완성도
2. Release 노출 게이트 정책
3. Privacy Copy 금지 표현 준수
4. Swift 6 actor isolation 경고 해소
5. 권한/저작권 copy 정확성
6. 빌드 상태

---

## 2. Character Asset Pipeline 구현 상태

### 2.1 신규 파일

| 파일 | 역할 | 상태 |
|---|---|---|
| `CharacterAssetAvailability.swift` | 4단계 에셋 가용성 enum (productionReady / partialAllowed / placeholder / missing) | ✅ 완료 |
| `CharacterAssetManifest.swift` | 캐릭터별 스프라이트 에셋 완성도 선언 + CharacterAssetRegistry | ✅ 완료 |
| `ReleaseVisibleCharacterPolicy.swift` | Release UI 노출 단일 게이트 정책 | ✅ 완료 |

### 2.2 CharacterAssetAvailability 등급 기준

| 등급 | 조건 | Release 노출 | DLC 구매 |
|---|---|---|---|
| `productionReady` | idle + working + success + icon + screenshot | ✅ | ✅ |
| `partialAllowed` | idle 또는 working 일부 있음 + 명시적 승인 | ✅ | ❌ |
| `placeholder` | 모든 스프라이트 없음 | ❌ | ❌ |
| `missing` | manifest 미등록 | ❌ | ❌ |

### 2.3 현재 캐릭터 에셋 상태 (v1.0 기준)

| 캐릭터 | ID | 등급 | Release 노출 | 비고 |
|---|---|---|---|---|
| 치코 | `chiko` | `partialAllowed` | ✅ | idle 스프라이트만 보유. working/success 미제작. |
| 기타 모든 캐릭터 | — | `missing` | ❌ | placeholder 에셋도 없음 — DEBUG 전용 |

**결론**: v1.0 Release에서는 치코만 대표 UI에 노출. DLC 구매 버튼은 미노출 (isDLCReady 미달성).

---

## 3. Release 노출 게이트 정책

### 3.1 ReleaseVisibleCharacterPolicy

```
Release 빌드:
  built-in 캐릭터 → CharacterAssetRegistry.manifest → availability.isVisibleInRelease
  premium 캐릭터  → !isComingSoon (DLC 준비 전 숨김)

DEBUG 빌드:
  전체 roster 노출 (개발 진단용)
```

### 3.2 DLC 구매 버튼 게이트

```
isPremium && !isComingSoon && manifest.isDLCReady → 구매 버튼 노출
현재: 모든 premium 캐릭터 isDLCReady=false → 구매 버튼 전체 숨김
```

### 3.3 검증

- `ReleaseVisibleCharacterPolicy.visibleBuiltIn` → [chiko] (DEBUG: 전체 roster)
- `ReleaseVisibleCharacterPolicy.purchasablePremium` → [] (DLC 준비 캐릭터 0명)
- `RuntimeDiagnosticsService` → `visibleCharacterCountLive`, `purchasableCharacterCountLive` 필드로 런타임 추적 가능

---

## 4. Privacy Copy 준수 감사

### 4.1 금지 표현 목록

| 금지 표현 | 대체 표현 |
|---|---|
| "외부 서버 없음" | "MyTeam 자체 서버에 파일을 저장하지 않습니다" |
| "완전 로컬" | "로컬 중심", "기기 내에서 계산" |
| "내 기기 안에서만" | "로컬 기능은 내 Mac에서 먼저 시작할 수 있습니다" |
| "어떤 데이터도 외부로 나가지 않음" | 금지 — AI provider 전송 가능성 명시 필요 |
| "서버 없음" | 금지 — API provider 사용 명시 필요 |

### 4.2 감사 결과

- `BuiltInKoreanSkills.swift` L101: `"완전 로컬로 계산한다"` → `"로컬에서 계산한다"` ✅
- `BuiltInKoreanSkills.swift` L109: `"완전 로컬로 계산하세요"` → `"기기 내에서 계산하세요"` ✅
- `RouterBurnInSuite.swift` L134: `"완전 로컬 처리"` → `"로컬 처리 (기기 내 계산)"` ✅
- `DEVLOG.md` L1541: `"완전 로컬 처리"` → `"기기 내 로컬 처리"` ✅

**결론**: Swift 소스 전체에서 금지 표현 0건 확인 (preflight_round76.sh check 1 통과).

---

## 5. Swift 6 Actor Isolation 경고

### 5.1 근본 원인

`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (Xcode 26 설정) — 모든 모듈 타입이 `@MainActor` 기본값으로 추론됨.

### 5.2 수정 파일

| 파일 | 수정 내용 |
|---|---|
| `ArtifactStore.swift` | `ActionLogEntry`, `IndexedArtifact` — `nonisolated` init/Codable 명시 |
| `AgentTool.swift` | `ToolResult` init overloads, `WorkflowTool` protocol 모든 property `nonisolated` |
| `AppLaunchArtifactWriter.swift` | 불필요 `await` 제거 (nonisolated var 접근) |
| `KoreanPrivacyTermsArtifactWriter.swift` | 동일 |

**결론**: 앱 코드 warning 0 (Debug/Release).

---

## 6. 저작권 및 권한 Copy

| 항목 | 수정 전 | 수정 후 | 상태 |
|---|---|---|---|
| Copyright | "MyTeam" 또는 연도 미지정 | "© 2026 DALGRACSTUDIO. All rights reserved." | ✅ |
| NSMicrophoneUsageDescription | 이전 copy | "회의록 작성을 위해 사용자가 시작한 녹음에만 마이크를 사용합니다." | ✅ |
| NSLocationWhenInUseUsageDescription | 이전 copy | "날씨·지역 기반 브리핑 제공을 위해 위치를 사용할 수 있습니다." | ✅ |

---

## 7. RuntimeDiagnostics 신규 필드 (Round 76)

```
characterAssetManifestAvailable: Bool
releaseVisibleCharacterPolicyAvailable: Bool
chikoDefaultExperienceReady: Bool
privacyCopyForbiddenPhraseClean: Bool
visibleCharacterCountLive: Int   ← ReleaseVisibleCharacterPolicy.visibleCharacters.count
purchasableCharacterCountLive: Int  ← ReleaseVisibleCharacterPolicy.purchasablePremium.count
```

summary 출력: `characterAssetPipeline: manifest=true policy=true chikoReady=true privacyClean=true visible=1 purchasable=0`

---

## 8. 빌드 상태

| 항목 | 상태 |
|---|---|
| Debug build | ✅ error 0, warning 0 (앱 코드) |
| Release build | ✅ error 0, warning 0 (앱 코드) |
| preflight_round76.sh | ✅ PASS=16, WARN=2 (미commit + InternalReviewReport), FAIL=0 |
| 신규 Swift 파일 3개 pbxproj 등록 | ✅ 확인 |

---

## 9. 알려진 한계 (v1.0 Release)

| 항목 | 상태 | 계획 |
|---|---|---|
| 치코 working/success/screenshot 스프라이트 미제작 | ⚠️ | Round 96A Visual Asset Production |
| 모든 premium 캐릭터 DLC 미준비 | ⚠️ | 에셋 제작 후 CharacterAssetRegistry 업데이트 |
| `CharacterAssetRegistry` 하드코딩 | ℹ️ | v1.0 용도로 충분. plist/JSON 전환은 향후 |
| `partialAllowed` 는 명시적 승인 없이 자동 적용 | ℹ️ | 치코는 승인된 캐릭터. 향후 승인 플래그 추가 검토 |

---

## 10. 결론

Round 76A-95Z의 Character Asset Pipeline, Privacy Copy 감사, Swift 6 actor isolation 수정,
저작권/권한 copy 업데이트, preflight 스크립트, RuntimeDiagnostics 확장이 완료되었다.

v1.0 Release 기준: 치코 1명 노출, DLC 구매 미노출. 코드 품질 기준 충족.
다음 단계는 Round 96A Visual Asset Production (치코 working/success/screenshot 스프라이트 제작).

---

*이 문서는 코드 정적 분석 기반의 내부 리뷰 문서입니다. 런타임 실행 결과를 보증하지 않습니다.*
