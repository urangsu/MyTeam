const SERVICE = "myteam-basic-lookup-api";
const VERSION = "0.3.0";
const BUILD = "public-lookup-0.3.0";

const PROVIDERS = {
  news: "naver-news",
  dart: "dart",
  kma: "kma",
  law: "korean-law",
  publicData: "public-data-portal"
};

const MAX_DISPLAY = 20;
const DEFAULT_DISPLAY = 10;
const DIAGNOSTIC_TOKEN_HEADER = "x-myteam-diagnostic-token";

const USER_ROUTES = [
  "/health",
  "/news/search?query=삼성전자",
  "/weather/kma/nowcast?nx=63&ny=89",
  "/weather/kma/forecast?nx=63&ny=89",
  "/weather/kma/ultra-forecast?nx=63&ny=89",
  "/weather/kma/village-forecast?nx=63&ny=89",
  "/weather/kma/version?nx=63&ny=89",
  "/finance/krx/items?query=삼성전자",
  "/finance/stocks/prices?query=삼성전자",
  "/finance/index/stock?query=코스피",
  "/finance/index/bond?query=채권",
  "/finance/index/derivatives?query=코스피200",
  "/finance/company/summary?crno=1101110000000&bizYear=2023",
  "/finance/company/balance-sheet?crno=1101110000000&bizYear=2023",
  "/finance/company/income-statement?crno=1101110000000&bizYear=2023",
  "/law/search?query=근로기준법&display=2"
];

