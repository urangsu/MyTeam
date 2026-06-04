# K-Skills 한글 읽기 + HWP 지원 로드맵

**상태**: 현황 분석 완료 (2026-05-25)  
**주요 발견**: K-skills 한글 읽기 인프라 70% 구현, HWP 지원 0%

---

## 1. 현재 구현 상태

### 1.1 ✅ 이미 구현된 것들

#### A. 한글 음절 분해 (KoreanSyllableDecomposer.swift)
```swift
enum KoreanSyllableDecomposer {
    static func decompose(_ char: Character) -> KoreanSyllableParts
    // ✅ 각 한글 음절 → 초성(19) + 중성(21) + 종성(28) 분해
    // ✅ Unicode Hangul block (0xAC00~0xD7A3) 분석
    // ✅ Sendable 프로토콜 적용 (concurrency-safe)
}
```

#### B. 감정 스타일 기반 한글 전처리 (SupertonicProsodyTextProcessor.swift)
```swift
enum SupertonicEmotionStyle: String, CaseIterable {
    case neutral       // 수치/법률/보고서
    case friendly      // 쉬운 문장, 부드러운 말투
    case confident     // 전략가, 개발자 톤
    case careful       // 법률, QA, PM 톤
    case excited       // 마케터, 디자이너 톤
    case bubbleSpeech // 미래 옵션 (기본 비활성)
}
```

**구현된 변환 규칙:**
- 법률/회계/숫자 감지 → neutral 처리 (변환 스킵)
- 개행 정리, 연속 공백 제거
- 쉼표 보완 (짧은 텍스트: "먼저 " → "먼저, ")
- Friendly 모드: 경어 소프트 변환
- Expression tags (TTS Lab 감정 테스트 전용)

#### C. 문서 포맷 Intake (FileIntakeService.swift - 1209줄)
**구현된 형식:**
- ✅ TXT, MD, CSV: 기본 텍스트 (ingestPlainText)
- ✅ PDF: PDFKit 기반, 최대 20페이지 (ingestPDF)
- ✅ XLSX: CoreXLSX 기반, 마크다운 테이블 변환 (ingestXLSX)
- ✅ DOCX: ZIP 기반 언팩, Word XML 파싱 (ingestDOCX)
- ✅ PPTX: ZIP 기반 언팩, 슬라이드 마크다운 변환 (ingestPPTX)

**각 포맷 메타데이터:**
- PDF: 페이지 수, 작성자, 주제
- XLSX: 시트명, 행/열 수, 데이터 범위
- DOCX: 섹션 수, 헤더/푸터 감지
- PPTX: 슬라이드 수, 노트 텍스트, 스피커 노트

#### D. K-Skills 응답 구조화 (KSkillAssistRuntime.swift + KSkillAssistCardView.swift)
```swift
// 섹션 파싱:
struct ParsedSections {
    let title: String
    let message: String
    let checklist: [String]          // ✅ 준비 체크리스트
    let requiredInputs: [String]     // 필요한 입력
    let nextActions: [String]        // 다음에 할 일
    let hardBlockedActions: [String] // ⚠️ 직접 진행이 필요한 작업
}
```

#### E. 캐릭터별 TTS 설정 (CharacterVoiceProfile.swift)
```swift
// 캐릭터별 감정 스타일 매핑
CharacterVoiceProfileCatalog.profile(for: agentID)
// → 래키, 올리버, Chiko 등 기본 캐릭터 포함
// → defaultEmotionStyle: SupertonicEmotionStyle
```

#### F. Supertonic3 ONNX 런타임 (Supertonic3ONNXRunner.swift)
- ✅ 4-stage ONNX inference pipeline
- ✅ text_encoder → duration_predictor → vector_estimator → vocoder
- ✅ 44.1kHz PCM 변환

---

### 1.2 ❌ 미구현된 것들

#### A. HWP/HWPX 파일 읽기 (0% 구현)
```
FileIntakeService.ingest()
    ├─ case "txt", "md", "csv" ✅
    ├─ case "pdf" ✅
    ├─ case "xlsx" ✅
    ├─ case "docx" ✅
    ├─ case "pptx" ✅
    └─ case "hwp", "hwpx" ❌ ← 미구현
```

