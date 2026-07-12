# MyTeam Character Language Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace BubbleSpeech's equal-width waveform chopping with a fast, expressive, partly intelligible character language that preserves each Supertonic3 voice while automatically reducing the effect for long business answers.

**Architecture:** Keep the required single Supertonic3 synthesis pass. Analyze that render into reusable voiced grains, map Korean syllable properties to compatible grains, and reconstruct a deterministic rhythmic utterance with character-specific pitch and timing. `BubbleSpeechSynthesizer` remains the public facade; analysis, rendering, and eligibility policy move into focused components.

**Tech Stack:** Swift 5, Foundation, Accelerate/vDSP when already available through the macOS SDK, XCTest, existing Supertonic3 and audio playback pipeline.

---

## 1. Research Findings and Design Boundary

### What is publicly supportable

- Public descriptions consistently characterize the reference speech as text-driven short pronunciation units played rapidly rather than ordinary full-sentence speech.
- Japanese text maps naturally to kana syllables. International versions use language-adapted pronunciation units with deliberately reduced intelligibility.
- Character identity, mood, and dialogue speed alter pitch and delivery.
- Numbers are kept clearer than ordinary speech.
- The original Animal Forest decompilation exposes separate message speed, voice mode, and per-voice sound calls (`Na_MessageSpeed`, `Na_SetVoiceMode`, `Na_VoiceSe`). The exact proprietary synthesis algorithm is not yet recovered, so this is evidence of event-level voice control, not proof of a particular DSP implementation.

### What MyTeam must not do

- Do not copy, extract, bundle, or learn from Nintendo audio assets.
- Do not ship Nintendo names in Swift runtime identifiers, presets, UI, or marketing.
- Do not create a voice clone of a named character.
- Do not call Supertonic3 once per syllable.
- Do not rewrite the visible/spoken text to manufacture pronunciation.
- Do not fall back to the original unmodified samples when BubbleSpeech rendering fails.

### Why the current implementation misses the target

`BubbleSpeechSynthesizer.chopVoiceSamples` computes:

```swift
let sourceStride = Double(voiceSamples.count) / Double(syllableCount)
```

Natural speech does not allocate equal time to every written syllable. The current code therefore slices consonants, vowels, silence, and coarticulation at arbitrary positions. Shortening those slices produces a stuttered human sentence rather than a stable character language.

### Chosen mechanism

Use **voice-derived granular syllable rendering**:

```text
Supertonic3 single render
-> voiced-region analysis
-> stable grain bank extraction
-> Hangul syllable feature mapping
-> deterministic grain selection
-> pitch/formant/rhythm transformation
-> overlap-add reconstruction
-> loudness and click validation
```

This intentionally preserves only roughly 20-40% lexical intelligibility in strong mode while retaining the source character's timbre and sentence emotion.

---

## 2. File Structure

### New files

- `MyTeam/BubbleSpeechEffectPolicy.swift`
  - Chooses bypass, light, medium, or strong rendering from text length and content.
- `MyTeam/BubbleSpeechGrainAnalyzer.swift`
  - Detects voiced regions and extracts stable source-voice grains.
- `MyTeam/BubbleSpeechCharacterRenderer.swift`
  - Maps Hangul syllable features to grains and reconstructs character-language audio.
- `MyTeamTests/BubbleSpeechCharacterLanguageTests.swift`
  - Deterministic DSP, policy, click, duration, and character differentiation tests.
- `docs/qa/BubbleSpeechCharacterLanguageQA.md`
  - Manual listening matrix and evidence fields.

### Modified files

- `MyTeam/BubbleSpeechSynthesizer.swift`
  - Keep tokenization and procedural guide helpers; replace equal-stride chopping with analyzer/renderer delegation.
- `MyTeam/BubbleSpeechCharacterTuningPolicy.swift`
  - Replace pitch-only differentiation with rhythm, grain, and contour parameters.
- `MyTeam/SpeechManager.swift`
  - Apply automatic strength policy and log measured render quality.
- `MyTeam/TTSLabView.swift`
  - Show automatic mode and an explicit lab-only strength override.
