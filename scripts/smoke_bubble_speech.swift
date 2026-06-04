#!/usr/bin/env swift
import Foundation

let sampleRate = 44_100
let voiceSamples = (0..<(sampleRate / 2)).map { index -> Float in
    let t = Double(index) / Double(sampleRate)
    let fundamental = sin(2.0 * .pi * 330.0 * t) * 0.20
    let formant = sin(2.0 * .pi * 990.0 * t) * 0.06
    return Float(fundamental + formant)
}

func peak(_ samples: [Float]) -> Float {
    samples.map { abs($0) }.max() ?? 0
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let cuteConfig = BubbleSpeechConfig.from(profile: .cute, speed: 1.0)
let tinyConfig = BubbleSpeechConfig.from(profile: .tiny, speed: 1.12)
let arcadeConfig = BubbleSpeechConfig.from(profile: .arcade, speed: 1.18)

let guide = BubbleSpeechSynthesizer.synthesize(text: "좋아요", config: cuteConfig)
require(!guide.isEmpty, "procedural guide should not be empty")
require(peak(guide) > 0.01, "procedural guide should have audible peak")

let rendered = BubbleSpeechSynthesizer.renderVoiceBasedEffect(
    text: "좋아요",
    voiceSamples: voiceSamples,
    sampleRate: sampleRate,
    config: cuteConfig
)
require(!rendered.isEmpty, "voice-based render should not be empty")
require(rendered.count == voiceSamples.count, "voice-based render should preserve source length")
require(BubbleSpeechSynthesizer.meanAbsoluteDelta(rendered, voiceSamples) > 0.002, "voice-based render should modify samples")
require(peak(rendered) > 0.01, "voice-based render should have non-zero peak")
require(!rendered.contains { !$0.isFinite }, "voice-based render should not contain NaN/Inf")

let guideFailure = BubbleSpeechSynthesizer.renderVoiceBasedEffect(
    text: " !!!",
    voiceSamples: voiceSamples,
    sampleRate: sampleRate,
    config: cuteConfig
)
require(guideFailure.isEmpty, "guide failure should return empty output, not passthrough")

let tinyRendered = BubbleSpeechSynthesizer.renderVoiceBasedEffect(
    text: "좋아요",
    voiceSamples: voiceSamples,
    sampleRate: sampleRate,
    config: tinyConfig
)
let arcadeRendered = BubbleSpeechSynthesizer.renderVoiceBasedEffect(
    text: "좋아요",
    voiceSamples: voiceSamples,
    sampleRate: sampleRate,
    config: arcadeConfig
)
require(BubbleSpeechSynthesizer.meanAbsoluteDelta(tinyRendered, arcadeRendered) > 0.001, "profiles should produce different output")

print("PASS bubble_speech_smoke guide=\(guide.count) rendered=\(rendered.count) delta=\(String(format: "%.5f", BubbleSpeechSynthesizer.meanAbsoluteDelta(rendered, voiceSamples))) peak=\(String(format: "%.4f", peak(rendered)))")
