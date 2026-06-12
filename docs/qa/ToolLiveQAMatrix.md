# Tool Live QA Matrix

Date: 2026-06-11

| Tool ID | Provider | Credential | Sample Input | Expected Result | Zero Result | Error Behavior | Manual QA |
|---|---|---|---|---|---|---|---|
| `weather.current` | KMA | Service Key | `광양 날씨` | Current weather card with region/grid metadata | Explain no matching forecast item | Show credential/validator/network failure, not success | Pending |
| `dart.disclosures.search` | DART | API Key | `포스코 공시` | Recent disclosure list with source links | Show no disclosures found | Show OpenDART failure code/body parser result | Pending |
| `news.search` | Naver News | Client ID + Secret | `최신 뉴스 반도체` | News list with source links and cleaned HTML | Show no news found | Show auth/rate/network failure | Pending |
| `law.search` | Korean Law | Law OC | `근로기준법 조문 찾아` | Official law/article result with source policy | Show no matching law/article | Never mark legal citation verified without official source | Pending |
| `calendar.events.today` | Google Calendar | OAuth readonly | `오늘 일정` | Today's events with time/location summary | Show today's schedule is empty only after API success | Needs connection/reauth/forbidden split | Pending |
| `spreadsheet.googleSheets.read` | Google Sheets | OAuth readonly | Sheets URL or ID | Sheet/range preview and row count | Show empty range | Needs connection/permission/range parse failure split | Pending |
| `document.meetingMinutes` | Local draft | None | Meeting notes | Draft meeting minutes | Draft with missing fields noted | Never claim saved/exported unless artifact is written | Pending |
| `spreadsheet.postprocess` | Local draft | None | Pasted table | Cleanup/check plan | Draft with insufficient data noted | Never claim Excel file modified | Pending |
