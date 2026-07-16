import SwiftUI
import AppKit

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
        if let qaRoot = QARuntimeProfile.rootURL(arguments: ProcessInfo.processInfo.arguments) {
            return qaRoot
                .appendingPathComponent("Application Support", isDirectory: true)
                .appendingPathComponent(appDirectoryName, isDirectory: true)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent(appDirectoryName, isDirectory: true)
    }

    nonisolated static var cacheDirectory: URL {
        if let qaRoot = QARuntimeProfile.rootURL(arguments: ProcessInfo.processInfo.arguments) {
            return qaRoot
                .appendingPathComponent("Caches", isDirectory: true)
                .appendingPathComponent(appDirectoryName, isDirectory: true)
        }
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent(appDirectoryName, isDirectory: true)
    }

    nonisolated static var ttsBenchDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("TTSBench", isDirectory: true)
    }

}

enum QARuntimeProfile {
    nonisolated static func rootURL(arguments: [String]) -> URL? {
        #if DEBUG
        guard let flagIndex = arguments.firstIndex(of: "--qa-root") else { return nil }
        let valueIndex = arguments.index(after: flagIndex)
        guard arguments.indices.contains(valueIndex) else { return nil }
        let path = arguments[valueIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        guard path.hasPrefix("/") else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
        #else
        return nil
        #endif
    }
}

enum AppRuntimeEnvironment {
    nonisolated static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}

// MARK: - App Entry Point
@main
struct MyTeamApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptySettingsSceneView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("MyTeam 설정...") {
                    AgentWindowManager.shared.showSettingsWindow()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

private struct EmptySettingsSceneView: View {
    var body: some View {
        EmptyView()
            .frame(width: 0, height: 0)
    }
}

// MARK: - AppDelegate
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if AppRuntimeEnvironment.isRunningTests {
            NSApp.setActivationPolicy(.prohibited)
            return
        }

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
        AppTerminationCoordinator.shared.requestTermination(source: .system, application: sender)
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppTerminationCoordinator.shared.handleApplicationWillTerminate()
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
        menu.addItem(NSMenuItem(title: "설정",            action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "종료",            action: #selector(quitApp),   keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc func showTeam() { AgentWindowManager.shared.showTeam() }
    @objc func hideTeam() { AgentWindowManager.shared.hideTeam() }
    @objc func showSettings() { AgentWindowManager.shared.showSettingsWindow() }
    @objc func quitApp()  {
        AppTerminationCoordinator.shared.requestMenuQuit()
    }
}
