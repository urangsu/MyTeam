#!/usr/bin/env python3
"""Validate MyTeam release backlog evidence gates."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
BACKLOG_PATH = ROOT / "docs" / "backlog" / "myteam_product_backlog.json"
SWIFT_ROOT = ROOT / "MyTeam"
SKILL_PACKAGE_VALIDATOR = ROOT / "scripts" / "validate_skill_packages.py"
ALLOWED_STATUSES = {
    "todo",
    "partial",
    "done",
    "blocked",
    "wont_do",
    "in_progress",
}
FORBIDDEN_SWIFT_PATTERNS = {
    r"UserDefaults.*apiKey": "API keys must not be stored in UserDefaults",
    r"UserDefaults.*token": "tokens must not be stored in UserDefaults",
    r"apiKey.*UserDefaults": "API keys must not be stored in UserDefaults",
    r"token.*UserDefaults": "tokens must not be stored in UserDefaults",
    r"estimated.*cost": "cost estimation UI is not allowed until MyTeam pays API costs",
    r"usage.*limit": "usage limit UI is not allowed until MyTeam pays API costs",
    r"무료.*호출": "free-call quota UI is not allowed until MyTeam provides calls",
    r"잔여.*량": "remaining-quota UI is not allowed until MyTeam provides calls",
}


def load_json(path: Path) -> Any:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except json.JSONDecodeError as exc:
        raise ValueError(f"{path}: invalid JSON at line {exc.lineno}, column {exc.colno}: {exc.msg}") from exc


def non_empty_string(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def non_empty_list(value: Any) -> bool:
    return isinstance(value, list) and any(item for item in value)


def validate_done_task(task: dict[str, Any]) -> list[str]:
    task_id = task.get("id", "<missing-id>")
    evidence = task.get("completion_evidence")
    errors: list[str] = []

    if not isinstance(evidence, dict):
        return [f"{task_id}: status=done requires completion_evidence object"]

    if evidence.get("required") is not True:
        errors.append(f"{task_id}: status=done requires completion_evidence.required == true")
    if not non_empty_string(evidence.get("commit_sha")):
        errors.append(f"{task_id}: status=done requires completion_evidence.commit_sha")
    if not non_empty_list(evidence.get("files_changed")):
        errors.append(f"{task_id}: status=done requires non-empty completion_evidence.files_changed")
    if not non_empty_string(evidence.get("validation_summary")):
        errors.append(f"{task_id}: status=done requires completion_evidence.validation_summary")

    return errors


def validate_partial_task(task: dict[str, Any]) -> list[str]:
    task_id = task.get("id", "<missing-id>")
    evidence = task.get("completion_evidence") if isinstance(task.get("completion_evidence"), dict) else {}
    notes = task.get("notes")
    validation_summary = evidence.get("validation_summary")

    note_text = " ".join(str(note) for note in notes) if isinstance(notes, list) else ""
    combined = f"{validation_summary or ''} {note_text}".lower()
    has_reason = any(marker in combined for marker in ("partial reason", "partial because", "manual", "remains", "남은", "수동"))

    if has_reason:
        return []
    return [f"{task_id}: status=partial requires notes or validation_summary with the remaining validation reason"]


def validate_backlog(path: Path) -> list[str]:
    data = load_json(path)
    errors: list[str] = []

    if not isinstance(data, dict):
        return [f"{path}: root must be a JSON object"]

    tasks = data.get("tasks")
    if not isinstance(tasks, list):
        return [f"{path}: tasks array is required"]

    p0_tasks = [task for task in tasks if isinstance(task, dict) and task.get("priority") == "P0"]
    if not p0_tasks:
        errors.append(f"{path}: at least one P0 task is required")

    for index, task in enumerate(tasks):
        if not isinstance(task, dict):
            errors.append(f"{path}: tasks[{index}] must be an object")
            continue

        task_id = task.get("id", f"tasks[{index}]")
        status = task.get("status")
        if status not in ALLOWED_STATUSES:
            errors.append(f"{task_id}: invalid status {status!r}")
            continue

        if status == "done":
            errors.extend(validate_done_task(task))
        elif status == "partial":
            errors.extend(validate_partial_task(task))

    return errors


def validate_forbidden_swift_patterns(root: Path) -> list[str]:
    errors: list[str] = []
    compiled = [(re.compile(pattern), message) for pattern, message in FORBIDDEN_SWIFT_PATTERNS.items()]

    for path in sorted(root.rglob("*.swift")):
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            text = path.read_text(encoding="utf-8", errors="ignore")
        for line_number, line in enumerate(text.splitlines(), start=1):
            for pattern, message in compiled:
                if pattern.search(line):
                    rel = path.relative_to(ROOT)
                    errors.append(f"{rel}:{line_number}: {message}")

    return errors


def validate_keychain_boundary(root: Path) -> list[str]:
    errors: list[str] = []
    pattern = re.compile(r"KeychainManager\.(save|delete|load)")
    allowed = Path("MyTeam/SecureCredentialStore.swift")

    for path in sorted(root.rglob("*.swift")):
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            text = path.read_text(encoding="utf-8", errors="ignore")
        rel = path.relative_to(ROOT)
        for line_number, line in enumerate(text.splitlines(), start=1):
            if pattern.search(line) and rel != allowed:
                errors.append(f"{rel}:{line_number}: KeychainManager direct access must go through SecureCredentialStore")

    return errors


def validate_skill_packages() -> list[str]:
    if not SKILL_PACKAGE_VALIDATOR.exists():
        return [f"{SKILL_PACKAGE_VALIDATOR.relative_to(ROOT)}: missing skill package validator"]

    # Keep this import-free so the release checklist also verifies the standalone script entry point.
    import subprocess

    result = subprocess.run(
        [sys.executable, str(SKILL_PACKAGE_VALIDATOR)],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode == 0:
        return []
    output = "\n".join(part for part in [result.stdout.strip(), result.stderr.strip()] if part)
    return [f"skill package validation failed:\n{output}"]


def main() -> int:
    errors = validate_backlog(BACKLOG_PATH)
    errors.extend(validate_forbidden_swift_patterns(SWIFT_ROOT))
    errors.extend(validate_keychain_boundary(SWIFT_ROOT))
    errors.extend(validate_skill_packages())
    if errors:
        print("Release checklist validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print(f"Release checklist validation passed: {BACKLOG_PATH.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
