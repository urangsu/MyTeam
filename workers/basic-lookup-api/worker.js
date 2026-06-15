const SERVICE = "myteam-basic-lookup-api";
const VERSION = "0.1.0";
const NAVER_NEWS_PROVIDER = "naver-news";
const MAX_NEWS_DISPLAY = 20;
const DEFAULT_NEWS_DISPLAY = 10;

export default {
  async fetch(request, env) {
    const startedAt = Date.now();
    const url = new URL(request.url);

    if (request.method !== "GET") {
      return jsonError("method_not_allowed", "GET requests only.", 405);
    }

    try {
      if (url.pathname === "/" || url.pathname === "/health") {
        return jsonResponse({
          ok: true,
          service: SERVICE,
          version: VERSION,
          routes: [
            "/health",
            "/news/search?query=삼성전자"
          ]
        });
      }

      if (url.pathname === "/news/search") {
        return await handleNewsSearch(url, env, startedAt);
      }

      return jsonError("not_found", "Route not found.", 404);
    } catch (error) {
      return jsonError(
        "provider_system_error",
        "The lookup proxy could not complete the request.",
        500,
        { provider: NAVER_NEWS_PROVIDER }
      );
    }
  }
};

async function handleNewsSearch(url, env, startedAt) {
  const query = normalizeText(url.searchParams.get("query") || "");
  if (query.length < 2) {
    return jsonError("query_too_short", "Query must be at least two characters.", 400, {
      provider: NAVER_NEWS_PROVIDER
    });
  }
  if (query.length > 80) {
    return jsonError("query_too_long", "Query must be 80 characters or fewer.", 400, {
      provider: NAVER_NEWS_PROVIDER
    });
  }

  const display = clampInteger(url.searchParams.get("display"), DEFAULT_NEWS_DISPLAY, 1, MAX_NEWS_DISPLAY);
  if (!env.NAVER_CLIENT_ID || !env.NAVER_CLIENT_SECRET) {
    return jsonError("missing_worker_secrets", "News lookup is not configured.", 503, {
      provider: NAVER_NEWS_PROVIDER
    });
  }

  const upstreamURL = new URL("https://openapi.naver.com/v1/search/news.json");
  upstreamURL.searchParams.set("query", query);
  upstreamURL.searchParams.set("display", String(display));
  upstreamURL.searchParams.set("start", "1");
  upstreamURL.searchParams.set("sort", "date");

  const upstreamResponse = await fetch(upstreamURL, {
    headers: {
      "X-Naver-Client-Id": env.NAVER_CLIENT_ID,
      "X-Naver-Client-Secret": env.NAVER_CLIENT_SECRET
    }
  });

  if (!upstreamResponse.ok) {
    return naverErrorResponse(upstreamResponse.status);
  }

  let upstreamJSON;
  try {
    upstreamJSON = await upstreamResponse.json();
  } catch {
    return jsonError("invalid_upstream_json", "News provider returned an invalid response.", 502, {
      provider: NAVER_NEWS_PROVIDER
    });
  }

  const rawItems = Array.isArray(upstreamJSON.items) ? upstreamJSON.items : [];
  const items = dedupeNewsItems(rawItems).slice(0, display);
  return jsonResponse({
    ok: true,
    provider: NAVER_NEWS_PROVIDER,
    query,
    count: items.length,
    elapsedMs: Date.now() - startedAt,
    items
  });
}

function dedupeNewsItems(items) {
  const seen = new Set();
  const result = [];
  for (const item of items) {
    const normalized = normalizeNewsItem(item);
    if (!normalized) {
      continue;
    }
    const keys = [
      normalized.originallink,
      normalized.link,
      normalized.title
    ].filter(Boolean).map((value) => String(value).toLowerCase());
    const dedupeKey = keys.find((key) => !seen.has(key)) || normalized.dedupeKey;
    if (seen.has(dedupeKey)) {
      continue;
    }
    for (const key of keys) {
      seen.add(key);
    }
    seen.add(normalized.dedupeKey);
    result.push(normalized);
  }
  return result;
}

function normalizeNewsItem(item) {
  const title = cleanHTML(item?.title || "");
  const description = cleanHTML(item?.description || "");
  const originallink = normalizeURLString(item?.originallink);
  const link = normalizeURLString(item?.link);
  const sourceURL = originallink || link;
  if (!title || !sourceURL) {
    return null;
  }
  const pubDate = normalizeText(item?.pubDate || "");
  const publishedAtISO = parseNaverPubDate(pubDate);
  const sourceDomain = domainFromURL(sourceURL);
  const dedupeKey = [sourceURL, title].filter(Boolean).join("|").toLowerCase();
  return {
    title,
    description,
    sourceDomain,
    originallink,
    link,
    pubDate,
    publishedAtISO,
    dedupeKey,
    isNaverNews: true
  };
}

function naverErrorResponse(status) {
  if (status === 401) {
    return jsonError("invalid_credentials", "News provider credentials are invalid.", 502, {
      provider: NAVER_NEWS_PROVIDER,
      status
    });
  }
  if (status === 403) {
    return jsonError("provider_permission_denied", "News provider permission was denied.", 502, {
      provider: NAVER_NEWS_PROVIDER,
      status
    });
  }
  if (status === 429) {
    return jsonError("provider_quota_exceeded", "News provider quota was exceeded.", 503, {
      provider: NAVER_NEWS_PROVIDER,
      status
    });
  }
  if (status >= 500) {
    return jsonError("provider_system_error", "News provider is temporarily unavailable.", 502, {
      provider: NAVER_NEWS_PROVIDER,
      status
    });
  }
  return jsonError("upstream_error", "News provider returned an error.", 502, {
    provider: NAVER_NEWS_PROVIDER,
    status
  });
}

function cleanHTML(value) {
  return normalizeText(String(value)
    .replace(/<[^>]*>/g, "")
    .replace(/&quot;/g, "\"")
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">"));
}

function normalizeText(value) {
  return String(value).replace(/\s+/g, " ").trim();
}

function normalizeURLString(value) {
  const text = normalizeText(value || "");
  if (!text) {
    return null;
  }
  try {
    return new URL(text).toString();
  } catch {
    return null;
  }
}

function domainFromURL(value) {
  try {
    return new URL(value).hostname.replace(/^www\./, "");
  } catch {
    return "unknown";
  }
}

function parseNaverPubDate(value) {
  if (!value) {
    return null;
  }
  const timestamp = Date.parse(value);
  if (Number.isNaN(timestamp)) {
    return null;
  }
  return new Date(timestamp).toISOString();
}

function clampInteger(value, fallback, minimum, maximum) {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed)) {
    return fallback;
  }
  return Math.min(Math.max(parsed, minimum), maximum);
}

function jsonResponse(payload, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store"
    }
  });
}

function jsonError(error, message, status, extra = {}) {
  return jsonResponse({
    ok: false,
    error,
    message,
    ...extra
  }, status);
}