**필요한 것들:**
1. HWP 파일 포맷 파서 (ZIP 기반 + XML)
2. FileIntakePolicy.decision() 업데이트
3. ingestHWP(_ request) 함수
4. 한글 스타일 정보 추출 (글꼴, 크기, 색상, 굵기 등)

#### B. 고유명사/영문/숫자 정규화 사전 (0% 구현)
```swift
// 현재 SupertonicProsodyTextProcessor에는 있음:
- looksLikeFormalOrNumericText() ← ✅ 감지만 함
- 하지만 정규화 사전이 없음:
    - 한국 이름/회사명/지역명 사전
    - 영문 약자 발음 (AWS → "아더블유에스")
    - 숫자 읽기 규칙 ("2024" → "이천이십사" vs "영공이사")
```

#### C. 발음 규칙 레지스트리 (0% 구현)
```swift
// 필요한 규칙들:
- 받침 연음: "받침" [받침] vs "낡다" [낄다]
- 축약 발음: "되었다" → [됐다], "아니었다" → [아니었따]
- 특수 발음: "휴지" [휴지], "종이" [종이], "선생님" [선생님]
- 겹받침: "닭" [닭], "긷" [깟]
```

#### D. K-Skills 캐릭터별 톤 제어 (부분 구현)
```swift
// 현재 상태:
- CharacterVoiceProfile ✅ (기본 정의)
- SupertonicProsodyTextProcessor ✅ (감정 스타일)
- 하지만 K-Skills 응답에서는 아직 미사용:
    - korean.ktx-booking → 문체 자동 선택 ❌
    - korean.law-search → 정중한 톤 ❌
    - korean.accounting-tax → 명확한 톤 ❌
```

---

## 2. 세부 미구현 항목 목록

| 항목 | 현황 | 의존성 | 우선순위 |
|------|------|--------|---------|
| HWP 포맷 파서 | 0% | ZIP/XML parser | **P0** |
| FileIntakePolicy.decision() 업데이트 | 0% | HWP 파서 | **P0** |
| ingestHWP 함수 | 0% | HWP 파서 | **P0** |
| 고유명사 사전 (이름/회사/지역) | 0% | 수작업 | **P1** |
| 영문 약자 발음 규칙 | 10% (looksLike만) | 사전 구축 | **P1** |
| 숫자 읽기 정규화 | 0% | NLP | **P1** |
| 받침 연음 규칙 | 0% | 발음 규칙 DB | **P2** |
| K-Skills 캐릭터 톤 적용 | 0% | prosody processor | **P2** |
| TTSLabView 캐릭터 A/B 비교 UI | 30% (기본 구조) | 전체 규칙 | **P2** |

---

## 3. 실행 계획 (3개 Phase, 약 3-4주)

### Phase 1A: HWP 파일 읽기 기초 (3-4일) — **다음 주 시작**

**커밋 분리:**
```
1. docs/HWPFormatSpecification.md — HWP 파일 구조 문서
2. MyTeam/HWPFileExtractor.swift — ZIP 언팩 + XML 파싱 스켈레톤
3. MyTeam/FileIntakeService.swift — ingestHWP() 함수 추가
4. MyTeam/FileIntakePolicy.swift — hwp/hwpx 허용 추가
5. test: scripts/preflight_round277_hwp_intake.sh
```

