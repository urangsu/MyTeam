import AppKit
import SwiftUI

// MARK: - FloatingPanel
// NSPanel을 서브클래싱하여 투명하고 항상 최상단에 떠있는 창을 만듭니다.
class FloatingPanel: NSPanel {

    // 에이전트 식별자 (agent_1, agent_2 ...)
    var agentID: String = "agent_1"

    // MARK: - 초기화
    init(agentID: String, position: NSPoint = NSPoint(x: 100, y: 400)) {
        self.agentID = agentID

        // 창 크기: 캐릭터 한 명 220x280
        let rect = NSRect(origin: position, size: NSSize(width: 220, height: 280))

        super.init(
            contentRect: rect,
            styleMask: [
                .borderless,          // 테두리(크롬) 완전 제거
                .nonactivatingPanel   // 다른 앱 포커스를 빼앗지 않음
            ],
            backing: .buffered,
            defer: false
        )

        // ── 투명 창 핵심 설정 ──
        self.backgroundColor = .clear      // 배경 투명
        self.isOpaque = false              // 불투명 처리 해제
        self.hasShadow = false             // 그림자 제거

        // ── 화면 최상단 고정 ──
        self.level = .floating             // 모든 일반 앱 위에 표시

        // ── 모든 가상 데스크톱(Spaces)에서 유지 ──
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary
        ]

        // ── 마우스 이벤트 수신 가능하도록 설정 ──
        self.isMovableByWindowBackground = false
        self.acceptsMouseMovedEvents = true

        // 저장된 위치 복원 (UserDefaults)
        restorePosition()
    }

    // 포커스를 받을 수 있도록 오버라이드
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    // MARK: - 위치 저장/복원
    func savePosition() {
        let origin = self.frame.origin
        UserDefaults.standard.set(origin.x, forKey: "\(agentID)_x")
        UserDefaults.standard.set(origin.y, forKey: "\(agentID)_y")
    }

    func restorePosition() {
        let x = UserDefaults.standard.double(forKey: "\(agentID)_x")
        let y = UserDefaults.standard.double(forKey: "\(agentID)_y")
        if x != 0 || y != 0 {
            self.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}
