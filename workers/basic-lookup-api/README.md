# MyTeam Basic Lookup API Worker

This Cloudflare Worker provides MyTeam's basic read-only lookup path for public data that should not require ordinary users to bring their own API keys first.

Current route scope:

- `GET /`
- `GET /health`
- `GET /news/search?query={query}&display={1...20}`

The Worker source is stored here for operational review and recovery. Cloudflare secrets are not stored in this repository.

## Required Secrets

Configure these in Cloudflare Dashboard -> Workers & Pages -> Worker -> Settings -> Variables and Secrets:

- `NAVER_CLIENT_ID`
- `NAVER_CLIENT_SECRET`

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

## Future Routes

Planned routes are documented in `/Users/su/Desktop/MyTeam/docs/MYTEAM_BASIC_LOOKUP_PROXY.md`.

Do not add DART, KMA, or Korean Law proxy routes without separately validating secrets, response schemas, rate limits, and MyTeam app copy.
