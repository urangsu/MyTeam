#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    target = ROOT / path
    if not target.exists():
        raise SystemExit(f"FAIL: missing expected file: {path}")
    return target.read_text(encoding="utf-8")


def collect_action_ids(paths: list[Path]) -> set[str]:
    pattern = re.compile(r'MyTeamNextAction\s*\(\s*id:\s*"([^"]+)"')
    action_ids: set[str] = set()
    for path in paths:
        if not path.exists():
            continue
        source = path.read_text(encoding="utf-8")
        action_ids.update(pattern.findall(source))
    return action_ids


def main() -> None:
    runners_dir = ROOT / "MyTeam" / "ToolRunners"
    producer_paths = sorted(runners_dir.glob("*.swift")) + [
        ROOT / "MyTeam" / "ToolResultFormatters.swift",
    ]
    produced = collect_action_ids(producer_paths)

    ui_sources = "\n".join([
        read("MyTeam/ToolResultCardView.swift"),
        read("MyTeam/HomeDashboardView.swift"),
        read("MyTeam/ToolActionCardView.swift"),
        read("MyTeam/ToolExecutionLogView.swift"),
    ])

    handled: set[str] = set(re.findall(r'case\s+"([^"]+)"', ui_sources))
    # The HomeDashboard switch handles these ids as comma-separated cases.
    handled.update(re.findall(r'"([^"]+)"', ui_sources))

    allow_documented_only: set[str] = set()
    unhandled = sorted(produced - handled - allow_documented_only)
    failures: list[str] = []

    if unhandled:
        failures.append("unhandled tool recovery/action ids: " + ", ".join(unhandled))

    required = {
        "openConnection": "external connection routing",
        "openAssistantConnection": "assistant connector routing",
        "changeKeyword": "input correction routing",
        "searchAgain": "retry routing",
        "retryLater": "retry-later routing",
    }
    for action_id, label in required.items():
        if action_id in produced and action_id not in handled:
            failures.append(f"{label} action is produced but not handled: {action_id}")

    if "openConnection" in produced and "onOpenConnection" not in ui_sources:
        failures.append("openConnection action must route to connection settings")
    if "openAssistantConnection" in produced and "onOpenAssistantConnection" not in ui_sources:
        failures.append("openAssistantConnection action must route to assistant connection settings")
    if "retryLater" in produced and "retryLater" not in read("MyTeam/HomeDashboardView.swift"):
        failures.append("retryLater must be handled as a retry action in HomeDashboardView")

    if failures:
        print("FAIL: tool recovery action validation failed")
        for failure in failures:
            print(f"- {failure}")
        sys.exit(1)

    print("PASS: tool recovery action validation")


if __name__ == "__main__":
    main()
