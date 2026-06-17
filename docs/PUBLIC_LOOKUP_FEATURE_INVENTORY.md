# Public Lookup Feature Inventory

This inventory tracks public-data lookup features that are visible in MyTeam. A visible lookup must either execute against a real source or show a clear failure/connection state.

| User-facing feature | Tool ID / Skill | Current execution path | Provider | Worker secret | Proxy route | BYOK fallback | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 뉴스 브리핑 | `news.search`, `korean.news-search` | Cloudflare proxy first, Naver BYOK fallback | Naver News Search | `NAVER_CLIENT_ID`, `NAVER_CLIENT_SECRET` | `GET /news/search?query={query}&display={1...20}` | Client ID + Client Secret | done |
| 공시 조회 | `dart.disclosures.search`, `korean.dart` | Cloudflare proxy first, OpenDART BYOK fallback | DART | `DART_API_KEY` | `GET /dart/recent?corpCode={corpCode}&days={1...30}&display={1...20}` or `corpName={name}` | OpenDART API Key | conditional-pass |
| 날씨 조회 | `weather.current`, `korean.weather` | Cloudflare proxy first, KMA BYOK fallback | KMA VilageFcst | `KMA_SERVICE_KEY` | `GET /weather/kma/nowcast?nx={nx}&ny={ny}` | Public Data Service Key | conditional-pass |
| 법령 검색 | `law.search`, `korean.law-search` | Cloudflare proxy first, Law.go.kr BYOK fallback | Korean Law | `LAW_OC` | `GET /law/search?query={query}&display={1...20}` | Law.go.kr OC | done |

## Product Truth Rules

- News briefings use search-result titles and descriptions, not article full text.
- DART results are disclosure lists and official links, not full disclosure analysis.
- DART `corpCode` maps to OpenDART `corp_code`. DART `corpName` is MyTeam Worker best-effort post-filtering, not an official OpenDART `list.json` parameter.
- KMA results are grid-based official weather data.
- Korean Law results are search results and official links, not legal advice.
- BYOK credentials are optional fallback for public-data lookups.
- If both proxy and BYOK fail, MyTeam must show failure, not success.

## Remaining Live Validation

Cloudflare production Worker must be updated from:

- `/Users/su/Desktop/MyTeam/workers/basic-lookup-api/worker.js`

## Main Merge Gate

Do not merge this public lookup proxy work to `main` while any required live route still returns `404` from the production Worker. `/health` must report the current Worker source `version`, a non-empty `build` marker, and list the public lookup routes before merge.

Required live endpoints after deployment:

- `GET /health`
- `GET /news/search?query=삼성전자&display=2`
- `GET /dart/company?corpCode=00126380`
- `GET /dart/recent?corpCode=00126380&days=30&display=2`
- `GET /dart/diagnose?corpCode=00126380`
- `GET /weather/kma/nowcast?nx=63&ny=89`
- `GET /weather/kma/forecast?nx=63&ny=89`
- `GET /law/search?query=근로기준법&display=2`

## KMA Secret Checklist

- Confirm the KMA VilageFcst API application is approved in the public data portal.
- Confirm the service key is active.
- Prefer the Decoding key value in `KMA_SERVICE_KEY`.
- If using the Encoding key, confirm Worker `normalizePublicDataServiceKey()` is deployed.
- Confirm the Cloudflare variable type is Secret, not plaintext.

## Live Gate Result

- checkedAt: 2026-06-17 KST
- workerVersion: 0.2.1
- workerBuild: public-lookup-0.2.1
- news.search: PASS, HTTP 200, `ok: true`, provider `naver-news`
- dart.recent corpCode: CONDITIONAL PASS, HTTP 502, `provider_system_error`, provider `dart`, status `522`, stage `dart_fetch`, classification `provider_reachability_failure`, mergeGate `conditional-pass`
- dart.recent corpName: CONDITIONAL PASS, HTTP 502, `provider_system_error`, provider `dart`, stage `dart_fetch`, classification `provider_reachability_failure`, mergeGate `conditional-pass`
- kma.nowcast: CONDITIONAL PASS, HTTP 502, `invalid_credentials`, provider `kma`, status `401`, baseDate `20260617`, baseTime `2030`, grid `63,89`
- kma.forecast: CONDITIONAL PASS, HTTP 502, `invalid_credentials`, provider `kma`, status `401`, baseDate `20260617`, baseTime `2030`, grid `63,89`
- law.search: PASS, HTTP 200, `ok: true`, provider `korean-law`, official `sourceURL` values present, legal advice notice present
- appFailureSurface: PASS, proxy `no_results` is shown as an empty-result state; `invalid_credentials`, `provider_permission_denied`, and `provider_system_error` throw through the proxy client and render as failure or personal-key fallback, not success cards.
- blocker: none for the proxy-to-main merge gate. DART stabilization remains a follow-up because the provider request still fails at `dart_fetch`, but the deployed Worker now returns provider/stage/status/classification and the app renders that state as failure rather than success.

## App Manual QA

- checkedAt: 2026-06-17 KST
- appBuild: post-merge code path review complete; full tap-through QA remains
- News: PASS by code path and live route. Result cards show source domain and links, and the notice stays scoped to titles/descriptions rather than article full text.
- Law: PASS by code path and live route. Result cards keep official `sourceURL` links and the legal-disclaimer notice.
- KMA: CONDITIONAL PASS by code path and live route. Current expected result is a failure card with credential guidance, not a success summary.
- DART: CONDITIONAL PASS by code path and live route. Current expected result is a failure card with provider reachability guidance, not a disclosure summary.
- fakeSuccess: PASS. `no_results` stays an empty-result state, and KMA/DART provider failures do not render as success cards.
- notes: full in-app button-by-button manual QA is still pending; this section records the post-merge router/client surface and live proxy verification.
