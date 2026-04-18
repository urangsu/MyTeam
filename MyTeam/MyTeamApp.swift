import SwiftUI
import AppKit

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
class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()

        // 1순위: 이전 평문 저장소(UserDefaults)에 남은 비밀번호를 Keychain으로 마이그레이션
        KeychainManager.migrateFromUserDefaultsIfNeeded()

        // 앱 시작 시 팀 테이블 창 표시 (4명 한 번에)
        AgentWindowManager.shared.showTeam()

        // Dock 아이콘 숨기기 (백그라운드 앱)
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        AgentWindowManager.shared.savePosition()
        // InferenceActor가 busy 상태면 Task dispatch가 큐에 쌓여 데드락 발생 가능.
        // 추론은 OS가 프로세스 종료 시 강제 정리하므로 그냥 즉시 종료.
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 위의 applicationShouldTerminate에서 이미 처리
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