- `MyTeam/MyTeam.xcodeproj/project.pbxproj`
  - Add new production and test files.
- `scripts/validate_tts_runtime_truth.py`
  - Prevent equal-stride chopping, per-syllable TTS, passthrough success, and protected-name regressions.
- `docs/backlog/myteam_product_backlog.json`
  - Record code/build evidence while leaving audio QA partial until listened to.

---

## 3. Runtime Contracts

```swift
enum BubbleSpeechEffectStrength: String, Sendable, Equatable {
    case bypass
    case light
    case medium
    case strong
}

struct BubbleSpeechEffectDecision: Sendable, Equatable {
    let strength: BubbleSpeechEffectStrength
    let wetMix: Float
    let targetSyllableDuration: ClosedRange<Double>
    let reason: String
}

struct BubbleSpeechGrain: Sendable, Equatable {
    let samples: [Float]
    let rms: Float
    let zeroCrossingRate: Float
    let spectralCentroid: Float
    let voicingConfidence: Float
}

struct BubbleSpeechGrainBank: Sendable, Equatable {
    let bright: [BubbleSpeechGrain]
    let neutral: [BubbleSpeechGrain]
    let round: [BubbleSpeechGrain]
    let dark: [BubbleSpeechGrain]
    let narrow: [BubbleSpeechGrain]
}

struct BubbleSpeechRenderMetrics: Sendable, Equatable {
    let peak: Float
    let rms: Float
    let durationRatio: Double
    let estimatedClickCount: Int
    let voicedGrainCount: Int
    let wetMix: Float
}
```

Automatic policy:

| Input | Strength | Wet mix | Target syllable duration |
|---|---:|---:|---:|
| 1-24 voiced characters | strong | 0.78 | 42-68 ms |
| 25-80 voiced characters | medium | 0.58 | 50-78 ms |
| 81-180 voiced characters | light | 0.28 | 58-88 ms |
| over 180 characters | bypass | 0.00 | source timing |
| URL/code/table-heavy text | bypass | 0.00 | source timing |
| number/date/money-heavy short text | light | 0.25 | 60-90 ms |

The policy uses visible text only. It does not rewrite text before synthesis.

---

### Task 1: Lock the automatic effect policy

**Files:**
- Create: `MyTeam/BubbleSpeechEffectPolicy.swift`
- Create: `MyTeamTests/BubbleSpeechCharacterLanguageTests.swift`
- Modify: `MyTeam/MyTeam.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write failing policy tests**

```swift
final class BubbleSpeechCharacterLanguageTests: XCTestCase {
    func testShortCharacterLineUsesStrongEffect() {
        let decision = BubbleSpeechEffectPolicy.decision(for: "수석님, 다녀오셨어요?", requested: true)
        XCTAssertEqual(decision.strength, .strong)
        XCTAssertEqual(decision.wetMix, 0.78, accuracy: 0.001)
    }

    func testLongBusinessAnswerBypassesEffect() {
        let text = String(repeating: "업무 결과와 공식 출처를 확인했습니다. ", count: 12)
        XCTAssertEqual(BubbleSpeechEffectPolicy.decision(for: text, requested: true).strength, .bypass)
    }

    func testDataHeavyLineRemainsReadable() {
        let decision = BubbleSpeechEffectPolicy.decision(
            for: "삼성전자 종가 84,000원, 기준일 2026-07-11",
            requested: true
        )
        XCTAssertEqual(decision.strength, .light)
    }
}
```

- [ ] **Step 2: Run the tests and verify RED**

```bash
xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Debug \
  -destination 'platform=OS X,arch=arm64' test \
  -only-testing:MyTeamTests/BubbleSpeechCharacterLanguageTests
