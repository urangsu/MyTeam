import XCTest
@testable import MyTeam

final class SupertonicProsodyTextProcessorTests: XCTestCase {
    func testProductSpeechPreservesVisibleBubbleWording() {
        let visible = "먼저 확인했습니다. 지금 진행하겠습니다!"

        let spoken = SupertonicProsodyTextProcessor.preprocess(
            visible,
            agentID: nil,
            style: .friendly
        )

        XCTAssertEqual(spoken, visible)
    }

    func testProductSpeechPreservesLongVisibleBubbleWithoutTruncation() {
        let visible = String(repeating: "긴 업무 문장입니다. ", count: 30)

        let spoken = SupertonicProsodyTextProcessor.preprocess(
            visible,
            agentID: "agent_3",
            style: .careful
        )

        XCTAssertGreaterThan(visible.count, 200)
        XCTAssertEqual(spoken, visible)
    }

    func testProductSpeechPreservesWhitespaceAndPunctuation() {
        let visible = "첫 줄입니다.\n둘째 줄입니다!!  그대로 읽어주세요..."

        let spoken = SupertonicProsodyTextProcessor.preprocess(
            visible,
            agentID: "agent_2",
            style: .excited
        )

        XCTAssertEqual(spoken, visible)
    }

    func testStreamingSpeechChunkValidationDoesNotRewriteText() {
        let visible = "잠시만요!!  확인 중입니다...\n"

        XCTAssertEqual(SpeechManager.validatedTTSChunk(visible), visible)
        XCTAssertNil(SpeechManager.validatedTTSChunk("  !!!  "))
    }
}

final class SpeechRequestQueueTests: XCTestCase {
    func testQueuedSpeechRequestsRemainFIFO() async {
        let queue = SpeechRequestQueue()
        let first = SpeechRequest(id: UUID(), text: "첫 번째", agentID: "agent_1", characterName: "레오")
        let second = SpeechRequest(id: UUID(), text: "두 번째", agentID: "agent_2", characterName: "루나")

        let firstAccepted = await queue.enqueue(first, policy: .queue)
        let secondAccepted = await queue.enqueue(second, policy: .queue)
        let firstDequeued = await queue.next()
        XCTAssertTrue(firstAccepted)
        XCTAssertTrue(secondAccepted)
        XCTAssertEqual(firstDequeued, first)
        await queue.markFinished()
        let secondDequeued = await queue.next()
        XCTAssertEqual(secondDequeued, second)
    }

    func testDropIfBusyDoesNotReplaceActiveSpeech() async {
        let queue = SpeechRequestQueue()
        let active = SpeechRequest(id: UUID(), text: "재생 중", agentID: "agent_1", characterName: "레오")
        let dropped = SpeechRequest(id: UUID(), text: "겹친 대사", agentID: "agent_2", characterName: "루나")

        let activeAccepted = await queue.enqueue(active, policy: .queue)
        let activeDequeued = await queue.next()
        let droppedAccepted = await queue.enqueue(dropped, policy: .dropIfBusy)
        let snapshot = await queue.snapshot()
        XCTAssertTrue(activeAccepted)
        XCTAssertEqual(activeDequeued, active)
        XCTAssertFalse(droppedAccepted)
        XCTAssertEqual(snapshot.pendingCount, 0)
    }
}

final class AudioPlaybackQualityPolicyTests: XCTestCase {
    func testRejectsSilentSamples() {
        let result = AudioPlaybackQualityPolicy.validate(
            samples: [Float](repeating: 0, count: 4_410),
            sampleRate: 44_100
        )

        XCTAssertEqual(result, .rejected(.silent))
    }

    func testRejectsNonFiniteSamples() {
        let result = AudioPlaybackQualityPolicy.validate(
            samples: [0.1, .nan, 0.2],
            sampleRate: 44_100
        )

        XCTAssertEqual(result, .rejected(.nonFinite))
    }

    func testRejectsOutOfRangePeak() {
        let result = AudioPlaybackQualityPolicy.validate(
            samples: [0.1, 1.2, -0.2],
            sampleRate: 44_100
        )

        XCTAssertEqual(result, .rejected(.peakOutOfRange))
    }

    func testAcceptsFiniteAudibleVoiceSamples() {
        let sampleRate = 44_100
        let samples = (0..<sampleRate / 10).map { index in
            Float(sin(2 * Double.pi * 220 * Double(index) / Double(sampleRate)) * 0.2)
        }

        let result = AudioPlaybackQualityPolicy.validate(samples: samples, sampleRate: sampleRate)

        guard case .accepted(let snapshot) = result else {
            return XCTFail("Expected audible samples to pass: \(result)")
        }
        XCTAssertGreaterThan(snapshot.rms, 0.01)
        XCTAssertLessThanOrEqual(snapshot.peak, 1.0)
    }
}

final class BubbleSpeechSynthesizerTests: XCTestCase {
    func testBubbleSpeechPolicyUsesStrongEffectForShortCharacterLine() {
        let decision = BubbleSpeechEffectPolicy.decision(
            for: "수석님, 다녀오셨어요?",
            requested: true
        )

        XCTAssertEqual(decision.strength, .strong)
        XCTAssertLessThanOrEqual(decision.wetMix, 0.46)
    }

