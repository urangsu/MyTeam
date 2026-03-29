import SwiftUI
import SpriteKit

// MARK: - SpriteAgentView
// SpriteKit 씬을 SwiftUI 뷰로 감싸는 래퍼입니다.
// AgentSeatView에서 이모지 대신 이 뷰를 사용합니다.
//
// 사용 예시:
//   SpriteAgentView(
//       characterID: "sloth",
//       fallbackEmoji: "🦥",
//       state: .idle
//   )
//   .frame(width: 100, height: 120)
struct SpriteAgentView: View {

    let characterID: String         // Assets 파일명 접두사 (예: "sloth", "dog")
    let fallbackImageName: String   // 스프라이트 없을 때 표시할 얼굴 이미지명
    let state: AnimationState       // 현재 재생할 애니메이션 상태

    // SpriteKit 씬은 한 번 생성되고 재사용됩니다.
    // @StateObject 대신 직접 인스턴스를 들고 있습니다.
    // (SpriteKit은 SwiftUI의 생명주기와 분리되어 관리됩니다)
    @State private var scene: CharacterSpriteScene = CharacterSpriteScene()

    var body: some View {
        GeometryReader { geo in
            // SpriteView: SwiftUI 안에서 SpriteKit을 표시하는 공식 방법
            // options: .allowsTransparency → 배경 투명 처리
            SpriteView(
                scene: scene,
                options: [.allowsTransparency]
            )
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear {
            setupScene()
        }
        // state 값이 변경될 때마다 씬에 새 상태를 전달합니다.
        .onChange(of: state) { _, newState in
            scene.loadAndPlay(state: newState)
        }
    }

    // MARK: - 씬 초기화
    private func setupScene() {
        // 캐릭터 ID와 폴백 이미지 설정
        scene.characterID = characterID
        scene.fallbackImageName = fallbackImageName

        // 씬 크기: SpriteView 프레임과 동일하게 맞춥니다
        // (나중에 fitCharacterToScene()에서 캐릭터 크기 조절)
        scene.size = CGSize(width: 100, height: 140)

        // 배경 투명
        scene.backgroundColor = .clear

        // 초기 상태 재생
        scene.loadAndPlay(state: state)
    }
}

// MARK: - SpriteAgentView (Preview)
#if DEBUG
struct SpriteAgentView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("SpriteKit 캐릭터 뷰 테스트")
                .font(.headline)

            // 스프라이트가 있을 때
            SpriteAgentView(
                characterID: "치코",
                fallbackImageName: "치코_profile",
                state: .idle
            )
            .frame(width: 100, height: 140)
            .border(Color.gray.opacity(0.3))

            // 스프라이트가 없을 때 (이미지 폴백)
            SpriteAgentView(
                characterID: "dog",
                fallbackImageName: "dog_profile",
                state: .idle
            )
            .frame(width: 100, height: 140)
            .border(Color.gray.opacity(0.3))
        }
        .padding()
        .background(Color.black)
    }
}
#endif

// MARK: - CharacterAnimationController
// AgentSeatView와 WebSocketClient 상태를 연결해주는 어댑터입니다.
// WebSocket에서 받은 이벤트 → AnimationState로 변환합니다.
struct CharacterAnimationController: View {
    let characterID: String
    let fallbackImageName: String
    let agentID: String

    // WebSocket에서 실시간으로 받아오는 값들
    let isSpeaking: Bool
    let isThinking: Bool
    let isDragging: Bool

    // 현재 재생할 애니메이션 상태
    @State private var currentAnimState: AnimationState = .idle
    // 드래그 상태 이전값 (변화 감지용)
    @State private var wasDragging: Bool = false

    var body: some View {
        SpriteAgentView(
            characterID: characterID,
            fallbackImageName: fallbackImageName,
            state: currentAnimState
        )
        // 상태 변화를 감지하여 AnimationState 업데이트
        .onChange(of: isSpeaking) { _, speaking in
            updateState(speaking: speaking, thinking: isThinking, dragging: isDragging)
        }
        .onChange(of: isThinking) { _, thinking in
            updateState(speaking: isSpeaking, thinking: thinking, dragging: isDragging)
        }
        .onChange(of: isDragging) { _, dragging in
            updateState(speaking: isSpeaking, thinking: isThinking, dragging: dragging)
        }
        .onAppear {
            updateState(speaking: isSpeaking, thinking: isThinking, dragging: isDragging)
        }
        // 시스템 이벤트 (클릭, 감정 반응 등) 수신
        .onReceive(NotificationCenter.default.publisher(for: .characterEmote)) { notification in
            guard let info = notification.userInfo,
                  let targetID = info["agentID"] as? String,
                  let emoteName = info["emote"] as? String,
                  targetID == agentID else { return }

            if let state = AnimationState(rawValue: emoteName) {
                currentAnimState = state
            }
        }
    }

    // ── 우선순위 로직 ──────────────────────────────────────
    // 드래그 > 생각 중 > 말하는 중 > 대기 순서로 우선순위 적용
    private func updateState(speaking: Bool, thinking: Bool, dragging: Bool) {
        if dragging && !wasDragging {
            currentAnimState = .drag
            wasDragging = true
        } else if !dragging && wasDragging {
            currentAnimState = .landing
            wasDragging = false
        } else if thinking {
            currentAnimState = .thinking
        } else if speaking {
            currentAnimState = .speaking
        } else {
            currentAnimState = .idle
        }
    }
}
