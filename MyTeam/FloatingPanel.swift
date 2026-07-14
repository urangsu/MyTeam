import AppKit
import SwiftUI

enum PanelTuckEdge: String, Codable, CaseIterable, Sendable {
    case left
    case right
    case top
    case bottom

    var menuTitle: String {
        switch self {
        case .left: return "왼쪽에 숨기기"
        case .right: return "오른쪽에 숨기기"
        case .top: return "상단에 숨기기"
        case .bottom: return "Dock 위에 숨기기"
        }
    }
}

enum PanelTuckState: Equatable, Sendable {
    case expanded
    case minimizedBar
    case tucked(PanelTuckEdge)

    var tuckedEdge: PanelTuckEdge? {
        if case .tucked(let edge) = self { return edge }
        return nil
    }
}

enum PanelTuckGeometry {
    nonisolated static let snapThreshold: CGFloat = 32
    nonisolated static let revealThickness: CGFloat = 22
    nonisolated static let allowedPanelIDs: Set<String> = [
        "swap_window"
    ]

    nonisolated static func isTuckAllowed(agentID: String) -> Bool {
        agentID != "team" && allowedPanelIDs.contains(agentID)
    }

    nonisolated static func nearestTuckEdge(
        frame: NSRect,
        visibleFrame: NSRect,
        threshold: CGFloat = snapThreshold
    ) -> PanelTuckEdge? {
        let distances: [(PanelTuckEdge, CGFloat)] = [
            (.left, max(0, frame.minX - visibleFrame.minX)),
            (.right, max(0, visibleFrame.maxX - frame.maxX)),
            (.top, max(0, visibleFrame.maxY - frame.maxY)),
            (.bottom, max(0, frame.minY - visibleFrame.minY))
        ]
        guard let nearest = distances.min(by: { $0.1 < $1.1 }), nearest.1 <= threshold else {
            return nil
        }
        return nearest.0
    }

    nonisolated static func tuckedFrame(
        for frame: NSRect,
        edge: PanelTuckEdge,
        visibleFrame: NSRect,
        revealThickness: CGFloat = revealThickness
    ) -> NSRect {
        var next = clampedExpandedFrame(frame, visibleFrame: visibleFrame)
        switch edge {
        case .left:
            next.origin.x = visibleFrame.minX - next.width + revealThickness
        case .right:
            next.origin.x = visibleFrame.maxX - revealThickness
        case .top:
            next.origin.y = visibleFrame.maxY - revealThickness
        case .bottom:
            next.origin.y = visibleFrame.minY - next.height + revealThickness
        }
        return next
    }

    nonisolated static func clampedExpandedFrame(_ frame: NSRect, visibleFrame: NSRect) -> NSRect {
        var next = frame
        next.origin.x = min(max(next.origin.x, visibleFrame.minX + 8), visibleFrame.maxX - min(next.width, visibleFrame.width) - 8)
        next.origin.y = min(max(next.origin.y, visibleFrame.minY + 8), visibleFrame.maxY - min(next.height, visibleFrame.height) - 8)
        return next
    }
}

// MARK: - FloatingPanel
// NSPanel을 서브클래싱하여 투명하고 항상 최상단에 떠있는 창.
// 마우스 이벤트를 직접 처리하여 창 이동 + 드래그 상태를 SwiftUI에 전달합니다.
class FloatingPanel: NSPanel {

    var agentID: String = "team"
    private(set) var tuckState: PanelTuckState = .expanded
    private var expandedFrameBeforeTuck: NSRect?

    // 드래그 추적용 — 마우스 눌린 시점의 위치 기억
    private var dragStartMouseLocation: NSPoint?
    private var didBeginWindowDrag = false

    // MARK: - 초기화
    init(agentID: String, position: NSPoint = NSPoint(x: 100, y: 200), size: NSSize = NSSize(width: 880, height: 260)) {
        self.agentID = agentID

        let rect = NSRect(origin: position, size: size)

        super.init(
            contentRect: rect,
            styleMask: [
                .titled,              // .borderless 대신 .titled 사용 (크기 조절 원활하게)
                .fullSizeContentView, // 컨텐트 뷰가 타이틀바 영역까지 확장
                .resizable,           // 사용자 크기 조절 활성화
                .nonactivatingPanel
            ],
            backing: .buffered,
            defer: false
        )

        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = allowsBackgroundDragging

        // 표준 버튼(신호등) 숨기기 - 디자인 통앤매너 유지 (개별 X버튼이 이미 존재함)
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true

        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isRestorable = false
        self.identifier = NSUserInterfaceItemIdentifier("MyTeam.\(agentID)")

        self.acceptsMouseMovedEvents = true

        restorePosition()
        restoreSizeIfAvailable(defaultSize: size)
        if PanelTuckGeometry.isTuckAllowed(agentID: agentID) {
            restoreTuckStateIfAvailable()
        } else {
            clearPersistedTuckState()
        }
    }

