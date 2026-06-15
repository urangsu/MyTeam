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
      "originallink": "...",
      "link": "...",
      "pubDate": "Mon, 15 Jun 2026 21:18:00 +0900"
    }
  ]
}
```

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
- Add provider quota exceeded messages.
- Add `sourceDomain`, `publishedAtISO`, and `dedupeKey` server-side.
- Add `/version`.
- Add DART, KMA, and Korean Law only after news proxy is stable.
