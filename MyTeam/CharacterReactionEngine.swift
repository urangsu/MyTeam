import Foundation

/// Character reaction 실행을 관리하는 engine.
/// CharacterReactionDelegate, CharacterReactionDiagnostics는 CharacterReactionEventSink.swift에 정의.
@MainActor
final class CharacterReactionEngine {
    static let shared = CharacterReactionEngine()

    private var reactionCooldowns: [String: Date] = [:]
    private var isProcessingReaction = false

    private init() {}

    // MARK: - Public API

    /// Workroom event를 처리하고 character reaction을 trigger한다.
    func processEvent(_ event: WorkroomCharacterEvent, delegate: CharacterReactionDelegate?) async {
        guard !isInCooldown(for: event) else {
            AppLog.debug("CharacterReactionEngine: Event \(event.id) in cooldown, skipping")
            return
        }

        guard let reaction = CharacterReactionMapping.reactionFor(event) else {
            AppLog.debug("CharacterReactionEngine: No reaction mapping for \(event.id)")
            return
        }

        isProcessingReaction = true
        defer { isProcessingReaction = false }

        await executeReaction(reaction, delegate: delegate)
        recordCooldown(for: event, seconds: reaction.cooldownSeconds)
    }

    // MARK: - Private

    private func executeReaction(_ reaction: CharacterReaction, delegate: CharacterReactionDelegate?) async {
        AppLog.debug("CharacterReactionEngine: executing reaction for \(reaction.event.id)")
        await delegate?.applyCharacterReaction(
            animationState: reaction.targetAnimationState,
            responseText: reaction.responseText,
            duration: 2.0
        )
    }

    private func isInCooldown(for event: WorkroomCharacterEvent) -> Bool {
        guard let lastTime = reactionCooldowns[event.id] else { return false }
        return Date().timeIntervalSince(lastTime) < 30
    }

    private func recordCooldown(for event: WorkroomCharacterEvent, seconds: Double) {
        reactionCooldowns[event.id] = Date()
    }

    // MARK: - Diagnostics

    func cooldownStatus() -> [String: String] {
        let now = Date()
        return reactionCooldowns.mapValues { lastTime in
            let remaining = 30 - now.timeIntervalSince(lastTime)
            return remaining > 0 ? "\(Int(remaining))s remaining" : "ready"
        }
    }
}
