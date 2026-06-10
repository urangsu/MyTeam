#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


CHECKS = [
    ["python3", "scripts/validate_release_checklist.py"],
    ["python3", "scripts/validate_skill_packages.py"],
    ["python3", "scripts/validate_app_store_profile.py"],
]


FORBIDDEN_RELEASE_PATTERNS = [
    ("UserDefaults API key/token storage", r"UserDefaults.*apiKey|UserDefaults.*token|apiKey.*UserDefaults|token.*UserDefaults"),
    ("cost/usage quota UI", r"estimated.*cost|usage.*limit|무료.*호출|잔여.*량"),
]


def run(command: list[str]) -> None:
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
    if result.stdout:
        print(result.stdout, end="")
    if result.returncode != 0:
        if result.stderr:
            print(result.stderr, end="", file=sys.stderr)
        raise SystemExit(result.returncode)


def run_forbidden_grep(label: str, pattern: str) -> None:
    command = [
        "rg",
        "--glob",
        "*.swift",
        "--glob",
        "!tools/legacy/**",
        pattern,
        "MyTeam",
    ]
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
    if result.returncode == 0:
        print(result.stdout, file=sys.stderr)
        raise SystemExit(f"FAIL: forbidden pattern found: {label}")
    if result.returncode > 1:
        print(result.stderr, file=sys.stderr)
        raise SystemExit(result.returncode)


def main() -> None:
    for command in CHECKS:
        run(command)
    for label, pattern in FORBIDDEN_RELEASE_PATTERNS:
        run_forbidden_grep(label, pattern)
    print("PASS: MyTeam release validators")


if __name__ == "__main__":
    main()
