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
    case stoppingAudio
    case stoppingEngine
    case replying
    case terminating
    case forcedExit
}

@MainActor
final class AppTerminationCoordinator: ObservableObject {
    static let shared = AppTerminationCoordinator()

    private let engineStopTimeoutNanoseconds: UInt64 = 2_000_000_000
    private let terminationWatchdogNanoseconds: UInt64 = 5_000_000_000

    @Published private(set) var phase: AppTerminationPhase = .idle

    private var didReplyToShouldTerminate = false
    private var terminationTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?
    private var pendingSource: AppTerminationSource = .unknown
    private weak var pendingApplication: NSApplication?

    private init() {}

    func requestTermination(
        source: AppTerminationSource,
        application: NSApplication
    ) -> NSApplication.TerminateReply {
        if phase == .terminating || phase == .forcedExit || didReplyToShouldTerminate {
            return .terminateNow
        }

        if phase != .idle {
            return .terminateLater
        }

        phase = .requested
        pendingSource = source
        pendingApplication = application
        didReplyToShouldTerminate = false

        startTerminationSequence(source: source)
        return .terminateLater
    }

    func requestMenuQuit() {
        pendingSource = .menu
        NSApplication.shared.terminate(nil)
    }

    func handleApplicationWillTerminate() {
        watchdogTask?.cancel()
        terminationTask?.cancel()
        phase = .terminating
        Task(priority: .userInitiated) {
            await AudioPlaybackService.shared.stopAll()
            await AudioPlaybackService.shared.stopEngineForTermination()
        }
    }

    private func startTerminationSequence(source: AppTerminationSource) {
        terminationTask?.cancel()
        watchdogTask?.cancel()

        watchdogTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: self.terminationWatchdogNanoseconds)
            await MainActor.run {
                self.forceExitIfNeeded(reason: "termination watchdog expired")
            }
        }

        terminationTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await self.runTerminationSequence(source: source)
        }
    }

    private func runTerminationSequence(source: AppTerminationSource) async {
        phase = .savingState
        AgentWindowManager.shared.savePosition()
        AgentWindowManager.shared.cancelAllActiveWorkflowTasks()

        phase = .stoppingAudio
        _ = AppTerminationSpeechService.shared.playPreparedFarewell(completion: {})
        await stopAudioNonBlocking()

        phase = .stoppingEngine
        await stopEngineWithTimeout()

        phase = .replying
        replyOnce()
    }

    private func stopAudioNonBlocking() async {
        await AudioPlaybackService.shared.stopAll()
    }

    private func stopEngineWithTimeout() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await AudioPlaybackService.shared.stopEngineForTermination()
            }
            group.addTask { [engineStopTimeoutNanoseconds] in
                try? await Task.sleep(nanoseconds: engineStopTimeoutNanoseconds)
            }
            await group.next()
            group.cancelAll()
        }
    }

    private func replyOnce() {
        guard !didReplyToShouldTerminate else { return }
        didReplyToShouldTerminate = true
        watchdogTask?.cancel()
        terminationTask?.cancel()
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
