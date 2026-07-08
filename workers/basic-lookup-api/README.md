# MyTeam Basic Lookup API Worker

This Cloudflare Worker provides MyTeam's basic read-only lookup path for public data that should not require ordinary users to bring their own API keys first.

Current route scope:

- `GET /`
- `GET /health`
- `GET /news/search?query={query}&display={1...20}`
- `GET /weather/kma/nowcast?nx={nx}&ny={ny}`
- `GET /weather/kma/forecast?nx={nx}&ny={ny}`
- `GET /weather/kma/ultra-forecast?nx={nx}&ny={ny}`
- `GET /weather/kma/village-forecast?nx={nx}&ny={ny}`
- `GET /weather/kma/version?nx={nx}&ny={ny}`
- `GET /finance/krx/items?query={query}`
- `GET /finance/stocks/prices?query={query}`
- `GET /finance/index/stock?query={query}`
- `GET /finance/index/bond?query={query}`
- `GET /finance/index/derivatives?query={query}`
- `GET /finance/company/summary?crno={crno}&bizYear={year}`
- `GET /finance/company/balance-sheet?crno={crno}&bizYear={year}`
- `GET /finance/company/income-statement?crno={crno}&bizYear={year}`
- `GET /law/search?query={query}&display={1...20}`

Diagnostic-only route scope:

- `GET /dart/company?corpCode={corpCode}`
- `GET /dart/recent?corpCode={corpCode}&days={1...30}&display={1...20}`
- `GET /dart/recent?corpName={corpName}&days={1...30}&display={1...20}`
- `GET /dart/diagnose?corpCode={corpCode}`

Diagnostic routes require `x-myteam-diagnostic-token`. They are not user-facing product routes.

The Worker source is stored here for operational review and recovery. Cloudflare secrets are not stored in this repository.

## Required Secrets

Configure these in Cloudflare Dashboard -> Workers & Pages -> Worker -> Settings -> Variables and Secrets:

- `NAVER_CLIENT_ID`
- `NAVER_CLIENT_SECRET`
- `DART_API_KEY`
- `KMA_SERVICE_KEY`
- `LAW_OC`
- `DIAGNOSTIC_ROUTE_TOKEN`

## Cloudflare Dashboard Manual Deploy

This Worker is currently deployed from the Cloudflare Dashboard, not from a repo-bound CI pipeline. After editing this source file, deploy the same source manually:

1. Commit and push the exact source revision that will be deployed.
2. Open Cloudflare Dashboard -> Workers & Pages -> `late-waterfall-c95c` -> Production.
3. Confirm the required secrets above exist in Settings -> Variables and Secrets.
4. Set `MYTEAM_WORKER_GIT_SHA` to the exact pushed commit SHA.
5. Set `MYTEAM_WORKER_DEPLOYED_AT` to the UTC deploy timestamp, e.g. `2026-07-08T12:34:56Z`.
6. Paste or sync `/Users/su/Desktop/MyTeam/workers/basic-lookup-api/worker.js` into the Worker editor.
7. Save and deploy to Production.
8. Verify `/health` before enabling any public lookup Release surface.

The production `/health` response must show `version: "0.3.0"`, a non-empty `build` marker, `contractVersion: 2`, `gitSha`, `deployedAt`, `userRoutes`, and `diagnosticContract`.

```text
/health
/news/search?query=삼성전자
/weather/kma/nowcast?nx=63&ny=89
/weather/kma/forecast?nx=63&ny=89
/weather/kma/ultra-forecast?nx=63&ny=89
/weather/kma/village-forecast?nx=63&ny=89
/weather/kma/version?nx=63&ny=89
/finance/krx/items?query=삼성전자
/finance/stocks/prices?query=삼성전자
/finance/index/stock?query=코스피
/finance/index/bond?query=채권
/finance/index/derivatives?query=코스피200
/finance/company/summary?crno=1101110000000&bizYear=2023
/finance/company/balance-sheet?crno=1101110000000&bizYear=2023
/finance/company/income-statement?crno=1101110000000&bizYear=2023
/law/search?query=근로기준법&display=2
```

`/health` must not expose full diagnostic route names. It may expose only this diagnostic contract:

```json
{
  "diagnosticContract": {
    "enabled": true,
    "routeCount": 3,
    "auth": "header-token"
  },
  "contractVersion": 2,
  "gitSha": "40-character commit SHA",
  "deployedAt": "2026-07-08T12:34:56Z"
}
```

Live route checks:

```bash
curl -fsS 'https://late-waterfall-c95c.urange.workers.dev/health'
curl -fsS 'https://late-waterfall-c95c.urange.workers.dev/news/search?query=%EC%82%BC%EC%84%B1%EC%A0%84%EC%9E%90&display=2'
curl -i 'https://late-waterfall-c95c.urange.workers.dev/dart/company?corpCode=00126380' # must return 404
curl -i -H 'x-myteam-diagnostic-token: wrong' 'https://late-waterfall-c95c.urange.workers.dev/dart/company?corpCode=00126380' # must return 404
MYTEAM_DIAGNOSTIC_TOKEN='<local secret>' python3 scripts/validate_worker_production_health.py --validate-diagnostic-auth
curl -fsS 'https://late-waterfall-c95c.urange.workers.dev/weather/kma/nowcast?nx=63&ny=89'
curl -fsS 'https://late-waterfall-c95c.urange.workers.dev/weather/kma/forecast?nx=63&ny=89'
curl -fsS 'https://late-waterfall-c95c.urange.workers.dev/weather/kma/ultra-forecast?nx=63&ny=89'
curl -fsS 'https://late-waterfall-c95c.urange.workers.dev/weather/kma/village-forecast?nx=63&ny=89'
curl -fsS 'https://late-waterfall-c95c.urange.workers.dev/weather/kma/version?nx=63&ny=89'
curl -fsS 'https://late-waterfall-c95c.urange.workers.dev/finance/krx/items?query=%EC%82%BC%EC%84%B1%EC%A0%84%EC%9E%90'
curl -fsS 'https://late-waterfall-c95c.urange.workers.dev/finance/stocks/prices?query=%EC%82%BC%EC%84%B1%EC%A0%84%EC%9E%90'
curl -fsS 'https://late-waterfall-c95c.urange.workers.dev/finance/index/stock?query=%EC%BD%94%EC%8A%A4%ED%94%BC'
curl -fsS 'https://late-waterfall-c95c.urange.workers.dev/law/search?query=%EA%B7%BC%EB%A1%9C%EA%B8%B0%EC%A4%80%EB%B2%95&display=2'
```

If any required user route returns `404`, do not merge this branch to `main`.
Unauthenticated and wrong-token `/dart/*` diagnostic requests must return exactly `404`.
Correct-token `/dart/*` diagnostic requests must return the expected DART diagnostic JSON contract. HTTP `500`, non-JSON, `not_found`, or missing `provider: "dart"` is a failure. Do not print the token value in logs, QA Markdown, or chat.

## Naver Developer Setup

In Naver Developers:

1. Open the application used for MyTeam.
2. Enable Search API.
3. Add the Worker URL as a web service URL.

Production candidate:

```text
https://late-waterfall-c95c.urange.workers.dev
```

## Local Editing Policy

- Do not commit secret values.
- Do not add Cloudflare account IDs.
- Keep default result size at 10 and maximum result size at 20.
- Treat news output as search-result title/description snippets, not article full text.
- Keep `/news/search` as a read-only GET route.
- Treat DART output as disclosure lists and official links, not disclosure full-text analysis.
- Treat DART `corpName` lookup as Worker-side best-effort filtering. It is not an official OpenDART `list.json` request parameter; prefer `corpCode` for reliable lookup.
- Keep all `/dart/*` Worker routes as token-protected operational diagnostics. User-facing app DART lookup uses personal OpenDART API Key direct calls because production Worker outbound calls to OpenDART return provider reachability `522`.
- Never put the diagnostic token value into app code, Info.plist, bundled JSON, release capability manifests, logs, QA Markdown, or URL query strings. Use Cloudflare secrets, CI secrets, or local environment variables only.
- Public user routes consume provider quotas. Keep query length limits, result limits, isolate-local rate limiting, provider timeouts, maximum upstream response size, and no-store responses. Add durable rate limiting/cache before broad Release traffic if usage grows beyond low-volume demo/RC traffic.
- Do not use Worker `corpName` handling as product behavior. The app resolves company name or stock code to OpenDART `corp_code` locally before direct BYOK lookup.
- Treat Korean Law output as official search results, not legal advice.
- Pass KMA grid coordinates only; do not accept raw address strings in Worker routes.

## Future Routes

Planned routes are documented in `/Users/su/Desktop/MyTeam/docs/MYTEAM_BASIC_LOOKUP_PROXY.md`.

Do not add write, send, deletion, crawling, or full-text analysis behavior to this Worker. Public lookup routes are read-only.
