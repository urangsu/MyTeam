# Workflow QA Burn-in

## 환경
- macOS: current local machine
- Xcode: current local Xcode toolchain
- Build: Debug build succeeded
- Branch: main
- Commit: local working tree

## 1. Build
- Result: PASS
- Notes: `xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Debug build`

## 2. Router Regression
| 입력 | 기대 route | 금지 route | 결과 | 비고 |
|---|---|---|---|---|
| 오늘 기분 어때? | directChat | universalDocument | code-reviewed pass | 잡담 유지 |
| 그냥 정리해봐 | directChat 또는 teamDiscussion | universalDocument | code-reviewed pass | vague organize guard |
| 아래 내용 업무용으로 정리해줘 | universalDocument | artifactWorkflow | code-reviewed pass | document work |
| 이 내용 요약해줘 | universalDocument.summary | artifactWorkflow | code-reviewed pass | summary |
| 검토보고서 초안 만들어줘 | universalDocument.reportDraft | artifactWorkflow | code-reviewed pass | report draft |
| 기능 목록을 표로 정리해줘 | universalDocument.tableSummary | artifactWorkflow | code-reviewed pass | table summary |
| PPT 만들어줘 | artifactWorkflow | fileIntakeDocument | code-reviewed pass | file intake should not intercept |
| PPT 파일 만들어줘 | artifactWorkflow | fileIntakeDocument | code-reviewed pass | file intake should not intercept |
| 엑셀 파일 만들어줘 | artifactWorkflow | fileIntakeDocument | code-reviewed pass | file intake should not intercept |
| IMMM 앱스토어 설명문 만들어줘 | appLaunch | universalDocument | code-reviewed pass | app launch priority |
| 개인정보처리방침 초안 만들어줘 | privacyTerms | universalDocument | code-reviewed pass | privacy terms priority |
| 자동으로 로그인해서 일정 가져와 | blocked | any execution | code-reviewed pass | blocked capability |
| 메일 보내줘 | blocked | any execution | code-reviewed pass | blocked capability |
| 일정 만들어줘 | blocked | any execution | code-reviewed pass | blocked capability |
| 파일 삭제해줘 | blocked | any execution | code-reviewed pass | destructive action blocked |

## 3. File Intake Stateful QA
| 단계 | 기대 | 결과 | 비고 |
|---|---|---|---|
| sample.md 선택 | ready | code-reviewed pass | recent file 저장 경로 존재 |
| 파일 요약해줘 | recent ready file 기반 summary | code-reviewed pass | sourceName 연결 |
| 이 파일 보고서로 만들어줘 | reportDraft | code-reviewed pass | sourceName 연결 |
| 파일 내용을 표로 정리해줘 | tableSummary | code-reviewed pass | sourceName 연결 |
| 파일 체크리스트 만들어줘 | checklist | code-reviewed pass | sourceName 연결 |
| sample.pdf 선택 | planned 안내 | code-reviewed pass | 파싱 미구현 유지 |
| run.sh 선택 | blocked 안내 | code-reviewed pass | destructive / unsafe 차단 |
| 3MB txt | tooLarge 안내 | code-reviewed pass | size policy 유지 |
| empty.txt | empty 안내 | code-reviewed pass | empty file 유지 |

## 4. Multi-room Active Task QA
| 단계 | 기대 | 결과 | 비고 |
|---|---|---|---|
| Room A 긴 보고서 요청 | Room A task active | code-reviewed pass | activeTasksByRoom 유지 |
| Room B 글자 수 세기 | Room B 즉시 완료 | code-reviewed pass | 방간 취소 없음 |
| Room A 나중 완료 | Room A 유지 | unverified | 실제 런타임 재생 필요 |
| room isolation | B가 A를 cancel하지 않음 | code-reviewed pass | room별 task map |

## 5. Blocked Capability QA
| 입력 | 기대 | 결과 | 비고 |
|---|---|---|---|
| 자동으로 로그인해서 일정 가져와 | blocked | code-reviewed pass | early return |
| 메일 보내줘 | blocked | code-reviewed pass | early return |
| 일정 만들어줘 | blocked | code-reviewed pass | early return |
| 파일 삭제해줘 | blocked | code-reviewed pass | early return |

## 6. ResultVerifier / Recovery QA
| 케이스 | 기대 | 결과 | 비고 |
|---|---|---|---|
| 빈 결과 | 저장 금지 | code-reviewed pass | error gate |
| 매우 짧은 결과 | warning | code-reviewed pass | 검토 메모 톤 |
| API key/token 패턴 | 저장 금지 | code-reviewed pass | sensitive keyword gate |
| 정상 markdown | 저장 | code-reviewed pass | artifact 저장 경로 유지 |
| verification 실패 후 재생성 1회 | 1회 재시도 | code-reviewed pass | recovery policy |
| 재생성 실패 | 저장 금지 | code-reviewed pass | fallback only for recoverable runtime error |

## 7. Artifact Persistence QA
| 케이스 | 기대 | 결과 | 비고 |
|---|---|---|---|
| Markdown artifact 생성 | 저장 | code-reviewed pass | workspace registration 유지 |
| filename sanitize | 정상 | code-reviewed pass | type suffix 유지 |
| Finder 열기 버튼 | 표시 | unverified | UI 런타임 확인 필요 |
| 경로 복사 | 표시 | unverified | UI 런타임 확인 필요 |
| sourceName 표시 | 표시 | code-reviewed pass | completion message |

## 8. PlanRunner Feature Flag QA
| 상태 | 기대 | 결과 | 비고 |
|---|---|---|---|
| flag false | legacy workflow | code-reviewed pass | 기본값 false |
| flag true | PlanRunner 경로 | code-reviewed pass | DEBUG only |
| verification/safety failure | legacy fallback 금지 | code-reviewed pass | failure reason aware |
| recoverable runtime failure | fallback 가능 | code-reviewed pass | safety gate 분리 |

## 실패 / 미확인
- Room A 실제 장시간 task가 Room B 입력으로 취소되지 않는지의 런타임 재현은 미확인
- Finder open / path copy는 실제 UI 런타임 확인이 필요
- fileImporter의 실제 sandbox 동작은 런타임 재현이 필요
- PlanRunner flag true 경로의 실제 UI 토글은 런타임 재현이 필요