    func testBubbleSpeechPolicyBypassesLongBusinessAnswer() {
        let text = String(repeating: "업무 결과와 공식 출처를 확인했습니다. ", count: 12)

        XCTAssertEqual(
            BubbleSpeechEffectPolicy.decision(for: text, requested: true).strength,
            .bypass
        )
    }

    func testBubbleSpeechPolicyKeepsDataHeavyLineReadable() {
        let decision = BubbleSpeechEffectPolicy.decision(
            for: "삼성전자 종가 84,000원, 기준일 2026-07-11",
            requested: true
        )

        XCTAssertEqual(decision.strength, .light)
        XCTAssertLessThanOrEqual(decision.wetMix, 0.28)
    }

    func testBubbleSpeechPolicyBypassesWhenNotRequested() {
        XCTAssertEqual(
            BubbleSpeechEffectPolicy.decision(for: "안녕하세요", requested: false).strength,
            .bypass
        )
    }

    func testBubbleSpeechGrainAnalyzerRejectsSilence() {
        let samples = [Float](repeating: 0, count: 44_100)

        XCTAssertNil(BubbleSpeechGrainAnalyzer.analyze(samples: samples, sampleRate: 44_100))
    }

    func testBubbleSpeechGrainAnalyzerExtractsFiniteVoicedGrains() throws {
        let sampleRate = 44_100
        let samples = (0..<sampleRate).map { index -> Float in
            let t = Double(index) / Double(sampleRate)
            let carrier = sin(2 * Double.pi * 180 * t)
            let color = sin(2 * Double.pi * 720 * t) * 0.22
            return Float((carrier + color) * 0.28)
        }

        let bank = try XCTUnwrap(
            BubbleSpeechGrainAnalyzer.analyze(samples: samples, sampleRate: sampleRate)
        )
        let grains = bank.allGrains

        XCTAssertGreaterThanOrEqual(grains.count, 8)
        XCTAssertTrue(grains.flatMap(\.samples).allSatisfy(\.isFinite))
        XCTAssertTrue(grains.allSatisfy { (1_058...2_117).contains($0.samples.count) })
        XCTAssertTrue(grains.allSatisfy { $0.rms > 0.008 })
    }

    func testBubbleSpeechGrainAnalyzerIsDeterministic() throws {
        let sampleRate = 44_100
        let samples = (0..<sampleRate / 2).map { index in
            Float(sin(2 * Double.pi * 240 * Double(index) / Double(sampleRate)) * 0.3)
        }

        let first = try XCTUnwrap(BubbleSpeechGrainAnalyzer.analyze(samples: samples, sampleRate: sampleRate))
        let second = try XCTUnwrap(BubbleSpeechGrainAnalyzer.analyze(samples: samples, sampleRate: sampleRate))

        XCTAssertEqual(first, second)
    }

    func testVoiceBasedCharacterLanguageIsDeterministicAndCompressed() {
        let sampleRate = 44_100
        let voiceSamples = (0..<sampleRate).map { index -> Float in
            let t = Double(index) / Double(sampleRate)
            return Float((sin(2 * .pi * 210 * t) + sin(2 * .pi * 730 * t) * 0.2) * 0.25)
        }
        let config = BubbleSpeechConfig.from(profile: .cute, speed: 1.0)

        let first = BubbleSpeechSynthesizer.renderVoiceBasedEffect(
            text: "좋아요, 바로 해볼게요!",
            voiceSamples: voiceSamples,
            sampleRate: sampleRate,
            config: config
        )
        let second = BubbleSpeechSynthesizer.renderVoiceBasedEffect(
            text: "좋아요, 바로 해볼게요!",
            voiceSamples: voiceSamples,
            sampleRate: sampleRate,
            config: config
        )

        XCTAssertEqual(first, second)
        XCTAssertFalse(first.isEmpty)
        XCTAssertLessThan(first.count, voiceSamples.count)
        XCTAssertGreaterThan(first.count, sampleRate / 8)
        XCTAssertTrue(first.allSatisfy(\.isFinite))
        XCTAssertLessThanOrEqual(first.map { abs($0) }.max() ?? 0, 0.98)
    }

    func testVoiceBasedCharacterLanguageTracksQuestionContour() {
        let sampleRate = 44_100
        let voiceSamples = (0..<sampleRate / 2).map { index in
            Float(sin(2 * .pi * 260 * Double(index) / Double(sampleRate)) * 0.3)
        }
        let config = BubbleSpeechConfig.from(profile: .cute, speed: 1.0)

        let statement = BubbleSpeechSynthesizer.renderVoiceBasedEffect(
            text: "갈까요.", voiceSamples: voiceSamples, sampleRate: sampleRate, config: config
        )
        let question = BubbleSpeechSynthesizer.renderVoiceBasedEffect(
            text: "갈까요?", voiceSamples: voiceSamples, sampleRate: sampleRate, config: config
        )

        XCTAssertFalse(statement.isEmpty)
        XCTAssertFalse(question.isEmpty)
        XCTAssertNotEqual(statement, question)
    }

