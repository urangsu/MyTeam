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
    for path in staged_files():
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

    if failures:
        print("precommit safety check failed:", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        raise SystemExit(1)

    print("precommit safety check passed")


if __name__ == "__main__":
    main()
