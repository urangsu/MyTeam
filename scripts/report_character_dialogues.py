#!/usr/bin/env python3
import argparse
import re
import sys
from collections import Counter
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
    "moved",
    "settled",
    "taskStarted",
    "userNeedsComfort",
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

USER_HOSTILE_PATTERNS = [
    r"가만\s*안",
    r"왜\s+.*(?:안|못)",
    r"농땡이",
    r"안\s*보이세요",
    r"선을.*넘",
    r"그냥\s*넘어갈\s*수\s*없",
    r"변명은",
    r"참는\s*데도",
    r"제\s*허락\s*없이",
    r"누구야",
    r"저\s*좀\s*위로",
    r"마음에\s*안\s*드시",
    r"빨리\s*내려",
    r"마우스\s*내려놓",
    r"살려\s*주세요",
    r"사용자.*(?:탓|잘못)",
    r"당신.*(?:탓|잘못)",
]

RUNTIME_CALL_SITES = [
    ROOT / "MyTeam" / "AgentWindowManager.swift",
    ROOT / "MyTeam" / "AgentSeatView.swift",
    ROOT / "MyTeam" / "TeamTableView.swift",
    ROOT / "MyTeam" / "CharacterReactionEngine.swift",
    ROOT / "MyTeam" / "CharacterReactionEventSink.swift",
    ROOT / "MyTeam" / "WorkroomCharacterEvent.swift",
]


def parse_lines(source: str) -> list[dict[str, str]]:
    initializer_pattern = re.compile(
        r'\.init\(\s*id:\s*"(?P<id>[^"]+)",\s*'
        r'agentID:\s*"(?P<agentID>[^"]+)",\s*'
        r'event:\s*\.(?P<event>[A-Za-z0-9_]+),\s*'
        r'text:\s*"(?P<text>(?:\\"|[^"])*)"',
        re.S,
    )
    helper_pattern = re.compile(
        r'line\(\s*"(?P<agentID>agent_\d+)",\s*'
        r'\.(?P<event>[A-Za-z0-9_]+),\s*'
        r'"(?P<text>(?:\\"|[^"])*)"'
        r'(?:,\s*variant:\s*(?P<variant>\d+))?',
        re.S,
    )
    parsed = [
        {
            "id": match.group("id"),
            "agentID": match.group("agentID"),
            "event": match.group("event"),
            "text": match.group("text").replace('\\"', '"'),
        }
        for match in initializer_pattern.finditer(source)
    ]
    parsed.extend(
        {
            "id": f"{match.group('agentID')}.{match.group('event')}.{match.group('variant') or '1'}",
            "agentID": match.group("agentID"),
            "event": match.group("event"),
            "text": match.group("text").replace('\\"', '"'),
        }
        for match in helper_pattern.finditer(source)
    )
    return parsed


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check-only", action="store_true", help="validate without writing the markdown report")
    args = parser.parse_args()

    source = SOURCE.read_text()
    lines = parse_lines(source)
    active_lines = [line for line in lines if line["agentID"] in AGENT_IDS]

    failures: list[str] = []
    warnings: list[str] = []

    id_counts = Counter(line["id"] for line in active_lines)
    duplicate_ids = sorted(line_id for line_id, count in id_counts.items() if count > 1)
    for line_id in duplicate_ids:
        failures.append(f"duplicate dialogue id: {line_id}")

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
        for pattern in USER_HOSTILE_PATTERNS:
            if re.search(pattern, text, re.IGNORECASE):
                failures.append(f"user-hostile pattern '{pattern}' in {line['id']}")
        if line["event"] == "appWillQuit":
            if len(text) > 60:
                failures.append(f"appWillQuit too long ({len(text)} chars): {line['id']}")
            elif len(text) > 45:
                warnings.append(f"appWillQuit over recommended 45 chars ({len(text)}): {line['id']}")
        elif len(text) > 80:
            warnings.append(f"long dialogue line ({len(text)}): {line['id']}")

    if "AnimationState" in source or "sanitizedUserFirstLine" in source:
        failures.append("legacy AnimationState dialogue catalog must not return")

    for call_site in RUNTIME_CALL_SITES:
        call_source = call_site.read_text()
        if re.search(r"CharacterDialogues\.randomLine\([^\n]+state:", call_source):
            failures.append(f"legacy state-based dialogue call in {call_site.relative_to(ROOT)}")
        for pattern in USER_HOSTILE_PATTERNS:
            if re.search(pattern, call_source, re.IGNORECASE):
                failures.append(f"user-hostile pattern '{pattern}' in {call_site.relative_to(ROOT)}")

    required_runtime_events = {
        "AgentWindowManager.swift": ["kind.dialogueEvent"],
        "AgentSeatView.swift": ["event: .wake"],
        "TeamTableView.swift": ["event: .settled", "TrailingDragReactionGate"],
        "CharacterReactionEngine.swift": ["CharacterDialogues.randomText"],
        "CharacterReactionEventSink.swift": ["targetAgentID(for: event)"],
        "WorkroomCharacterEvent.swift": ["dialogueEvent: .taskStarted", "dialogueEvent: .taskCompleted"],
    }
    for call_site in RUNTIME_CALL_SITES:
        call_source = call_site.read_text()
        for marker in required_runtime_events.get(call_site.name, []):
            if marker not in call_source:
                failures.append(f"missing runtime event '{marker}' in {call_site.relative_to(ROOT)}")

    team_table_source = (ROOT / "MyTeam" / "TeamTableView.swift").read_text()
    drag_dialogue_marker = ".onReceive(NotificationCenter.default.publisher(for: .agentDragBegan))"
    drag_dialogue_region = team_table_source.split(drag_dialogue_marker, 1)[-1].split("// MARK: - 팀 입력 전송", 1)[0]
    if "manager.currentRoomID" in drag_dialogue_region:
        failures.append("team-panel drag dialogue must not be stored in the current personal room")
    if drag_dialogue_region.count("manager.selectedTeamWorkroomID") != 1:
        failures.append("team-panel drag burst must store exactly one settled dialogue in the selected team workroom")
    if "event: .moved" in drag_dialogue_region:
        failures.append("team-panel drag start must not generate dialogue before the final settled position")
    if "policy: .dropIfBusy" not in drag_dialogue_region:
        failures.append("team-panel settled speech must not interrupt or trail substantive speech")

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
