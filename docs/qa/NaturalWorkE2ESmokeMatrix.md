# Natural Work E2E Smoke Matrix

Static smoke validates code wiring. Manual result remains blank until a UI run is performed.

| Case ID | Input | Surface | Expected route | Expected tools | Expected behavior | Artifact expectation | Manual result | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| NW-001 | 삼성전자 알려줘 | Personal chat | company briefing | finance stock, finance index, DART if connected, finance statement, news | One progress bubble, one final composite answer, partial failures listed | One composite artifact | Pending | Static smoke |
| NW-002 | 삼성전자 알려줘 | Team workroom | company briefing | finance stock, finance index, DART if connected, finance statement, news | WorkflowInputCoordinator handles before legacy workflow | Room-scoped composite artifact | Pending | Static smoke |
| NW-003 | 삼성전자 주가 알려줘 | Personal chat | stock price | finance stock, finance index | 기준일 공공데이터 wording, no investment advice | One composite artifact | Pending | Static smoke |
| NW-004 | 삼성전자 주가랑 공시랑 재무상황 알려줘 | Team workroom | mixed company request | finance stock, DART, finance statement | Missing credentials become 확인 필요, not total failure | Room-scoped composite artifact | Pending | Static smoke |
| NW-005 | 회의록 만들어줘 | Personal chat | clarification | none | Ask for meeting notes/source text | No artifact until answered | Pending | Static smoke |
| NW-006 | 회의 내용 붙여넣기 | Personal chat | pending resume | document meeting minutes | Merge into pending request | One composite artifact after resume | Pending | Static smoke |
| NW-007 | 뉴스 기사처럼 써줘 | Personal chat | document draft | no news lookup | False positive blocked | Draft artifact only if source exists | Pending | Static smoke |
| NW-008 | 공시 양식처럼 써줘 | Personal chat | document draft | no DART lookup | False positive blocked | Draft artifact only if source exists | Pending | Static smoke |
| NW-009 | 주가처럼 변동표 만들어줘 | Personal chat | table/document draft | no finance lookup | False positive blocked | Draft/checklist artifact only | Pending | Static smoke |
| NW-010 | 날씨 알려줘 | Personal chat | clarification | none | Ask for region | No artifact until answered | Pending | Static smoke |
| NW-011 | 광양 출장 날씨 | Personal chat | weather | KMA weather | Region mapped, KMA failure not shown as success | One composite artifact or failed detail | Pending | Static smoke |
| NW-012 | 근로기준법 연차 조문 찾아줘 | Personal chat | law | law search | Official-source wording, legal advice disclaimer | One composite artifact | Pending | Static smoke |
| NW-013 | 법적으로 자연스럽게 써줘 | Personal chat | document rewrite | no law lookup | False positive blocked | Draft artifact only if source exists | Pending | Static smoke |
| NW-014 | 최근 실행 상세 열기 | Home / log | artifact detail | none | Open in-app detail, not only external markdown | Existing artifact body is readable | Pending | Static smoke |
| NW-015 | Home hidden tools 미노출 | Home | product surface policy | none | Spreadsheet/Google Sheets hidden; naturalOnly not primary | Not applicable | Pending | Product audit |

PASS criteria:

- Natural work plan does not fall through to legacy fallback.
- Fallback uses the legacy runner only.
- Progress appears as one bubble and final answer as one bubble.
- Composite work creates one artifact.
- Individual tool artifacts are suppressed in composite execution.
- Missing information asks a question.
- Pending answer resumes the original request.
- False positives do not trigger external lookups.
- Finance wording states 기준일 data, not real-time prices or investment advice.
- DART missing key is shown as connection/key issue.
- KMA credential failure is not shown as success.
