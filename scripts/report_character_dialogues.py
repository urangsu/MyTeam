#!/usr/bin/env python3
import argparse
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "MyTeam" / "CharacterDialogues.swift"
REPORT = ROOT / "build" / "reports" / "character_dialogues.md"

AGENT_IDS = [f"agent_{index}" for index in range(1, 12)]
EVENTS = [
    "startup",
    "wake",
    "idle",
    "sleep",
    "appWillQuit",
    "taskCompleted",
    "taskFailedRecoverable",
    "connectionNeeded",
    "validationSucceeded",
]
FORBIDDEN_TERMS = [
    "MCP",
    "token",
    "process",
    "runtime",
    "OAuth scope",
    "subprocess",
    "Animalese",
    "Animal Crossing",
    "Chatterbox",
    "Qwen",
    "MLX",
]


def parse_lines(source: str) -> list[dict[str, str]]:
    pattern = re.compile(
        r'\.init\(\s*id:\s*"(?P<id>[^"]+)",\s*'
        r'agentID:\s*"(?P<agentID>[^"]+)",\s*'
        r'event:\s*\.(?P<event>[A-Za-z0-9_]+),\s*'
        r'text:\s*"(?P<text>(?:\\"|[^"])*)"',
        re.S,
    )
    return [
        {
            "id": match.group("id"),
            "agentID": match.group("agentID"),
            "event": match.group("event"),
            "text": match.group("text").replace('\\"', '"'),
        }
        for match in pattern.finditer(source)
    ]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check-only", action="store_true", help="validate without writing the markdown report")
    args = parser.parse_args()

    source = SOURCE.read_text()
    lines = parse_lines(source)
    active_lines = [line for line in lines if line["agentID"] in AGENT_IDS]

    failures: list[str] = []
    warnings: list[str] = []

    seen = {(line["agentID"], line["event"]) for line in active_lines}
    for agent_id in AGENT_IDS:
        for event in EVENTS:
            if (agent_id, event) not in seen:
                failures.append(f"missing line: {agent_id} / {event}")

    for line in active_lines:
        text = line["text"]
        for term in FORBIDDEN_TERMS:
            if term.lower() in text.lower():
                failures.append(f"forbidden term '{term}' in {line['id']}")
        if line["event"] == "appWillQuit":
            if len(text) > 60:
                failures.append(f"appWillQuit too long ({len(text)} chars): {line['id']}")
            elif len(text) > 45:
                warnings.append(f"appWillQuit over recommended 45 chars ({len(text)}): {line['id']}")
        elif len(text) > 80:
            warnings.append(f"long dialogue line ({len(text)}): {line['id']}")

    report_lines = [
        "# Character Dialogue Report",
        "",
        f"- Active agents: {len(AGENT_IDS)}",
        f"- Required events: {len(EVENTS)}",
        f"- Active catalog lines: {len(active_lines)}",
        f"- Required coverage: {len(AGENT_IDS) * len(EVENTS)}",
        f"- Status: {'FAIL' if failures else 'PASS'}",
        "",
        "## Warnings",
        "",
    ]
    report_lines.extend([f"- {warning}" for warning in warnings] or ["- none"])
    report_lines.extend(["", "## Failures", ""])
    report_lines.extend([f"- {failure}" for failure in failures] or ["- none"])
    report_lines.append("")

    if not args.check_only:
        REPORT.parent.mkdir(parents=True, exist_ok=True)
        REPORT.write_text("\n".join(report_lines))
        print(f"wrote {REPORT.relative_to(ROOT)}")

    if failures:
        print("\n".join(report_lines), file=sys.stderr)
        return 1

    print(f"PASS: {len(active_lines)} character dialogue lines cover {len(AGENT_IDS)} agents x {len(EVENTS)} events")
    if warnings:
        print(f"WARN: {len(warnings)} dialogue warning(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
