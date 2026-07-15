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
memory = read("MyTeam/ConversationMemory.swift")
tts_validator = read("MyTeam/ToolContractValidator.swift")
window_manager = read("MyTeam/AgentWindowManager.swift")
floating_panel = read("MyTeam/FloatingPanel.swift")
model_policy = read("MyTeam/AIModelPolicy.swift")
ai_service = read("MyTeam/AIService.swift")
agent_toolkit = read("MyTeam/AgentToolKit.swift")
speech_manager = read("MyTeam/SpeechManager.swift")
chat_models = read("MyTeam/ChatModels.swift")
project = read("MyTeam/MyTeam.xcodeproj/project.pbxproj")

require(chat, "enum ConversationReplyPolicy", "ConversationReplyPolicy is missing")
require(chat, "enum CasualBubbleSegmenter", "CasualBubbleSegmenter is missing")
require(chat, "enum ConversationSentenceBoundary", "shared streaming sentence boundary parser is missing")
require(chat, "enum ConversationTextSanitizer", "casual Markdown marker sanitizer is missing")
forbid(chat, 'replacingOccurrences(of: "*", with: "")', "casual sanitizer deletes meaningful single asterisks")
require(chat, "maximumCasualBubbles = 3", "casual bubble cap must remain three")
require(chat, "strokesPerMinute = 600", "casual typing speed is not based on 600 strokes per minute")
forbid(chat, "normalCharactersPerSecond: Double = 26", "legacy machine-fast casual typing speed returned")
require(chat, "struct CopyableMessageContainer", "copyable message component is missing")
require(chat, 'accessibilityLabel("메시지 복사")', "copy button accessibility label is missing")
require(agent_chat, "CasualBubbleSegmenter.streamingSegments", "personal streaming does not use stable bubble segmentation")
require(speech_manager, "ConversationSentenceBoundary.splitStreaming", "TTS streaming still flushes incomplete sentence tails")
require(speech_manager, "replyMode: ConversationReplyMode", "TTS streaming cannot match the displayed casual text policy")
forbid(speech_manager, 'sentenceBuffer.contains(where:', "TTS streaming still flushes an entire buffer after any punctuation")
require(speech_manager, "realtimeIngestionTask", "SSE ingestion ownership is not explicit")
require(speech_manager, "currentPlaybackTask", "serialized playback ownership is not explicit")
forbid(speech_manager, "currentStreamTask", "stream ingestion and queued playback share one task slot")
forbid(speech_manager, "Perfect Lip-Sync", "chat text still claims a playback-gated contract")
require(agent_chat, "CopyableMessageContainer", "personal chat result surfaces are not copyable")
require(team, "CopyableMessageContainer", "team workroom messages are not copyable")
require(team, "log.presentationStyle == .casualTypewriter", "team typewriter rendering ignores conversation mode")
require(chat_models, "enum ChatPresentationStyle", "chat presentation mode is not persisted with messages")
require(team, ".overlay(WindowDragHandle())", "team collaboration header has no stable frontmost drag handle")
require(floating_panel, "windowOriginAtMouseDown", "team drag handle does not preserve a stable initial frame")
require(floating_panel, "window.setFrameOrigin", "team drag handle does not move the panel")
require(floating_panel, "acceptsFirstMouse", "team drag handle cannot start from an inactive panel")
require(chat, "enum KoreanText", "Korean particle helper is missing")
require(memory, "let usesProfessionalRole = replyMode == .work || replyMode == .explicitDetail", "personal chat still injects professional roles into casual greetings")
require(memory, "후속 질문은 정말 필요할 때 하나만", "casual personal chat can still ask stacked follow-up questions")
require(agent_chat, "[응답 참고 정보 - 사용자 발화가 아님]", "personal chat mixes internal context into the user utterance without a boundary")
require(ai_service, "streamStartupTimeoutSeconds: TimeInterval = 15", "LLM first-token timeout regressed to an overly aggressive value")
require(window_manager, "facts.suffix(12)", "unbounded long-term memory can overwhelm casual chat prompts")
require(agent_chat, "personalRoomDisplayName", "personal room labels do not normalize legacy names")
forbid(agent_chat, 'Text(room.name)', "personal room labels bypass the normalized display name")
forbid(agent_chat, "tuckChatWindow", "personal chat still exposes the unstable tuck action")
require(window_manager, "hostingController.sizingOptions = []", "SwiftUI can still resize the chat NSWindow during layout")
require(window_manager, "applyStatusWindowSize", "team panel sizing is not deferred away from SwiftUI layout")
forbid(window_manager, "panel.setFrame(frame, display: true, animate: true)", "team panel resizing still animates during SwiftUI layout")
require(window_manager, "width >= 520", "personal chat accepts the legacy collapsing width")
if '"chat_single"' in floating_panel.split("allowedPanelIDs", 1)[1].split("]", 1)[0]:
    raise SystemExit("FAIL: personal chat must not participate in panel tuck geometry")

require(model_policy, "static var dynamicModelDiscoveryAllowed", "model discovery policy is missing")
require(model_policy, "return false", "unverified model discovery can become a runtime model")
for source, label in ((ai_service, "AIService"), (agent_toolkit, "AgentToolKit")):
    forbid(source, "generateContent?key=", f"{label} puts Gemini credentials in URLs")
forbid(ai_service, "models?key=", "model discovery puts Gemini credentials in URLs")
forbid(ai_service, "streamGenerateContent?key=", "Gemini streaming puts credentials in URLs")
require(ai_service, 'forHTTPHeaderField: "x-goog-api-key"', "Gemini credentials are not sent in a header")
require(orchestrator, "estimatedTypingDurationNanoseconds", "team casual bubbles can overlap their typing animations")
forbid(orchestrator, "try? await Task.sleep(nanoseconds: typingDuration)", "cancelled team replies can append another bubble")
forbid(orchestrator, "350_000_000...700_000_000", "team casual bubbles still use a fixed machine-fast interval")
forbid(orchestrator, "900_000_000...1_400_000_000", "legacy fixed casual pacing returned")
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