    func testGranularRendererUsesVoiceDerivedBank() throws {
        let sampleRate = 44_100
        let voiceSamples = (0..<sampleRate / 2).map { index in
            Float(sin(2 * .pi * 230 * Double(index) / Double(sampleRate)) * 0.3)
        }
        let bank = try XCTUnwrap(BubbleSpeechGrainAnalyzer.analyze(samples: voiceSamples, sampleRate: sampleRate))

        let rendered = BubbleSpeechCharacterRenderer.render(
            text: "안녕하세요!",
            bank: bank,
            sampleRate: sampleRate,
            config: BubbleSpeechConfig.from(profile: .cute, speed: 1.0),
            segmentRate: 1.0
        )

        XCTAssertFalse(rendered.isEmpty)
        XCTAssertTrue(rendered.allSatisfy(\.isFinite))
    }

    func testAllCharactersHaveDistinctBubbleSpeechRhythms() {
        let patterns = (1...11).map { index in
            BubbleSpeechCharacterTuningPolicy.tuning(
                agentID: "agent_\(index)",
                preset: index <= 5 ? "F1" : "M1",
                profile: .cute
            ).pitchStepPattern
        }

        let signatures = patterns.map { pattern in
            pattern.map { String(format: "%.1f", $0) }.joined(separator: ",")
        }
        XCTAssertEqual(Set(signatures).count, 11)
    }

    func testCharacterRhythmIdentityIsNotPitchOnly() {
        let leo = BubbleSpeechCharacterTuningPolicy.tuning(agentID: "agent_1", preset: "M1", profile: .cute)
        let pin = BubbleSpeechCharacterTuningPolicy.tuning(agentID: "agent_4", preset: "F1", profile: .cute)
        let chiko = BubbleSpeechCharacterTuningPolicy.tuning(agentID: "agent_5", preset: "F1", profile: .cute)

        XCTAssertNotEqual(leo.accentPattern, pin.accentPattern)
        XCTAssertNotEqual(pin.grainRepeatPattern, chiko.grainRepeatPattern)
        XCTAssertGreaterThan(leo.maxSegmentDuration, chiko.minSegmentDuration)
    }

    func testAdaptiveBubbleSpeechExplicitBypassPreservesSource() throws {
        let samples = (0..<4_410).map { index in Float(sin(Double(index) * 0.04) * 0.2) }
        let text = String(repeating: "긴 업무 설명입니다. ", count: 30)
        let decision = BubbleSpeechEffectPolicy.decision(
            for: text,
            requested: true
        )

        let output = try XCTUnwrap(BubbleSpeechSynthesizer.applyAdaptiveEffect(
            text: text,
            voiceSamples: samples,
            sampleRate: 44_100,
            config: BubbleSpeechConfig.from(profile: .cute),
            segmentRate: 1,
            decision: decision
        ))

        XCTAssertEqual(decision.strength, .bypass)
        XCTAssertEqual(output, samples)
    }

    func testAdaptiveBubbleSpeechFailureDoesNotPassThroughSource() {
        let samples = [Float](repeating: 0, count: 44_100)
        let decision = BubbleSpeechEffectPolicy.decision(for: "안녕하세요!", requested: true)

        let output = BubbleSpeechSynthesizer.applyAdaptiveEffect(
            text: "안녕하세요!",
            voiceSamples: samples,
            sampleRate: 44_100,
            config: BubbleSpeechConfig.from(profile: .cute),
            segmentRate: 1,
            decision: decision
        )

        XCTAssertNil(output)
    }

    func testAdaptiveBubbleSpeechPreservesIntelligibleSourceTiming() throws {
        let sampleRate = 44_100
        let samples = (0..<(sampleRate * 2)).map { index in
            Float(sin(2 * .pi * 240 * Double(index) / Double(sampleRate)) * 0.24)
        }
        let decision = BubbleSpeechEffectPolicy.decision(for: "좋아요, 바로 도와드릴게요.", requested: true)

        let output = try XCTUnwrap(BubbleSpeechSynthesizer.applyAdaptiveEffect(
            text: "좋아요, 바로 도와드릴게요.",
            voiceSamples: samples,
            sampleRate: sampleRate,
            config: BubbleSpeechConfig.from(profile: .cute),
            segmentRate: 1,
            decision: decision
        ))

        XCTAssertGreaterThanOrEqual(
            BubbleSpeechSynthesizer.durationRatio(renderedSamples: output, sourceSamples: samples),
            0.72
        )
        XCTAssertEqual(output.count, samples.count)
        XCTAssertLessThan(BubbleSpeechSynthesizer.meanAbsoluteDelta(output, samples), 0.05)
        XCTAssertLessThanOrEqual(decision.wetMix, 0.46)
    }

    func testBubbleSpeechGeneratesProceduralSyllableAudio() {
        let config = BubbleSpeechConfig.from(profile: .cute, speed: 1.0)
        let samples = BubbleSpeechSynthesizer.synthesize(text: "뽀글뽀글 말하기!", config: config)

        XCTAssertGreaterThan(samples.count, 1_000)
        XCTAssertGreaterThan(samples.map { abs($0) }.max() ?? 0, 0.01)
    }

