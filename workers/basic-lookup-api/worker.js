const SERVICE = "myteam-basic-lookup-api";
const VERSION = "0.2.0";

const PROVIDERS = {
  news: "naver-news",
  dart: "dart",
  kma: "kma",
  law: "korean-law"
};

const MAX_DISPLAY = 20;
const DEFAULT_DISPLAY = 10;

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
            "/news/search?query=삼성전자",
            "/dart/recent?corpCode=00126380",
            "/weather/kma/nowcast?nx=63&ny=89",
            "/weather/kma/forecast?nx=63&ny=89",
            "/law/search?query=근로기준법&display=2"
          ]
        });
      }

      if (url.pathname === "/news/search") {
        return await handleNewsSearch(url, env, startedAt);
      }
      if (url.pathname === "/dart/recent") {
        return await withProviderErrorBoundary(PROVIDERS.dart, () => handleDARTRecent(url, env, startedAt));
      }
      if (url.pathname === "/weather/kma/nowcast") {
        return await withProviderErrorBoundary(PROVIDERS.kma, () => handleKMA(url, env, startedAt, "nowcast"));
      }
      if (url.pathname === "/weather/kma/forecast") {
        return await withProviderErrorBoundary(PROVIDERS.kma, () => handleKMA(url, env, startedAt, "forecast"));
      }
      if (url.pathname === "/law/search") {
        return await withProviderErrorBoundary(PROVIDERS.law, () => handleLawSearch(url, env, startedAt));
      }

      return jsonError("not_found", "Route not found.", 404);
    } catch {
      return jsonError(
        "provider_system_error",
        "The lookup proxy could not complete the request.",
        500
      );
    }
  }
};

async function handleNewsSearch(url, env, startedAt) {
  const query = normalizeText(url.searchParams.get("query") || "");
  const display = clampInteger(url.searchParams.get("display"), DEFAULT_DISPLAY, 1, MAX_DISPLAY);
  const validationError = validateQuery(query, PROVIDERS.news);
  if (validationError) {
    return validationError;
  }
  if (!env.NAVER_CLIENT_ID || !env.NAVER_CLIENT_SECRET) {
    return missingSecret(PROVIDERS.news, "News lookup is not configured.");
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
    return providerError(PROVIDERS.news, upstreamResponse.status);
  }

  const upstreamJSON = await safeJSON(upstreamResponse, PROVIDERS.news);
  if (upstreamJSON instanceof Response) {
    return upstreamJSON;
  }

  const rawItems = Array.isArray(upstreamJSON.items) ? upstreamJSON.items : [];
  const items = dedupeBy(rawItems.map(normalizeNewsItem).filter(Boolean), ["originallink", "link", "title"]).slice(0, display);
  return jsonResponse({
    ok: true,
    provider: PROVIDERS.news,
    query,
    count: items.length,
    elapsedMs: Date.now() - startedAt,
    items
  });
}

async function handleDARTRecent(url, env, startedAt) {
  if (!env.DART_API_KEY) {
    return missingSecret(PROVIDERS.dart, "DART lookup is not configured.");
  }
  const corpCode = normalizeText(url.searchParams.get("corpCode") || "");
  const corpName = normalizeText(url.searchParams.get("corpName") || "");
  const days = clampInteger(url.searchParams.get("days"), 7, 1, 30);
  const display = clampInteger(url.searchParams.get("display"), DEFAULT_DISPLAY, 1, MAX_DISPLAY);
  if (!corpCode && corpName.length > 80) {
    return jsonError("query_too_long", "Company name must be 80 characters or fewer.", 400, {
      provider: PROVIDERS.dart
    });
  }

  const now = new Date();
  const begin = new Date(now.getTime() - days * 24 * 60 * 60 * 1000);
  const upstreamURL = new URL("https://opendart.fss.or.kr/api/list.json");
  upstreamURL.searchParams.set("crtfc_key", env.DART_API_KEY);
  upstreamURL.searchParams.set("bgn_de", formatDateYYYYMMDD(begin));
  upstreamURL.searchParams.set("end_de", formatDateYYYYMMDD(now));
  upstreamURL.searchParams.set("sort", "date");
  upstreamURL.searchParams.set("sort_mth", "desc");
  upstreamURL.searchParams.set("page_no", "1");
  upstreamURL.searchParams.set("page_count", String(MAX_DISPLAY));
  if (corpCode) {
    upstreamURL.searchParams.set("corp_code", corpCode);
  }

  const upstreamResponse = await fetch(upstreamURL);
  if (!upstreamResponse.ok) {
    return providerError(PROVIDERS.dart, upstreamResponse.status);
  }

  const upstreamJSON = await safeJSON(upstreamResponse, PROVIDERS.dart);
  if (upstreamJSON instanceof Response) {
    return upstreamJSON;
  }

  const status = normalizeText(upstreamJSON.status || "");
  if (status && status !== "000") {
    if (status === "013") {
      return noResults(PROVIDERS.dart, {
        query: { corpName: corpName || null, corpCode: corpCode || null, days },
        elapsedMs: Date.now() - startedAt
      });
    }
    return dartError(status);
  }

  const rawItems = Array.isArray(upstreamJSON.list) ? upstreamJSON.list : [];
  const nameTokens = significantTokens(corpName);
  const filtered = corpCode || nameTokens.length === 0
    ? rawItems
    : rawItems.filter((item) => {
      const haystack = `${item.corp_name || ""} ${item.report_nm || ""}`.toLowerCase();
      return nameTokens.some((token) => haystack.includes(token));
    });
  const items = filtered.map(normalizeDARTItem).filter(Boolean).slice(0, display);
  if (items.length === 0) {
    return noResults(PROVIDERS.dart, {
      query: { corpName: corpName || null, corpCode: corpCode || null, days },
      elapsedMs: Date.now() - startedAt
    });
  }
  return jsonResponse({
    ok: true,
    provider: PROVIDERS.dart,
    query: {
      corpName: corpName || null,
      corpCode: corpCode || null,
      days
    },
    count: items.length,
    elapsedMs: Date.now() - startedAt,
    items
  });
}

