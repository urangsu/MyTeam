#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import urllib.error
import urllib.request
import os
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_BASE_URL = "https://late-waterfall-c95c.urange.workers.dev"
EXPECTED_VERSION = "0.4.1"
EXPECTED_BUILD = "public-lookup-0.4.1"
EXPECTED_CONTRACT_VERSION = 3
REQUIRED_USER_ROUTES = {
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
    "/law/search?query=근로기준법&display=2",
}
DIAGNOSTIC_ROUTES = {
    "/dart/company?corpCode=00126380",
    "/dart/recent?corpCode=00126380",
    "/dart/diagnose?corpCode=00126380",
}
DIAGNOSTIC_TOKEN_ENV = "MYTEAM_DIAGNOSTIC_TOKEN"
DIAGNOSTIC_TOKEN_HEADER = "x-myteam-diagnostic-token"
WORKER_SOURCE_PATH = "workers/basic-lookup-api"


def expected_worker_git_sha() -> str:
    dirty = subprocess.run(
        ["git", "status", "--porcelain", "--", WORKER_SOURCE_PATH],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=True,
    ).stdout.strip()
    if dirty:
        raise SystemExit("FAIL: Worker source has uncommitted changes; production deployment cannot be verified")

    return subprocess.check_output(
        ["git", "log", "-1", "--format=%H", "--", WORKER_SOURCE_PATH],
        cwd=ROOT,
        text=True,
    ).strip()


def fetch_health(base_url: str) -> dict[str, object]:
    url = base_url.rstrip("/") + "/health"
    request = urllib.request.Request(url, headers={"Accept": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            payload = response.read().decode("utf-8")
    except urllib.error.URLError as exc:
        curl = subprocess.run(
            ["/usr/bin/curl", "-fsS", "--max-time", "20", url],
            text=True,
            capture_output=True,
            check=False,
        )
        if curl.returncode != 0:
            detail = curl.stderr.strip() or str(exc)
            raise SystemExit(f"FAIL: Worker production /health request failed: {detail}") from exc
        payload = curl.stdout

    try:
        data = json.loads(payload)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"FAIL: Worker production /health returned invalid JSON: {exc}") from exc

    if not isinstance(data, dict):
        raise SystemExit("FAIL: Worker production /health must return a JSON object")
    return data


def fetch_status(base_url: str, route: str, headers: dict[str, str] | None = None) -> int:
    url = base_url.rstrip("/") + route
    request_headers = {"Accept": "application/json"}
    if headers:
        request_headers.update(headers)
    request = urllib.request.Request(url, headers=request_headers)
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            response.read()
            return response.status
    except urllib.error.HTTPError as exc:
        return exc.code
    except urllib.error.URLError as exc:
        curl = subprocess.run(
            ["/usr/bin/curl", "-sS", "-o", "/dev/null", "-w", "%{http_code}", "--max-time", "5", url],
            text=True,
            capture_output=True,
            check=False,
        )
        if curl.returncode != 0:
            detail = curl.stderr.strip() or str(exc)
            raise SystemExit(f"FAIL: Worker diagnostic route request failed: {detail}") from exc
        try:
            return int(curl.stdout.strip())
        except ValueError as value_error:
            raise SystemExit(f"FAIL: Worker diagnostic route returned invalid status: {curl.stdout!r}") from value_error


def fetch_json_status(
    base_url: str,
    route: str,
    headers: dict[str, str] | None = None,
) -> tuple[int, dict[str, object] | None]:
    url = base_url.rstrip("/") + route
    request_headers = {"Accept": "application/json"}
    if headers:
        request_headers.update(headers)
    request = urllib.request.Request(url, headers=request_headers)
    payload = ""
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            payload = response.read().decode("utf-8")
            status = response.status
    except urllib.error.HTTPError as exc:
        status = exc.code
        payload = exc.read().decode("utf-8", errors="replace")
    except urllib.error.URLError as exc:
        raise SystemExit(f"FAIL: Worker diagnostic route request failed: {exc}") from exc

    try:
        data = json.loads(payload) if payload else None
    except json.JSONDecodeError:
        return status, None
    return status, data if isinstance(data, dict) else None


def string_list(data: dict[str, object], key: str) -> list[str] | None:
    value = data.get(key)
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        return None
    return value


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate deployed Cloudflare Worker /health contract.")
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL)
    parser.add_argument(
        "--validate-diagnostic-auth",
        action="store_true",
        help=f"Also validate an authenticated diagnostic request using {DIAGNOSTIC_TOKEN_ENV}.",
    )
    args = parser.parse_args()

    data = fetch_health(args.base_url)
    failures: list[str] = []

    if data.get("ok") is not True:
        failures.append("ok must be true")
    if data.get("service") != "myteam-basic-lookup-api":
        failures.append("service must be myteam-basic-lookup-api")
    if data.get("version") != EXPECTED_VERSION:
        failures.append(f"version must be {EXPECTED_VERSION}")
    if data.get("build") != EXPECTED_BUILD:
        failures.append(f"build must be {EXPECTED_BUILD}")
    if data.get("contractVersion") != EXPECTED_CONTRACT_VERSION:
        failures.append(f"contractVersion must be {EXPECTED_CONTRACT_VERSION}")
    git_sha = data.get("gitSha")
    if not isinstance(git_sha, str) or not re.fullmatch(r"[0-9a-f]{40}", git_sha):
        failures.append("gitSha must be a 40-character lowercase commit SHA")
    else:
        expected_sha = expected_worker_git_sha()
        if git_sha != expected_sha:
            failures.append("gitSha must match the latest commit that changed Worker source")
    deployed_at = data.get("deployedAt")
    if not isinstance(deployed_at, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z", deployed_at):
        failures.append("deployedAt must be an ISO-8601 UTC timestamp like 2026-07-08T12:34:56Z")

    user_routes = string_list(data, "userRoutes")
    if user_routes is None:
        failures.append("userRoutes must be present as a string array")
        user_routes = []
    if "diagnosticRoutes" in data:
        failures.append("diagnosticRoutes must not expose diagnostic path names in public /health")
    diagnostic_contract = data.get("diagnosticContract")
    if not isinstance(diagnostic_contract, dict):
        failures.append("diagnosticContract must be present as an object")
        diagnostic_contract = {}
    else:
        if diagnostic_contract.get("enabled") is not True:
            failures.append("diagnosticContract.enabled must be true")
        if diagnostic_contract.get("routeCount") != len(DIAGNOSTIC_ROUTES):
            failures.append(f"diagnosticContract.routeCount must be {len(DIAGNOSTIC_ROUTES)}")
        if diagnostic_contract.get("auth") != "header-token":
            failures.append("diagnosticContract.auth must be header-token")
    abuse_controls = data.get("abuseControls")
    if not isinstance(abuse_controls, dict):
        failures.append("abuseControls must be present as an object")
    else:
        if abuse_controls.get("rateLimitBinding") is not True:
            failures.append("abuseControls.rateLimitBinding must be true")
        if abuse_controls.get("rateLimitScope") != "cloudflare-location":
            failures.append("abuseControls.rateLimitScope must be cloudflare-location")
        if abuse_controls.get("cacheAPI") is not True:
            failures.append("abuseControls.cacheAPI must be true")
        if abuse_controls.get("cacheContractVersion") != 1:
            failures.append("abuseControls.cacheContractVersion must be 1")

    user_set = set(user_routes)
    missing_user = sorted(REQUIRED_USER_ROUTES - user_set)
    if missing_user:
        failures.append("missing userRoutes: " + ", ".join(missing_user))
    if any(route.startswith("/dart/") for route in user_routes):
        failures.append("DART routes must not appear in userRoutes")
    should_probe_diagnostics = not failures
    if should_probe_diagnostics:
        for route in sorted(DIAGNOSTIC_ROUTES):
            status = fetch_status(args.base_url, route)
            if status != 404:
                failures.append(f"diagnostic route without token must return HTTP 404: {route} returned HTTP {status}")
            wrong_status = fetch_status(args.base_url, route, {DIAGNOSTIC_TOKEN_HEADER: "invalid-diagnostic-token"})
            if wrong_status != 404:
                failures.append(f"diagnostic route with wrong token must return HTTP 404: {route} returned HTTP {wrong_status}")
    if args.validate_diagnostic_auth:
        token = os.environ.get(DIAGNOSTIC_TOKEN_ENV, "").strip()
        if not token:
            failures.append(f"{DIAGNOSTIC_TOKEN_ENV} must be set for --validate-diagnostic-auth")
        elif should_probe_diagnostics:
            for route in sorted(DIAGNOSTIC_ROUTES):
                status, payload = fetch_json_status(args.base_url, route, {DIAGNOSTIC_TOKEN_HEADER: token})
                schema_failure = diagnostic_payload_failure(route, status, payload)
                if schema_failure:
                    failures.append(schema_failure)

    if failures:
        print("FAIL: Worker production /health validation")
        for failure in failures:
            print(f"- {failure}")
        print("Observed /health:")
        print(json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True))
        return 1

    print("PASS: Worker production /health validation")
    return 0


