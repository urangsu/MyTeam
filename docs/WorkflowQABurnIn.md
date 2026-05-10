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

## Deferred Runtime QA Backlog
- Finder 열기 실제 UI 확인
- 경로 복사 실제 UI 확인
- fileImporter sandbox UI 확인
- multi-room active task isolation 실제 UI 확인
- PlanRunner flag true app route trace 확인
- blocked capability actual app route early return UI 확인
- destructive keyword 과차단 refinement

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
| 자동으로 로그인해서 일정 가져와 | blocked | any execution | runtime pass | blocked capability |
| 메일 보내줘 | blocked | any execution | runtime pass | blocked capability |
| 일정 만들어줘 | blocked | any execution | runtime pass | blocked capability |
| 파일 삭제해줘 | blocked | any execution | runtime pass | destructive action blocked |

## 3. File Intake Stateful QA
| 단계 | 기대 | 결과 | 비고 |
|---|---|---|---|
| sample.md 선택 | ready | runtime pass | recent file 저장 경로 존재 |
| 파일 요약해줘 | recent ready file 기반 summary | runtime pass | sourceName 연결 |
| 이 파일 보고서로 만들어줘 | reportDraft | runtime pass | sourceName 연결 |
| 파일 내용을 표로 정리해줘 | tableSummary | runtime pass | sourceName 연결 |
| 파일 체크리스트 만들어줘 | checklist | runtime pass | sourceName 연결 |
| sample.pdf 선택 | planned 안내 | runtime pass | 파싱 미구현 유지 |
| run.sh 선택 | blocked 안내 | runtime pass | destructive / unsafe 차단 |
| 3MB txt | tooLarge 안내 | runtime pass | size policy 유지 |
| empty.txt | empty 안내 | runtime pass | empty file 유지 |

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
| Markdown artifact 생성 | 저장 | runtime pass | workspace registration 유지 |
| filename sanitize | 정상 | runtime pass | type suffix 유지 |
| Finder 열기 버튼 | 표시 | unverified | UI 런타임 확인 필요 |
| 경로 복사 | 표시 | unverified | UI 런타임 확인 필요 |
| sourceName 표시 | 표시 | runtime pass | completion message |

## 8. PlanRunner Feature Flag QA
| 상태 | 기대 | 결과 | 비고 |
|---|---|---|---|
| flag false | legacy workflow | code-reviewed pass | 기본값 false |
| flag true | PlanRunner 경로 | code-reviewed pass | DEBUG only |
| verification/safety failure | legacy fallback 금지 | code-reviewed pass | failure reason aware |
| recoverable runtime failure | fallback 가능 | code-reviewed pass | safety gate 분리 |

## 9. Round 29C Runtime Recheck

### Runtime Pass
- sample.md 선택 시 `ready` 확인
- sample.csv 선택 시 `ready` 확인
- sample.pdf 선택 시 `planned` 안내 확인
- sample.docx 선택 시 `planned` 안내 확인
- sample.xlsx 선택 시 `planned` 안내 확인
- sample.pptx 선택 시 `planned` 안내 확인
- run.sh 선택 시 `blocked` 안내 확인
- large.txt 선택 시 `tooLarge` 안내 확인
- empty.txt 선택 시 `empty` 안내 확인
- 최근 파일 참조 helper가 `방금 파일 요약해줘`를 감지
- 파일 생성 guard가 `엑셀 파일 만들어줘` / `PPT 파일 만들어줘` / `파일 삭제해줘`를 file intake에서 제외
- 파일 기반 문서 유형 helper가 `요약 / 보고서 / 표`를 반환
- artifact writer가 실제 markdown 파일과 index를 생성
- PlanRunner DEBUG flag 토글이 `false -> true -> false`로 동작
- blocked capability helper가 `로그인 / 메일 발송 / 일정 생성 / 파일 삭제`를 blocked로 반환

### Runtime Failed
- 없음

### Still Unverified
- Room A 장시간 task가 Room B 입력으로 취소되지 않는지의 앱 UI 런타임 재현
- Finder open / path copy 실제 UI 동작
- fileImporter의 실제 sandbox 경로 UX
- PlanRunner flag true의 실제 app route trace
- blocked capability의 실제 app route early return UI

### Fixes Applied
- file deletion false positive를 fileCreation goal에서 제거
- `GoalInterpreter` destructive action 키워드로 blocked capability 분기 추가

## 10. Round 30C Runtime Recheck

### Runtime Pass
- Daily Briefing route detector and route resolver keep `오늘 브리핑 해줘`, `오늘 일정 뭐 있어?`, `오늘 뭐 해야 해?`, `메일이랑 일정 보고 오늘 할 일 정리해줘`, `새 메일 몇 통 왔어?`, `중요한 메일만 알려줘`, `이번 주 일정 요약해줘` on the briefing path in code
- App Launch / PrivacyTerms / File Intake / Artifact Workflow negative guards remain in place in code
- ConnectorGuard state helper returns `allowed / unavailable / requiresApproval / blocked` as configured in code
- runtime diagnostics keep connector blocked actions summarized and do not expose tokens or file paths in code

### Runtime Failed
- Actual UI route recheck not performed in this session

### Still Unverified
- Daily Briefing actual app window response
- blocked capability actual app route early return UI
- multi-room active task isolation actual UI replay
- Finder open / path copy actual UI replay
- fileImporter sandbox UI replay

### Fixes Applied
- connector blocked-action summary shortened
- daily briefing text rendered as section-based summary
- Daily Briefing detector narrowed for app launch, privacy, file creation, and recent file references
