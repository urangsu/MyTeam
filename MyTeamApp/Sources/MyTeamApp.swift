import SwiftUI
import AppKit

// MARK: - App Entry Point
@main
struct MyTeamApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 메인 설정 창 (메뉴바에서 열 수 있음)
        // 에이전트 창들은 AppDelegate에서 별도로 관리됩니다.
        Settings {
            SettingsView()
        }
    }
}

// MARK: - AppDelegate
// 앱 시작 시 에이전트 창을 띄우고,
// 앱 종료 시 에이전트 창 위치를 저장합니다.
class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem?   // 메뉴바 아이콘

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 메뉴바 아이콘 생성
        setupMenuBar()

        // Phase 1: 에이전트 1명만 먼저 띄우기
        // (테스트 완료 후 showAgents(count: 4) 로 변경)
        AgentWindowManager.shared.showAgents(count: 1)

        // Dock 아이콘 숨기기 (배경 앱처럼 동작)
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 종료 전 모든 창 위치 저장
        AgentWindowManager.shared.saveAllPositions()
    }

    // MARK: - 메뉴바 설정
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "person.3.fill", accessibilityDescription: "MyTeam")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "에이전트 1명 표시",  action: #selector(show1Agent),  keyEquivalent: "1"))
        menu.addItem(NSMenuItem(title: "에이전트 4명 표시",  action: #selector(show4Agents), keyEquivalent: "4"))
        menu.addItem(NSMenuItem(title: "모두 숨기기",        action: #selector(hideAll),     keyEquivalent: "h"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "종료",              action: #selector(quitApp),     keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc func show1Agent()  { AgentWindowManager.shared.showAgents(count: 1) }
    @objc func show4Agents() { AgentWindowManager.shared.showAgents(count: 4) }
    @objc func hideAll()     { AgentWindowManager.shared.hideAll() }
    @objc func quitApp()     { NSApp.terminate(nil) }
}

// MARK: - SettingsView (메뉴바 → 설정 창)
// Phase 4에서 스킨 갤러리, API 키 설정 등으로 확장됩니다.
struct SettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)

            Text("MyTeam — AI 에이전트 팀")
                .font(.title2.bold())

            Text("메뉴바 아이콘을 클릭하여 에이전트를 제어하세요.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text("Phase 1 v0.1")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(40)
        .frame(width: 360, height: 260)
    }
}
