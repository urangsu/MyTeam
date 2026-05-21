# Screen Observation Policy

**Round 243A-OBSERVE**

---

## 현재 상태

화면 관찰 기능은 **planned** 상태. 정책 + stub만 구현됨.

---

## 하드 블록 (변경 불가)

| 항목 | 값 | 이유 |
|---|---|---|
| 상시 캡처 | 하드 블록 | 사용자 동의 없이 화면 상시 기록 = 심각한 프라이버시 침해 |
| 자동 OCR | 금지 | 화면의 민감 정보(비밀번호, 금융 정보) 자동 수집 위험 |
| 스크린샷 원본 장기 저장 | 금지 | 임시 사용 후 즉시 폐기 |

---

## 허용 예정 (future phase)

- 단발성 사용자 명시 요청만
- 예: "지금 화면 설명해줘", "이 화면 뭔지 알려줘"
- CGRequestScreenCaptureAccess() 권한 요청 후 실행
- 스크린샷은 단발성으로만 사용, 원본 저장 금지

---

## 구현 파일

`ScreenObservationPolicy.swift` — hard block constants + permission stub

---

## 사용자 안내

현재: "화면 읽기는 다음 업데이트에서 제공됩니다."
상시 캡처 관련: "MyTeam은 화면을 항상 캡처하지 않습니다. 필요할 때만 직접 요청해 주세요."

## Round 247A-OBSERVE-RUNTIME 확인

- 화면 캡처 planned notice route 추가 (WorkflowOrchestrator)
- 트리거: "현재 화면 설명해줘", "화면 읽어줘", "지금 보고 있는 거 분석해줘"
- 응답: ObservationPresentationPolicy.screenSnapshotPlannedMessage()
  > "현재 화면 읽기는 단발성 권한 기반 기능으로 준비 중입니다. 상시 화면 감시는 하지 않습니다."
- ToolContractValidator: validateScreenSnapshotPlannedNoticePolicy 추가
- 상시 화면 감시 ScreenObservationPolicy.continuousCaptureAllowed = false 유지
