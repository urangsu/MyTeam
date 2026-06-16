# Public Lookup Feature Inventory

This inventory tracks public-data lookup features that are visible in MyTeam. A visible lookup must either execute against a real source or show a clear failure/connection state.

| User-facing feature | Tool ID / Skill | Current execution path | Provider | Worker secret | Proxy route | BYOK fallback | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 뉴스 브리핑 | `news.search`, `korean.news-search` | Cloudflare proxy first, Naver BYOK fallback | Naver News Search | `NAVER_CLIENT_ID`, `NAVER_CLIENT_SECRET` | `GET /news/search?query={query}&display={1...20}` | Client ID + Client Secret | done |
| 공시 조회 | `dart.disclosures.search`, `korean.dart` | Cloudflare proxy first, OpenDART BYOK fallback | DART | `DART_API_KEY` | `GET /dart/recent?corpCode={corpCode}&days={1...30}&display={1...20}` or `corpName={name}` | OpenDART API Key | ready-after-worker-deploy |
| 날씨 조회 | `weather.current`, `korean.weather` | Cloudflare proxy first, KMA BYOK fallback | KMA VilageFcst | `KMA_SERVICE_KEY` | `GET /weather/kma/nowcast?nx={nx}&ny={ny}` | Public Data Service Key | ready-after-worker-deploy |
| 법령 검색 | `law.search`, `korean.law-search` | Cloudflare proxy first, Law.go.kr BYOK fallback | Korean Law | `LAW_OC` | `GET /law/search?query={query}&display={1...20}` | Law.go.kr OC | ready-after-worker-deploy |

## Product Truth Rules

- News briefings use search-result titles and descriptions, not article full text.
- DART results are disclosure lists and official links, not full disclosure analysis.
- KMA results are grid-based official weather data.
- Korean Law results are search results and official links, not legal advice.
- BYOK credentials are optional fallback for public-data lookups.
- If both proxy and BYOK fail, MyTeam must show failure, not success.

## Remaining Live Validation

Cloudflare production Worker must be updated from:

- `/Users/su/Desktop/MyTeam/workers/basic-lookup-api/worker.js`

## Main Merge Gate

Do not merge this public lookup proxy work to `main` while any required live route still returns `404` from the production Worker. `/health` must report `version: "0.2.0"` and list the public lookup routes before merge.

Required live endpoints after deployment:

- `GET /health`
- `GET /news/search?query=삼성전자&display=2`
- `GET /dart/recent?corpCode=00126380&days=7&display=2`
- `GET /weather/kma/nowcast?nx=63&ny=89`
- `GET /weather/kma/forecast?nx=63&ny=89`
- `GET /law/search?query=근로기준법&display=2`

## Live Gate Result

- checkedAt: 2026-06-16 KST
- workerVersion: 0.2.0
- news.search: PASS, `ok: true`
- dart.recent corpCode: BLOCKED, `provider_system_error`
- dart.recent corpName: BLOCKED, `provider_system_error`
- kma.nowcast: BLOCKED, `invalid_credentials`
- kma.forecast: BLOCKED, `invalid_credentials`
- law.search: PASS, `ok: true`
- blocker: main merge remains blocked until DART no longer returns provider system error and KMA credentials are accepted by the upstream provider. No live route returned 404 after Worker 0.2.0 deployment, but provider-level failures remain.
