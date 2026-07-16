#!/usr/bin/env python3
import json
import subprocess
import sys
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]


CHECKS = [
    ["node", "--check", "workers/basic-lookup-api/worker.js"],
    ["node", "--test", "workers/basic-lookup-api/worker.test.mjs"],
    ["python3", "scripts/validate_myteam_release_tests.py"],
    ["python3", "scripts/validate_release_checklist.py"],
    ["python3", "scripts/validate_skill_packages.py"],
    ["python3", "scripts/validate_app_store_profile.py"],
    ["python3", "scripts/validate_supertonic3_bundle.py", "--profile", "appstore"],
    ["python3", "scripts/validate_tts_runtime_truth.py"],
    ["python3", "scripts/report_character_dialogues.py", "--check-only"],
    ["python3", "scripts/audit_product_completeness.py"],
    ["python3", "scripts/validate_app_termination_architecture.py"],
    ["python3", "scripts/smoke_natural_work_e2e.py"],
    ["python3", "scripts/validate_tool_recovery_actions.py"],
    ["python3", "scripts/validate_result_presentation.py"],
    ["python3", "scripts/validate_conversation_presentation.py"],
    ["python3", "scripts/validate_release_qa_evidence.py"],
    ["python3", "scripts/validate_launch_readiness.py"],
]


FORBIDDEN_RELEASE_PATTERNS = [
    ("UserDefaults API key/token storage", r"UserDefaults.*apiKey|UserDefaults.*token|apiKey.*UserDefaults|token.*UserDefaults"),
    ("cost/usage quota UI", r"estimated.*cost|usage.*limit|무료.*호출|잔여.*량"),
]


FORBIDDEN_SETTINGS_SURFACE_PATTERNS = [
    ("legacy api settings tab", r"\bapiSettingsTab\b"),
    ("connector diagnostics view", r"\bConnectorStatusView\s*\("),
    ("playwright diagnostics view", r"\bPlaywrightMCPStatusView\s*\("),
]


FORBIDDEN_ACTIVE_SWIFT_PATTERNS = [
    ("Apple TTS runtime", r"\bAVSpeechSynthesizer\s*\("),
    ("Apple speech runtime", r"\bNSSpeechSynthesizer\s*\("),
    ("Apple speech utterance", r"\bAVSpeechUtterance\s*\("),
    ("legacy Animalese runtime", r"\bAnimalese\b"),
    ("legacy Animal Crossing naming", r"\bAnimal\s+Crossing\b"),
    ("legacy Chatterbox runtime", r"\bChatterbox\b"),
    ("legacy Qwen runtime", r"\bQwen\b"),
    ("legacy MLX runtime", r"\bMLX\b"),
]


BASIC_LOOKUP_WORKER_VERSION = "0.4.1"
BASIC_LOOKUP_WORKER_ROUTES = [
    "/health",
    "/news/search?query=삼성전자",
    "/dart/company?corpCode=00126380",
    "/dart/recent?corpCode=00126380",
    "/dart/diagnose?corpCode=00126380",
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
]


def run(command: list[str]) -> None:
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
    if result.stdout:
        print(result.stdout, end="")
    if result.returncode != 0:
        if result.stderr:
            print(result.stderr, end="", file=sys.stderr)
        raise SystemExit(result.returncode)


def find_forbidden_swift_matches(root: Path, pattern: str) -> list[str]:
    matches: list[str] = []
    regex = re.compile(pattern)
    source_root = root / "MyTeam"
    for path in sorted(source_root.rglob("*.swift")):
        relative = path.relative_to(root)
        if relative.parts[:3] == ("MyTeam", "tools", "legacy"):
            continue
        for line_number, line in enumerate(
            path.read_text(encoding="utf-8", errors="ignore").splitlines(),
            start=1,
        ):
            if regex.search(line):
                matches.append(f"{relative.as_posix()}:{line_number}:{line}")
    return matches


def run_forbidden_grep(label: str, pattern: str) -> None:
    matches = find_forbidden_swift_matches(ROOT, pattern)
    if matches:
        print("\n".join(matches), file=sys.stderr)
        raise SystemExit(f"FAIL: forbidden pattern found: {label}")


