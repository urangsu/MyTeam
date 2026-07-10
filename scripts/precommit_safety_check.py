#!/usr/bin/env python3
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

BLOCKED_PATH_PATTERNS = (
    "build/reports/",
    "graphify-out/",
    "myenv/",
    ".venv/",
    "DerivedData/",
    "xcuserdata/",
)

BLOCKED_FILE_SUFFIXES = (
    ".xcuserstate",
)

FORBIDDEN_SWIFT_PATTERNS = (
    ("Apple TTS runtime", r"\bAVSpeechSynthesizer\s*\("),
    ("Apple speech runtime", r"\bNSSpeechSynthesizer\s*\("),
    ("Apple speech utterance", r"\bAVSpeechUtterance\s*\("),
    ("legacy Animalese runtime", r"\bAnimalese\b"),
    ("legacy Animal Crossing naming", r"\bAnimal\s+Crossing\b"),
    ("legacy Chatterbox runtime", r"\bChatterbox\b"),
    ("legacy Qwen runtime", r"\bQwen\b"),
    ("legacy MLX runtime", r"\bMLX\b"),
)

FORBIDDEN_SETTINGS_PATTERNS = (
    ("legacy api settings tab", r"\bapiSettingsTab\b"),
    ("connector diagnostics view", r"\bConnectorStatusView\s*\("),
    ("playwright diagnostics view", r"\bPlaywrightMCPStatusView\s*\("),
)

BASIC_LOOKUP_WORKER_VERSION = "0.4.0"
BASIC_LOOKUP_WORKER_ROUTES = (
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
)


def run(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=ROOT, text=True, capture_output=True)


def staged_files() -> list[str]:
    result = run(["git", "diff", "--cached", "--name-only", "--diff-filter=ACMR"])
    if result.returncode != 0:
        print(result.stderr, file=sys.stderr)
        raise SystemExit(result.returncode)
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def staged_content(path: str) -> str:
    result = run(["git", "show", f":{path}"])
    if result.returncode != 0:
        print(result.stderr, file=sys.stderr)
        raise SystemExit(result.returncode)
    return result.stdout


def strip_swift_comments_and_strings(source: str) -> str:
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.S)
    source = re.sub(r"//.*", "", source)
    source = re.sub(r'#"(?:.|\n)*?"#', '""', source)
    source = re.sub(r'"(?:\\.|[^"\\])*"', '""', source)
    return source


def is_active_swift_runtime_path(path: str) -> bool:
    if not path.startswith("MyTeam/") or not path.endswith(".swift"):
        return False
    wrapped = f"/{path}"
    excluded = (
        "/tools/legacy/",
        "/legacy/",
        "/tmp/",
        "/build/",
        "/DerivedData/",
        "/Tests/",
    )
    if any(part in wrapped for part in excluded):
        return False
    name = Path(path).name
    if name.startswith("Preview") or name.startswith("Mock") or "Test" in name:
        return False
    return True


def main() -> None:
    failures: list[str] = []
    staged = staged_files()
    for path in staged:
        if any(blocked in path for blocked in BLOCKED_PATH_PATTERNS) or path.endswith(BLOCKED_FILE_SUFFIXES):
            failures.append(f"{path}: generated, local, or machine-specific file is blocked")
            continue

        if is_active_swift_runtime_path(path):
            source = strip_swift_comments_and_strings(staged_content(path))
            for label, pattern in FORBIDDEN_SWIFT_PATTERNS:
                if re.search(pattern, source):
                    failures.append(f"{path}: {label}")

        if path == "MyTeam/SettingsView.swift":
            source = strip_swift_comments_and_strings(staged_content(path))
            for label, pattern in FORBIDDEN_SETTINGS_PATTERNS:
                if re.search(pattern, source):
                    failures.append(f"{path}: {label}")

        if path == "workers/basic-lookup-api/worker.js":
            source = staged_content(path)
            expected_version = f'const VERSION = "{BASIC_LOOKUP_WORKER_VERSION}";'
            if expected_version not in source:
                failures.append(f"{path}: Worker version must be {BASIC_LOOKUP_WORKER_VERSION}")
            if re.search(r'const\s+BUILD\s*=\s*"[^"]+";', source) is None:
                failures.append(f"{path}: Worker BUILD marker missing")
            missing_routes = [route for route in BASIC_LOOKUP_WORKER_ROUTES if route not in source]
            if missing_routes:
                failures.append(f"{path}: /health route list missing {', '.join(missing_routes)}")
            if 'classification: "provider_reachability_failure"' not in source:
                failures.append(f"{path}: DART reachability failure classification missing")
            if 'mergeGate: "conditional-pass"' not in source:
                failures.append(f"{path}: DART conditional-pass merge gate marker missing")
            if 'retryable: true' not in source:
                failures.append(f"{path}: DART retryable marker missing")

    if "MyTeam/CharacterDialogues.swift" in staged:
        result = run(["python3", "scripts/report_character_dialogues.py", "--check-only"])
        if result.returncode != 0:
            failures.append("MyTeam/CharacterDialogues.swift: character dialogue report check failed")
            if result.stdout:
                print(result.stdout, file=sys.stderr)
            if result.stderr:
                print(result.stderr, file=sys.stderr)

    if failures:
        print("precommit safety check failed:", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        raise SystemExit(1)

    print("precommit safety check passed")


if __name__ == "__main__":
    main()
