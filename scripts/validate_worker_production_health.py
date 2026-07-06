#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import urllib.error
import urllib.request


DEFAULT_BASE_URL = "https://late-waterfall-c95c.urange.workers.dev"
EXPECTED_VERSION = "0.3.0"
EXPECTED_BUILD = "public-lookup-0.3.0"
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
REQUIRED_DIAGNOSTIC_ROUTES = {
    "/dart/company?corpCode=00126380",
    "/dart/recent?corpCode=00126380",
    "/dart/diagnose?corpCode=00126380",
}


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


def fetch_status(base_url: str, route: str) -> int:
    url = base_url.rstrip("/") + route
    request = urllib.request.Request(url, headers={"Accept": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
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


def string_list(data: dict[str, object], key: str) -> list[str] | None:
    value = data.get(key)
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        return None
    return value


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate deployed Cloudflare Worker /health contract.")
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL)
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

    user_routes = string_list(data, "userRoutes")
    diagnostic_routes = string_list(data, "diagnosticRoutes")
    if user_routes is None:
        failures.append("userRoutes must be present as a string array")
        user_routes = []
    if diagnostic_routes is None:
        failures.append("diagnosticRoutes must be present as a string array")
        diagnostic_routes = []

    user_set = set(user_routes)
    diagnostic_set = set(diagnostic_routes)
    missing_user = sorted(REQUIRED_USER_ROUTES - user_set)
    missing_diagnostic = sorted(REQUIRED_DIAGNOSTIC_ROUTES - diagnostic_set)
    if missing_user:
        failures.append("missing userRoutes: " + ", ".join(missing_user))
    if missing_diagnostic:
        failures.append("missing diagnosticRoutes: " + ", ".join(missing_diagnostic))
    if any(route.startswith("/dart/") for route in user_routes):
        failures.append("DART routes must not appear in userRoutes")
    for route in sorted(REQUIRED_DIAGNOSTIC_ROUTES):
        status = fetch_status(args.base_url, route)
        if status not in {401, 403, 404}:
            failures.append(f"diagnostic route must reject unauthenticated access: {route} returned HTTP {status}")

    if failures:
        print("FAIL: Worker production /health validation")
        for failure in failures:
            print(f"- {failure}")
        print("Observed /health:")
        print(json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True))
        return 1

    print("PASS: Worker production /health validation")
    return 0


if __name__ == "__main__":
    sys.exit(main())
