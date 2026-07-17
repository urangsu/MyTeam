import AppKit
import Combine
import Darwin
import Foundation

enum AppTerminationSource: String, Sendable {
    case commandQ
    case menu
    case appleScript
    case system
    case watchdog
    case unknown
}

enum AppTerminationPhase: String, Sendable {
    case idle
    case requested
    case savingState
    case playingFarewell
    case stoppingAudio
    case stoppingEngine
    case replying
    case terminating
    case forcedExit
}

@MainActor
final class AppTerminationCoordinator: ObservableObject {
    static let shared = AppTerminationCoordinator()

    private let terminationWatchdogNanoseconds: UInt64 = 8_000_000_000

    @Published private(set) var phase: AppTerminationPhase = .idle

    private var didReplyToShouldTerminate = false
    private var watchdogTask: Task<Void, Never>?
    private var pendingSource: AppTerminationSource = .unknown
    private weak var pendingApplication: NSApplication?

    private init() {}

    func requestTermination(
        source: AppTerminationSource,
        application: NSApplication
    ) -> NSApplication.TerminateReply {
        if phase == .terminating || phase == .forcedExit {
            return .terminateNow
        }
        if phase == .playingFarewell || phase == .replying {
            return .terminateLater
        }

        phase = .requested
        pendingSource = source
        pendingApplication = application
        didReplyToShouldTerminate = false

        phase = .savingState
        AgentWindowManager.shared.savePosition()
        AgentWindowManager.shared.cancelAllActiveWorkflowTasks()

        if AppTerminationSpeechService.shared.playPreparedFarewell(completion: { [weak self] in
            self?.finishAfterFarewell()
        }) {
            phase = .playingFarewell
            startWatchdog()
            return .terminateLater
        }

        didReplyToShouldTerminate = true
        stopAudioNonBlocking()
        stopEngineBestEffort()

        phase = .terminating
        return .terminateNow
    }

    func requestMenuQuit() {
        pendingSource = .menu
        NSApplication.shared.terminate(nil)
    }

    #if DEBUG
    /// Headless QA probes need a deterministic process result without entering
    /// the interactive AppKit termination path. Keep the hard-exit boundary
    /// centralized here so production code cannot bypass coordinated shutdown.
    func terminateRuntimeProbe(succeeded: Bool) -> Never {
        Darwin.exit(succeeded ? EXIT_SUCCESS : EXIT_FAILURE)
    }
    #endif

    func handleApplicationWillTerminate() {
        watchdogTask?.cancel()
        phase = .terminating
        Task.detached(priority: .utility) {
            await AudioPlaybackService.shared.stopAll()
            await AudioPlaybackService.shared.stopEngineForTermination()
        }
    }

    private func startWatchdog() {
        watchdogTask?.cancel()

        watchdogTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: self.terminationWatchdogNanoseconds)
            await MainActor.run {
                self.forceExitIfNeeded(reason: "termination watchdog expired")
            }
        }

    }

    private func finishAfterFarewell() {
        guard phase == .playingFarewell else { return }
        phase = .stoppingAudio
        stopAudioNonBlocking()
        phase = .stoppingEngine
        stopEngineBestEffort()
        phase = .replying
        replyOnce()
    }

    private func stopAudioNonBlocking() {
        Task.detached(priority: .utility) {
            await AudioPlaybackService.shared.stopAll()
        }
    }

    private func stopEngineBestEffort() {
        Task.detached(priority: .utility) {
            await AudioPlaybackService.shared.stopEngineForTermination()
        }
    }

    private func replyOnce() {
        guard !didReplyToShouldTerminate else { return }
        didReplyToShouldTerminate = true
        watchdogTask?.cancel()
        phase = .terminating
        (pendingApplication ?? NSApplication.shared).reply(toApplicationShouldTerminate: true)
    }

    private func forceExitIfNeeded(reason: String) {
        guard phase != .terminating, phase != .forcedExit else { return }
        AppLog.warning("[AppTermination] forcing exit: \(reason)")
        phase = .forcedExit
        Darwin.exit(0)
    }
}