const DIAGNOSTIC_ROUTES = [
  "/dart/company?corpCode=00126380",
  "/dart/recent?corpCode=00126380",
  "/dart/diagnose?corpCode=00126380"
];

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
          build: BUILD,
          userRoutes: USER_ROUTES,
          diagnosticContract: {
            enabled: true,
            routeCount: DIAGNOSTIC_ROUTES.length,
            auth: "header-token"
          },
          routes: USER_ROUTES
        });
      }

      if (url.pathname === "/news/search") {
        return await handleNewsSearch(url, env, startedAt);
      }
      if (url.pathname.startsWith("/dart/")) {
        const diagnosticAccessError = requireDiagnosticAccess(request, env);
        if (diagnosticAccessError) {
          return diagnosticAccessError;
        }
      }
      if (url.pathname === "/dart/company") {
        return await withProviderErrorBoundary(PROVIDERS.dart, () => handleDARTCompany(url, env, startedAt));
      }
      if (url.pathname === "/dart/recent") {
        return await withProviderErrorBoundary(PROVIDERS.dart, () => handleDARTRecent(url, env, startedAt));
      }
      if (url.pathname === "/dart/diagnose") {
        return await withProviderErrorBoundary(PROVIDERS.dart, () => handleDARTDiagnose(url, env, startedAt));
      }
      if (url.pathname === "/weather/kma/nowcast") {
        return await withProviderErrorBoundary(PROVIDERS.kma, () => handleKMA(url, env, startedAt, "nowcast"));
      }
      if (url.pathname === "/weather/kma/forecast") {
        return await withProviderErrorBoundary(PROVIDERS.kma, () => handleKMA(url, env, startedAt, "forecast"));
      }
      if (url.pathname === "/weather/kma/ultra-forecast") {
        return await withProviderErrorBoundary(PROVIDERS.kma, () => handleKMA(url, env, startedAt, "forecast"));
      }
      if (url.pathname === "/weather/kma/village-forecast") {
        return await withProviderErrorBoundary(PROVIDERS.kma, () => handleKMA(url, env, startedAt, "village"));
      }
      if (url.pathname === "/weather/kma/version") {
        return await withProviderErrorBoundary(PROVIDERS.kma, () => handleKMAVersion(url, env, startedAt));
      }
      if (url.pathname.startsWith("/finance/")) {
        return await withProviderErrorBoundary(PROVIDERS.publicData, () => handleFinanceLookup(url, env, startedAt));
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
  let stage = "dart_secret_check";
  try {
    const dartAPIKey = normalizeDARTAPIKey(env);
    if (!dartAPIKey) {
      return missingSecret(PROVIDERS.dart, "DART lookup is not configured.");
    }
    const corpCode = normalizeText(url.searchParams.get("corpCode") || "");
    const corpName = normalizeText(url.searchParams.get("corpName") || "");
    const days = clampInteger(url.searchParams.get("days"), 7, 1, 30);
    const display = clampInteger(url.searchParams.get("display"), DEFAULT_DISPLAY, 1, MAX_DISPLAY);
    if (corpCode) {
      const corpCodeError = validateDARTCorpCode(corpCode, "recent");
      if (corpCodeError) {
        return corpCodeError;
      }
    }
    if (!corpCode && corpName.length > 80) {
      return jsonError("query_too_long", "Company name must be 80 characters or fewer.", 400, {
        provider: PROVIDERS.dart
      });
    }

    stage = "dart_build_request";
    const now = new Date();
    const begin = new Date(now.getTime() - days * 24 * 60 * 60 * 1000);
    const upstreamURL = new URL("https://opendart.fss.or.kr/api/list.json");
    upstreamURL.searchParams.set("crtfc_key", dartAPIKey);
    upstreamURL.searchParams.set("bgn_de", formatDateYYYYMMDD(begin));
    upstreamURL.searchParams.set("end_de", formatDateYYYYMMDD(now));
    upstreamURL.searchParams.set("sort", "date");
    upstreamURL.searchParams.set("sort_mth", "desc");
    upstreamURL.searchParams.set("page_no", "1");
    upstreamURL.searchParams.set("page_count", String(MAX_DISPLAY));
    if (corpCode) {
      upstreamURL.searchParams.set("corp_code", corpCode);
    }

    stage = "dart_fetch";
    const upstreamResponse = await fetch(upstreamURL);
    if (!upstreamResponse.ok) {
      return providerError(PROVIDERS.dart, upstreamResponse.status, { stage });
    }

    stage = "dart_parse_json";
    const upstreamJSON = await safeJSON(upstreamResponse, PROVIDERS.dart);
    if (upstreamJSON instanceof Response) {
      return upstreamJSON;
    }

    stage = "dart_status_check";
    const status = normalizeText(upstreamJSON.status || "");
    const providerMessage = normalizeText(upstreamJSON.message || "");
    if (status && status !== "000") {
      if (status === "013") {
        return noResults(PROVIDERS.dart, {
          query: { corpName: corpName || null, corpCode: corpCode || null, days },
          providerStatus: status,
          providerMessage,
          stage,
          elapsedMs: Date.now() - startedAt
        });
      }
      return dartError(status, providerMessage, stage);
    }

    stage = "dart_normalize_items";
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
  } catch (error) {
    if (stage === "dart_fetch") {
      return providerStageError(PROVIDERS.dart, stage, "DART provider could not be reached from the lookup proxy.", {
        status: providerReachabilityStatus(error),
        classification: "provider_reachability_failure",
        retryable: true,
        mergeGate: "conditional-pass"
      });
    }
    return providerStageError(PROVIDERS.dart, stage, "DART lookup failed during provider request.");
  }
}

