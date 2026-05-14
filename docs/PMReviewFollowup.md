# PMReviewFollowup
**Round 76A-95Z 이후 PM 관점 후속 조치 및 리스크 추적**
**작성일**: 2026-05-15
**기준**: Round 76A-95Z 완료 직후 스냅샷

---

## 1. Round 76A-95Z 완료 요약

### 1.1 완료된 항목

| 라운드 항목 | 완료 여부 |
|---|---|
| Swift 6 actor isolation warning 제거 | ✅ |
| CharacterAssetManifest.swift 신규 생성 | ✅ |
| CharacterAssetAvailability.swift 신규 생성 | ✅ |
| ReleaseVisibleCharacterPolicy.swift 신규 생성 | ✅ |
| pbxproj 신규 파일 3개 등록 | ✅ |
| Privacy copy 금지 표현 제거 (Swift 소스) | ✅ |
| 저작권 © 2026 DALGRACSTUDIO 업데이트 | ✅ |
| 권한 copy (마이크/위치) 업데이트 | ✅ |
| RuntimeDiagnostics Round 76 신규 필드 6개 | ✅ |
| preflight_round76.sh 작성 + PASS 확인 | ✅ |
| InternalReviewReport.md 작성 | ✅ |
| MarketingReviewFollowup.md 작성 | ✅ |

### 1.2 다음 라운드로 이월된 항목

| 항목 | 라운드 | 이유 |
|---|---|---|
| 치코 working/success/screenshot 스프라이트 | Round 96A | Visual asset 제작 필요 |
| DLC 구매 버튼 활성화 | Round 96A 이후 | DLC 준비 캐릭터 0명 |
| App Store 스크린샷 | Round 96A 완료 후 | 스프라이트 의존 |

---

## 2. 리스크 레지스터 (v1.0 출시 기준)

| ID | 리스크 | 심각도 | 가능성 | 현황 |
|---|---|---|---|---|
| R-01 | 치코 idle 스프라이트만으로 App Store 심사 통과 불가 | 중 | 중 | 심사 기준 불명확. 기본 UI 기능은 정상. |
| R-02 | Premium DLC 캐릭터 0명 노출 → 수익화 지연 | 높음 | 확정 | Round 96A 후 해소 예정 |
| R-03 | `partialAllowed` 자동 승인 — 향후 품질 기준 혼선 | 낮음 | 낮음 | 문서화 완료. 명시적 승인 플래그 향후 추가 |
| R-04 | CharacterAssetRegistry 하드코딩 — 캐릭터 추가 시 코드 수정 필요 | 낮음 | 확정 | v1.0 허용. plist/JSON 전환 Round 100+ |
| R-05 | SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor — Xcode 버전 변경 시 회귀 가능 | 중 | 낮음 | nonisolated 명시로 방어. CI에서 warning 0 확인 필요 |

---

## 3. v1.0 출시 전 PM 승인 체크리스트

### 3.1 반드시 확인 (MUST)

- [ ] App Store Connect 앱 등록 완료
- [ ] Privacy Nutrition Label 제출 (PrivacyNutritionDraft.md 기반)
- [ ] 앱 설명문 금지 표현 없음 (MarketingReviewAcceptanceMatrix 기준)
- [ ] 치코 기반 스크린샷 최소 3장 (ScreenshotReadinessPlan.md 기준)
- [ ] 가격 책정 — 무료 기본 / 유료 DLC 정책 확정
- [ ] TestFlight 베타 최소 1회 배포

### 3.2 권장 확인 (SHOULD)

- [ ] 한국어 App Store 설명문 최종 교정
- [ ] 지원 URL / 개인정보처리방침 URL 등록
- [ ] 연령 등급 설정 (4+)

---

## 4. 캐릭터 로드맵 PM 관점

### 4.1 v1.0 (현재)

| 캐릭터 | 상태 | 노출 |
|---|---|---|
| 치코 | `partialAllowed` — idle 스프라이트 보유 | ✅ 노출 |
| 기타 캐릭터 | `missing` — 에셋 없음 | ❌ 숨김 |

**사용자 경험 영향**: 캐릭터 선택 UI에 치코 1명만 표시. 선택 폭 없음 → 기본 경험으로 충분하나, 단조로움.

### 4.2 Round 96A 완료 후 목표

| 캐릭터 | 목표 상태 | 노출 변화 |
|---|---|---|
| 치코 | `productionReady` | DLC 구매 UI 포함 가능 |
| 1–2명 premium | `productionReady` | DLC 구매 버튼 활성화 |

---

## 5. 다음 스프린트 우선순위 권장

| 우선순위 | 항목 | 기대 효과 |
|---|---|---|
| P0 | 치코 working + success + screenshot 스프라이트 제작 | App Store 스크린샷 준비 + `productionReady` 달성 |
| P0 | App Store Connect 제출 준비 | v1.0 출시 |
| P1 | Premium 캐릭터 1명 DLC 준비 | 수익화 첫 경로 |
| P2 | CharacterAssetRegistry JSON 전환 | 코드 수정 없이 캐릭터 추가 |

---

## 6. 의사결정 로그

| 날짜 | 결정 | 근거 |
|---|---|---|
| 2026-05-15 | 치코 `partialAllowed`로 v1.0 Release 노출 승인 | idle 스프라이트 존재, 기본 경험 제공 가능 |
| 2026-05-15 | DLC 구매 버튼 v1.0 전면 숨김 | isDLCReady 캐릭터 0명, 미완성 UX 방지 |
| 2026-05-15 | Privacy 금지 표현 전면 제거 | App Store 심사 리스크 감소, 사용자 신뢰 |

---

*이 문서는 PM 리뷰 추적 문서입니다. 실제 출시 결정은 별도 승인 프로세스를 따릅니다.*
