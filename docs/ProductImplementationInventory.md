# Product Implementation Inventory

**기준**: 2026-07-18 working tree
**목적**: 코드 존재 여부, Release 노출 여부, 실사용 검증 여부를 분리해 출시 판단 오류를 막는다.

이 문서의 `구현됨`은 코드 경로가 있다는 뜻이다. `Release 사용 가능`이나 live QA 완료를 뜻하지 않는다. 세부 surface 정책은 `docs/qa/ProductCompletenessInventory.md`, 실데이터 검증은 `docs/qa/LiveProviderQAMatrix.md`가 기준이다.

## 현재 제품 상태

| 영역 | 코드 상태 | Release 상태 | 남은 검증/작업 |
| --- | --- | --- | --- |
| 개인 대화·팀 협업·Natural Work | 구현됨 | 핵심 surface | 현재 빌드에서 APPTERM/NW/ART/HOME 수동 RC 매트릭스 재실행 |
| Google Calendar read-only OAuth | 구현됨 | live QA 전 비활성 | no-token, valid-token, 만료·권한 실패 QA |
| Google Sheets read-only | 구현됨 | 일반 surface 숨김 | URL/range 입력 및 OAuth 성공·실패, 결과 artifact QA |
| 연결 상태·credential 설정 | 구현됨 | provider별 fail-closed | 실제 Keychain 교체·삭제·만료·오프라인 수명주기 QA |
| PDF/DOCX/XLSX/PPTX 파일 intake | 구현됨 | 보조 surface | 포맷별 추출·artifact 경로는 존재하나, 원본 서식 보존 편집이나 모든 표의 심층 분석을 약속하지 않음 |
| 문서·XLSX·PPTX artifact 생성 | 구현됨 | 승인된 로컬/draft 흐름 | 동시 저장, 재열기, 해시·room 귀속 ART 수동 QA |
| DART 공시 검색 | direct BYOK 코드 구현됨 | live QA 전 비활성 | no-key, valid-key, invalid-key 및 stock-code resolver QA |
| 뉴스·법령·주가·지수·날씨 | Worker/client 코드 구현됨 | live QA 전 비활성 | Worker health와 provider별 실제 응답·오류·오탐 QA. health는 2026-07-18 재검증 통과 |
| Supertonic3·BubbleSpeech | 구현됨 | 배포 정책에 따라 제한 | 실제 청취, 중단, 연속 발화, 종료 인사 QA |
| 캐릭터 sprite | 치코 runtime 구현, 일부 캐릭터 정적 이미지 | 치코 사용 가능 | 치코 전체 상태·패널 이동 시각 QA, 세나/카이/유나 DLC art 제작 |
| 캐릭터 상점·유료 unlock | 미완성 | 숨김 | StoreKit 상품·복원·영수증·sandbox QA 후 노출 |

## 의도적으로 미구현 또는 금지된 범위

| 항목 | 상태 | 제품 원칙 |
| --- | --- | --- |
| Gmail send | 미구현 | 외부 전송은 명시 승인 계약 전 노출 금지 |
| Calendar 생성·수정·삭제 | 미구현 | read-only OAuth와 분리하고 write 승인 흐름 필요 |
| Google Sheets write | 미구현 | 현재 구현은 read-only이며 수정 완료를 암시하면 안 됨 |
| 자동 화면·Finder 지속 관찰 | developer/부분 기능 | 사용자 확인 없는 지속 캡처 금지 |
| 사용자 설치형 MCP·로컬 agent·Python backend | App Store 기능으로 금지 | Swift 앱 내부 coordination을 사용 |

## 출시 판정

- 정적 validator, XCTest, Debug/Release build 통과는 코드·패키징 증거다. 포인터 감각, 화면 layering, 실제 음성, 동시성, 실 provider 성공을 증명하지 않는다.
- `validate_release_qa_evidence.py --release-strict`는 provider가 `PASS` 또는 명시적 `DISABLED`인지 확인한다. 비활성 provider의 실사용 성공을 증명하지 않는다.
- `validate_release_qa_evidence.py --strict`가 실패하는 동안 현재 빌드를 RC 수동 검증 완료로 표시하지 않는다.
- generated Release capability manifest는 활성화할 provider의 live QA가 끝난 뒤 그 증거로 생성한다. 비활성 기능을 켜기 위해 placeholder manifest를 만들지 않는다.

## 다음 우선순위

1. 현재 commit/build metadata로 APPTERM/HOME 수동 QA.
2. NW/ART 동시 실행·저장·재열기 QA.
3. 치코의 패널 이동과 전체 animation-state 시각 sweep, SpriteKit object/leak 재계측.
4. 출시 범위에 포함할 provider만 valid/no-key/failure live QA 후 capability manifest에 활성화.
5. 세나/카이/유나 sprite와 StoreKit은 별도 디자인·상거래 작업으로 유지.