    func testBubbleSpeechProfilesProduceDifferentTiming() {
        let cute = BubbleSpeechSynthesizer.synthesize(
            text: "안녕하세요",
            config: BubbleSpeechConfig.from(profile: .cute, speed: 1.0)
        )
        let deep = BubbleSpeechSynthesizer.synthesize(
            text: "안녕하세요",
            config: BubbleSpeechConfig.from(profile: .deep, speed: 1.0)
        )

        XCTAssertNotEqual(cute.count, deep.count)
    }

    func testBubbleSpeechVowelColorsAffectWaveform() {
        let config = BubbleSpeechConfig.from(profile: .cute, speed: 1.0)
        let bright = BubbleSpeechSynthesizer.synthesize(text: "가가가", config: config)
        let round = BubbleSpeechSynthesizer.synthesize(text: "고고고", config: config)

        XCTAssertEqual(bright.count, round.count)
        XCTAssertNotEqual(Array(bright.prefix(256)), Array(round.prefix(256)))
    }

    func testBubbleSpeechChopsExistingVoiceIntoShorterSyllableRhythm() {
        let sampleRate = 44_100
        let voiceSamples = (0..<sampleRate / 2).map { index -> Float in
            let t = Double(index) / Double(sampleRate)
            return Float(sin(2.0 * .pi * 440.0 * t) * 0.25)
        }

        let rendered = BubbleSpeechSynthesizer.renderVoiceBasedEffect(
            text: "뽀글뽀글 말하기",
            voiceSamples: voiceSamples,
            sampleRate: sampleRate,
            config: BubbleSpeechConfig.from(profile: .cute, speed: 1.0)
        )

        XCTAssertLessThan(rendered.count, Int(Double(voiceSamples.count) * 0.95))
        XCTAssertGreaterThan(rendered.count, sampleRate / 20)
        XCTAssertGreaterThan(BubbleSpeechSynthesizer.meanAbsoluteDelta(rendered, voiceSamples), 0.002)
        XCTAssertGreaterThan(rendered.map { abs($0) }.max() ?? 0, 0.01)
        XCTAssertFalse(rendered.contains { !$0.isFinite })
    }

    func testBubbleSpeechGuideFailureDoesNotPassthroughVoiceSamples() {
        let sampleRate = 44_100
        let voiceSamples = (0..<sampleRate / 4).map { index -> Float in
            let t = Double(index) / Double(sampleRate)
            return Float(sin(2.0 * .pi * 330.0 * t) * 0.2)
        }

        let rendered = BubbleSpeechSynthesizer.renderVoiceBasedEffect(
            text: " !!!",
            voiceSamples: voiceSamples,
            sampleRate: sampleRate,
            config: BubbleSpeechConfig.from(profile: .cute, speed: 1.0)
        )

        XCTAssertTrue(rendered.isEmpty)
    }

    func testBubbleSpeechProfilesProduceDifferentChopperDurations() {
        let sampleRate = 44_100
        let voiceSamples = (0..<sampleRate).map { index -> Float in
            let t = Double(index) / Double(sampleRate)
            return Float((sin(2.0 * .pi * 220.0 * t) + sin(2.0 * .pi * 660.0 * t) * 0.25) * 0.2)
        }

        let cute = BubbleSpeechSynthesizer.renderVoiceBasedEffect(
            text: "좋아요 바로 해볼게요",
            voiceSamples: voiceSamples,
            sampleRate: sampleRate,
            config: BubbleSpeechConfig.from(profile: .cute, speed: 1.0)
        )
        let arcade = BubbleSpeechSynthesizer.renderVoiceBasedEffect(
            text: "좋아요 바로 해볼게요",
            voiceSamples: voiceSamples,
            sampleRate: sampleRate,
            config: BubbleSpeechConfig.from(profile: .arcade, speed: 1.18)
        )

        XCTAssertFalse(cute.isEmpty)
        XCTAssertFalse(arcade.isEmpty)
        XCTAssertNotEqual(cute.count, arcade.count)
        XCTAssertGreaterThan(BubbleSpeechSynthesizer.meanAbsoluteDelta(cute, arcade), 0.001)
    }
}

final class PublicAPIConnectorValidatorTests: XCTestCase {
    func testNaverNewsValidationUsesClientHeadersAndURLComponents() throws {
        let request = PublicAPIValidationRequest(
            provider: .naverNews,
            fields: ["clientID": "id-123", "clientSecret": "secret-456"]
        )

        let built = try PublicAPIConnectorValidator.makeRequest(for: request)

        XCTAssertEqual(built.url?.scheme, "https")
        XCTAssertEqual(built.url?.host, "openapi.naver.com")
        XCTAssertEqual(built.url?.path, "/v1/search/news.json")
        XCTAssertEqual(built.value(forHTTPHeaderField: "X-Naver-Client-Id"), "id-123")
        XCTAssertEqual(built.value(forHTTPHeaderField: "X-Naver-Client-Secret"), "secret-456")
        XCTAssertEqual(built.url?.queryValue("query"), "뉴스")
        XCTAssertEqual(built.url?.queryValue("display"), "1")
    }

