import AppKit
import SwiftUI

// MARK: - FloatingPanel
// NSPanel을 서브클래싱하여 투명하고 항상 최상단에 떠있는 창.
// 마우스 이벤트를 직접 처리하여 창 이동 + 드래그 상태를 SwiftUI에 전달합니다.
class FloatingPanel: NSPanel {

    var agentID: String = "team"

    // 드래그 추적용 — 마우스 눌린 시점의 위치 기억
    private var dragStartMouseLocation: NSPoint?

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
        self.isMovableByWindowBackground = true
        
        // 표준 버튼(신호등) 숨기기 - 디자인 통앤매너 유지
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true
        
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        self.acceptsMouseMovedEvents = true

        restorePosition()
    }

    override var canBecomeKey: Bool  { true }
    override var canBecomeMain: Bool { true }
    
    // 화살표 키 등 키보드 이벤트가 다른 UI 컨트롤로 전파되는 것을 차단
    override func keyDown(with event: NSEvent) {
        // 화살표 키는 무시 (테마 토글 방지)
        // 다른 키 이벤트는 정상 전파
    }

    // MARK: - 마우스 이벤트: 드래그로 창 이동

    override func mouseDown(with event: NSEvent) {
        // 드래그 시작점 기록
        dragStartMouseLocation = NSEvent.mouseLocation
        // AgentWindowManager.shared.updateInteractionTime() // TODO: 복원 예정

        // SwiftUI 뷰에 드래그 시작 알림 (팀 창 이동 시에만 에이전트들이 반응하게 함)
        if agentID == "team" {
            NotificationCenter.default.post(name: .agentDragBegan, object: nil)
            
            // 백엔드에 드래그 시작 시스템 이벤트 전송
            let dragStartGreetings = ["앗, 사용자님! 갑자기 왜요?", "으악! 살살 잡아주세요!", "선택받았다!", "출동인가요?"]
            // WebSocketClient.shared.sendSystemEvent(eventType: "drag_start", ...) // TODO: 복원 예정

            // 에이전트별 개인 효과음 재생
            for config in AgentWindowManager.shared.activeAgents {
                SoundPlayer.playDragStart(soundName: config.dragSoundName)
            }
        }
        
        super.mouseDown(with: event)
    }
    
    private var lastDraggingEventTime: Date = .distantPast

    override func mouseDragged(with event: NSEvent) {
        guard let startLocation = dragStartMouseLocation else { return }

        let currentLocation = NSEvent.mouseLocation

        // 마우스 이동량 계산 → 창 위치에 반영
        let deltaX = currentLocation.x - startLocation.x
        let deltaY = currentLocation.y - startLocation.y

        let newOrigin = NSPoint(
            x: self.frame.origin.x + deltaX,
            y: self.frame.origin.y + deltaY
        )
        self.setFrameOrigin(newOrigin)

        // 다음 mouseDragged를 위한 기준점 업데이트
        dragStartMouseLocation = currentLocation

        // 드래그 중인 상태 백엔드 전송 (부하 방지를 위해 3초에 한 번만)
        if Date().timeIntervalSince(lastDraggingEventTime) > 3.0 {
            let draggingGreetings = ["공중에 떴다!", "화면이 다 보여요!", "어디로 가시는 거예요?", "슝~ 날아간다!"]
            // WebSocketClient.shared.sendSystemEvent(eventType: "dragging", ...) // TODO: 복원 예정
            lastDraggingEventTime = Date()
        }

        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        dragStartMouseLocation = nil

        // SwiftUI 뷰에 드래그 종료 알림
        NotificationCenter.default.post(name: .agentDragEnded, object: nil)
        
        // 백엔드에 드롭 시스템 이벤트 전송
        let dropGreetings = ["착지 성공!", "여기가 제 새 자리인가요?", "안전하게 배달 완료!", "도착!"]
        // WebSocketClient.shared.sendSystemEvent(eventType: "drop", ...) // TODO: 복원 예정

        // 에이전트별 개인 착지 효과음 재생
        for config in AgentWindowManager.shared.activeAgents {
            SoundPlayer.playDropEnd(soundName: config.dropSoundName)
        }

        // 현재 위치 저장
        savePosition()

        super.mouseUp(with: event)
    }

    // MARK: - 위치 저장/복원
    func savePosition() {
        // 위치만 저장, 크기는 저장하지 않음 (항상 코드에서 지정한 기본 크기 사용)
        UserDefaults.standard.set(self.frame.origin.x, forKey: "\(agentID)_x")
        UserDefaults.standard.set(self.frame.origin.y, forKey: "\(agentID)_y")
        
        // 기존에 저장된 크기 값을 명시적으로 삭제 (이전 버전 잔류 데이터 제거)
        UserDefaults.standard.removeObject(forKey: "\(agentID)_w")
        UserDefaults.standard.removeObject(forKey: "\(agentID)_h")
    }

    func restorePosition() {
        let x = UserDefaults.standard.double(forKey: "\(agentID)_x")
        let y = UserDefaults.standard.double(forKey: "\(agentID)_y")
        
        // 위치만 복원, 창 크기는 init에서 전달된 기본 크기를 그대로 사용
        if x != 0 || y != 0 {
            self.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}