    override var canBecomeKey: Bool  { true }
    override var canBecomeMain: Bool { true }

    // TextEditor, TextField, 버튼 단축키가 정상 동작하도록 AppKit responder chain에 전달한다.
    override func keyDown(with event: NSEvent) {
        super.keyDown(with: event)
    }

    // MARK: - 마우스 이벤트: 드래그로 창 이동

    override func mouseDown(with event: NSEvent) {
        if tuckState.tuckedEdge != nil {
            restoreFromTuck()
            return
        }

        guard allowsBackgroundDragging else {
            AgentWindowManager.shared.updateInteractionTime()
            super.mouseDown(with: event)
            return
        }

        // 클릭 위치가 NSScrollView 내부면 창 드래그 시작 안 함
        let pointInContent = contentView?.convert(event.locationInWindow, from: nil) ?? .zero
        var hitView: NSView? = contentView?.hitTest(pointInContent)
        var insideScroll = false
        while let v = hitView {
            if v is NSScrollView { insideScroll = true; break }
            hitView = v.superview
        }
        if !insideScroll {
            dragStartMouseLocation = NSEvent.mouseLocation
            didBeginWindowDrag = false
        }
        AgentWindowManager.shared.updateInteractionTime()

        super.mouseDown(with: event)
    }

    private var lastDraggingEventTime: Date = .distantPast

    override func mouseDragged(with event: NSEvent) {
        guard allowsBackgroundDragging else {
            super.mouseDragged(with: event)
            return
        }
        guard let startLocation = dragStartMouseLocation else { return }

        if !didBeginWindowDrag {
            didBeginWindowDrag = true
            if agentID == "team" {
                for config in AgentWindowManager.shared.activeAgents {
                    SoundPlayer.playDragStart(soundName: config.dragSoundName)
                }
            }
        }

        let currentLocation = NSEvent.mouseLocation
        let deltaX = currentLocation.x - startLocation.x
        let deltaY = currentLocation.y - startLocation.y

        let newOrigin = NSPoint(
            x: self.frame.origin.x + deltaX,
            y: self.frame.origin.y + deltaY
        )
        self.setFrameOrigin(newOrigin)
        dragStartMouseLocation = currentLocation

        if Date().timeIntervalSince(lastDraggingEventTime) > 3.0 {
            lastDraggingEventTime = Date()
        }

    }