def descriptor_blocks(source: str) -> list[str]:
    marker = "MyTeamToolDescriptor("
    blocks: list[str] = []
    start = 0
    while True:
        marker_index = source.find(marker, start)
        if marker_index == -1:
            break
        open_index = marker_index + len("MyTeamToolDescriptor")
        depth = 0
        end_index = None
        for index in range(open_index, len(source)):
            char = source[index]
            if char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
                if depth == 0:
                    end_index = index + 1
                    break
        if end_index is None:
            raise SystemExit("FAIL: unterminated MyTeamToolDescriptor block")
        blocks.append(source[marker_index:end_index])
        start = end_index
    return blocks


def validate_tool_descriptors() -> None:
    registry_path = ROOT / "MyTeam" / "MyTeamToolRegistry.swift"
    source = registry_path.read_text()
    failures: list[str] = []
    for block in descriptor_blocks(source):
        id_match = re.search(r'id:\s*"([^"]+)"', block)
        tool_id = id_match.group(1) if id_match else "<unknown>"
        is_implemented_false = re.search(r"isImplemented:\s*false\b", block) is not None
        is_user_facing_true = re.search(r"isUserFacing:\s*true\b", block) is not None
        if is_implemented_false and is_user_facing_true:
            failures.append(tool_id)

    if failures:
        joined = ", ".join(failures)
        raise SystemExit(f"FAIL: unimplemented user-facing tools: {joined}")


def validate_settings_surface() -> None:
    settings_path = ROOT / "MyTeam" / "SettingsView.swift"
    source = settings_path.read_text()
    for label, pattern in FORBIDDEN_SETTINGS_SURFACE_PATTERNS:
        if re.search(pattern, source):
            raise SystemExit(f"FAIL: forbidden SettingsView surface found: {label}")


def is_git_tracked(path: Path) -> bool:
    relative = path.relative_to(ROOT).as_posix()
    result = subprocess.run(
        ["git", "ls-files", "--error-unmatch", relative],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )
    return result.returncode == 0


def validate_release_capability_manifest() -> None:
    template_path = ROOT / "MyTeam" / "Resources" / "ReleaseCapabilityManifest.template.json"
    generated_path = ROOT / "MyTeam" / "Resources" / "ReleaseCapabilityManifest.generated.json"
    loader_path = ROOT / "MyTeam" / "ReleaseCapabilityManifest.swift"
    surface_path = ROOT / "MyTeam" / "ProductSurfacePolicy.swift"

    if not loader_path.exists():
        raise SystemExit("FAIL: ReleaseCapabilityManifest.swift missing")
    if not template_path.exists():
        raise SystemExit("FAIL: ReleaseCapabilityManifest.template.json missing")
    if is_git_tracked(generated_path):
        raise SystemExit("FAIL: generated release capability manifest must not be tracked")

    data = json.loads(template_path.read_text(encoding="utf-8"))
    if data.get("schema_version") != 1:
        raise SystemExit("FAIL: ReleaseCapabilityManifest template schema_version must be 1")
    if data.get("tested_commit") != "UNTESTED":
        raise SystemExit("FAIL: ReleaseCapabilityManifest template must not assert tested_commit")
    providers = data.get("providers")
    if not isinstance(providers, dict):
        raise SystemExit("FAIL: ReleaseCapabilityManifest template providers must be an object")
    for key in ["google", "finance", "dart", "kma", "news", "law"]:
        if providers.get(key) != "DISABLED":
            raise SystemExit(f"FAIL: ReleaseCapabilityManifest template must be fail-closed: {key}")
    worker = data.get("worker")
    if not isinstance(worker, dict) or worker.get("production_health") != "DISABLED":
        raise SystemExit("FAIL: ReleaseCapabilityManifest template worker must be fail-closed")

    loader_source = loader_path.read_text(encoding="utf-8")
    if '"ReleaseCapabilityManifest.generated"' not in loader_source and "ReleaseCapabilityManifest.generated" not in loader_source:
        raise SystemExit("FAIL: release capability loader must read generated manifest at runtime")
    if "ReleaseCapabilityManifest.template" not in loader_source:
        raise SystemExit("FAIL: release capability loader must name the template separately from generated evidence")

    surface_source = surface_path.read_text(encoding="utf-8")
    for token in [
        "workerProductionHealthPassed",
        "googleLiveQAPassed",
        "financeLiveQAPassed",
        "dartLiveQAPassed",
        "kmaLiveQAPassed",
        "newsLiveQAPassed",
        "lawLiveQAPassed",
    ]:
        if token in surface_source:
            raise SystemExit(f"FAIL: ReleaseLiveProviderGate must not use hardcoded provider boolean: {token}")
    if re.search(r"default:\s*return\s+true", surface_source):
        raise SystemExit("FAIL: ReleaseLiveProviderGate must not default unknown capabilities to enabled")
    for token in [
        "workerIsRuntimeCompatible",
        "isKnownLocalSafeCapability",
        "ReleaseCapabilityManifestStore.status",
        "ReleaseCapabilityManifestStore.hasGeneratedManifest",
    ]:
        if token not in surface_source:
            raise SystemExit(f"FAIL: ReleaseLiveProviderGate missing manifest-backed guard: {token}")


