import SpriteKit
import SwiftUI

// MARK: - AnimationState
// 캐릭터가 취할 수 있는 모든 상태를 정의합니다.
// 각 상태마다 PNG 시퀀스 파일들이 Assets에 등록되어 있어야 합니다.
// 파일명 규칙: "{캐릭터ID}_{상태명}_{번호}.png"
// 예시: sloth_idle_001.png, sloth_joy_001.png
enum AnimationState: String {
    case idle             = "idle"              // 대기 중 (기본 상태)
    case speaking         = "speaking"          // 말하는 중
    case thinking         = "thinking"          // 생각 중
    case joy              = "joy"               // 기쁨
    case sad              = "sad"               // 슬픔
    case drag             = "drag"              // 드래그 중
    case landing          = "landing"           // 착지 및 안도
    case greeting         = "greeting"          // 인사
    case praise           = "praise"            // 칭찬
    case lookLeft         = "look_left"         // 왼쪽 보기
    case lookRight        = "look_right"        // 오른쪽 보기
    case agree            = "agree"             // 긍정 대답
    case disagree         = "disagree"          // 부정 대답
    case angry            = "angry"             // 분노
    case sleeping         = "sleeping"          // 졸기/수면
    case look             = "look"              // 두리번
    case lifted           = "lifted"            // 들려짐
    case dropped          = "dropped"           // 떨어짐
    case backToWork       = "back_to_work"      // 업무 복귀
    case loopReturn       = "loop_return"       // 루프 복귀
    case typing           = "typing"            // 업무 중 (타이핑)
    case clockOut         = "clock_out"         // 퇴근
    case resting          = "resting"           // 휴식/대기
    case clockIn          = "clock_in"          // 출근
    case returnToTyping   = "return_to_typing"  // 타자 복귀
    case confused         = "confused"          // 혼란
}

// MARK: - CharacterSpriteScene
// SpriteKit 씬. 캐릭터 1명을 표시하고 애니메이션 상태를 관리합니다.
// SwiftUI에서는 SpriteView(scene:)으로 삽입됩니다.
class CharacterSpriteScene: SKScene {

    // ── 공개 설정값 ───────────────────────────────────────
    var characterID: String = "sloth"          // 캐릭터 식별자 (에셋 파일명 접두사)
    var fallbackEmoji: String = "🦥"           // 스프라이트 없을 때 대체 이모지

    // ── 내부 노드 ─────────────────────────────────────────
    private var characterNode: SKSpriteNode!   // 캐릭터 이미지를 담는 노드
    private var emojiNode: SKLabelNode?        // 폴백 이모지 노드

    // ── 상태 관리 ─────────────────────────────────────────
    private(set) var currentState: AnimationState = .idle
    private var isAnimationLoaded: Bool = false

    // ── 애니메이션 설정 ──────────────────────────────────
    // timePerFrame: 한 프레임이 표시되는 시간(초). 12fps → 1/12 ≈ 0.083초
    private let defaultFPS: Double = 12.0

    // 상태별 반복 설정
    // true = 계속 반복 (idle, speaking, thinking)
    // false = 1회 재생 후 idle로 복귀 (joy, sad, landing, greeting 등)
    private let loopingStates: Set<AnimationState> = [
        .idle, .speaking, .thinking, .sleeping,
        .typing,    // 업무 중 — 타이핑 루프
        .resting    // 휴식/대기 — 쉬는 루프
    ]

    // MARK: - Scene 초기화
    override func didMove(to view: SKView) {
        // 씬 배경 완전 투명 (NSPanel 투명 처리와 연동)
        backgroundColor = .clear
        scaleMode = .aspectFit

        setupCharacterNode()
        loadAndPlay(state: .idle)
    }

    // MARK: - 노드 셋업
    private func setupCharacterNode() {
        // 캐릭터 노드 생성 (초기 텍스처는 idle 첫 프레임으로 설정)
        let placeholder = SKTexture(imageNamed: "\(characterID)_idle_001")
        characterNode = SKSpriteNode(texture: placeholder)

        // 씬 정중앙 하단에 배치 (캐릭터가 책상에 앉은 느낌)
        characterNode.position = CGPoint(x: 0, y: 0)
        characterNode.anchorPoint = CGPoint(x: 0.5, y: 0.0) // 하단 중앙 기준점

        addChild(characterNode)

        // 이미지가 없을 경우를 위한 이모지 폴백 노드
        let label = SKLabelNode(text: fallbackEmoji)
        label.fontSize = 60
        label.position = CGPoint(x: 0, y: 10)
        label.verticalAlignmentMode = .bottom
        label.name = "emojiNode"
        emojiNode = label
    }