```

Expected: compile failure because `BubbleSpeechEffectPolicy` does not exist.

- [ ] **Step 3: Implement the deterministic policy**

Use Hangul/letter character count, URL detection, code-fence detection, line count, and numeric-density calculation. A requested value of `false` always returns `.bypass`.

- [ ] **Step 4: Run the targeted tests and verify GREEN**

- [ ] **Step 5: Commit**

```bash
git add MyTeam/BubbleSpeechEffectPolicy.swift MyTeamTests/BubbleSpeechCharacterLanguageTests.swift MyTeam/MyTeam.xcodeproj/project.pbxproj
git commit -m "feat(tts): add adaptive bubble speech policy"
```

---

### Task 2: Extract a stable grain bank from one Supertonic3 render

**Files:**
- Create: `MyTeam/BubbleSpeechGrainAnalyzer.swift`
- Modify: `MyTeamTests/BubbleSpeechCharacterLanguageTests.swift`
- Modify: `MyTeam/MyTeam.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add failing analyzer tests**

Tests must prove that silence produces no bank, voiced synthetic input produces multiple grains, every grain is finite, and grains stay between 24 ms and 48 ms.

```swift
func testGrainAnalyzerRejectsSilence() {
    let samples = [Float](repeating: 0, count: 44_100)
    XCTAssertNil(BubbleSpeechGrainAnalyzer.analyze(samples: samples, sampleRate: 44_100))
}

func testGrainAnalyzerExtractsFiniteVoicedGrains() throws {
    let samples = (0..<44_100).map { index in
        Float(sin(2 * Double.pi * 180 * Double(index) / 44_100)) * 0.35
    }
    let bank = try XCTUnwrap(BubbleSpeechGrainAnalyzer.analyze(samples: samples, sampleRate: 44_100))
    let grains = bank.bright + bank.neutral + bank.round + bank.dark + bank.narrow
    XCTAssertGreaterThanOrEqual(grains.count, 8)
    XCTAssertTrue(grains.flatMap(\.samples).allSatisfy(\.isFinite))
    XCTAssertTrue(grains.allSatisfy { (1_058...2_117).contains($0.samples.count) })
}
```

- [ ] **Step 2: Verify RED**

- [ ] **Step 3: Implement analysis**

Implementation requirements:

1. Compute 10 ms RMS windows.
2. Derive a noise floor from the lower RMS quartile.
3. Mark voiced windows above `max(noiseFloor * 2.5, 0.008)`.
4. Extract 32 ms grains with a 16 ms hop only inside voiced regions.
5. Reject grains with non-finite values, clipping, or insufficient RMS.
6. Apply a Hann window.
7. Compute zero-crossing rate and spectral centroid.
8. Classify grains into five vowel-color buckets by centroid bands relative to the utterance median.
9. Cap each bucket at 24 deterministic grains to bound memory and latency.

- [ ] **Step 4: Verify GREEN and measure analyzer time under 20 ms for a 10-second render**

- [ ] **Step 5: Commit**

```bash
git add MyTeam/BubbleSpeechGrainAnalyzer.swift MyTeamTests/BubbleSpeechCharacterLanguageTests.swift MyTeam/MyTeam.xcodeproj/project.pbxproj
git commit -m "feat(tts): extract voice derived grain bank"
```

---

### Task 3: Render Hangul syllables from the grain bank

