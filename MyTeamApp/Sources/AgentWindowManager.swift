import AppKit
import SwiftUI

// MARK: - AgentWindowManager
// 최대 4개의 에이전트 창(FloatingPanel)을 생성하고 관리합니다.
class AgentWindowManager: ObservableObject {

    static let shared = AgentWindowManager()

    // 에이전트 설정 (Phase 2에서 YAML로 분리)
    struct AgentConfig {
        let id: String
        let name: String
        let emoji: String
        let color: Color
        let defaultPosition: NSPoint
    }

    private let agentConfigs: [AgentConfig] = [
        AgentConfig(id: "agent_1", name: "Alex (PM)",         emoji: "🧑‍💼", color: .blue,   defaultPosition: NSPoint(x: 80,  y: 400)),
        AgentConfig(id: "agent_2", name: "Mia (Researcher)",  emoji: "🔬",   color: .purple, defaultPosition: NSPoint(x: 340, y: 400)),
        AgentConfig(id: "agent_3", name: "Leo (Developer)",   emoji: "💻",   color: .green,  defaultPosition: NSPoint(x: 600, y: 400)),
        AgentConfig(id: "agent_4", name: "Zoe (QA)",          emoji: "✅",   color: .orange, defaultPosition: NSPoint(x: 860, y: 400)),
    ]

    private var panels: [String: FloatingPanel] = [:]

    private init() {}

    // MARK: - 에이전트 창 열기
    // count: 띄울 에이전트 수 (1~4)
    func showAgents(count: Int = 1) {
        let toShow = agentConfigs.prefix(count)

        for config in toShow {
            if panels[config.id] != nil { continue }  // 이미 열려있으면 스킵

            let panel = FloatingPanel(agentID: config.id, position: config.defaultPosition)

            // SwiftUI 뷰를 창에 주입
            let view = AgentView(
                agentID: config.id,
                agentName: config.name,
                emoji: config.emoji,
                color: config.color
            )
            let hostingController = NSHostingController(rootView: view)
            panel.contentViewController = hostingController

            panel.orderFront(nil)   // 화면에 표시
            panel.makeKey()         // 포커스 확보

            panels[config.id] = panel
        }
    }

    // MARK: - 특정 에이전트 창 닫기
    func hideAgent(id: String) {
        panels[id]?.close()
        panels.removeValue(forKey: id)
    }

    // MARK: - 모든 창 닫기
    func hideAll() {
        panels.values.forEach { $0.close() }
        panels.removeAll()
    }

    // MARK: - 모든 창 위치 저장
    func saveAllPositions() {
        panels.values.forEach { $0.savePosition() }
    }
}