async function handleDARTCompany(url, env, startedAt) {
  let stage = "dart_company_secret_check";
  try {
    const dartAPIKey = normalizeDARTAPIKey(env);
    if (!dartAPIKey) {
      return missingSecret(PROVIDERS.dart, "DART company lookup is not configured.");
    }

    const corpCode = normalizeText(url.searchParams.get("corpCode") || "");
    const corpCodeError = validateDARTCorpCode(corpCode, "company");
    if (corpCodeError) {
      return corpCodeError;
    }

    stage = "dart_company_build_request";
    const upstreamURL = new URL("https://opendart.fss.or.kr/api/company.json");
    upstreamURL.searchParams.set("crtfc_key", dartAPIKey);
    upstreamURL.searchParams.set("corp_code", corpCode);

    stage = "dart_company_fetch";
    const upstreamResponse = await fetch(upstreamURL);
    if (!upstreamResponse.ok) {
      return providerError(PROVIDERS.dart, upstreamResponse.status, {
        type: "company",
        stage,
        keyLength: dartAPIKey.length
      });
    }

    stage = "dart_company_parse_json";
    const upstreamJSON = await safeJSON(upstreamResponse, PROVIDERS.dart);
    if (upstreamJSON instanceof Response) {
      return upstreamJSON;
    }

    stage = "dart_company_status_check";
    const status = normalizeText(upstreamJSON.status || "");
    const providerMessage = normalizeText(upstreamJSON.message || "");
    if (status && status !== "000") {
      return dartError(status, providerMessage, stage, {
        type: "company",
        keyLength: dartAPIKey.length
      });
    }

    return jsonResponse({
      ok: true,
      provider: PROVIDERS.dart,
      type: "company",
      corpCode,
      status: status || "000",
      providerMessage,
      keyLength: dartAPIKey.length,
      elapsedMs: Date.now() - startedAt,
      company: normalizeDARTCompany(upstreamJSON)
    });
  } catch (error) {
    if (stage === "dart_company_fetch") {
      return providerStageError(PROVIDERS.dart, stage, "DART company provider could not be reached from the lookup proxy.", {
        type: "company",
        status: providerReachabilityStatus(error),
        classification: "provider_reachability_failure",
        retryable: true,
        mergeGate: "conditional-pass"
      });
    }
    return providerStageError(PROVIDERS.dart, stage, "DART company lookup failed during provider request.", {
      type: "company"
    });
  }
}

