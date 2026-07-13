#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def require(source: str, token: str, failure: str) -> None:
    if token not in source:
        raise SystemExit(f"FAIL: {failure}")


def forbid(source: str, token: str, failure: str) -> None:
    if token in source:
        raise SystemExit(f"FAIL: {failure}")


def function_body(source: str, signature: str, next_marker: str) -> str:
    start = source.find(signature)
    if start < 0:
        raise SystemExit(f"FAIL: missing function: {signature}")
    end = source.find(next_marker, start)
    return source[start:] if end < 0 else source[start:end]


def main() -> None:
    prosody = (ROOT / "MyTeam" / "SupertonicProsodyTextProcessor.swift").read_text()
    speech = (ROOT / "MyTeam" / "SpeechManager.swift").read_text()
    playback = (ROOT / "MyTeam" / "AudioPlaybackService.swift").read_text()
    wav_writer = (ROOT / "MyTeam" / "S3WavWriter.swift").read_text()
    audio_features = (ROOT / "MyTeam" / "AudioFeatureSnapshot.swift").read_text()
    onnx_runner = (ROOT / "MyTeam" / "Supertonic3ONNXRunner.swift").read_text()
    bubble = (ROOT / "MyTeam" / "BubbleSpeechSynthesizer.swift").read_text()
    bubble_policy = (ROOT / "MyTeam" / "BubbleSpeechCharacterTuningPolicy.swift").read_text()
    window_manager = (ROOT / "MyTeam" / "AgentWindowManager.swift").read_text()
    team_table = (ROOT / "MyTeam" / "TeamTableView.swift").read_text()
    tests = (ROOT / "MyTeamTests" / "PublicAPIConnectorValidatorTests.swift").read_text()

    require(
        prosody,
        "guard useExpressionTags else { return text }",
        "normal product TTS must preserve the visible text exactly",
    )
    forbid(prosody, "prefix(200)", "product TTS must not truncate text at 200 characters")

    validated_chunk = function_body(
        speech,
        "static func validatedTTSChunk",
        "\n    func speak(",
    )
    for token in ["replacingOccurrences", "trimmingCharacters"]:
        forbid(validated_chunk, token, "streaming TTS validation must not rewrite text")

    production_pipeline = function_body(
        speech,
        "private func dispatchToInferencePipeline",
        "// MARK: - 권한 요청",
    )
    forbid(production_pipeline, "S3WavWriter.write", "normal speech must not write WAV artifacts")
    require(
        production_pipeline,
        "bubbleSpeechPlaybackSamples(",
        "normal character playback must route through the adaptive BubbleSpeech layer",
    )

    for token in [
        "struct BubbleSpeechGrainBank",
        "enum BubbleSpeechGrainAnalyzer",
        "enum BubbleSpeechCharacterRenderer",
        "static func applyAdaptiveEffect",
    ]:
        require(bubble, token, f"missing granular BubbleSpeech runtime contract: {token}")
    forbid(
        bubble,
        "sourceStride = Double(voiceSamples.count) / Double(syllableCount)",
        "BubbleSpeech must not return to equal source-stride chopping",
    )
    require(
        speech,
        'UserDefaults.standard.bool(forKey: "useBubbleSpeechEffect")',
        "BubbleSpeech preference must affect product character playback, not only TTS Lab",
    )
    require(
        speech,
        "mode=sourceAlignedSyllabic",
        "BubbleSpeech runtime must identify the source-aligned syllable renderer",
    )
    require(
        window_manager,
        "speakingTextByAgentID",
        "character speech bubbles must retain the exact currently playing text",
    )
    require(
        team_table,
        "manager.speakingTextByAgentID[agent.id]",
        "team speech bubbles must not reuse a stale persisted chat line",
    )
    require(
        bubble_policy,
        "guard count <= 180 else",
        "long business answers must bypass the character-language effect",
    )

    speak_once = function_body(speech, "func speakOnce", "// MARK: - Round 258B")
    forbid(speak_once, "S3WavWriter.write", "normal speakOnce must not write WAV artifacts")
    require(speak_once, "audioFileURL: nil", "normal speakOnce must not expose a diagnostic WAV URL")

    require(playback, ".dataPlayedBack", "float playback must observe dataPlayedBack completion")
    require(playback, "await completion.wait", "float playback must await completion or timeout")
    require(playback, "did not reach dataPlayedBack", "playback timeout must be observable")
    require(playback, "@MainActor @Sendable", "playback-start callbacks must be main-actor isolated")
    require(playback, "AudioPlaybackQualityPolicy.validate", "float playback must validate PCM before engine use")
    require(audio_features, "case nonFinite", "PCM quality policy must reject non-finite samples")
    require(audio_features, "case silent", "PCM quality policy must reject silent output")
    require(audio_features, "case peakOutOfRange", "PCM quality policy must reject unsafe peaks")
    forbid(onnx_runner, 'outs["text_emb"]!', "ONNX output lookup must not force unwrap")
    require(onnx_runner, 'missingOutput("text_emb")', "missing text encoder output must be a typed failure")
    for token in [
        "private var cachedEnvironment: ORTEnv?",
        "private var cachedSessions: [String: ORTSession]",
        "private var cachedIndexers: [String: Supertonic3UnicodeIndexer]",
        "private var cachedVoiceStyles: [String: Supertonic3VoiceStyle]",
        "let env = try runtimeEnvironment()",
    ]:
        require(onnx_runner, token, f"missing actor-isolated Supertonic runtime cache: {token}")

    for token in [
        "enum SpeechRequestPolicy",
        "actor SpeechRequestQueue",
        "policy: SpeechRequestPolicy = .queue",
        "await speechQueue.next()",
        "await speechQueue.markFinished()",
    ]:
        require(speech, token, f"missing serialized speech queue contract: {token}")

    speaking_state = function_body(
        window_manager,
        "func setAgentSpeaking",
        "func clearAgentSpeaking",
    )
    forbid(speaking_state, "asyncAfter", "speaking state must not use a fixed 30-second timer")

    for path in sorted((ROOT / "MyTeam").glob("*.swift")):
        if path.name in {"SpeechManager.swift", "AgentWindowManager.swift"}:
            continue
        forbid(
            path.read_text(),
            "setAgentSpeaking(",
            f"{path.name} must let SpeechManager own playback lifecycle state",
        )

    forbid(wav_writer, 'appendingPathComponent("Desktop")', "diagnostic WAV files must not use Desktop")
    require(wav_writer, 'appendingPathComponent("TTSLab"', "diagnostic WAV files must stay in the app cache")
    require(wav_writer, "UUID().uuidString", "diagnostic WAV filenames must not collide within one second")

    for test_name in [
        "testProductSpeechPreservesLongVisibleBubbleWithoutTruncation",
        "testProductSpeechPreservesWhitespaceAndPunctuation",
        "testStreamingSpeechChunkValidationDoesNotRewriteText",
        "testQueuedSpeechRequestsRemainFIFO",
        "testDropIfBusyDoesNotReplaceActiveSpeech",
        "testRejectsSilentSamples",
        "testRejectsNonFiniteSamples",
        "testRejectsOutOfRangePeak",
        "testAcceptsFiniteAudibleVoiceSamples",
        "testAdaptiveBubbleSpeechExplicitBypassPreservesSource",
        "testAdaptiveBubbleSpeechFailureDoesNotPassThroughSource",
        "testAdaptiveBubbleSpeechPreservesIntelligibleSourceTiming",
        "testAllCharactersHaveDistinctBubbleSpeechRhythms",
    ]:
        require(tests, test_name, f"missing TTS regression test: {test_name}")

    print("PASS: TTS runtime truth contracts")


if __name__ == "__main__":
    main()
