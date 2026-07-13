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
let renderedRatio = BubbleSpeechSynthesizer.durationRatio(renderedSamples: rendered, sourceSamples: voiceSamples)
let renderedDelta = BubbleSpeechSynthesizer.meanAbsoluteDelta(rendered, voiceSamples)
let renderedPeak = peak(rendered)
require(!rendered.isEmpty, "voice-based render should not be empty")
require(renderedRatio > 0.18, "voice-based render should not be too short")
require(renderedRatio < 0.95, "voice-based render should be shorter than source")
require(rendered.count > sampleRate / 20, "voice-based render should not collapse into a broken ultra-short clip")
require(renderedDelta > 0.002, "voice-based render should modify samples")
require(renderedPeak > 0.01, "voice-based render should have non-zero peak")
require(!rendered.contains { !$0.isFinite }, "voice-based render should not contain NaN/Inf")

let adaptiveDecision = BubbleSpeechEffectPolicy.decision(for: "좋아요", requested: true)
let adaptive = BubbleSpeechSynthesizer.applyAdaptiveEffect(
    text: "좋아요",
    voiceSamples: voiceSamples,
    sampleRate: sampleRate,
    config: cuteConfig,
    segmentRate: 1.0,
    decision: adaptiveDecision
)
require(adaptive != nil, "adaptive BubbleSpeech should render")
let adaptiveRatio = BubbleSpeechSynthesizer.durationRatio(
    renderedSamples: adaptive ?? [],
    sourceSamples: voiceSamples
)
require(adaptiveRatio >= 0.72, "adaptive BubbleSpeech must preserve intelligible source timing")
require(adaptiveDecision.wetMix <= 0.46, "short lines must retain at least half of the Supertonic3 voice")
require(adaptive?.count == voiceSamples.count, "adaptive BubbleSpeech must preserve the Supertonic3 timeline")
let adaptiveDelta = BubbleSpeechSynthesizer.meanAbsoluteDelta(adaptive ?? [], voiceSamples)
require(adaptiveDelta > 0.0001, "adaptive BubbleSpeech should add audible syllable shaping")
require(adaptiveDelta < 0.05, "adaptive BubbleSpeech must not replace the voice with a machine-like layer")

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

print("PASS bubble_speech_smoke guide=\(guide.count) rendered=\(rendered.count) ratio=\(String(format: "%.3f", renderedRatio)) adaptiveRatio=\(String(format: "%.3f", adaptiveRatio)) adaptiveDelta=\(String(format: "%.5f", adaptiveDelta)) delta=\(String(format: "%.5f", renderedDelta)) peak=\(String(format: "%.4f", renderedPeak))")