def strip_swift_comments_and_strings(source: str) -> str:
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.S)
    source = re.sub(r"//.*", "", source)
    source = re.sub(r'#"(?:.|\n)*?"#', '""', source)
    source = re.sub(r'"(?:\\.|[^"\\])*"', '""', source)
    return source


def is_active_swift_runtime_file(path: Path) -> bool:
    relative = path.relative_to(ROOT).as_posix()
    if not relative.startswith("MyTeam/") or not relative.endswith(".swift"):
        return False
    excluded_parts = (
        "/tools/legacy/",
        "/legacy/",
        "/tmp/",
        "/build/",
        "/DerivedData/",
        "/Tests/",
    )
    wrapped = f"/{relative}"
    if any(part in wrapped for part in excluded_parts):
        return False
    name = path.name
    if name.startswith("Preview") or name.startswith("Mock") or "Test" in name:
        return False
    return True


def validate_active_swift_runtime() -> None:
    failures: list[str] = []
    for path in sorted((ROOT / "MyTeam").rglob("*.swift")):
        if not is_active_swift_runtime_file(path):
            continue
        source = strip_swift_comments_and_strings(path.read_text())
        relative = path.relative_to(ROOT).as_posix()
        for label, pattern in FORBIDDEN_ACTIVE_SWIFT_PATTERNS:
            if re.search(pattern, source):
                failures.append(f"{relative}: {label}")
    if failures:
        details = "\n".join(f"- {failure}" for failure in failures)
        raise SystemExit(f"FAIL: forbidden active Swift runtime pattern found:\n{details}")