async function handleDARTDiagnose(url, env, startedAt) {
  const dartAPIKey = normalizeDARTAPIKey(env);
  if (!dartAPIKey) {
    return missingSecret(PROVIDERS.dart, "DART diagnostic lookup is not configured.");
  }

  const corpCode = normalizeText(url.searchParams.get("corpCode") || "");
  const corpCodeError = validateDARTCorpCode(corpCode, "diagnose");
  if (corpCodeError) {
    return corpCodeError;
  }

  const companyURL = new URL(url.toString());
  companyURL.pathname = "/dart/company";
  companyURL.searchParams.set("corpCode", corpCode);

  const recentURL = new URL(url.toString());
  recentURL.pathname = "/dart/recent";
  recentURL.searchParams.set("corpCode", corpCode);
  recentURL.searchParams.set("days", normalizeText(url.searchParams.get("days") || "30"));
  recentURL.searchParams.set("display", normalizeText(url.searchParams.get("display") || "2"));

  const companyResponse = await handleDARTCompany(companyURL, env, Date.now());
  const companyPayload = await responsePayload(companyResponse);
  const listResponse = await handleDARTRecent(recentURL, env, Date.now());
  const listPayload = await responsePayload(listResponse);

  const companyCheck = summarizeDARTDiagnosticCheck(companyPayload, companyResponse.status);
  const listCheck = summarizeDARTDiagnosticCheck(listPayload, listResponse.status);
  const conclusion = concludeDARTDiagnosis(companyCheck, listCheck);
  const ok = companyCheck.ok && listCheck.ok;

  return jsonResponse({
    ok,
    provider: PROVIDERS.dart,
    type: "diagnose",
    corpCode,
    keyLength: dartAPIKey.length,
    elapsedMs: Date.now() - startedAt,
    checks: {
      company: companyCheck,
      list: listCheck
    },
    conclusion
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
  const operation = type === "village" ? "getVilageFcst" : type === "forecast" ? "getUltraSrtFcst" : "getUltraSrtNcst";
  const upstreamURL = new URL(`https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/${operation}`);
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
    return kmaHTTPError(upstreamResponse.status, base, nx, ny);
  }
  const upstreamJSON = await safeJSON(upstreamResponse, PROVIDERS.kma);
  if (upstreamJSON instanceof Response) {
    return upstreamJSON;
  }

  const header = upstreamJSON?.response?.header;
  const resultCode = normalizeText(header?.resultCode || "");
  const resultMsg = normalizeText(header?.resultMsg || "");
  if (resultCode !== "00") {
    return kmaError(resultCode, resultMsg, base, nx, ny);
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

async function handleKMAVersion(url, env, startedAt) {
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
  const base = kmaBaseDateTime("forecast", url.searchParams.get("base_date"), url.searchParams.get("base_time"));
  const upstreamURL = new URL("https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getFcstVersion");
  upstreamURL.searchParams.set("serviceKey", normalizePublicDataServiceKey(env.KMA_SERVICE_KEY));
  upstreamURL.searchParams.set("pageNo", "1");
  upstreamURL.searchParams.set("numOfRows", "10");
  upstreamURL.searchParams.set("dataType", "JSON");
  upstreamURL.searchParams.set("base_date", base.date);
  upstreamURL.searchParams.set("base_time", base.time);
  upstreamURL.searchParams.set("nx", String(nx));
  upstreamURL.searchParams.set("ny", String(ny));

  const upstreamResponse = await fetch(upstreamURL);
  if (!upstreamResponse.ok) {
    return kmaHTTPError(upstreamResponse.status, base, nx, ny);
  }
  const upstreamJSON = await safeJSON(upstreamResponse, PROVIDERS.kma);
  if (upstreamJSON instanceof Response) {
    return upstreamJSON;
  }
  const header = upstreamJSON?.response?.header;
  const resultCode = normalizeText(header?.resultCode || "");
  const resultMsg = normalizeText(header?.resultMsg || "");
  if (resultCode !== "00") {
    return kmaError(resultCode, resultMsg, base, nx, ny);
  }
  const rawItems = upstreamJSON?.response?.body?.items?.item;
  const itemArray = Array.isArray(rawItems) ? rawItems : rawItems ? [rawItems] : [];
  const items = itemArray.map((item) => normalizePublicDataItem(item)).filter(Boolean);
  return jsonResponse({
    ok: true,
    provider: PROVIDERS.kma,
    type: "version",
    grid: { nx, ny },
    baseDate: base.date,
    baseTime: base.time,
    elapsedMs: Date.now() - startedAt,
    items
  });
}

async function handleFinanceLookup(url, env, startedAt) {
  if (!env.PUBLIC_DATA_SERVICE_KEY) {
    return missingSecret(PROVIDERS.publicData, "Public data lookup is not configured.");
  }
  const route = financeRoute(url.pathname);
  if (!route) {
    return jsonError("not_found", "Finance route not found.", 404, { provider: PROVIDERS.publicData });
  }

  const display = clampInteger(url.searchParams.get("display"), DEFAULT_DISPLAY, 1, MAX_DISPLAY);
  const upstreamURL = new URL(route.endpoint);
  upstreamURL.searchParams.set("serviceKey", normalizePublicDataServiceKey(env.PUBLIC_DATA_SERVICE_KEY));
  upstreamURL.searchParams.set("pageNo", normalizeText(url.searchParams.get("pageNo") || "1"));
  upstreamURL.searchParams.set("numOfRows", String(display));
  upstreamURL.searchParams.set("resultType", "json");

  const query = normalizeText(url.searchParams.get("query") || "");
  const baseDate = normalizeText(url.searchParams.get("basDt") || "");
  if (baseDate) {
    upstreamURL.searchParams.set("basDt", baseDate);
  }
  for (const [key, value] of financeQueryParams(route, url, query)) {
    if (value) {
      upstreamURL.searchParams.set(key, value);
    }
  }

  const upstreamResponse = await fetch(upstreamURL);
  if (!upstreamResponse.ok) {
    return providerError(PROVIDERS.publicData, upstreamResponse.status, { route: route.id });
  }
  const upstreamJSON = await safeJSON(upstreamResponse, PROVIDERS.publicData);
  if (upstreamJSON instanceof Response) {
    return upstreamJSON;
  }
  const header = upstreamJSON?.response?.header;
  const resultCode = normalizeText(header?.resultCode || "");
  const resultMsg = normalizeText(header?.resultMsg || "");
  if (resultCode && resultCode !== "00") {
    return publicDataError(resultCode, resultMsg, route.id);
  }
  const rawItems = upstreamJSON?.response?.body?.items?.item;
  const itemArray = Array.isArray(rawItems) ? rawItems : rawItems ? [rawItems] : [];
  const items = itemArray.map((item) => normalizePublicDataItem(item)).filter(Boolean);
  if (items.length === 0) {
    return noResults(PROVIDERS.publicData, {
      route: route.id,
      query,
      notice: route.notice,
      elapsedMs: Date.now() - startedAt
    });
  }
  return jsonResponse({
    ok: true,
    provider: PROVIDERS.publicData,
    route: route.id,
    query,
    count: items.length,
    elapsedMs: Date.now() - startedAt,
    notice: route.notice,
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

function normalizeDARTCompany(payload) {
  return {
    corpName: normalizeText(payload?.corp_name || ""),
    corpNameEng: normalizeText(payload?.corp_name_eng || ""),
    stockName: normalizeText(payload?.stock_name || ""),
    stockCode: normalizeText(payload?.stock_code || ""),
    ceoName: normalizeText(payload?.ceo_nm || ""),
    corpClass: normalizeText(payload?.corp_cls || ""),
    homepage: normalizeText(payload?.hm_url || ""),
    industryCode: normalizeText(payload?.induty_code || ""),
    establishedDate: normalizeText(payload?.est_dt || ""),
    accountingMonth: normalizeText(payload?.acc_mt || "")
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
    forecastDate: type === "forecast" || type === "village" ? normalizeText(item?.fcstDate || "") : null,
    forecastTime: type === "forecast" || type === "village" ? normalizeText(item?.fcstTime || "") : null
  };
}

function normalizePublicDataItem(item) {
  if (!item || typeof item !== "object") {
    return null;
  }
  const normalized = {};
  for (const [key, value] of Object.entries(item)) {
    if (value === null || value === undefined) {
      continue;
    }
    const text = normalizeText(value);
    if (text !== "") {
      normalized[key] = text;
    }
  }
  return Object.keys(normalized).length > 0 ? normalized : null;
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

function requireDiagnosticAccess(request, env) {
  const expectedToken = normalizeText(env?.DIAGNOSTIC_ROUTE_TOKEN || "");
  const providedToken = normalizeText(request.headers.get(DIAGNOSTIC_TOKEN_HEADER) || "");
  if (!expectedToken || providedToken !== expectedToken) {
    return jsonError("not_found", "Route not found.", 404);
  }
  return null;
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

function providerStageError(provider, stage, message, extra = {}) {
  return jsonError("provider_system_error", message, 502, {
    provider,
    stage,
    ...extra
  });
}

function providerError(provider, status, extra = {}) {
  if (status === 401) {
    return jsonError("invalid_credentials", "Provider credentials are invalid.", 502, { provider, status, ...extra });
  }
  if (status === 403) {
    return jsonError("provider_permission_denied", "Provider permission was denied.", 502, { provider, status, ...extra });
  }
  if (status === 429) {
    return jsonError("provider_quota_exceeded", "Provider quota was exceeded.", 503, { provider, status, ...extra });
  }
  if (provider === PROVIDERS.dart && status === 522) {
    return jsonError("provider_system_error", "DART provider could not be reached from the lookup proxy.", 502, {
      provider,
      status,
      classification: "provider_reachability_failure",
      retryable: true,
      mergeGate: "conditional-pass",
      ...extra
    });
  }
  if (status >= 500) {
    return jsonError("provider_system_error", "Provider is temporarily unavailable.", 502, { provider, status, ...extra });
  }
  return jsonError("upstream_error", "Provider returned an error.", 502, { provider, status, ...extra });
}

function dartError(status, providerMessage, stage, extra = {}) {
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
    stage,
    providerStatus: status,
    providerMessage,
    ...extra
  });
}

function kmaHTTPError(status, base, nx, ny) {
  return providerError(PROVIDERS.kma, status, {
    baseDate: base.date,
    baseTime: base.time,
    grid: { nx, ny }
  });
}

function kmaError(resultCode, resultMsg, base, nx, ny) {
  const normalizedMessage = resultMsg.toUpperCase();
  const code = resultCode === "03"
    ? "no_results"
    : resultCode === "30" || normalizedMessage.includes("SERVICE") || normalizedMessage.includes("KEY")
      ? "invalid_credentials"
      : "upstream_error";
  return jsonError(code, "KMA provider returned an error.", code === "no_results" ? 200 : 502, {
    provider: PROVIDERS.kma,
    status: resultCode || "unknown",
    providerMessage: resultMsg,
    baseDate: base.date,
    baseTime: base.time,
    grid: { nx, ny }
  });
}

function publicDataError(resultCode, resultMsg, route) {
  const normalizedMessage = resultMsg.toUpperCase();
  const code = resultCode === "03"
    ? "no_results"
    : resultCode === "30" || normalizedMessage.includes("SERVICE") || normalizedMessage.includes("KEY")
      ? "invalid_credentials"
      : "upstream_error";
  return jsonError(code, "Public data provider returned an error.", code === "no_results" ? 200 : 502, {
    provider: PROVIDERS.publicData,
    route,
    status: resultCode || "unknown",
    providerMessage: resultMsg
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

function normalizeDARTAPIKey(env) {
  return normalizeText(env?.DART_API_KEY || "");
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

function validateDARTCorpCode(corpCode, type) {
  if (!/^\d{8}$/.test(corpCode)) {
    return jsonError("invalid_provider_request", "DART corpCode must be an 8 digit company code.", 400, {
      provider: PROVIDERS.dart,
      type
    });
  }
  return null;
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

function financeRoute(pathname) {
  const routes = {
    "/finance/krx/items": {
      id: "krx-items",
      endpoint: "https://apis.data.go.kr/1160100/service/GetKrxListedInfoService/getItemInfo",
      queryKeys: ["likeItmsNm", "likeSrtnCd"],
      notice: "KRX 상장종목정보 기준일 공공데이터입니다."
    },
    "/finance/stocks/prices": {
      id: "stock-prices",
      endpoint: "https://apis.data.go.kr/1160100/service/GetStockSecuritiesInfoService/getStockPriceInfo",
      queryKeys: ["itmsNm", "srtnCd"],
      notice: "금융위원회 주식시세정보 기준일 공공데이터입니다. 실시간 시세가 아닙니다."
    },
    "/finance/index/stock": {
      id: "stock-index",
      endpoint: "https://apis.data.go.kr/1160100/service/GetMarketIndexInfoService/getStockMarketIndex",
      queryKeys: ["idxNm"],
      notice: "금융위원회 지수시세정보 기준일 공공데이터입니다. 실시간 지수가 아닙니다."
    },
    "/finance/index/bond": {
      id: "bond-index",
      endpoint: "https://apis.data.go.kr/1160100/service/GetMarketIndexInfoService/getBondMarketIndex",
      queryKeys: ["idxNm"],
      notice: "금융위원회 채권지수 기준일 공공데이터입니다."
    },
    "/finance/index/derivatives": {
      id: "derivatives-index",
      endpoint: "https://apis.data.go.kr/1160100/service/GetMarketIndexInfoService/getDerivationProductMarketIndex",
      queryKeys: ["idxNm"],
      notice: "금융위원회 파생상품지수 기준일 공공데이터입니다."
    },
    "/finance/company/summary": {
      id: "company-summary",
      endpoint: "https://apis.data.go.kr/1160100/service/GetFinaStatInfoService_V2/getSummFinaStat_V2",
      queryKeys: ["crno", "bizYear"],
      notice: "금융위원회 기업 재무정보 기준 공공데이터입니다."
    },
    "/finance/company/balance-sheet": {
      id: "company-balance-sheet",
      endpoint: "https://apis.data.go.kr/1160100/service/GetFinaStatInfoService_V2/getBs_V2",
      queryKeys: ["crno", "bizYear"],
      notice: "금융위원회 재무상태표 기준 공공데이터입니다."
    },
    "/finance/company/income-statement": {
      id: "company-income-statement",
      endpoint: "https://apis.data.go.kr/1160100/service/GetFinaStatInfoService_V2/getIncoStat_V2",
      queryKeys: ["crno", "bizYear"],
      notice: "금융위원회 손익계산서 기준 공공데이터입니다."
    }
  };
  return routes[pathname] || null;
}

function financeQueryParams(route, url, query) {
  const params = [];
  for (const key of route.queryKeys) {
    const direct = normalizeText(url.searchParams.get(key) || "");
    if (direct) {
      params.push([key, direct]);
    }
  }
  if (!query) {
    return params;
  }
  if (route.queryKeys.includes("srtnCd") && /^\d{6}$/.test(query)) {
    params.push(["srtnCd", query]);
  } else if (route.queryKeys.includes("likeSrtnCd") && /^\d{6}$/.test(query)) {
    params.push(["likeSrtnCd", query]);
  } else if (route.queryKeys.includes("idxNm")) {
    params.push(["idxNm", query]);
  } else if (route.queryKeys.includes("itmsNm")) {
    params.push(["itmsNm", query]);
  } else if (route.queryKeys.includes("likeItmsNm")) {
    params.push(["likeItmsNm", query]);
  }

  const tokens = query.split(/\s+/).filter(Boolean);
  if (route.queryKeys.includes("crno") && tokens[0]) {
    params.push(["crno", normalizeText(url.searchParams.get("crno") || tokens[0])]);
  }
  if (route.queryKeys.includes("bizYear") && tokens[1]) {
    params.push(["bizYear", normalizeText(url.searchParams.get("bizYear") || tokens[1])]);
  }
  return params;
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

function providerReachabilityStatus(error) {
  const candidates = [
    error?.status,
    error?.cause?.status,
    error?.response?.status
  ];
  for (const candidate of candidates) {
    const parsed = Number.parseInt(candidate, 10);
    if (Number.isFinite(parsed) && parsed > 0) {
      return parsed;
    }
  }
  return 522;
}

async function responsePayload(response) {
  try {
    return await response.clone().json();
  } catch {
    return {
      ok: false,
      error: "invalid_proxy_response",
      message: "Proxy diagnostic response was not JSON."
    };
  }
}

function summarizeDARTDiagnosticCheck(payload, httpStatus) {
  return compactObject({
    ok: payload?.ok === true,
    httpStatus,
    error: payload?.error || null,
    status: payload?.status || null,
    providerStatus: payload?.providerStatus || null,
    providerMessage: payload?.providerMessage || null,
    stage: payload?.stage || null,
    classification: payload?.classification || null,
    retryable: payload?.retryable === true ? true : null,
    mergeGate: payload?.mergeGate || null,
    elapsedMs: payload?.elapsedMs ?? null,
    count: payload?.count ?? null
  });
}

function concludeDARTDiagnosis(companyCheck, listCheck) {
  if (companyCheck.ok && listCheck.ok) {
    return "dart_ok";
  }
  if (companyCheck.error === "invalid_credentials") {
    return "dart_key_invalid";
  }
  if (companyCheck.error === "provider_permission_denied") {
    return "dart_key_or_ip_denied";
  }
  if (companyCheck.classification === "provider_reachability_failure") {
    return "opendart_company_reachability_failure";
  }
  if (companyCheck.ok && listCheck.classification === "provider_reachability_failure") {
    return "company_ok_list_fetch_failed";
  }
  if (companyCheck.ok && listCheck.error === "no_results") {
    return "company_ok_list_no_results";
  }
  if (!companyCheck.ok && !listCheck.ok) {
    return "dart_provider_or_key_failed";
  }
  return "dart_diagnostic_inconclusive";
}

function compactObject(value) {
  return Object.fromEntries(
    Object.entries(value).filter(([, entry]) => entry !== null && entry !== undefined && entry !== "")
  );
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
