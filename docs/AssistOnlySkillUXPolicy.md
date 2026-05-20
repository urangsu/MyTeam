# AssistOnly Skill UX Policy

**Round:** 246B-ACTION  
**원칙:** 구현 안 된 건 구현 안 됐다고 말한다. 대신 할 수 있는 걸 한다.

---

## assistOnly란?

`FeatureAvailability.assistOnly` = 외부 API 없이 LLM만으로 도움을 줄 수 있는 상태.
"사용 불가"가 아니라 "API 없이 LLM 보조만 가능".

---

## assistOnly 판단 기준 (SkillAvailabilityResolver)

| 조건 | 판단 |
|---|---|
| skill notes에 "미구현" 포함 | `.assistOnly` |
| `korean.dart` | `.assistOnly` (DART API 미연결) |
| `korean.law-search` | `.assistOnly` (법령 API 미연결) |
| `korean.naver-news`, `korean.naver-blog-research` | `.assistOnly` (Naver API 미연결) |
| API 연결 있고 동작 | `.available` |
| 정책상 차단 | `.blocked` |
| 개발 예정 | `.planned` |

---

## assistOnly 스킬 사용자 응답 패턴

```
"[스킬명] API 직접 조회는 아직 연결 전입니다.
[가능한 대안]: 자료를 주시면 [초안/요약/정리] 형식으로 도와드릴 수 있어요."
```

### 예시

**DART 공시 조회 요청 시:**
> "DART API 직접 조회는 아직 연결 전입니다. 종목명, 공시 PDF, 사업보고서 내용을 주시면 공시 요약 형식으로 정리해드릴 수 있어요."

**법령 검색 요청 시:**
> "법령 데이터베이스 직접 조회는 아직 연결 전입니다. 법령명, 조항, 내용을 붙여넣으시면 해석·요약을 도와드릴 수 있어요."

---

## OfficeReview assistOnly UX

파일 없이 office-review 요청:
> "검토할 파일을 올려주세요. PDF, CSV, 텍스트, 스프레드시트 파일을 드롭하거나 텍스트를 붙여넣으시면 바로 시작할 수 있습니다."

executionStatus가 `.inputDetected`인 스킬 (표 파싱 미구현):
> "[스킬명]은(는) 파일을 읽어 내용을 분석하는 기능입니다. 단, 표 파싱 및 근거 위치 추적은 아직 미구현 상태입니다. 텍스트 기반 초안 검토는 가능합니다."

---

## Observation 컴포넌트 정직한 상태 표시

| 컴포넌트 | ImplementationLevel | 사용자 안내 |
|---|---|---|
| DownloadsFolderWatcher | `.metadataOnly` | "파일명과 크기 정보만 확인 가능. 내용 분석 미지원." |
| ClipboardContextReader | `.explicitReadOnly` | "명시 요청 시만 읽기. 상시 감시 없음." |
| ScreenObservationPolicy | `.policyOnly` | "정책 정의만 있고 아직 동작하지 않음." |

---

## 절대 금지

- "이 기능은 사용할 수 없습니다." 만 표시하고 LLM 응답 없이 return → 금지
- API 없는 스킬을 `.available`로 표시 → 금지
- 사용자에게 가짜 공시 정보, 법령 내용 생성 → 금지 (assistOnly 안내 후 사용자 자료 기반으로만)