async function handleKMA(url, env, startedAt, type) {
  if (!env.KMA_SERVICE_KEY) {
    return missingSecret(PROVIDERS.kma, "KMA lookup is not configured.");
  }
  const nx = parseGrid(url.searchParams.get("nx"));
  const ny = parseGrid(url.searchParams.get("ny"));
  if (nx === null || ny === null) {
    return jsonError("invalid_provider_request", "KMA nx and ny must be integers between 1 and 149.", 400, {
      provider: PROVIDERS.kma
    });
  }

  const base = kmaBaseDateTime(type, url.searchParams.get("base_date"), url.searchParams.get("base_time"));
  const upstreamURL = new URL(`https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/${type === "forecast" ? "getUltraSrtFcst" : "getUltraSrtNcst"}`);
  upstreamURL.searchParams.set("serviceKey", normalizePublicDataServiceKey(env.KMA_SERVICE_KEY));
  upstreamURL.searchParams.set("pageNo", "1");
  upstreamURL.searchParams.set("numOfRows", "1000");
  upstreamURL.searchParams.set("dataType", "JSON");
  upstreamURL.searchParams.set("base_date", base.date);
  upstreamURL.searchParams.set("base_time", base.time);
  upstreamURL.searchParams.set("nx", String(nx));
  upstreamURL.searchParams.set("ny", String(ny));

  const upstreamResponse = await fetch(upstreamURL);
  if (!upstreamResponse.ok) {
    return providerError(PROVIDERS.kma, upstreamResponse.status);
  }
  const upstreamJSON = await safeJSON(upstreamResponse, PROVIDERS.kma);
  if (upstreamJSON instanceof Response) {
    return upstreamJSON;
  }

  const header = upstreamJSON?.response?.header;
  const resultCode = normalizeText(header?.resultCode || "");
  if (resultCode !== "00") {
    return kmaError(resultCode);
  }
  const rawItems = upstreamJSON?.response?.body?.items?.item;
  const itemArray = Array.isArray(rawItems) ? rawItems : [];
  const items = itemArray.map((item) => normalizeKMAItem(item, type)).filter(Boolean);
  if (items.length === 0) {
    return noResults(PROVIDERS.kma, {
      type,
      grid: { nx, ny },
      baseDate: base.date,
      baseTime: base.time,
      elapsedMs: Date.now() - startedAt
    });
  }
  return jsonResponse({
    ok: true,
    provider: PROVIDERS.kma,
    type,
    grid: { nx, ny },
    baseDate: base.date,
    baseTime: base.time,
    elapsedMs: Date.now() - startedAt,
    items
  });
}

