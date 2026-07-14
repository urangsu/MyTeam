#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text()


def require(source: str, needle: str, label: str) -> None:
    if needle not in source:
        raise SystemExit(f"FAIL: {label}")


def forbid(source: str, needle: str, label: str) -> None:
    if needle in source:
        raise SystemExit(f"FAIL: {label}")


chat = read("MyTeam/ChatComponents.swift")
agent_chat = read("MyTeam/AgentChatView.swift")
team = read("MyTeam/TeamStatusView.swift")
orchestrator = read("MyTeam/TeamOrchestrator.swift")
planner = read("MyTeam/AgenticToolOrchestration.swift")
verifier = read("MyTeam/ResultVerifier.swift")
tts_validator = read("MyTeam/ToolContractValidator.swift")
project = read("MyTeam/MyTeam.xcodeproj/project.pbxproj")

require(chat, "enum ConversationReplyPolicy", "ConversationReplyPolicy is missing")
require(chat, "enum CasualBubbleSegmenter", "CasualBubbleSegmenter is missing")
require(chat, "maximumCasualBubbles = 3", "casual bubble cap must remain three")
require(chat, "struct CopyableMessageContainer", "copyable message component is missing")
require(chat, 'accessibilityLabel("메시지 복사")', "copy button accessibility label is missing")
require(agent_chat, "CasualBubbleSegmenter.streamingSegments", "personal streaming does not use stable bubble segmentation")
require(agent_chat, "CopyableMessageContainer", "personal chat result surfaces are not copyable")
require(team, "CopyableMessageContainer", "team workroom messages are not copyable")
require(orchestrator, "350_000_000...700_000_000", "team casual pacing is outside the approved range")
forbid(orchestrator, "900_000_000...1_400_000_000", "legacy slow casual pacing returned")
forbid(orchestrator, "casualBubbleParts", "legacy casual splitter returned")

require(planner, "manifests(for: message)", "planner does not shortlist manifests")
require(planner, "ProductSurfacePolicy.isEnabledInCurrentReleaseSurface", "planner catalog ignores release surface")
require(planner, "min(limit, 5)", "planner candidate count is not capped")

for message in (
    "요약이 짧습니다",
    "고정 보고서 섹션이 적습니다",
    "체크리스트 항목이 적습니다",
    "고정 회의록 섹션이 적습니다",
):
    require(verifier, f'issue(.warning, "검토 메모: {message}', f"format-only verifier issue is not a warning: {message}")

require(tts_validator, "Supertonic3ONNXRunner.shared.synthesize", "TTS validator does not verify the active ONNX path")
for build_id in ("516E9FE1259EC755FFBFF634", "E0B171E3E70F26CCC0DD4279"):
    if project.count(build_id) != 1:
        raise SystemExit("FAIL: retired Supertonic skeleton remains in the app sources phase")

print("PASS: conversation presentation contract")