    func testDARTValidationChecksCredentialAgainstKnownCompany() throws {
        let clock = FixedPublicAPIClock(now: fixedDate("2026-06-03T00:30:00Z"))
        let request = PublicAPIValidationRequest(
            provider: .dartDisclosure,
            fields: ["apiKey": "dart-key"],
            clock: clock
        )

        let built = try PublicAPIConnectorValidator.makeRequest(for: request)

        XCTAssertEqual(built.url?.host, "opendart.fss.or.kr")
        XCTAssertEqual(built.url?.path, "/api/company.json")
        XCTAssertEqual(built.url?.queryValue("crtfc_key"), "dart-key")
        XCTAssertEqual(built.url?.queryValue("corp_code"), "00126380")
    }

    func testKMAValidationUsesDynamicBaseDateAndTime() throws {
        let clock = FixedPublicAPIClock(now: fixedDate("2026-06-03T00:30:00Z"))
        let request = PublicAPIValidationRequest(
            provider: .kmaWeather,
            fields: ["serviceKey": "kma-key"],
            clock: clock
        )

        let built = try PublicAPIConnectorValidator.makeRequest(for: request)

        XCTAssertEqual(built.url?.host, "apis.data.go.kr")
        XCTAssertEqual(built.url?.queryValue("serviceKey"), "kma-key")
        XCTAssertEqual(built.url?.queryValue("base_date"), "20260603")
        XCTAssertEqual(built.url?.queryValue("base_time"), "0900")
    }

    func testKMABaseSlots_followProductSchedulesInKoreaTime() {
        let nowcastBeforeRelease = KMABaseTimePolicy.candidates(
            for: .ultraShortNowcast,
            now: fixedDate("2026-06-02T15:05:00Z")
        )
        XCTAssertEqual(nowcastBeforeRelease.first, KMABaseSlot(date: "20260602", time: "2300"))

        let ultraBeforeRelease = KMABaseTimePolicy.candidates(
            for: .ultraShortForecast,
            now: fixedDate("2026-06-03T00:40:00Z")
        )
        XCTAssertEqual(ultraBeforeRelease.first, KMABaseSlot(date: "20260603", time: "0830"))

        let ultraAfterRelease = KMABaseTimePolicy.candidates(
            for: .ultraShortForecast,
            now: fixedDate("2026-06-03T00:50:00Z")
        )
        XCTAssertEqual(ultraAfterRelease.first, KMABaseSlot(date: "20260603", time: "0930"))

        let villageBeforeRelease = KMABaseTimePolicy.candidates(
            for: .villageForecast,
            now: fixedDate("2026-06-02T17:05:00Z")
        )
        XCTAssertEqual(villageBeforeRelease.first, KMABaseSlot(date: "20260602", time: "2300"))

        let villageAfterRelease = KMABaseTimePolicy.candidates(
            for: .villageForecast,
            now: fixedDate("2026-06-02T17:15:00Z")
        )
        XCTAssertEqual(villageAfterRelease.first, KMABaseSlot(date: "20260603", time: "0200"))
    }

    func testKMARegionMapper_neverFallsBackToSeoul() {
        XCTAssertNil(KMARegionGridMapper.resolve(nil))
        XCTAssertNil(KMARegionGridMapper.resolve(""))
        XCTAssertNil(KMARegionGridMapper.resolve("등록되지 않은 지역"))
        XCTAssertEqual(KMARegionGridMapper.resolve("광양 출장")?.name, "광양")
    }

    func testKoreanLawValidationUsesLawOCAndURLComponents() throws {
        let request = PublicAPIValidationRequest(
            provider: .koreanLaw,
            fields: ["lawOC": "law-key"]
        )

        let built = try PublicAPIConnectorValidator.makeRequest(for: request)

        XCTAssertEqual(built.url?.scheme, "https")
        XCTAssertEqual(built.url?.host, "www.law.go.kr")
        XCTAssertEqual(built.url?.path, "/DRF/lawSearch.do")
        XCTAssertEqual(built.url?.queryValue("OC"), "law-key")
        XCTAssertEqual(built.url?.queryValue("target"), "law")
        XCTAssertEqual(built.url?.queryValue("type"), "JSON")
        XCTAssertEqual(built.url?.queryValue("query"), "개인정보")
    }