    override func mouseUp(with event: NSEvent) {
        dragStartMouseLocation = nil
        let completedWindowDrag = didBeginWindowDrag
        didBeginWindowDrag = false

        if agentID == "team", completedWindowDrag {
            NotificationCenter.default.post(name: .agentDragEnded, object: nil)

            for config in AgentWindowManager.shared.activeAgents {
                SoundPlayer.playDropEnd(soundName: config.dropSoundName)
            }
        }

        if !snapToEdgeIfNeeded() {
            savePosition()
        }
        super.mouseUp(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        guard PanelTuckGeometry.isTuckAllowed(agentID: agentID) else {
            super.rightMouseDown(with: event)
            return
        }
        let menu = NSMenu()
        for edge in PanelTuckEdge.allCases {
            let item = NSMenuItem(title: edge.menuTitle, action: #selector(tuckMenuItemSelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = edge.rawValue
            menu.addItem(item)
        }
        if tuckState.tuckedEdge != nil {
            menu.addItem(.separator())
            let restore = NSMenuItem(title: "원래 위치로", action: #selector(restoreMenuItemSelected), keyEquivalent: "")
            restore.target = self
            menu.addItem(restore)
        }
        guard let menuView = contentView else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: menuView)
    }

    @objc private func tuckMenuItemSelected(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let edge = PanelTuckEdge(rawValue: raw) else { return }
        tuck(to: edge)
    }

    @objc private func restoreMenuItemSelected() {
        restoreFromTuck()
    }

    // MARK: - 위치 저장/복원
    func savePosition() {
        let frameToPersist = expandedFrameBeforeTuck ?? self.frame
        UserDefaults.standard.set(frameToPersist.origin.x, forKey: "\(agentID)_x")
        UserDefaults.standard.set(frameToPersist.origin.y, forKey: "\(agentID)_y")
        if persistencePolicy.persistSize {
            UserDefaults.standard.set(frameToPersist.size.width, forKey: "\(agentID)_w")
            UserDefaults.standard.set(frameToPersist.size.height, forKey: "\(agentID)_h")
        } else {
            UserDefaults.standard.removeObject(forKey: "\(agentID)_w")
            UserDefaults.standard.removeObject(forKey: "\(agentID)_h")
        }
    }

    func restorePosition() {
        let x = UserDefaults.standard.double(forKey: "\(agentID)_x")
        let y = UserDefaults.standard.double(forKey: "\(agentID)_y")
        if x != 0 || y != 0 {
            self.setFrameOrigin(NSPoint(x: x, y: y))
        }
        keepInsideVisibleScreen()
    }

    func tuck(to edge: PanelTuckEdge) {
        guard PanelTuckGeometry.isTuckAllowed(agentID: agentID),
              let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(frame) }) ?? NSScreen.main else {
            return
        }
        if tuckState.tuckedEdge == nil {
            expandedFrameBeforeTuck = frame
        }
        let hidden = PanelTuckGeometry.tuckedFrame(for: expandedFrameBeforeTuck ?? frame, edge: edge, visibleFrame: screen.visibleFrame)
        tuckState = .tucked(edge)
        persistTuckState(edge: edge)
        setFrame(hidden, display: true, animate: true)
    }

    func restoreFromTuck() {
        guard let edge = tuckState.tuckedEdge else { return }
        let restored = expandedFrameBeforeTuck ?? restoreExpandedFrameFromDefaults() ?? frame
        let visible = NSScreen.screens.first(where: { $0.visibleFrame.intersects(restored) })?.visibleFrame ?? NSScreen.main?.visibleFrame
        let finalFrame = visible.map { PanelTuckGeometry.clampedExpandedFrame(restored, visibleFrame: $0) } ?? restored
        tuckState = .expanded
        expandedFrameBeforeTuck = nil
        UserDefaults.standard.removeObject(forKey: "\(agentID)_tuckEdge")
        setFrame(finalFrame, display: true, animate: true)
        savePosition()
        AppLog.debug("[FloatingPanel] restored from \(edge.rawValue) edge id=\(agentID)")
    }

    private var persistencePolicy: PersistencePolicy {
        switch agentID {
        case "team", "swap_window", "agent_settings_window":
            return PersistencePolicy(persistSize: false)
        case "status_window":
            return PersistencePolicy(persistSize: true)
        default:
            if agentID.hasPrefix("chat_") {
                return PersistencePolicy(persistSize: true)
            }
            return PersistencePolicy(persistSize: false)
        }
    }

    private var allowsBackgroundDragging: Bool {
        switch agentID {
        case "status_window", "chat_single":
            return false
        default:
            return true
        }
    }

    private func restoreSizeIfAvailable(defaultSize: NSSize) {
        guard persistencePolicy.persistSize else { return }
        let width = UserDefaults.standard.double(forKey: "\(agentID)_w")
        let height = UserDefaults.standard.double(forKey: "\(agentID)_h")
        guard width >= max(240, minSize.width), height >= max(40, minSize.height) else { return }
        var frame = self.frame
        frame.size = NSSize(
            width: max(width, minSize.width == 0 ? defaultSize.width : minSize.width),
            height: max(height, minSize.height == 0 ? defaultSize.height : minSize.height)
        )
        self.setFrame(frame, display: false)
        keepInsideVisibleScreen()
    }

