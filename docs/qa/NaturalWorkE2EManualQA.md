# Natural Work E2E Manual QA

This document verifies that personal chat and team workroom route natural language requests through the common natural-work path without duplicate tool execution or scattered result bubbles.

| Case ID | Scenario | Input / Action | Expected result | Forbidden result | Actual result | PASS / FAIL / BLOCKED | Evidence | Notes |
|---|---|---|---|---|---|---|---|---|
| NW-001 | Personal chat company briefing | `삼성전자 알려줘` | One progress bubble, one final composite answer, no tool-bubble spray, DART missing key appears only as connection-needed section, finance wording says baseline public data and not investment advice, one composite artifact | Silent `삼성전자 2024` default, DART Cloudflare product path, real-time/current-price wording, buy/sell advice | Not run in this pass | BLOCKED | Pending manual chat QA | Reason: requires interactive chat run. Next: run in personal chat with current credentials. |
| NW-002 | Team workroom company briefing | `삼성전자 알려줘` in team workroom | WorkflowInputCoordinator path, same natural judgment as personal chat, room-scoped artifact | Team workflow bypasses natural route or global artifact only | Not run in this pass | BLOCKED | Pending team workroom QA | Reason: requires team workroom runtime. Next: run in workroom. |
| NW-003 | Personal chat stock price | `삼성전자 주가 알려줘` | Finance stock price lookup, baseline public data, not real-time, not investment advice | `현재가`, `실시간`, target price, buy/sell/recommendation wording | Not run in this pass | BLOCKED | Pending finance chat QA | Reason: requires live app request. Next: run with finance provider available. |
| NW-004 | Team workroom composite company work | `삼성전자 주가랑 공시랑 재무상황 알려줘` | Finance stock, DART, company statement combine into one composite work; missing DART key only blocks DART section; year/company gaps become question or missing section | Individual artifacts/bubbles per tool, fake DART success, silent finance defaults | Not run in this pass | BLOCKED | Pending team workroom QA | Reason: requires workroom runtime. Next: run with/without DART key. |
| NW-005 | Missing meeting content | `회의록 만들어줘` | Ask for meeting content and store pending clarification | Fake meeting minutes | Not run in this pass | BLOCKED | Pending clarification QA | Reason: requires chat state. Next: run missing-source request. |
| NW-006 | Pending answer merge | Paste meeting content after NW-005 | Merge with prior meeting-minutes request, generate draft, create artifact | Treat pasted text as unrelated new request | Not run in this pass | BLOCKED | Pending clarification QA | Reason: depends on NW-005 runtime state. Next: run after NW-005. |
| NW-007 | False positive news style | `뉴스 기사처럼 써줘` | Document/style rewrite path, no news lookup | `news.search` execution | Not run in this pass | BLOCKED | Pending false-positive QA | Reason: requires chat run. Next: inspect output/log. |
| NW-008 | False positive disclosure form | `공시 양식처럼 써줘` | Document/form writing path, no DART lookup | DART lookup | Not run in this pass | BLOCKED | Pending false-positive QA | Reason: requires chat run. Next: inspect output/log. |
| NW-009 | False positive stock-like table | `주가처럼 변동표 만들어줘` | Table/document creation path, no finance lookup | Finance lookup | Not run in this pass | BLOCKED | Pending false-positive QA | Reason: requires chat run. Next: inspect output/log. |
| NW-010 | Weather missing region | `날씨 알려줘` | Ask for region; no Seoul default | Silent Seoul lookup | Not run in this pass | BLOCKED | Pending weather clarification QA | Reason: requires chat run. Next: inspect question. |
| NW-011 | Weather with region | `광양 출장 날씨 알려줘` | Weather lookup for resolved Gwangyang region; credential failure shown as settings-needed, not success | Wrong region, invalid credentials shown as success | Not run in this pass | BLOCKED | Pending KMA QA | Reason: requires live provider state. Next: run with current KMA config. |
| NW-012 | Law search | `근로기준법 연차 조문 찾아줘` | Law search result with official-source framing and not legal advice | Legal-advice conclusion | Not run in this pass | BLOCKED | Pending law QA | Reason: requires live route/app run. Next: run law request. |
| NW-013 | False positive legal wording | `법적으로 자연스럽게 써줘` | Rewrite/risk wording path, no law search | Law lookup | Not run in this pass | BLOCKED | Pending false-positive QA | Reason: requires chat run. Next: inspect output/log. |

## Static Evidence

- `python3 scripts/smoke_natural_work_e2e.py`: expected static call-chain gate.
- `python3 scripts/validate_natural_work_routing.py`: expected routing fixture/static gate.

## Completion Rule

NW-001 through NW-013 must be PASS or have explicit BLOCKED reason and next action before main merge can even be reviewed. Any FAIL requires a fix commit and retest.
