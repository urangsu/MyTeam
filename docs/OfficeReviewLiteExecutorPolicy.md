# Office Review Lite Executor Policy

## Round 248A-OFFICE-LITE

### 정책

- **1차 휴리스틱 기반**: meetingActionItems, filenameOrganization, reportTonePolish
- **2차 assistOnly**: accountingConsistency, vendorNameMismatch, budgetActualAnalysis, invoiceDescriptionAnomaly, taxInvoiceComparison, contractChecklist
- **제약**:
  - 실제 Excel/PDF 파싱 금지
  - 원본 파일 변경 금지 (결과는 artifact로만 생성)
  - 근거 위치 추적 미지원 (휴리스틱 기반)
  - 자동 분석 금지 (사용자 명시 요청 후 실행)

### 1차 Heuristic 구현

#### meetingActionItems (회의록 액션아이템 추출)
- 키워드 기반: "확인", "준비", "검토", "제출", "완료", "연락", "조율", "요청", "작성", "보완"
- 할당 패턴: "담당:", "예정:", "기한:", "기일:"
- 제약: 라인 단위 추출, 복합 문장 분석 한계

#### filenameOrganization (파일명 정리 제안)
- 주제/날짜/버전 추출로 패턴 제안
- 정규식: 날짜 패턴 (YYYY년 MM월, YYYY-MM-DD)
- 제약: 실제 파일명 변경 미지원, 조직 규칙 의존

#### reportTonePolish (보고서 말투 정리)
- 피동형 감지: "되었습니다", "되고 있습니다"
- 과도한 경어: 짧은 문장의 "-하겠습니다"
- 장황한 표현: "다양한 관점에서", "종합적으로 검토한 결과"
- 제약: 패턴 기반, 직접 재작성 제공 미지원

### 2차 AssistOnly

사용자가 다음 스킬을 요청할 때:
- `unsupported(message:)` 반환
- LLM 상담 가이드 메시지 제공
- 예: "계정과목 정합성 검토는 전문 회계 검토가 필요합니다. LLM 기반 상담을 원하시면 '계정과목 검토 도와줘'라고 말씀해 주세요."

### Limitations Disclaimer

OfficeReviewResultCardView에서 항상 표시:

```
휴리스틱 기반 결과
– 휴리스틱 기반 추출: 키워드(확인·준비·검토 등)로 후보를 식별합니다.
– 근거 위치 추적 미지원: 원문에서 정확한 위치를 표시하지 않습니다.
– 복합 문장 분석 한계: 여러 액션이 한 문장에 있으면 일부 누락될 수 있습니다.
```

### LocalSkillExecutor 통합

```swift
if let officeSkill = detectOfficeReviewLiteSkill(skillID: skillID, message: userMessage) {
    if is1PhaseSkill(officeSkill) {
        let outcome = OfficeReviewLiteExecutor.execute(...)
        switch outcome {
        case .success:
            return .handled(message: "", skillID: skillID)  // 자동 분석 없음
        case .unsupported(let msg):
            return .needsInput(message: msg, skillID: skillID)
        }
    }
}
```

### Round 248A-HOTFIX 수정 사항

- `LocalSkillExecutionResult.officeReviewResult(ReviewResult, skillID:)` case 추가
- `LocalSkillExecutor.executeIfPossible`이 `.success(result)` → `.officeReviewResult(result)` 반환
- 빈 message 반환 제거
- 2차 assistOnly 스킬도 `detectIfPossible`에서 intercept → execute 경로 진입
- `WorkflowOrchestrator.dispatch`에 `.officeReviewResult` case 처리 추가
- `OfficeReviewLiteExecutor.formatMarkdown(_:)` 추가 (채팅 메시지 포맷)
- `OfficeReviewResultCardView` macOS-safe 색상 조건부 적용
- evidence 레이블 "위치:" → "휴리스틱 참고:"
- 미사용 바인딩 경고 수정 (`if let date` → `if !dates.isEmpty`)

### 다음 단계 (Round 249TTS 이후)

- 2차 skillID들을 실제 LLM 상담 파이프라인으로 연결
- 실제 Excel 표 파싱 구현
- 근거 위치 추적 (row/column 지시)
- 실제 파일 분석 기반 검토 확대