    private func keepInsideVisibleScreen() {
        var frame = self.frame
        guard let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(frame) }) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        frame = PanelTuckGeometry.clampedExpandedFrame(frame, visibleFrame: visible)
        self.setFrameOrigin(frame.origin)
    }

    private func snapToEdgeIfNeeded() -> Bool {
        guard PanelTuckGeometry.isTuckAllowed(agentID: agentID),
              tuckState.tuckedEdge == nil,
              let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(frame) }) ?? NSScreen.main,
              let edge = PanelTuckGeometry.nearestTuckEdge(frame: frame, visibleFrame: screen.visibleFrame) else {
            return false
        }
        tuck(to: edge)
        return true
    }

    private func persistTuckState(edge: PanelTuckEdge) {
        let expanded = expandedFrameBeforeTuck ?? frame
        UserDefaults.standard.set(edge.rawValue, forKey: "\(agentID)_tuckEdge")
        UserDefaults.standard.set(expanded.origin.x, forKey: "\(agentID)_expanded_x")
        UserDefaults.standard.set(expanded.origin.y, forKey: "\(agentID)_expanded_y")
        UserDefaults.standard.set(expanded.size.width, forKey: "\(agentID)_expanded_w")
        UserDefaults.standard.set(expanded.size.height, forKey: "\(agentID)_expanded_h")
    }

    private func clearPersistedTuckState() {
        UserDefaults.standard.removeObject(forKey: "\(agentID)_tuckEdge")
        UserDefaults.standard.removeObject(forKey: "\(agentID)_expanded_x")
        UserDefaults.standard.removeObject(forKey: "\(agentID)_expanded_y")
        UserDefaults.standard.removeObject(forKey: "\(agentID)_expanded_w")
        UserDefaults.standard.removeObject(forKey: "\(agentID)_expanded_h")
    }

    private func restoreTuckStateIfAvailable() {
        guard PanelTuckGeometry.isTuckAllowed(agentID: agentID),
              let raw = UserDefaults.standard.string(forKey: "\(agentID)_tuckEdge"),
              let edge = PanelTuckEdge(rawValue: raw),
              let screen = NSScreen.main else { return }
        expandedFrameBeforeTuck = restoreExpandedFrameFromDefaults() ?? frame
        tuckState = .tucked(edge)
        let hidden = PanelTuckGeometry.tuckedFrame(for: expandedFrameBeforeTuck ?? frame, edge: edge, visibleFrame: screen.visibleFrame)
        setFrame(hidden, display: false)
    }

    private func restoreExpandedFrameFromDefaults() -> NSRect? {
        let width = UserDefaults.standard.double(forKey: "\(agentID)_expanded_w")
        let height = UserDefaults.standard.double(forKey: "\(agentID)_expanded_h")
        guard width > 0, height > 0 else { return nil }
        return NSRect(
            x: UserDefaults.standard.double(forKey: "\(agentID)_expanded_x"),
            y: UserDefaults.standard.double(forKey: "\(agentID)_expanded_y"),
            width: width,
            height: height
        )
    }

}

private struct PersistencePolicy {
    let persistSize: Bool
}

// MARK: - WindowDragBlocker
// 스크롤 영역 위에서 마우스 드래그가 창 이동으로 이어지는 것을 차단.
// .background(WindowDragBlocker())를 ScrollView에 부착하면 됨.
// trackpad 두 손가락 스크롤(scrollWheel)은 차단하지 않으므로 정상 스크롤 가능.
struct WindowDragBlocker: NSViewRepresentable {
    func makeNSView(context: Context) -> BlockerView { BlockerView() }
    func updateNSView(_ nsView: BlockerView, context: Context) {}

    class BlockerView: NSView {
        override func mouseDown(with event: NSEvent) {
            // super 호출 안 함 → isMovableByWindowBackground 창이동 트리거 차단
        }
        override func mouseDragged(with event: NSEvent) {
            // 흡수 — 창이동 없음
        }
    }
}

// MARK: - WindowDragHandle
// Background dragging stays disabled for complex panels. A dedicated header
// handle moves only the window origin so controls, layout, and scroll views
// never compete with window movement.
struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> DragView { DragView() }
    func updateNSView(_ nsView: DragView, context: Context) {}

    final class DragView: NSView {
        private var mouseDownLocation: NSPoint?
        private var windowOriginAtMouseDown: NSPoint?

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            mouseDownLocation = NSEvent.mouseLocation
            windowOriginAtMouseDown = window?.frame.origin
        }

        override func mouseDragged(with event: NSEvent) {
            guard let window, let mouseDownLocation, let windowOriginAtMouseDown else { return }
            let current = NSEvent.mouseLocation
            window.setFrameOrigin(NSPoint(
                x: windowOriginAtMouseDown.x + current.x - mouseDownLocation.x,
                y: windowOriginAtMouseDown.y + current.y - mouseDownLocation.y
            ))
        }

        override func mouseUp(with event: NSEvent) {
            mouseDownLocation = nil
            windowOriginAtMouseDown = nil
            (window as? FloatingPanel)?.savePosition()
        }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .openHand)
        }
    }
}
