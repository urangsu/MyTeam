# MyTeam Basic Lookup Proxy

MyTeam Basic Lookup Proxy provides limited default lookups for user-facing read-only tools without requiring ordinary users to create API keys first.

Current production candidate:

- Base URL: `https://late-waterfall-c95c.urange.workers.dev`
- Health: `GET /health`
- Naver News: `GET /news/search?query={query}&display={1...20}`
- DART recent disclosures diagnostic: `GET /dart/recent?corpCode={corpCode}&days={1...30}&display={1...20}`
- DART company diagnostic: `GET /dart/company?corpCode={corpCode}`
- DART provider diagnostic: `GET /dart/diagnose?corpCode={corpCode}`
- KMA weather: `GET /weather/kma/nowcast?nx={nx}&ny={ny}`, `GET /weather/kma/forecast?nx={nx}&ny={ny}`
- Korean Law search: `GET /law/search?query={query}&display={1...20}`

## Product Policy

- The app must not contain `NAVER_CLIENT_ID` or `NAVER_CLIENT_SECRET` values.
- Worker secrets stay in Cloudflare and are never returned to the app.
- News output is a search-result briefing, not a full article summary.
- The app must preserve original links so users can inspect source articles.
- If the proxy is unavailable, MyTeam may fall back to user-provided BYOK credentials.
- DART is an exception: user-facing DART lookup uses app direct BYOK first. Cloudflare DART routes are operational diagnostics because production Worker calls to OpenDART currently fail with provider reachability `522`.
- DART app direct resolves user input before calling OpenDART. The MVP seed supports `삼성전자`, `삼성전자(주)`, `Samsung Electronics`, `005930`, and `00126380` as OpenDART corp code `00126380`.
- If both proxy and BYOK fail, show a failure state. Do not fake success.

## Cloudflare Setup

Cloudflare Dashboard:

1. Workers & Pages
2. `late-waterfall-c95c`
3. Settings
4. Variables and Secrets
5. Add secrets:
   - `NAVER_CLIENT_ID`
   - `NAVER_CLIENT_SECRET`
   - `DART_API_KEY`
   - `KMA_SERVICE_KEY`
   - `LAW_OC`
6. Deploy

## Naver Developer Setup

Naver Developers:

1. Application
2. My Applications
3. API settings
4. Enable Search API
5. Add web service URL:
   - `https://late-waterfall-c95c.urange.workers.dev`

## Response Shape

`/news/search` returns search-result snippets:

```json
{
  "ok": true,
  "provider": "naver-news",
  "query": "삼성전자",
  "count": 10,
  "elapsedMs": 844,
  "items": [
    {
      "title": "...",
      "description": "...",
      "sourceDomain": "kbs.co.kr",
      "originallink": "...",
      "link": "...",
      "pubDate": "Mon, 15 Jun 2026 21:18:00 +0900",
      "publishedAtISO": "2026-06-15T12:18:00.000Z",
      "dedupeKey": "...",
      "isNaverNews": true
    }
  ]
}
```

Error responses use this shape:

```json
{
  "ok": false,
  "error": "upstream_error",
  "provider": "naver-news",
  "status": 403,
  "message": "News provider returned an error."
}
```

Known error codes:

- `method_not_allowed`
- `not_found`
- `query_too_short`
- `query_too_long`
- `missing_worker_secrets`
- `invalid_credentials`
- `provider_permission_denied`
- `provider_quota_exceeded`
- `provider_system_error`
- `invalid_upstream_json`
- `upstream_error`
- `invalid_provider_request`
- `no_results`

## App Integration

MyTeam uses:

1. Proxy first: `MyTeamBasicLookupProxyClient`
2. BYOK fallback: direct provider connectors
3. Failure state if neither path succeeds

The UI must say:

- `뉴스 검색 결과 기반 브리핑`
- `뉴스 검색 결과의 제목과 설명을 기준으로 정리`
- `원문 링크에서 확인`

The UI must not say:

- `기사 전문을 요약했습니다`
- `본문을 분석했습니다`
- `원문 전체를 검토했습니다`
- `전문 요약`

## Follow-Up Worker Hardening

- Add optional `MYTEAM_PROXY_TOKEN` guard.
- Add per-IP or per-device rate limiting.
- Add `/version`.
- Deploy Worker source from `workers/basic-lookup-api/worker.js` before marking DART, KMA, or Korean Law live.

## Worker Source

The recoverable Worker source lives at:

