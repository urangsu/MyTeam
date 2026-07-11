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
        "func speak(text:",
    )
    for token in ["replacingOccurrences", "trimmingCharacters"]:
        forbid(validated_chunk, token, "streaming TTS validation must not rewrite text")

    production_pipeline = function_body(
        speech,
        "private func dispatchToInferencePipeline",
        "// MARK: - 권한 요청",
    )
    forbid(production_pipeline, "S3WavWriter.write", "normal speech must not write WAV artifacts")

    speak_once = function_body(speech, "func speakOnce", "// MARK: - Round 258B")
    forbid(speak_once, "S3WavWriter.write", "normal speakOnce must not write WAV artifacts")
    require(speak_once, "audioFileURL: nil", "normal speakOnce must not expose a diagnostic WAV URL")

    require(playback, ".dataPlayedBack", "float playback must observe dataPlayedBack completion")
    require(playback, "await completion.wait", "float playback must await completion or timeout")
    require(playback, "did not reach dataPlayedBack", "playback timeout must be observable")

    forbid(wav_writer, 'appendingPathComponent("Desktop")', "diagnostic WAV files must not use Desktop")
    require(wav_writer, 'appendingPathComponent("TTSLab"', "diagnostic WAV files must stay in the app cache")
    require(wav_writer, "UUID().uuidString", "diagnostic WAV filenames must not collide within one second")

    for test_name in [
        "testProductSpeechPreservesLongVisibleBubbleWithoutTruncation",
        "testProductSpeechPreservesWhitespaceAndPunctuation",
        "testStreamingSpeechChunkValidationDoesNotRewriteText",
    ]:
        require(tests, test_name, f"missing TTS regression test: {test_name}")

    print("PASS: TTS runtime truth contracts")


if __name__ == "__main__":
    main()