**Files:**
- Create: `MyTeam/BubbleSpeechCharacterRenderer.swift`
- Modify: `MyTeam/BubbleSpeechSynthesizer.swift`
- Modify: `MyTeamTests/BubbleSpeechCharacterLanguageTests.swift`
- Modify: `MyTeam/MyTeam.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add failing renderer tests**

Required tests:

- Same input, voice, profile, and agent produce byte-identical Float output.
- Different Hangul vowel classes produce measurably different waveforms.
- Question and statement endings produce different final pitch contours.
- Strong output duration is 18-55% of source duration for a short phrase.
- Output peak is below `0.98`, contains no non-finite samples, and estimated clicks remain zero.
- Missing/empty grain bank returns failure, never source passthrough.

- [ ] **Step 2: Verify RED**

- [ ] **Step 3: Implement deterministic grain selection**

For each `BubbleSpeechToken.syllable`:

1. Decompose Hangul with `KoreanSyllableDecomposer`.
2. Map the medial vowel to a grain bucket.
3. Choose a grain using a stable hash of character, index, agent ID, and profile.
4. Add the existing consonant transient at low gain.
5. Repeat or truncate the selected grain to the target duration using 50% overlap-add.
6. Apply a character contour in cents; do not change playback sample rate globally.
7. Add the existing final-tail treatment.
8. Insert a 4-11 ms shaped inter-syllable gap.
9. Crossfade every boundary for 3-6 ms.

The strong render should sound like a language generated from the character's vocal material, not like the original sentence accelerated.

- [ ] **Step 4: Replace equal-stride chopping**

Delete the `sourceStride` segmentation path. `renderVoiceBasedEffect` must call the analyzer once and renderer once. If either fails, return an empty array so `SpeechManager` reports BubbleSpeech failure.

- [ ] **Step 5: Verify GREEN**

- [ ] **Step 6: Commit**

```bash
git add MyTeam/BubbleSpeechCharacterRenderer.swift MyTeam/BubbleSpeechSynthesizer.swift MyTeamTests/BubbleSpeechCharacterLanguageTests.swift MyTeam/MyTeam.xcodeproj/project.pbxproj
git commit -m "feat(tts): render granular character language"
```

---

### Task 4: Give each character a rhythm identity

**Files:**
- Modify: `MyTeam/BubbleSpeechCharacterTuningPolicy.swift`
- Modify: `MyTeam/BubbleSpeechCharacterRenderer.swift`
- Modify: `MyTeamTests/BubbleSpeechCharacterLanguageTests.swift`

- [ ] **Step 1: Extend tuning parameters**

```swift
struct BubbleSpeechCharacterTuning: Sendable, Equatable {
    let minSegmentDuration: Double
    let maxSegmentDuration: Double
    let guideGain: Float
    let shimmerDepth: Float
    let gapScale: Double
    let pitchStepPattern: [Double]
    let accentPattern: [Float]
    let grainRepeatPattern: [Int]
    let formantColor: Float
}
```

- [ ] **Step 2: Add tests that compare timing and contour, not only waveform delta**

Leo must have a slower/lower three-step phrase, Chiko a faster syncopated phrase, and Pin a crisp two-step phrase. Tests compare segment-duration sequences and pitch-step arrays directly.

- [ ] **Step 3: Implement all current agent IDs with explicit defaults**

Do not change character text, personality, or visible role. Keep pitch shifts moderate; differentiation should come primarily from rhythm, accent, repetition, and formant color.

- [ ] **Step 4: Verify GREEN and commit**

```bash
git add MyTeam/BubbleSpeechCharacterTuningPolicy.swift MyTeam/BubbleSpeechCharacterRenderer.swift MyTeamTests/BubbleSpeechCharacterLanguageTests.swift
git commit -m "feat(tts): add character language rhythm identities"
```

---

### Task 5: Integrate automatic strength without changing spoken text

**Files:**
- Modify: `MyTeam/SpeechManager.swift`
- Modify: `MyTeam/TTSLabView.swift`
- Modify: `MyTeamTests/BubbleSpeechCharacterLanguageTests.swift`

- [ ] **Step 1: Add integration tests**

Test that short lines select strong rendering, long lines bypass, and TTS synthesis receives the exact visible text. Test that a render failure returns `.failed` rather than playing the source voice as BubbleSpeech.

- [ ] **Step 2: Apply policy after the single Supertonic3 render**

`SpeechManager.previewBubbleSpeech` and the product BubbleSpeech path must:

1. Sanitize text using the existing TTS-safe sanitizer without semantic rewriting.
2. Synthesize once with Supertonic3.
3. Resolve effect strength.
4. Bypass only when policy explicitly chooses `.bypass`.
5. Render and mix at the selected wet ratio.
6. Validate duration, finite samples, peak, click count, and non-empty modification.
7. Play through the existing serialized audio queue.

- [ ] **Step 3: Make TTS Lab controls truthful**

Add `자동`, `약하게`, `보통`, `강하게` as a segmented control. `자동` is the default. Manual overrides remain developer/lab-only and do not create another TTS engine.

- [ ] **Step 4: Verify targeted tests and commit**

```bash
git add MyTeam/SpeechManager.swift MyTeam/TTSLabView.swift MyTeamTests/BubbleSpeechCharacterLanguageTests.swift
git commit -m "fix(tts): integrate adaptive character language"
```

---

### Task 6: Add runtime truth and performance gates

**Files:**
- Modify: `scripts/validate_tts_runtime_truth.py`
- Modify: `scripts/audit_product_completeness.py`
- Create: `docs/qa/BubbleSpeechCharacterLanguageQA.md`
- Modify: `docs/backlog/myteam_product_backlog.json`

- [ ] **Step 1: Add static failures**

Fail when active runtime contains:

- `sourceStride = Double(voiceSamples.count) / Double(syllableCount)`
- multiple Supertonic synthesis calls inside one BubbleSpeech request
- per-syllable TTS requests
- source sample passthrough after a failed BubbleSpeech render
- Nintendo audio assets or protected product/character names in active Swift code
- non-Supertonic fallback TTS

- [ ] **Step 2: Add the manual listening matrix**

The QA document must include:

- 11 agents
- statement, question, greeting, completion, warning, number/date sentence
- short, medium, and long text
- headphones and Mac speaker
- intelligibility score from 1 to 5
- character identity score from 1 to 5
- click/noise failure
- original text equals spoken input evidence

Pass target for strong short lines:

- lexical intelligibility: 2-3/5
- emotion recognition: at least 4/5
- character distinction: at least 4/5
- no clicks, clipping, or playback overlap
- first audible feedback remains within the existing speech latency budget

- [ ] **Step 3: Run full validation**

```bash
cd /Users/su/Desktop/MyTeam