def diagnostic_payload_failure(route: str, status: int, payload: dict[str, object] | None) -> str | None:
    if status == 404:
        return f"diagnostic route with valid token must not return HTTP 404: {route}"
    if status == 500:
        return f"diagnostic route with valid token must not return HTTP 500: {route}"
    if payload is None:
        return f"diagnostic route with valid token must return JSON: {route}"
    if payload.get("provider") != "dart":
        return f"diagnostic route with valid token must return provider=dart: {route}"
    if payload.get("error") == "not_found":
        return f"diagnostic route with valid token must not return not_found JSON: {route}"

    route_type = "company" if route.startswith("/dart/company") else "diagnose" if route.startswith("/dart/diagnose") else "recent"
    if status < 300:
        if route_type == "company" and payload.get("type") != "company":
            return f"diagnostic company route must return type=company on HTTP {status}: {route}"
        if route_type == "diagnose" and payload.get("type") != "diagnose":
            return f"diagnostic diagnose route must return type=diagnose on HTTP {status}: {route}"
        if route_type == "recent" and not ("items" in payload or payload.get("error") == "no_results"):
            return f"diagnostic recent route must return items or no_results on HTTP {status}: {route}"
        return None

    if status >= 500:
        if isinstance(payload.get("stage"), str) or isinstance(payload.get("classification"), str):
            return None
        return f"diagnostic route provider failure must include stage or classification: {route} HTTP {status}"

    return f"diagnostic route with valid token returned unexpected HTTP {status}: {route}"


if __name__ == "__main__":
    sys.exit(main())
