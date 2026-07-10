import assert from "node:assert/strict";
import test from "node:test";

import worker from "./worker.js";

class MemoryCache {
  constructor() {
    this.values = new Map();
  }

  async match(request) {
    return this.values.get(request.url)?.clone();
  }

  async put(request, response) {
    this.values.set(request.url, response.clone());
  }
}

function context() {
  const pending = [];
  return {
    waitUntil(promise) {
      pending.push(promise);
    },
    async flush() {
      await Promise.all(pending);
    }
  };
}

function environment(rateLimitResult = true) {
  return {
    NAVER_CLIENT_ID: "test-client",
    NAVER_CLIENT_SECRET: "test-secret",
    PUBLIC_LOOKUP_RATE_LIMITER: {
      async limit() {
        return { success: rateLimitResult };
      }
    }
  };
}

function lookupRequest(query = "query=삼성전자&display=2") {
  return new Request(`https://worker.example/news/search?${query}`, {
    headers: {
      "CF-Connecting-IP": "203.0.113.10"
    }
  });
}

function validNewsResponse() {
  return new Response(JSON.stringify({
    items: [
      {
        title: "삼성전자 소식",
        originallink: "https://example.com/news/1",
        link: "https://example.com/news/1",
        description: "검색 결과 설명",
        pubDate: "Fri, 10 Jul 2026 10:00:00 +0900"
      }
    ]
  }), {
    status: 200,
    headers: { "content-type": "application/json" }
  });
}

test("fails closed when the rate limiting binding is missing", async () => {
  globalThis.caches = { default: new MemoryCache() };
  let upstreamCalls = 0;
  globalThis.fetch = async () => {
    upstreamCalls += 1;
    return validNewsResponse();
  };

  const response = await worker.fetch(lookupRequest(), {
    NAVER_CLIENT_ID: "test-client",
    NAVER_CLIENT_SECRET: "test-secret"
  }, context());
  const payload = await response.json();

  assert.equal(response.status, 503);
  assert.equal(payload.error, "rate_limit_unavailable");
  assert.equal(upstreamCalls, 0);
});

test("returns 429 when the platform limiter rejects the request", async () => {
  globalThis.caches = { default: new MemoryCache() };
  const response = await worker.fetch(lookupRequest(), environment(false), context());
  const payload = await response.json();

  assert.equal(response.status, 429);
  assert.equal(payload.error, "rate_limited");
});

test("caches successful lookups with a canonical query key", async () => {
  globalThis.caches = { default: new MemoryCache() };
  let upstreamCalls = 0;
  globalThis.fetch = async () => {
    upstreamCalls += 1;
    return validNewsResponse();
  };

  const firstContext = context();
  const first = await worker.fetch(lookupRequest("display=2&query=삼성전자"), environment(), firstContext);
  await firstContext.flush();
  const second = await worker.fetch(lookupRequest("query=삼성전자&display=2"), environment(), context());

  assert.equal(first.status, 200);
  assert.equal(first.headers.get("x-myteam-cache"), "MISS");
  assert.equal(second.status, 200);
  assert.equal(second.headers.get("x-myteam-cache"), "HIT");
  assert.equal(second.headers.get("cache-control"), "no-store");
  assert.ok(first.headers.get("x-myteam-request-id"));
  assert.ok(second.headers.get("x-myteam-request-id"));
  assert.notEqual(first.headers.get("x-myteam-request-id"), second.headers.get("x-myteam-request-id"));
  assert.equal(upstreamCalls, 1);
});

test("does not cache provider failures", async () => {
  globalThis.caches = { default: new MemoryCache() };
  let upstreamCalls = 0;
  globalThis.fetch = async () => {
    upstreamCalls += 1;
    return new Response("unavailable", { status: 503 });
  };

  const first = await worker.fetch(lookupRequest(), environment(), context());
  const second = await worker.fetch(lookupRequest(), environment(), context());

  assert.equal(first.status, 502);
  assert.equal(second.status, 502);
  assert.equal(upstreamCalls, 2);
});

test("keeps diagnostic routes hidden before rate limiting", async () => {
  globalThis.caches = { default: new MemoryCache() };
  const request = new Request("https://worker.example/dart/company?corpCode=00126380");
  const response = await worker.fetch(request, {}, context());
  const payload = await response.json();

  assert.equal(response.status, 404);
  assert.equal(payload.error, "not_found");
});
