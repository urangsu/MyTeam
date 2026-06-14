#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]


CHECKS = [
    ["python3", "scripts/validate_release_checklist.py"],
    ["python3", "scripts/validate_skill_packages.py"],
    ["python3", "scripts/validate_app_store_profile.py"],
    ["python3", "scripts/validate_supertonic3_bundle.py", "--profile", "appstore"],
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


def main() -> None:
    for command in CHECKS:
        run(command)
    for label, pattern in FORBIDDEN_RELEASE_PATTERNS:
        run_forbidden_grep(label, pattern)
    validate_tool_descriptors()
    validate_settings_surface()
    print("PASS: MyTeam release validators")


if __name__ == "__main__":
    main()
