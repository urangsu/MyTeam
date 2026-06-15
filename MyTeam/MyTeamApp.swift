import SwiftUI
import AppKit
import Darwin

enum AppLog {
    enum Category: String {
        case app = "App"
        case ai = "AIService"
        case audio = "Audio"
        case tts = "TTS"
        case window = "Window"
        case schedule = "Schedule"
        case legacy = "Legacy"
    }

    enum Level: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"
    }

    nonisolated static var isVerboseEnabled: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.environment["MYTEAM_VERBOSE_LOGS"] == "0" { return false }
        return true
        #else
        return ProcessInfo.processInfo.environment["MYTEAM_VERBOSE_LOGS"] == "1"
        #endif
    }

    nonisolated static func debug(_ message: @autoclosure () -> String, _ category: Category = .app) {
        guard isVerboseEnabled else { return }
        write(message(), category: category, level: .debug)
    }

    nonisolated static func info(_ message: @autoclosure () -> String, _ category: Category = .app) {
        write(message(), category: category, level: .info)
    }

    nonisolated static func warning(_ message: @autoclosure () -> String, _ category: Category = .app) {
        write(message(), category: category, level: .warning)
    }

    nonisolated static func error(_ message: @autoclosure () -> String, _ category: Category = .app) {
        write(message(), category: category, level: .error)
    }

    nonisolated private static func write(_ message: String, category: Category, level: Level) {
        print("[\(category.rawValue)] \(level.rawValue) \(message)")
        fflush(stdout)
    }
}

enum AppPaths {
    nonisolated static let appDirectoryName = "MyTeam"

    nonisolated static var applicationSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent(appDirectoryName, isDirectory: true)
    }

    nonisolated static var cacheDirectory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent(appDirectoryName, isDirectory: true)
    }

    nonisolated static var ttsBenchDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("TTSBench", isDirectory: true)
    }

}

// MARK: - App Entry Point
@main
struct MyTeamApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

// MARK: - AppDelegate
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem?
    private var isTerminationReplyPending = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.environment["MYTEAM_TTS_PROBE"] == "1" {
            // TTS probe: Supertonic3 only candidate.
            print("[TTSProbe] Supertonic3-only probe — no-op in this build")
            fflush(stdout)
            NSApp.setActivationPolicy(.prohibited)
            Task { await MainActor.run { NSApp.terminate(nil) } }
            return
        }

        setupMenuBar()

        // 1순위: 이전 평문 저장소(UserDefaults)에 남은 비밀번호를 Keychain으로 마이그레이션
        KeychainManager.migrateFromUserDefaultsIfNeeded()
        TeamNameplateAppearanceSettings.migrateLegacyValuesIfNeeded()

        // 앱 시작 시 팀 테이블 창 표시 (4명 한 번에)
        AgentWindowManager.shared.showTeam()
        AppTerminationSpeechService.shared.scheduleInitialPrewarm(manager: AgentWindowManager.shared)

        // Dock 아이콘 숨기기 (백그라운드 앱)
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        AgentWindowManager.shared.savePosition()
        guard !isTerminationReplyPending else { return .terminateNow }
        if AppTerminationSpeechService.shared.playPreparedFarewell(completion: { [weak sender] in
            sender?.reply(toApplicationShouldTerminate: true)
        }) {
            isTerminationReplyPending = true
            return .terminateLater
        }
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        // [종료 크래시 수정 #1] EXC_BAD_ACCESS in __hash__() — MLX Metal unordered_map 접근 경합
        // [종료 크래시 수정 #2] EXC_BAD_ACCESS in objc_msgSend (*pProc)(pObj, selector, args...)
        //   원인: AVAudioEngine 렌더 콜백이 in-flight인 상태에서 Swift 객체 해제
        //         → AVAudioNode(ObjC) 메시지 접근 크래시
        //   해결:
        //     1. CoreAudio 렌더 스레드 즉시 정지 (engine.stop())
        //     2. TTS actor 취소 후 DispatchSemaphore로 완료 확인
        //     3. Metal command queue drain 대기

        // Step 1: CoreAudio 렌더 스레드 즉시 정지
        Task { await AudioPlaybackService.shared.stopEngineForTermination() }
        // Task 디스패치 반영 대기 (AVAudio actor 큐 flush)
        Thread.sleep(forTimeInterval: 0.05)

        // Step 2: Metal command queue drain
        Thread.sleep(forTimeInterval: 0.1)
    }

    // MARK: - 메뉴바
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "person.3.fill", accessibilityDescription: "MyTeam")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "팀 테이블 표시",  action: #selector(showTeam),  keyEquivalent: "t"))
        menu.addItem(NSMenuItem(title: "팀 테이블 숨기기", action: #selector(hideTeam),  keyEquivalent: "h"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "종료",            action: #selector(quitApp),   keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc func showTeam() { AgentWindowManager.shared.showTeam() }
    @objc func hideTeam() { AgentWindowManager.shared.hideTeam() }
    @objc func quitApp()  { NSApp.terminate(nil) }
}