def validate_basic_lookup_worker_source() -> None:
    worker_path = ROOT / "workers" / "basic-lookup-api" / "worker.js"
    if not worker_path.exists():
        raise SystemExit("FAIL: basic lookup Worker source missing")
    source = worker_path.read_text()
    expected_version = f'const VERSION = "{BASIC_LOOKUP_WORKER_VERSION}";'
    if expected_version not in source:
        raise SystemExit(f"FAIL: basic lookup Worker version must be {BASIC_LOOKUP_WORKER_VERSION}")
    if re.search(r'const\s+BUILD\s*=\s*"[^"]+";', source) is None:
        raise SystemExit("FAIL: basic lookup Worker BUILD marker missing")
    missing_routes = [route for route in BASIC_LOOKUP_WORKER_ROUTES if route not in source]
    if missing_routes:
        joined = ", ".join(missing_routes)
        raise SystemExit(f"FAIL: basic lookup Worker /health route list missing: {joined}")
    user_routes_match = re.search(r"const\s+USER_ROUTES\s*=\s*\[(.*?)\];", source, re.S)
    diagnostic_routes_match = re.search(r"const\s+DIAGNOSTIC_ROUTES\s*=\s*\[(.*?)\];", source, re.S)
    if user_routes_match is None or diagnostic_routes_match is None:
        raise SystemExit("FAIL: basic lookup Worker source must define user and diagnostic route manifests")
    if "/dart/" in user_routes_match.group(1):
        raise SystemExit("FAIL: DART routes must not appear in basic lookup userRoutes")
    for route in ["/dart/company?corpCode=00126380", "/dart/recent?corpCode=00126380", "/dart/diagnose?corpCode=00126380"]:
        if route not in diagnostic_routes_match.group(1):
            raise SystemExit(f"FAIL: DART diagnostic route missing from diagnosticRoutes: {route}")
    health_response_match = re.search(r"if\s*\(url\.pathname === \"/\" \|\| url\.pathname === \"/health\"\)\s*\{(.*?)\n\s*\}", source, re.S)
    health_response = health_response_match.group(1) if health_response_match else ""
    if "userRoutes: USER_ROUTES" not in health_response or "diagnosticContract:" not in health_response:
        raise SystemExit("FAIL: basic lookup Worker /health must expose userRoutes and diagnosticContract")
    if "diagnosticRoutes:" in health_response:
        raise SystemExit("FAIL: basic lookup Worker /health must not expose diagnostic route path names")
    for token in ["CONTRACT_VERSION = 3", "MYTEAM_WORKER_GIT_SHA", "MYTEAM_WORKER_DEPLOYED_AT", "contractVersion:", "gitSha:", "deployedAt:"]:
        if token not in source:
            raise SystemExit(f"FAIL: basic lookup Worker missing deploy provenance contract: {token}")
    for token in ["PUBLIC_LOOKUP_RATE_LIMITER", "function rateLimit", "function withLookupCache", "globalThis.caches?.default", "function providerFetch", "PROVIDER_TIMEOUT_MS", "MAX_UPSTREAM_BYTES"]:
        if token not in source:
            raise SystemExit(f"FAIL: basic lookup Worker missing public route abuse guard: {token}")
    for token in ["abuseControls:", "rateLimitBinding:", "cacheContractVersion:"]:
        if token not in source:
            raise SystemExit(f"FAIL: basic lookup Worker /health missing abuse-control contract: {token}")
    for token in ['event: "provider_request"', 'event: "rate_limited"', "requestId:", "latencyMs:"]:
        if token not in source:
            raise SystemExit(f"FAIL: basic lookup Worker missing structured observability contract: {token}")
    wrangler_source = (worker_path.parent / "wrangler.jsonc").read_text()
    for token in ['"name": "PUBLIC_LOOKUP_RATE_LIMITER"', '"limit": 120', '"period": 60']:
        if token not in wrangler_source:
            raise SystemExit(f"FAIL: basic lookup Worker rate-limit binding config missing: {token}")
    if "function requireDiagnosticAccess" not in source or "DIAGNOSTIC_ROUTE_TOKEN" not in source:
        raise SystemExit("FAIL: basic lookup Worker diagnostic routes must require a diagnostic token")
    if 'url.pathname.startsWith("/dart/")' not in source or "requireDiagnosticAccess(request, env)" not in source:
        raise SystemExit("FAIL: basic lookup Worker must gate /dart/* diagnostic routes before handling them")
    if 'classification: "provider_reachability_failure"' not in source:
        raise SystemExit("FAIL: basic lookup Worker must classify DART reachability failures")
    if 'mergeGate: "conditional-pass"' not in source:
        raise SystemExit("FAIL: basic lookup Worker must mark DART reachability failures as conditional-pass")
    if 'retryable: true' not in source:
        raise SystemExit("FAIL: basic lookup Worker must mark DART reachability failures as retryable")
    app_source = "\n".join(path.read_text(errors="ignore") for path in (ROOT / "MyTeam").rglob("*") if path.is_file() and path.suffix in {".swift", ".plist", ".json"})
    for token in ["DIAGNOSTIC_ROUTE_TOKEN", "x-myteam-diagnostic-token"]:
        if token in app_source:
            raise SystemExit(f"FAIL: diagnostic token contract must not be embedded in app bundle/runtime: {token}")


def main() -> None:
    for command in CHECKS:
        run(command)
    for label, pattern in FORBIDDEN_RELEASE_PATTERNS:
        run_forbidden_grep(label, pattern)
    validate_tool_descriptors()
    validate_settings_surface()
    validate_release_capability_manifest()
    validate_active_swift_runtime()
    validate_basic_lookup_worker_source()
    print("PASS: MyTeam release validators")


if __name__ == "__main__":
    main()