- `/Users/su/Desktop/MyTeam/workers/basic-lookup-api/worker.js`
- `/Users/su/Desktop/MyTeam/workers/basic-lookup-api/README.md`

The production Worker is still deployed through Cloudflare Dashboard. If the Dashboard code is edited, copy the audited source back into this directory before changing the app integration.

## Optional Token Guard

`MYTEAM_PROXY_TOKEN` is a future abuse-reduction gate, not strong authentication. A token embedded in a macOS app can be extracted, so do not present it as a security boundary.

Future behavior:

- If `MYTEAM_PROXY_TOKEN` is configured in Cloudflare, require `X-MyTeam-Proxy-Token`.
- If it is not configured, skip token validation.
- Never commit the token value.

## Rate Limit Strategy

The MVP Worker is intentionally simple:

- GET routes only
- query length between 2 and 80
- `display` maximum 20
- no article crawling
- provider quota errors mapped to app-friendly failures

Future options:

- Cloudflare WAF / Rate Limiting Rules
- Cloudflare KV daily counters
- Durable Objects per-client limiter
- Supabase-backed account quota

## Public Lookup Route Policy

These routes are implemented in the repository Worker source. Do not mark them production-live until the Cloudflare Worker is redeployed from this source and the live endpoint checks pass.

### DART

Routes:

- `GET /dart/recent?corpName=삼성전자&days=7` (diagnostic route only; app direct does not use Worker `corpName`)
- `GET /dart/recent?corpCode=00126380&days=7`
- `GET /dart/company?corpCode=00126380`
- `GET /dart/diagnose?corpCode=00126380`

Required secret:

- `DART_API_KEY`

Product path:

- User-facing DART lookup does not use the Cloudflare Worker by default.
- MyTeam app reads the user's personal OpenDART API Key from Keychain and calls OpenDART directly.
- If no personal key is connected, the app must show "DART 개인 API 키 연결 필요" rather than trying the Worker route.

OpenDART guide alignment:

- `GET /dart/recent` calls the official `https://opendart.fss.or.kr/api/list.json` endpoint.
- Worker parameter `corpCode` maps to official OpenDART `corp_code`.
- The Worker sends `crtfc_key`, `corp_code` when present, `bgn_de`, `end_de`, `sort=date`, `sort_mth=desc`, `page_no=1`, and `page_count=20`.
- The Worker does not send `last_reprt_at`; OpenDART default `N` remains in effect.
- `corpName` is not an official OpenDART `list.json` parameter. User-facing app direct lookup resolves `corpName` or stock code to `corp_code` before calling OpenDART. Worker-side `corpName` remains diagnostic-only and best-effort.
- The current app direct seed supports Samsung Electronics only. Full cache is a follow-up: download OpenDART corpCode ZIP, parse `CORPCODE.xml`, cache company name / stock code / corp code, add TTL, and support manual refresh.

Response policy:

- disclosure list and official DART links only
- no full disclosure analysis in the basic lookup proxy
- source URL required for every item
- provider reachability failures may return `provider_system_error` only when `stage`, `status`, and `classification: provider_reachability_failure` are present
- DART fetch reachability failures should also return `retryable: true` and `mergeGate: conditional-pass`
- do not treat DART `522` as `no_results`
- `DART_API_KEY` is trimmed before use, but never returned or logged.
- Diagnostic responses may include `keyLength`; they must never include the key value or a full upstream URL containing `crtfc_key`.
- `/dart/company` returns only minimal non-sensitive company fields and omits company registration numbers, business registration numbers, phone, and address fields.
- `/dart/diagnose` calls `company.json` and `list.json` to distinguish credential, provider reachability, and list-specific failures. It is operational diagnostic output and is not exposed in the app UI.
- Live production diagnostic status as of 2026-06-17: `/dart/recent` returns OpenDART fetch failure `522`; `/dart/company` and `/dart/diagnose` timed out in a 12s client check. These routes remain non-user-facing diagnostics.

### KMA

Routes:

- `GET /weather/kma/nowcast?nx=63&ny=89`
- `GET /weather/kma/forecast?nx=63&ny=89`

Required secret:

- `KMA_SERVICE_KEY`

Response policy:

- pass grid coordinates, not raw address strings
- do not retain user location
- normalize public-data failures into app-friendly error codes

### Korean Law

Route:

- `GET /law/search?query=근로기준법`

Required secret:

- `LAW_OC`

Response policy:

- official legal source link required
- no legal-advice phrasing
- citation verification remains a separate MyTeam skill/runtime concern