async function handleLawSearch(url, env, startedAt) {
  if (!env.LAW_OC) {
    return missingSecret(PROVIDERS.law, "Korean law lookup is not configured.");
  }
  const query = normalizeText(url.searchParams.get("query") || "");
  const display = clampInteger(url.searchParams.get("display"), DEFAULT_DISPLAY, 1, MAX_DISPLAY);
  const validationError = validateQuery(query, PROVIDERS.law);
  if (validationError) {
    return validationError;
  }

  const upstreamURL = new URL("https://www.law.go.kr/DRF/lawSearch.do");
  upstreamURL.searchParams.set("OC", env.LAW_OC);
  upstreamURL.searchParams.set("target", "law");
  upstreamURL.searchParams.set("type", "JSON");
  upstreamURL.searchParams.set("query", query);
  upstreamURL.searchParams.set("display", String(display));

  const upstreamResponse = await fetch(upstreamURL);
  if (!upstreamResponse.ok) {
    return providerError(PROVIDERS.law, upstreamResponse.status);
  }
  const upstreamJSON = await safeJSON(upstreamResponse, PROVIDERS.law);
  if (upstreamJSON instanceof Response) {
    return upstreamJSON;
  }

  const lawNode = upstreamJSON?.LawSearch?.law;
  const laws = Array.isArray(lawNode) ? lawNode : lawNode ? [lawNode] : [];
  const items = laws.map(normalizeLawItem).filter(Boolean).slice(0, display);
  if (items.length === 0) {
    return noResults(PROVIDERS.law, {
      query,
      notice: "이 결과는 법령 검색 결과이며 법률 자문이 아닙니다.",
      elapsedMs: Date.now() - startedAt
    });
  }

  return jsonResponse({
    ok: true,
    provider: PROVIDERS.law,
    query,
    count: items.length,
    elapsedMs: Date.now() - startedAt,
    items,
    notice: "이 결과는 법령 검색 결과이며 법률 자문이 아닙니다."
  });
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
  const publishedAtISO = parseDateToISO(pubDate);
  return {
    title,
    description,
    sourceDomain: domainFromURL(sourceURL),
    originallink,
    link,
    pubDate,
    publishedAtISO,
    dedupeKey: ["news", sourceURL, title].filter(Boolean).join("|").toLowerCase(),
    isNaverNews: true
  };
}

function normalizeDARTItem(item) {
  const receiptNo = normalizeText(item?.rcept_no || "");
  if (!receiptNo) {
    return null;
  }
  return {
    corpName: normalizeText(item?.corp_name || ""),
    corpCode: normalizeText(item?.corp_code || ""),
    stockCode: normalizeText(item?.stock_code || ""),
    corpClass: normalizeText(item?.corp_cls || ""),
    reportName: normalizeText(item?.report_nm || ""),
    receiptNo,
    receiptDate: normalizeText(item?.rcept_dt || ""),
    submitter: normalizeText(item?.flr_nm || ""),
    remark: normalizeText(item?.rm || ""),
    sourceURL: `https://dart.fss.or.kr/dsaf001/main.do?rcpNo=${encodeURIComponent(receiptNo)}`,
    dedupeKey: `dart|${receiptNo}`
  };
}

function normalizeKMAItem(item, type) {
  const category = normalizeText(item?.category || "");
  const value = normalizeText(item?.obsrValue ?? item?.fcstValue ?? "");
  if (!category || value === "") {
    return null;
  }
  const meta = kmaCategoryMeta(category);
  return {
    category,
    label: meta.label,
    value,
    unit: meta.unit,
    baseDate: normalizeText(item?.baseDate || ""),
    baseTime: normalizeText(item?.baseTime || ""),
    forecastDate: type === "forecast" ? normalizeText(item?.fcstDate || "") : null,
    forecastTime: type === "forecast" ? normalizeText(item?.fcstTime || "") : null
  };
}

function normalizeLawItem(item) {
  const lawName = normalizeText(item?.["법령명한글"] || item?.lawName || "");
  const lawID = normalizeText(item?.["법령ID"] || item?.["법령일련번호"] || item?.lawId || "");
  if (!lawName || !lawID) {
    return null;
  }
  const sourceURL = `https://www.law.go.kr/법령?id=${encodeURIComponent(lawID)}`;
  return {
    lawName,
    lawId: lawID,
    promulgationDate: normalizeText(item?.["공포일자"] || ""),
    enforcementDate: normalizeText(item?.["시행일자"] || ""),
    sourceURL,
    dedupeKey: `law|${lawID}`,
    status: "partial"
  };
}

function validateQuery(query, provider) {
  if (query.length < 2) {
    return jsonError("query_too_short", "Query must be at least two characters.", 400, { provider });
  }
  if (query.length > 80) {
    return jsonError("query_too_long", "Query must be 80 characters or fewer.", 400, { provider });
  }
  return null;
}

function missingSecret(provider, message) {
  return jsonError("missing_worker_secrets", message, 503, { provider });
}

async function withProviderErrorBoundary(provider, handler) {
  try {
    return await handler();
  } catch {
    return jsonError(
      "provider_system_error",
      "The lookup proxy could not complete the provider request.",
      502,
      { provider }
    );
  }
}

function noResults(provider, extra = {}) {
  return jsonResponse({
    ok: false,
    error: "no_results",
    provider,
    message: "No matching public lookup results were found.",
    ...extra
  }, 200);
}