git diff --check
python3 scripts/validate_tts_runtime_truth.py
python3 scripts/validate_myteam_release.py
python3 scripts/audit_product_completeness.py
python3 scripts/report_character_dialogues.py --check-only

xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam \
  -configuration Debug -destination 'platform=OS X,arch=arm64' test

xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam \
  -configuration Debug -destination 'platform=OS X,arch=arm64' build

xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam \
  -configuration Release -destination 'platform=OS X,arch=arm64' build
```

- [ ] **Step 4: Record evidence without overstating completion**

Set backlog status to `partial` until the complete listening matrix passes. Code, tests, and builds are not substitutes for audio QA.

- [ ] **Step 5: Commit**

```bash
git add scripts/validate_tts_runtime_truth.py scripts/audit_product_completeness.py docs/qa/BubbleSpeechCharacterLanguageQA.md docs/backlog/myteam_product_backlog.json
git commit -m "test(tts): add character language quality gate"
```

---

## 4. Success Conditions

- A short line sounds like a fast, expressive character language rather than chopped human speech.
- Strong mode preserves roughly 20-40% lexical intelligibility.
- Emotion and speaker identity remain recognizable.
- Medium and long business answers automatically reduce or bypass the effect.
- Numbers, dates, money, URLs, code, tables, and legal citations are not obscured by strong rendering.
- One BubbleSpeech request performs one Supertonic3 synthesis pass.
- No original game audio, extracted assets, or named-character cloning is used.
- Rendering is deterministic, finite, click-free, and bounded in memory.
- BubbleSpeech failure remains a failure.

## 5. Failure Conditions

- Equal-width text-count waveform slicing remains in the active path.
- The output is merely the original sentence played faster.
- The procedural guide overwhelms the Supertonic3 character timbre.
- Every character differs only by pitch.
- Long reports become difficult to understand.
- Render failure silently plays the unmodified source as success.
- Per-syllable network/model calls are introduced.
- Audio QA is marked PASS without listening evidence.

## 6. Research References

- [Animal Forest decompilation project](https://github.com/zeldaret/af/): exposes distinct message-speed, voice-mode, and voice-sound interfaces; exact synthesis remains partially decompiled.
- [Nookipedia Animalese overview](https://nookipedia.com/wiki/Animalese): documents character/kana mapping, number clarity, pitch by character/mood, speed effects, and language-specific behavior.
- [Nintendo electronic sound synthesizer patent](https://patents.google.com/patent/US4783812A/en): historical evidence for stored-waveform playback with variable read rate and modulation in Nintendo game sound hardware; it is not direct proof of the later dialogue algorithm.
