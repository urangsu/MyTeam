# Office Review Evidence Honesty Policy

## Round 248A-OFFICE-LITE

### 핵심 약속: "하지 않는 것을 하는 것처럼 말하지 않는다"

#### Evidence Location Tracking (미지원)

**선언:**
```
근거 위치 추적 미지원: 원문에서 정확한 위치를 표시하지 않습니다.
```

**이유:** 휴리스틱 기반 추출이므로 정확한 위치 지시가 불가능

**절대 금지 표현:**
- ❌ "A 행 B 열에서 발견..." (실제 테이블 파싱이 없음)
- ❌ "Line 42에 문제..." (정확한 라인 번호 추적 미실시)
- ❌ "PDF page 3, 첫 번째 표..." (PDF 파싱 미구현)

**허용 표현:**
- ✅ "line 리스트의 첫 번째 항목에서..." (휴리스틱 결과 범위 내)
- ✅ "주제·날짜 기반 패턴 제안..." (알고리즘 설명)

#### Original File Mutation (금지)

**선언:**
```
원본 파일 변경 미지원: 검토 결과만 제공하며 원문 파일을 수정하지 않습니다.
```

**절대 금지 행동:**
- ❌ `FileManager.removeItem(at:)` 또는 file write in docURL
- ❌ `UNUserNotificationCenter`로 "파일 저장" 제안 후 실제 저장
- ❌ 결과 artifact의 content를 원본 파일로 덮어쓰기
- ❌ "파일명을 변경했습니다" 메시지 후 실제 rename 수행

**허용 행동:**
- ✅ Artifact로 제안 문서 생성
- ✅ "이 파일명을 사용해 보세요" 가이드 제시
- ✅ "저장할지 묻는" 대화 후 사용자가 직접 저장

#### Real Parsing Claims (금지)

**절대 금지:**
- ❌ `extractActualTableData()` 같은 이름으로 휴리스틱 결과 표시
- ❌ "Excel에서 추출한 정확한 수치..." (실제는 텍스트 라인 기반)
- ❌ "모든 거래처를 비교..." (텍스트 검색 기반, 누락 가능)

**투명한 표현:**
- ✅ `extractActionItems()` (추출 의도 명확)
- ✅ "키워드 기반 추출..." (알고리즘 명시)
- ✅ "휴리스틱 기반 제안..." (한계 선언)

### 체크리스트

**코드 리뷰:**
- [ ] ExecutionOutcome에 `unsupported(message:)` case 사용 (2차 skills)
- [ ] Limitations 배열에 3개 이상 한계 항목 포함
- [ ] Evidence 필드에 실제 위치 추적 또는 "위치 추적 미지원" 명시
- [ ] "근거 위치 추적\|evidence location tracking\|evidenceLinked" 주석 포함

**UI 리뷰:**
- [ ] OfficeReviewResultCardView에 limitations disclaimer 오렌지 박스
- [ ] "휴리스틱 기반" 태그 표시
- [ ] 원본 파일 변경 가능성 제시 금지
- [ ] Evidence 표시 시 "line 42: ..." 형식 (정확하지 않음 명시)

**문서화:**
- [ ] Round 248A 정책 문서에 "미지원" 명시
- [ ] 다음 라운드 계획에서만 지원 예정 (현재 라운드에서 약속 금지)
- [ ] 사용자 안내 메시지는 "...도와드릴 수 있습니다" (확정 아님)

### Round 249TTS 이후 진화 계획

1. **Real Parsing Support** (선택사항)
   - Actual Excel 테이블 파싱
   - PDF 텍스트 추출 + 표 인식
   - Row/column 정확한 위치 링크

2. **Evidence Linked Status** (OfficeReviewExecutionStatus.evidenceLinked)
   - 증거 위치 추적 가능
   - 사용자에게 "근거 위치가 포함됩니다" 명시

3. **Auto-save Proposal** (사용자 동의 후)
   - "파일명 변경을 적용할까요?" 대화
   - 사용자 명시 승인 후에만 실행

현재 라운드: **투명성 > 기능성**
