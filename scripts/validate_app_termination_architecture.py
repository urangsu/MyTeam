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


def method_body(source: str, signature: str) -> str:
    start = source.find(signature)
    if start == -1:
        raise SystemExit(f"FAIL: missing method signature: {signature}")
    brace = source.find("{", start)
    if brace == -1:
        raise SystemExit(f"FAIL: method has no body: {signature}")
    depth = 0
    for index in range(brace, len(source)):
        char = source[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[brace + 1:index]
    raise SystemExit(f"FAIL: unclosed method body: {signature}")


def main() -> None:
    failures: list[str] = []

    coordinator_path = ROOT / "MyTeam/AppTerminationCoordinator.swift"
    if not coordinator_path.exists():
        failures.append("AppTerminationCoordinator.swift is missing")
        coordinator = ""
    else:
        coordinator = coordinator_path.read_text(encoding="utf-8")

    app = read("MyTeam/MyTeamApp.swift")
    team_table = read("MyTeam/TeamTableView.swift")
    project = read("MyTeam/MyTeam.xcodeproj/project.pbxproj")

    if "AppTerminationCoordinator.shared.requestTermination" not in method_body(app, "func applicationShouldTerminate("):
        failures.append("applicationShouldTerminate must delegate to AppTerminationCoordinator")
    if "AppTerminationCoordinator.shared.handleApplicationWillTerminate" not in method_body(app, "func applicationWillTerminate("):
        failures.append("applicationWillTerminate must delegate to AppTerminationCoordinator")
    if "AppTerminationCoordinator.shared.requestMenuQuit" not in method_body(app, "@objc func quitApp()"):
        failures.append("menu quit path must call AppTerminationCoordinator.requestMenuQuit")
    if "AppTerminationCoordinator.shared.requestMenuQuit" not in team_table:
        failures.append("TeamTableView quit action must call AppTerminationCoordinator.requestMenuQuit")

    app_without_coordinator = "\n".join(
        line for line in app.splitlines() if "AppTerminationCoordinator" not in line
    )
    if "Darwin.exit" in app_without_coordinator:
        failures.append("Darwin.exit must not be used in MyTeamApp.swift")
    if "Thread.sleep" in app:
        failures.append("application termination path must not use Thread.sleep")

    if "Darwin.exit" in read("MyTeam/MyTeamApp.swift"):
        failures.append("Darwin.exit must only live inside AppTerminationCoordinator.swift")
    for swift_path in (ROOT / "MyTeam").rglob("*.swift"):
        if swift_path.name == "AppTerminationCoordinator.swift":
            continue
        source = swift_path.read_text(encoding="utf-8", errors="ignore")
        if "Darwin.exit" in source:
            failures.append(f"Darwin.exit found outside coordinator: {swift_path.relative_to(ROOT)}")

    should_body = method_body(app, "func applicationShouldTerminate(")
    for token in ["Task.sleep", "watchdog", "playPreparedFarewell", "reply(toApplicationShouldTerminate"]:
        if token in should_body:
            failures.append(f"applicationShouldTerminate still owns termination detail: {token}")

    for token in [
        "didReplyToShouldTerminate",
        "terminationWatchdogNanoseconds: UInt64 = 5_000_000_000",
        "engineStopTimeoutNanoseconds: UInt64 = 2_000_000_000",
        "replyOnce",
        "forceExitIfNeeded",
        "stopEngineWithTimeout",
    ]:
        if token not in coordinator:
            failures.append(f"AppTerminationCoordinator missing required guard/constant: {token}")

    if "APPTERMFILE00000000001" not in project and "AppTerminationCoordinator.swift" not in project:
        failures.append("AppTerminationCoordinator.swift is not included in Xcode project")

    if failures:
        print("FAIL: app termination architecture validation failed")
        for failure in failures:
            print(f"- {failure}")
        sys.exit(1)

    print("PASS: app termination architecture")


if __name__ == "__main__":
    main()
