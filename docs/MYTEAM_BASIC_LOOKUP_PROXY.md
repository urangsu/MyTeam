# MyTeam Basic Lookup Proxy

MyTeam Basic Lookup Proxy provides limited default lookups for user-facing read-only tools without requiring ordinary users to create API keys first.

Current production candidate:

- Base URL: `https://late-waterfall-c95c.urange.workers.dev`
- Health: `GET /health`
- Naver News: `GET /news/search?query={query}&display={1...20}`

## Product Policy

- The app must not contain `NAVER_CLIENT_ID` or `NAVER_CLIENT_SECRET` values.
- Worker secrets stay in Cloudflare and are never returned to the app.
- News output is a search-result briefing, not a full article summary.
- The app must preserve original links so users can inspect source articles.
- If the proxy is unavailable, MyTeam may fall back to user-provided BYOK credentials.
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

## App Integration

MyTeam uses:

1. Proxy first: `MyTeamBasicLookupProxyClient.searchNews`
2. BYOK fallback: `NaverNewsDirectConnector.search`
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
- Add DART, KMA, and Korean Law only after news proxy is stable.

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

## Future Proxy Routes

These are design targets only. Do not expose them as available until implemented and validated.

### DART

Candidate routes:

- `GET /dart/recent?corpName=삼성전자&days=7`
- `GET /dart/search?corpCode=00126380&days=7`

Required secret:

- `DART_API_KEY`

Response policy:

- disclosure list and official DART links only
- no full disclosure analysis in the basic lookup proxy
- source URL required for every item

### KMA

Candidate routes:

- `GET /weather/kma/nowcast?nx=63&ny=89`
- `GET /weather/kma/forecast?nx=63&ny=89`

Required secret:

- `KMA_SERVICE_KEY`

Response policy:

- pass grid coordinates, not raw address strings
- do not retain user location
- normalize public-data failures into app-friendly error codes

### Korean Law

Candidate route:

- `GET /law/search?query=근로기준법`

Required secret:

- `LAW_OC`

Response policy:

- official legal source link required
- no legal-advice phrasing
- citation verification remains a separate MyTeam skill/runtime concern