**구현 범위:**
- HWP는 ZIP 기반 패키지 (한글과컴퓨터 표준)
- 최상위 `content.xml` → text 노드 추출
- 1차 구현: 서식 무시, 텍스트만 추출
- 마크다운 변환: 제목(## ~), 본문, 목록(- )만 구분

**테스트:**
- 단순 HWP 파일 (200줄 이내) 읽기
- HWPX (압축) 호환성 확인
- 한글 인코딩 (UTF-8) 안정성

---

### Phase 1B: 고유명사 + 숫자 정규화 (3-4일) — Phase 1A 후

**커밋 분리:**
```
1. MyTeam/KoreanProperNounDictionary.swift
   - Common Korean names (이름), companies (회사), regions (지역)
   - 한국 금융 용어, 제도명

2. MyTeam/KoreanNumberNormalizer.swift
   - "2024" → ["이천이십사", "영공이사"] (선택지 제공)
   - "100,000" → "백만"
   - 날짜/시간 읽기

3. MyTeam/EnglishAcronymDictionary.swift
   - AWS → "아더블유에스"
   - API → "에이피아이"
   - UI → "유아이" vs "유아이"

4. SupertonicProsodyTextProcessor 확장
   - preprocess() 함수에 정규화 적용
```

**테스트:**
- 혼합 텍스트: "2024년 AWS API 문서" 정규화
- 회사명 감지: "삼성전자", "카카오", "구글"
- 사람 이름 감지: "홍길동", "김철수"

---

### Phase 2: K-Skills 캐릭터 톤 제어 (4-5일) — Phase 1B 후

**커밋 분리:**
```
1. MyTeam/KSkillToneProfile.swift
   - 스킬별 기본 톤 정의
   - korean.ktx-booking → friendly + careful (안전성 강조)
   - korean.law-search → careful + confident
   - korean.accounting-tax → careful + neutral

2. KSkillAssistRuntime 확장
   - skillIDToTone() 맵핑 추가
   - formatMarkdown() → tone 파라미터 추가

3. KSkillAssistCardView 확장
   - 톤 선택 토글 (UI에서 수동 선택)
   - "정중함" / "친근함" / "기술" 선택지

4. SupertonicProsodyTextProcessor 음절 연음 규칙 추가
   - KoreanSyllableDecomposer + prosody 통합
```

**테스트:**
- "KTX 예매하는 방법 알려줘" → friendly 톤
- "임대차 계약 법령 조회" → careful 톤
- 톤 변경 시 읽기 자연스러움 확인

---

### Phase 3: TTSLabView 캐릭터 A/B 비교 UI (3-5일) — Phase 2 후

**커밋 분리:**
```
1. MyTeam/TTSLabCharacterCompareView.swift
   - 텍스트 입력 → 캐릭터 A/B 선택
   - 동시 재생 + 순차 재생

2. MyTeam/TTSEmotionTestPanel.swift
   - 감정 스타일 선택 (neutral ~ excited)
   - 실시간 감정 변화 청취

3. TTSLabView 통합
   - "캐릭터 비교" 섹션 추가
   - "감정 테스트" 섹션 추가
```

**테스트:**
- 래키 vs 올리버 동시 재생
- 같은 캐릭터, 다른 감정 비교
- 종결형 변화 ("알려줘" → "알려드릴까요")

---

## 4. 코드 점검 체크리스트

- [ ] **FileIntakePolicy.swift**
  - [ ] readableExtensions / plannedExtensions 현황 확인
  - [ ] decision() 함수 로직 확인 (zip 파일 처리 여부)
  
- [ ] **FileIntakeService.swift**
  - [ ] ingest() 함수에 hwp/hwpx 케이스 있는지 확인
  - [ ] DOCX/PPTX 구현 패턴 분석 (HWP 참고용)
  - [ ] archiveEntries() ZIP 언팩 로직 재사용 가능 여부

- [ ] **SupertonicProsodyTextProcessor.swift**
  - [ ] applyFriendlyTransforms() 구현 상세 검토
  - [ ] looksLikeFormalOrNumericText() 정규표현식 분석

- [ ] **KSkillAssistRuntime.swift**
  - [ ] formatMarkdown() 출력 구조 확인
  - [ ] skillIDToTone() 맵핑 필요 여부

- [ ] **CharacterVoiceProfile.swift / ModelCatalog.swift**
  - [ ] 캐릭터별 기본 감정 스타일 정의 현황
  - [ ] reference audio 경로 구조 확인

- [ ] **TTSLabView.swift**
  - [ ] 현재 실험 UI 구조
  - [ ] 새 섹션 추가 위치 (레이아웃 검토)

---

## 5. 예상 커밋 수

```
Phase 1A: HWP 기초
  ├─ HWPFormatSpecification.md
  ├─ HWPFileExtractor.swift
  ├─ FileIntakeService (+ingestHWP)
  ├─ FileIntakePolicy
  ├─ preflight_round277_hwp_intake.sh
  └─ TASK.md / DEVLOG.md 업데이트
  = 약 7개 커밋

Phase 1B: 정규화 사전
  ├─ KoreanProperNounDictionary.swift
  ├─ KoreanNumberNormalizer.swift
  ├─ EnglishAcronymDictionary.swift
  ├─ SupertonicProsodyTextProcessor (확장)
  ├─ test + preflight
  └─ TASK.md / DEVLOG.md
  = 약 6-7개 커밋

Phase 2: K-Skills 톤
  ├─ KSkillToneProfile.swift
  ├─ KSkillAssistRuntime (확장)
  ├─ KSkillAssistCardView (확장)
  ├─ SupertonicProsodyTextProcessor (음절)
  ├─ test + preflight
  └─ TASK.md / DEVLOG.md
  = 약 6개 커밋

Phase 3: TTSLabView UI
  ├─ TTSLabCharacterCompareView.swift
  ├─ TTSEmotionTestPanel.swift
  ├─ TTSLabView (통합)
  ├─ test + preflight
  └─ TASK.md / DEVLOG.md
  = 약 5개 커밋

Total: ~24-25개 커밋 예상
Timeline: 3-4주 (주 5-6일 작업 기준)
```

---

## 6. 브랜치 전략

### 현재
- `main`: 기본 infrastructure (최신 272개 커밋)
- `cloud/round252-supertonic-license-lock`: TTS notice gate (PR #2)
- `claude/myteam-product-completion-H97FZ`: 지정 개발 브랜치

### 추천 (사용자 선택 필요)

**옵션 A: main 기반 신규 브랜치** (권장)
```bash
git checkout main
git pull origin main
git checkout -b round-277-korean-hwp-intake
# Phase 1A: HWP + 정책 개발

git checkout main
git checkout -b round-278-korean-normalization
# Phase 1B: 고유명사 + 숫자 정규화

git checkout main
git checkout -b round-279-kskill-character-tones
# Phase 2: K-Skills 톤 제어

git checkout main
git checkout -b round-280-ttslab-character-compare
# Phase 3: TTSLabView UI
```

**옵션 B: claude/myteam-product-completion-H97FZ 기반**
```bash
git checkout claude/myteam-product-completion-H97FZ
# 전체 작업을 한 브랜치에서 진행
# (작지만 관련된 작업들)
```

---

## 7. 의존성 정리

```
Phase 1A (HWP 기초)
├─ No external deps (ZIP, XML은 Swift stdlib에 포함)
└─ FileIntakeResult.swift 구조 확인 필요

Phase 1B (정규화)
├─ No external deps
└─ SupertonicProsodyTextProcessor 구조 활용

Phase 2 (K-Skills 톤)
├─ Phase 1B 완료 필수
├─ KSkillAssistRuntime 구조 파악 필수
└─ CharacterVoiceProfile 확인 필수

Phase 3 (TTSLabView)
├─ Phase 2 완료 필수
├─ SwiftUI 레이아웃 경험
└─ 실시간 재생 테스트 환경 필요 (Mac 로컬)
```

---

## 다음 단계

1. **사용자 선택:**
   - Phase 1A부터 시작할 것인가?
   - 어느 브랜치에서 작업할 것인가? (옵션 A vs B)
   - 우선순위 조정 사항이 있는가?

2. **코드 점검 실행:**
   - 위의 "코드 점검 체크리스트" 항목들 확인
   - FileIntakePolicy 현황 재확인

3. **문서 준비:**
   - HWP 파일 포맷 스펙 (docs/HWPFormatSpecification.md)
   - 고유명사 사전 초안 (선택)

4. **테스트 샘플:**
   - 단순 HWP 파일 준비 (테스트용)
   - 한글 섞인 텍스트 샘플 준비

