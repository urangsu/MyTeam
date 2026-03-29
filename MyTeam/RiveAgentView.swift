import SwiftUI
import RiveRuntime

struct RiveAgentView: View {
    let agentID: String
    let emojiFallback: String
    
    // Rive 파일명이 에이전트 ID와 매칭된다고 가정 (예: agent_1.riv)
    private var rivName: String {
        return agentID
    }
    
    // RiveViewModel 설정
    // stateMachine을 활용하면 'Speaking', 'Idle', 'Thinking' 상태별 애니메이션 전환이 가능합니다.
    @StateObject var riveVM: RiveViewModel
    
    init(agentID: String, emojiFallback: String) {
        self.agentID = agentID
        self.emojiFallback = emojiFallback
        
        // 초기화 시점에 파일 로드 (파일이 없을 경우 대비는 riveVM 내부에서 처리)
        _riveVM = StateObject(wrappedValue: RiveViewModel(fileName: agentID, stateMachineName: "State Machine 1"))
    }
    
    var body: some View {
        ZStack {
            // Rive 애니메이션 뷰
            riveVM.view()
                .frame(width: 80, height: 80)
                // 만약 .riv 파일이 리소스에 없으면 빈 화면이 나옵니다.
            
            // 파일이 없는 경우를 위한 투명도 처리나 조건부 렌더링은 Rive SDK 구조상 복잡하므로,
            // 일단은 ZStack으로 겹쳐두거나 에러 핸들링 로직을 추가할 수 있습니다.
            // 여기서는 단순하게 배경에 이모지를 살짝 띄워두거나 파일 로드 실패를 체크합니다.
            
            if !hasRivFile(name: agentID) {
                Text(emojiFallback)
                    .font(.system(size: 40))
            }
        }
        .onAppear {
            updateAnimationState()
        }
        // 에이전트 상태 변화에 따라 애니메이션 트리거
        .onChange(of: WebSocketClient.shared.agentStatus) { _, _ in
            updateAnimationState()
        }
    }
    
    private func updateAnimationState() {
        let status = WebSocketClient.shared.agentStatus
        let currentSpeaker = WebSocketClient.shared.currentSpeakerID
        
        // 현재 내가 말하는 중인지 확인
        if currentSpeaker == agentID {
            if status == "Speaking" {
                riveVM.setInput("Status", value: 1.0) // 1: Speaking
            } else if status == "Thinking" {
                riveVM.setInput("Status", value: 2.0) // 2: Thinking
            }
        } else {
            riveVM.setInput("Status", value: 0.0) // 0: Idle
        }
    }
    
    // 로컬 리소스에 파일이 있는지 체크하는 간단한 헬퍼
    private func hasRivFile(name: String) -> Bool {
        return Bundle.main.path(forResource: name, ofType: "riv") != nil
    }
}