    func testNaverBodyParserRequiresItemsEvenWhenHTTPStatusIs200() throws {
        let empty = Data(#"{"lastBuildDate":"now","total":0,"start":1,"display":0,"items":[]}"#.utf8)
        let valid = Data(#"{"lastBuildDate":"now","total":1,"start":1,"display":1,"items":[{"title":"뉴스","originallink":"https://example.com","link":"https://example.com","description":"본문","pubDate":"Wed, 03 Jun 2026 09:00:00 +0900"}]}"#.utf8)

        XCTAssertFalse(PublicAPIConnectorValidator.bodyIndicatesSuccess(provider: .naverNews, data: empty))
        XCTAssertTrue(PublicAPIConnectorValidator.bodyIndicatesSuccess(provider: .naverNews, data: valid))
    }

    func testDARTBodyParserRejectsErrorStatusEvenWhenHTTPStatusIs200() {
        let invalid = Data(#"{"status":"010","message":"등록되지 않은 키입니다."}"#.utf8)
        let valid = Data(#"{"status":"000","message":"정상","list":[{"corp_name":"테스트"}]}"#.utf8)
        let validNoData = Data(#"{"status":"013","message":"조회된 데이타가 없습니다."}"#.utf8)

        XCTAssertFalse(PublicAPIConnectorValidator.bodyIndicatesSuccess(provider: .dartDisclosure, data: invalid))
        XCTAssertTrue(PublicAPIConnectorValidator.bodyIndicatesSuccess(provider: .dartDisclosure, data: valid))
        XCTAssertTrue(PublicAPIConnectorValidator.bodyIndicatesSuccess(provider: .dartDisclosure, data: validNoData))
    }

    func testKMABodyParserRequiresNormalServiceResult() {
        let invalid = Data(#"{"response":{"header":{"resultCode":"03","resultMsg":"NO_DATA"}}}"#.utf8)
        let emptyBody = Data(#"{"response":{"header":{"resultCode":"00","resultMsg":"NORMAL_SERVICE"},"body":{"items":{"item":[]}}}}"#.utf8)
        let valid = Data(#"{"response":{"header":{"resultCode":"00","resultMsg":"NORMAL_SERVICE"},"body":{"items":{"item":[{"obsrValue":"20"}]}}}}"#.utf8)

        XCTAssertFalse(PublicAPIConnectorValidator.bodyIndicatesSuccess(provider: .kmaWeather, data: invalid))
        XCTAssertFalse(PublicAPIConnectorValidator.bodyIndicatesSuccess(provider: .kmaWeather, data: emptyBody))
        XCTAssertTrue(PublicAPIConnectorValidator.bodyIndicatesSuccess(provider: .kmaWeather, data: valid))
    }

    func testKoreanLawBodyParserRequiresOfficialLawResult() {
        let invalid = Data(#"{"LawSearch":{"totalCnt":"0","law":[]}}"#.utf8)
        let valid = Data(#"{"LawSearch":{"totalCnt":"1","law":[{"법령명한글":"개인정보 보호법","법령ID":"011357","법령일련번호":"123456"}]}}"#.utf8)

        XCTAssertFalse(PublicAPIConnectorValidator.bodyIndicatesSuccess(provider: .koreanLaw, data: invalid))
        XCTAssertTrue(PublicAPIConnectorValidator.bodyIndicatesSuccess(provider: .koreanLaw, data: valid))
    }

    func testKoreanLawDirectConnectorBuildsSearchRequest() throws {
        let request = KoreanLawSearchRequest(query: "개인정보", lawName: nil, article: nil)

        let built = try KoreanLawDirectConnector.makeSearchRequest(request, lawOC: "law-key")

        XCTAssertEqual(built.url?.host, "www.law.go.kr")
        XCTAssertEqual(built.url?.path, "/DRF/lawSearch.do")
        XCTAssertEqual(built.url?.queryValue("OC"), "law-key")
        XCTAssertEqual(built.url?.queryValue("target"), "law")
        XCTAssertEqual(built.url?.queryValue("type"), "JSON")
        XCTAssertEqual(built.url?.queryValue("query"), "개인정보")
    }

    func testKoreanLawDirectConnectorKeepsSearchResultsPartial() {
        let data = Data(#"{"LawSearch":{"totalCnt":"1","law":[{"법령명한글":"개인정보 보호법","법령ID":"011357","시행일자":"20240315"}]}}"#.utf8)

        let results = KoreanLawDirectConnector.parseSearchResponse(data)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].status, .partial)
        XCTAssertEqual(results[0].verificationStatus, "partial")
        XCTAssertEqual(results[0].lawName, "개인정보 보호법")
        XCTAssertEqual(results[0].effectiveDate, "20240315")
        XCTAssertFalse(results[0].sources.isEmpty)
        XCTAssertTrue(results[0].disclaimer.contains("법률 자문이 아닌"))
    }

    func testKoreanLawCitationVerificationFailsWhenExpectedArticleIsMissing() {
        let result = KoreanLawResult(
            status: .partial,
            lawName: "개인정보 보호법",
            article: nil,
            effectiveDate: "20240315",
            officialSourceURL: URL(string: "https://www.law.go.kr/법령?id=011357"),
            verificationStatus: "partial",
            summary: "공식 법령 검색 결과입니다.",
            mismatchDetails: [],
            sources: [],
            disclaimer: KoreanLawDirectConnector.disclaimer
        )
        let request = KoreanLawCitationVerificationRequest(
            citationText: "개인정보 보호법 제1조",
            expectedLawName: "개인정보 보호법",
            expectedArticle: "제1조",
            expectedParagraph: nil,
            expectedItem: nil,
            expectedEffectiveDate: nil
        )

        let verified = KoreanLawDirectConnector.verifyCitation(request, against: result)

        XCTAssertEqual(verified.status, .failed)
        XCTAssertTrue(verified.mismatchDetails.contains { $0.contains("조문 누락") })
    }

    func testKoreanLawCitationVerificationFailsWithoutOfficialSource() {
        let result = KoreanLawResult(
            status: .partial,
            lawName: "개인정보 보호법",
            article: "제1조",
            effectiveDate: "20240315",
            officialSourceURL: nil,
            verificationStatus: "partial",
            summary: "공식 법령 검색 결과입니다.",
            mismatchDetails: [],
            sources: [],
            disclaimer: KoreanLawDirectConnector.disclaimer
        )
        let request = KoreanLawCitationVerificationRequest(
            citationText: "개인정보 보호법 제1조",
            expectedLawName: "개인정보 보호법",
            expectedArticle: "제1조",
            expectedParagraph: nil,
            expectedItem: nil,
            expectedEffectiveDate: "20240315"
        )

        let verified = KoreanLawDirectConnector.verifyCitation(request, against: result)

        XCTAssertEqual(verified.status, .failed)
        XCTAssertTrue(verified.mismatchDetails.contains { $0.contains("공식 출처 URL 누락") })
    }

    private func fixedDate(_ iso8601: String) -> Date {
        ISO8601DateFormatter().date(from: iso8601)!
    }
}

final class DARTCompanyIndexTests: XCTestCase {
    private let entries = [
        DARTCompanyIndexEntry(
            corpCode: "00126380",
            corpName: "삼성전자(주)",
            stockCode: "005930",
            modifyDate: "20260701"
        ),
        DARTCompanyIndexEntry(
            corpCode: "00164779",
            corpName: "에스케이하이닉스(주)",
            stockCode: "000660",
            modifyDate: "20260701"
        ),
        DARTCompanyIndexEntry(
            corpCode: "00900001",
            corpName: "동일상사",
            stockCode: nil,
            modifyDate: "20260701"
        ),
        DARTCompanyIndexEntry(
            corpCode: "00900002",
            corpName: "동일상사(주)",
            stockCode: nil,
            modifyDate: "20260701"
        )
    ]

    func testResolvesAnyIndexedCompanyByStockCode() {
        let result = index.resolve(input: "000660", indexUpdatedAt: nil, isIndexStale: false)

        XCTAssertEqual(result.corpCode, "00164779")
        XCTAssertEqual(result.stockCode, "000660")
        XCTAssertEqual(result.resolutionSource, .officialStockCodeIndex)
    }

    func testResolvesNormalizedOfficialCompanyName() {
        let result = index.resolve(input: "삼성전자", indexUpdatedAt: nil, isIndexStale: false)

        XCTAssertEqual(result.corpCode, "00126380")
        XCTAssertEqual(result.resolutionSource, .officialCompanyNameIndex)
    }

    func testAcceptsExplicitCorpCodeWithoutChoosingAnotherCompany() {
        let result = index.resolve(input: "12345678", indexUpdatedAt: nil, isIndexStale: false)

        XCTAssertEqual(result.corpCode, "12345678")
        XCTAssertEqual(result.resolutionSource, .directCorpCode)
    }

    func testAmbiguousCompanyNameDoesNotAutoResolveFirstCandidate() {
        let result = index.resolve(input: "동일상사", indexUpdatedAt: nil, isIndexStale: false)

        XCTAssertNil(result.corpCode)
        XCTAssertEqual(result.resolutionSource, .ambiguous)
        XCTAssertEqual(result.candidates.count, 2)
    }

    func testPartialNameOnlySuggestsCandidates() {
        let result = index.resolve(input: "하이닉스", indexUpdatedAt: nil, isIndexStale: true)

        XCTAssertNil(result.corpCode)
        XCTAssertEqual(result.resolutionSource, .ambiguous)
        XCTAssertEqual(result.candidates.first?.stockCode, "000660")
        XCTAssertTrue(result.isIndexStale)
    }

    private var index: DARTCompanyIndex {
        DARTCompanyIndex(entries: entries)
    }
}

final class RuntimeTruthPersistenceTests: XCTestCase {
    func testEmptyExternalLookupResultsAreNotSuccessful() {
        let sheets = GoogleSheetsResultFormatter.resultState(
            GoogleSheetsReadResult(spreadsheetID: "sheet", range: "Sheet1!A1:D20", values: [])
        )
        let calendar = GoogleCalendarResultFormatter.resultState(items: [], statusMessage: "조회 완료")
        let news = NewsResultFormatter.resultState(
            query: "리튬",
            items: [],
            sourceLabel: "Naver News",
            modeNotice: "제목과 설명 기준"
        )
        let weather = WeatherResultFormatter.resultState(
            regionName: "광양",
            nx: 73,
            ny: 70,
            observations: [],
            sourceLabel: "기상청",
            modeNotice: "공식 기상 데이터"
        )
        let law = LawResultFormatter.resultState(
            query: "근로기준법 연차",
            results: [],
            sourceLabel: "국가법령정보센터",
            modeNotice: "공식 검색 결과"
        )

        for state in [sheets, calendar, news, weather, law] {
            guard case .checkedEmpty = state else {
                return XCTFail("빈 외부 조회 결과는 succeeded가 아니라 checkedEmpty여야 합니다: \(state)")
            }
        }
    }

    func testNewsFormatterDoesNotClaimUnperformedIssueClustering() throws {
        let item = NaverNewsDirectItem(
            title: "삼성전자 공급망 소식",
            description: "검색 결과 설명",
            link: try XCTUnwrap(URL(string: "https://example.com/news")),
            originalLink: nil,
            publishedAt: nil
        )

        let state = NewsResultFormatter.resultState(
            query: "삼성전자",
            items: [item],
            sourceLabel: "Naver News",
            modeNotice: "제목과 설명 기준"
        )
        guard case .succeeded(let result) = state else {
            return XCTFail("뉴스 결과가 성공 상태여야 합니다")
        }

        XCTAssertFalse(result.summary.contains("공통 이슈를 묶었습니다"))
        XCTAssertFalse(result.body?.contains("공통 이슈 후보") == true)
        XCTAssertTrue(result.body?.contains("주요 검색 결과") == true)
    }

    func testWeatherImpactNotesFollowObservedThresholds() {
        let observations = [
            KMAWeatherDirectObservation(category: "RN1", value: "4.5", baseDate: "20260712", baseTime: "1200"),
            KMAWeatherDirectObservation(category: "WSD", value: "9.2", baseDate: "20260712", baseTime: "1200")
        ]
        let state = WeatherResultFormatter.resultState(
            regionName: "광양",
            nx: 73,
            ny: 70,
            observations: observations,
            sourceLabel: "기상청",
            modeNotice: "공식 기상 데이터"
        )
        guard case .succeeded(let result) = state else {
            return XCTFail("관측값이 있는 날씨 결과가 성공 상태여야 합니다")
        }

        XCTAssertTrue(result.body?.contains("강수") == true)
        XCTAssertTrue(result.body?.contains("강풍") == true)
        XCTAssertFalse(result.body?.contains("항목에 따라") == true)
    }

    func testCompositeSummaryUsesVerifiedSectionSummaries() {
        let sections = [
            NaturalResultSection(
                title: "기준일 시세",
                summary: "2026-07-11 종가 84,000원",
                body: nil,
                sourceLabel: "금융위원회",
                sourceLinks: []
            ),
            NaturalResultSection(
                title: "뉴스",
                summary: "관련 뉴스 3건의 제목과 설명을 확인했습니다.",
                body: nil,
                sourceLabel: "Naver News",
                sourceLinks: []
            )
        ]

        let summary = NaturalResultComposer.oneLineSummary(from: sections)

        XCTAssertEqual(
            summary,
            "기준일 시세: 2026-07-11 종가 84,000원 · 뉴스: 관련 뉴스 3건의 제목과 설명을 확인했습니다."
        )
        XCTAssertFalse(summary.contains("2개 항목"))
    }

    func testCompositeResultPreservesPartialState() {
        let request = NaturalWorkRequest(
            originalText: "삼성전자 알려줘",
            entities: [.companyName("삼성전자")],
            intents: [.companyOverview],
            confidence: .high,
            clarificationQuestion: nil
        )
        let step = NaturalToolStep(
            id: "news",
            toolID: "news.search",
            input: MyTeamToolInput(query: "삼성전자"),
            sectionTitle: "뉴스"
        )
        let plan = NaturalWorkPlan(
            request: request,
            workType: .companyBriefing,
            title: "삼성전자 브리핑",
            userFacingSummary: "확인 중",
            steps: [step],
            compositionStyle: .compositeBriefing,
            userNotice: nil,
            preflightMissingSections: []
        )
        let partialResult = MyTeamToolResult(
            title: "일부 뉴스만 확인했습니다",
            summary: "뉴스 1건을 확인했고 일부 출처는 응답하지 않았습니다.",
            sourceLabel: "Naver News",
            body: "확인된 뉴스 1건",
            items: [],
            nextActions: [MyTeamNextAction(id: "searchAgain", title: "다시 검색", role: .normal)]
        )

        let result = NaturalResultComposer.compose(
            plan: plan,
            executions: [NaturalStepExecution(step: step, descriptor: nil, state: .partial(partialResult))]
        )

        XCTAssertEqual(result.sections.first?.status, .partial)
        XCTAssertTrue(result.artifactMarkdown.contains("뉴스 · 일부 확인"))
        XCTAssertTrue(result.artifactMarkdown.contains("## 확인하지 못한 항목"))
        XCTAssertTrue(result.artifactMarkdown.contains("일부 결과만 확인했습니다"))
    }

    func testUnknownPersistedToolLogStateFailsClosed() throws {
        let data = Data(#""futureState""#.utf8)

        let state = try JSONDecoder().decode(ToolExecutionLogState.self, from: data)

        XCTAssertEqual(state, .blocked)
    }

    func testPartialToolLogStateRoundTripsWithoutBecomingSuccess() throws {
        let encoded = try JSONEncoder().encode(ToolExecutionLogState.partial)
        let decoded = try JSONDecoder().decode(ToolExecutionLogState.self, from: encoded)

        XCTAssertEqual(decoded, .partial)
    }

    func testReleaseGateFailsClosedForUnapprovedExternalLookup() throws {
        let descriptor = try XCTUnwrap(MyTeamToolRegistry.descriptor(id: "news.search"))

        XCTAssertFalse(ReleaseLiveProviderGate.isApprovedForRelease(descriptor))
    }

    func testReleaseGateAllowsKnownLocalDraftCapability() throws {
        let descriptor = try XCTUnwrap(MyTeamToolRegistry.descriptor(id: "document.meetingMinutes"))

        XCTAssertTrue(ReleaseLiveProviderGate.isApprovedForRelease(descriptor))
    }
}

private struct FixedPublicAPIClock: PublicAPIClock {
    let now: Date
    let timeZone = TimeZone(identifier: "Asia/Seoul")!
}

private extension URL {
    func queryValue(_ name: String) -> String? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == name }?
            .value
    }
}