function providerError(provider, status) {
  if (status === 401) {
    return jsonError("invalid_credentials", "Provider credentials are invalid.", 502, { provider, status });
  }
  if (status === 403) {
    return jsonError("provider_permission_denied", "Provider permission was denied.", 502, { provider, status });
  }
  if (status === 429) {
    return jsonError("provider_quota_exceeded", "Provider quota was exceeded.", 503, { provider, status });
  }
  if (status >= 500) {
    return jsonError("provider_system_error", "Provider is temporarily unavailable.", 502, { provider, status });
  }
  return jsonError("upstream_error", "Provider returned an error.", 502, { provider, status });
}

function dartError(status) {
  const map = {
    "010": "invalid_credentials",
    "011": "invalid_credentials",
    "012": "provider_permission_denied",
    "020": "provider_quota_exceeded",
    "021": "provider_quota_exceeded",
    "100": "invalid_provider_request",
    "101": "invalid_provider_request",
    "800": "provider_system_error",
    "900": "provider_system_error",
    "901": "provider_system_error"
  };
  const code = map[status] || "upstream_error";
  const httpStatus = code === "provider_quota_exceeded" ? 503 : 502;
  return jsonError(code, "DART provider returned an error.", httpStatus, {
    provider: PROVIDERS.dart,
    status
  });
}

function kmaError(resultCode) {
  const code = resultCode === "03" ? "no_results" : "upstream_error";
  return jsonError(code, "KMA provider returned an error.", code === "no_results" ? 200 : 502, {
    provider: PROVIDERS.kma,
    status: resultCode || "unknown"
  });
}

async function safeJSON(response, provider) {
  try {
    return await response.json();
  } catch {
    return jsonError("invalid_upstream_json", "Provider returned an invalid JSON response.", 502, { provider });
  }
}

function dedupeBy(items, fields) {
  const seen = new Set();
  const result = [];
  for (const item of items) {
    const keys = fields.map((field) => item[field]).filter(Boolean).map((value) => String(value).toLowerCase());
    const key = keys.find((candidate) => !seen.has(candidate)) || item.dedupeKey;
    if (!key || seen.has(key)) {
      continue;
    }
    for (const candidate of keys) {
      seen.add(candidate);
    }
    seen.add(key);
    result.push(item);
  }
  return result;
}

function significantTokens(value) {
  return normalizeText(value)
    .toLowerCase()
    .split(/[\s,./()·-]+/)
    .map((token) => token.trim())
    .filter((token) => token.length >= 2);
}

function cleanHTML(value) {
  return normalizeText(String(value)
    .replace(/<[^>]*>/g, "")
    .replace(/&quot;/g, "\"")
    .replace(/&apos;/g, "'")
    .replace(/&#39;/g, "'")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">"));
}

function normalizeText(value) {
  return String(value ?? "").replace(/\s+/g, " ").trim();
}

function normalizePublicDataServiceKey(value) {
  const text = normalizeText(value || "");
  if (!text) {
    return "";
  }
  try {
    if (text.includes("%")) {
      return decodeURIComponent(text);
    }
  } catch {
    return text;
  }
  return text;
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

function parseDateToISO(value) {
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

function parseGrid(value) {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isInteger(parsed) || parsed < 1 || parsed > 149) {
    return null;
  }
  return parsed;
}

function kmaBaseDateTime(type, dateOverride, timeOverride) {
  if (/^\d{8}$/.test(dateOverride || "") && /^\d{4}$/.test(timeOverride || "")) {
    return { date: dateOverride, time: timeOverride };
  }
  const now = new Date(Date.now() + 9 * 60 * 60 * 1000);
  if (type === "forecast") {
    now.setMinutes(now.getMinutes() - 45);
  } else {
    now.setMinutes(now.getMinutes() - 40);
  }
  const minutes = now.getUTCMinutes();
  now.setUTCMinutes(minutes - (minutes % 30), 0, 0);
  const hour = String(now.getUTCHours()).padStart(2, "0");
  const minute = String(now.getUTCMinutes()).padStart(2, "0");
  return {
    date: `${now.getUTCFullYear()}${String(now.getUTCMonth() + 1).padStart(2, "0")}${String(now.getUTCDate()).padStart(2, "0")}`,
    time: `${hour}${minute}`
  };
}

function kmaCategoryMeta(category) {
  const map = {
    T1H: { label: "기온", unit: "℃" },
    RN1: { label: "1시간 강수량", unit: "mm" },
    REH: { label: "습도", unit: "%" },
    WSD: { label: "풍속", unit: "m/s" },
    PTY: { label: "강수형태", unit: "" },
    SKY: { label: "하늘상태", unit: "" }
  };
  return map[category] || { label: category, unit: "" };
}

function formatDateYYYYMMDD(date) {
  return `${date.getUTCFullYear()}${String(date.getUTCMonth() + 1).padStart(2, "0")}${String(date.getUTCDate()).padStart(2, "0")}`;
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