    // MARK: - 애니메이션 로드 & 재생
    /// 특정 상태의 PNG 시퀀스를 Assets에서 읽어 SKAction으로 재생합니다.
    /// - Parameters:
    ///   - state: 재생할 AnimationState
    ///   - fps: 초당 프레임 수 (기본값 12)
    func loadAndPlay(state: AnimationState, fps: Double? = nil) {
        // didMove(to:) 이전에 호출되면 characterNode가 nil → 무시
        guard characterNode != nil else { return }

        let actualFPS = fps ?? defaultFPS
        let timePerFrame = 1.0 / actualFPS

        // Assets에서 해당 상태의 텍스처 배열 로드
        let textures = loadTextures(for: state)

        if textures.isEmpty {
            // 해당 상태의 스프라이트가 없으면 이모지로 폴백
            showEmojiFallback()
            return
        }

        // 스프라이트가 있으면 이모지 숨기기
        hideEmojiFallback()
        currentState = state
        isAnimationLoaded = true

        // 현재 실행 중인 액션 제거
        characterNode.removeAllActions()

        // 애니메이션 액션 생성
        // SKAction.animate: 텍스처 배열을 순서대로 교체하며 재생
        let animateAction = SKAction.animate(
            with: textures,
            timePerFrame: timePerFrame,
            resize: true,      // 프레임마다 크기가 다를 경우 자동 조절
            restore: true      // 애니메이션 끝나면 원래 텍스처로 복원
        )

        if loopingStates.contains(state) {
            // 반복 재생 (idle, speaking 등)
            let loopAction = SKAction.repeatForever(animateAction)
            characterNode.run(loopAction, withKey: "animation")
        } else {
            // 1회 재생 후 idle로 돌아가기
            let sequence = SKAction.sequence([
                animateAction,
                SKAction.run { [weak self] in
                    // 메인 스레드에서 idle 복귀
                    DispatchQueue.main.async {
                        self?.loadAndPlay(state: .idle)
                    }
                }
            ])
            characterNode.run(sequence, withKey: "animation")
        }
    }

    // MARK: - 텍스처 로드 헬퍼
    /// Assets에서 "{characterID}_{state}_{001~}" 패턴의 이미지를 순서대로 로드합니다.
    /// 최대 60프레임까지 탐색 (없는 번호에서 탐색 중단)
    private func loadTextures(for state: AnimationState) -> [SKTexture] {
        var textures: [SKTexture] = []
        // 서브디렉토리 우선 탐색: Resources/Sprites/{characterID}/
        let subdir = "Sprites/\(characterID)"

        for i in 1...60 {
            let imageName = String(format: "%@_%@_%03d", characterID, state.rawValue, i)
            let exists = Bundle.main.path(forResource: imageName, ofType: "png", inDirectory: subdir) != nil
                      || Bundle.main.path(forResource: imageName, ofType: "png") != nil
                      || UIImageOrNSImageExists(named: imageName)
            if exists {
                textures.append(SKTexture(imageNamed: imageName))
            } else {
                break // 연속이 끊기면 탐색 종료
            }
        }

        return textures
    }

    /// Assets 또는 번들에서 이미지 존재 여부를 확인합니다.
    private func UIImageOrNSImageExists(named name: String) -> Bool {
        // macOS에서는 NSImage 사용
        return NSImage(named: name) != nil
    }

    // MARK: - 폴백 이모지 표시/숨기기
    private func showEmojiFallback() {
        guard let emoji = emojiNode else { return }
        if emoji.parent == nil {
            addChild(emoji)
        }
        characterNode.isHidden = true
        emoji.isHidden = false
    }

    private func hideEmojiFallback() {
        emojiNode?.isHidden = true
        characterNode.isHidden = false
    }

    // MARK: - 드래그 인터랙션 (흔들림 효과)
    /// 드래그 시작 시 호출: 흔들리는 애니메이션 재생
    func startDragging() {
        loadAndPlay(state: .drag)
        // 약간 흔들리는 물리적 효과 추가
        let wobble = SKAction.sequence([
            SKAction.rotate(byAngle: 0.1, duration: 0.08),
            SKAction.rotate(byAngle: -0.2, duration: 0.16),
            SKAction.rotate(byAngle: 0.1, duration: 0.08)
        ])
        let wobbleForever = SKAction.repeatForever(wobble)
        characterNode.run(wobbleForever, withKey: "wobble")
    }

    /// 드래그 종료 시 호출: 착지 애니메이션 재생
    func stopDragging() {
        characterNode.removeAction(forKey: "wobble")
        // 회전 각도 원래대로 복귀
        characterNode.run(SKAction.rotate(toAngle: 0, duration: 0.2, shortestUnitArc: true))
        loadAndPlay(state: .landing)
    }

    // MARK: - 크기 조절
    /// 캐릭터를 씬 크기에 맞게 자동 스케일링합니다.
    func fitCharacterToScene() {
        guard !characterNode.isHidden,
              characterNode.size.width > 0 else { return }

        let sceneWidth = size.width
        let sceneHeight = size.height
        let nodeWidth = characterNode.size.width
        let nodeHeight = characterNode.size.height

        // 가로/세로 중 작은 쪽을 기준으로 스케일 계산
        let scaleX = sceneWidth / nodeWidth
        let scaleY = sceneHeight / nodeHeight
        let scale = min(scaleX, scaleY) * 0.9 // 90%로 여백 확보

        characterNode.setScale(scale)
    }
}
