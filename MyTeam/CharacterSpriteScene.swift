import SpriteKit
import SwiftUI

// MARK: - AnimationState
// 캐릭터가 취할 수 있는 모든 상태를 정의합니다.
// 파일명 규칙: "{캐릭터ID}_{rawValue}_{번호}.png"
//
// ── 최종 확정 모션 (실제 파일 존재) ─────────────────────────
//   idle, typing, speaking, joy, sad, agree, greeting,
//   lifted, dropped(→lowering), landing, backToWork,
//   resting, clockIn, confused, drag, idleLoop, returnToTyping
//
// ── 폴백 처리 모션 (파일 없음 → 대체 재생) ───────────────────
//   thinking   → idle       (생각중 = 대기로 표현)
//   praise     → agree      (칭찬 = 긍정대답으로 흡수)
//   sleeping   → resting    (수면 = 휴식으로 통합)
//   clockOut   → resting    (퇴근 = 휴식 진입으로 흡수)
//   disagree   → angry      (부정대답 = 화남 스프라이트 활용)
//   lookLeft   → look       (왼쪽보기 = 두리번으로)
//   lookRight  → look       (오른쪽보기 = 두리번으로)
//   look       → idle       (두리번 파일 없으면 대기로)
enum AnimationState: String, CaseIterable {

    // ── 핵심 루프 모션 ────────────────────────────────────────
    case idle             = "idle"           // 대기 (앉아있는 앵커)
    case typing           = "typing"         // 업무 중 ★ 기본 상태
    case idleLoop         = "idle_loop"      // 아이들 루프 (있으면 사용)
    case speaking         = "speaking"       // 말하는 중
    case resting          = "resting"        // 휴식 (노트북 닫힘, 수면 통합)

    // ── 감정/반응 모션 ────────────────────────────────────────
    case joy              = "joy"            // 기쁨 (어깨 으쓱)
    case sad              = "sad"            // 슬픔 (눈물 맺힘)
    case agree            = "agree"          // 긍정대답 + 칭찬 흡수
    case angry            = "angry"          // 화남 → disagree 폴백 소스
    case confused         = "confused"       // 갸우뚱 ★ (disagree 대체)

    // ── 인터랙션 모션 ─────────────────────────────────────────
    case greeting         = "greeting"       // 인사 (목례)
    case drag             = "drag"           // 드래그 중
    case lifted           = "lifted"         // 들려짐
    case dropped          = "drop"           // 떨어짐 (구 파일명 유지)
    case lowering         = "lowering"       // 내려감 (신규 파일명, drop 대체)
    case landing          = "landing"        // 착지

    // ── 업무 흐름 모션 ────────────────────────────────────────
    case clockIn          = "clockin"        // 출근 (노트북 열기)
    case clockOut         = "clockout"       // 퇴근 → resting 폴백
    case backToWork       = "backwork"       // 업무 복귀
    case returnToTyping   = "typing_return"  // 타자 복귀

    // ── 폴백 전용 케이스 (파일 없음, 코드 호환용) ─────────────
    case thinking         = "thinking"       // → idle 폴백
    case praise           = "praise"         // → agree 폴백
    case sleeping         = "sleeping"       // → resting 폴백
    case disagree         = "disagree"       // → angry 폴백
    case look             = "look"           // → idle 폴백
    case lookLeft         = "look_left"      // → look → idle 폴백
    case lookRight        = "look_right"     // → look → idle 폴백
}

// MARK: - CharacterSpriteScene
class CharacterSpriteScene: SKScene {

    // ── 공개 설정값 ───────────────────────────────────────────
    var characterID: String = "sloth"
    var fallbackImageName: String = ""        // 스프라이트 없을 때 표시할 얼굴 이미지

    // ── 내부 노드 ─────────────────────────────────────────────
    private var characterNode: SKSpriteNode!
    private var fallbackImageNode: SKSpriteNode?

    // ── 상태 관리 ─────────────────────────────────────────────
    private(set) var currentState: AnimationState = .typing
    private var isAnimationLoaded: Bool = false

    // ── 애니메이션 설정 ────────────────────────────────────────
    private let defaultFPS: Double = 12.0

    // ── 루프 재생할 상태 목록 ─────────────────────────────────
    private let loopingStates: Set<AnimationState> = [
        .idle,          // 대기 앵커 루프
        .typing,        // 업무 중 ★ 기본 루프
        .idleLoop,      // 아이들 루프
        .speaking,      // 말하는 중 루프
        .resting,       // 휴식 루프
        .sleeping,      // sleeping → resting으로 폴백되지만 루프로 등록
        .drag,          // 드래그 상태
    ]

    // ── 폴백 매핑: 파일 없는 상태 → 대체 상태 ──────────────────
    // 이미지 파일이 없을 때 자동으로 대체 모션을 재생합니다.
    private let fallbackStates: [AnimationState: AnimationState] = [
        .thinking   : .idle,       // 생각중 → 대기
        .praise     : .agree,      // 칭찬 → 긍정대답
        .sleeping   : .resting,    // 수면 → 휴식
        .clockOut   : .resting,    // 퇴근 → 휴식 진입
        .disagree   : .angry,      // 부정대답 → 화남 스프라이트
        .lookLeft   : .look,       // 왼쪽보기 → 두리번
        .lookRight  : .look,       // 오른쪽보기 → 두리번
        .look       : .idle,       // 두리번 없으면 → 대기
        .dropped    : .lowering,   // 구 drop 파일 없으면 → 신규 lowering
    ]

    // ── 1회 재생 후 복귀할 기본 상태 ────────────────────────────
    // idle 대신 typing으로 복귀 (앱의 기본 상태)
    private var defaultReturnState: AnimationState { .typing }

    // MARK: - Scene 초기화
    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .aspectFit
        anchorPoint = CGPoint(x: 0.5, y: 0.0)  // origin = 씬 하단 중앙

        setupCharacterNode()
        loadAndPlay(state: .typing)             // 기본 상태: 타이핑
    }

    // MARK: - 노드 셋업
    private func setupCharacterNode() {
        let placeholder = SKTexture(imageNamed: "\(characterID)_idle_001")
        characterNode = SKSpriteNode(texture: placeholder)
        characterNode.position = CGPoint(x: 0, y: 0)
        characterNode.anchorPoint = CGPoint(x: 0.5, y: 0.0)
        addChild(characterNode)

        // 폴백 이미지 노드 (스프라이트 없을 때 표시)
        if !fallbackImageName.isEmpty {
            let fallbackNode = SKSpriteNode(imageNamed: fallbackImageName)
            fallbackNode.position = CGPoint(x: 0, y: 0)
            fallbackNode.anchorPoint = CGPoint(x: 0.5, y: 0.0)
            fallbackNode.name = "fallbackImageNode"
            fallbackNode.isHidden = true
            fallbackImageNode = fallbackNode
            addChild(fallbackNode)
        }
    }

    // MARK: - 상태 해석 (폴백 체인)
    /// 파일이 없는 상태는 fallbackStates를 따라 대체 상태를 찾습니다.
    /// 무한 루프 방지: 방문한 상태를 기록하고 최대 5단계까지만 탐색.
    private func resolveWithFallback(_ state: AnimationState) -> AnimationState {
        var current = state
        var visited = Set<AnimationState>()
        while visited.insert(current).inserted {
            if !loadTextures(for: current).isEmpty { return current }
            guard let next = fallbackStates[current] else { break }
            current = next
        }
        // 최종 폴백: idle (파일이 반드시 존재해야 함)
        return .idle
    }

    // MARK: - 애니메이션 로드 & 재생
    /// 특정 상태의 PNG 시퀀스를 로드해 재생합니다.
    /// 파일이 없으면 fallbackStates 체인을 통해 자동 대체됩니다.
    func loadAndPlay(state: AnimationState, fps: Double? = nil) {
        guard characterNode != nil else { return }

        // 폴백 체인으로 실제 재생할 상태 결정
        let resolved = resolveWithFallback(state)
        let textures = loadTextures(for: resolved)

        guard !textures.isEmpty else {
            showEmojiFallback()
            return
        }

        hideEmojiFallback()
        currentState = resolved
        isAnimationLoaded = true

        // 첫 프레임 적용 후 씬에 맞게 스케일
        characterNode.texture = textures[0]
        characterNode.size = textures[0].size()
        fitCharacterToScene(basedOn: textures.map { $0.size() })

        characterNode.removeAllActions()

        let timePerFrame = 1.0 / (fps ?? defaultFPS)
        let animateAction = SKAction.animate(
            with: textures,
            timePerFrame: timePerFrame,
            resize: true,
            restore: true
        )

        if loopingStates.contains(resolved) {
            characterNode.run(SKAction.repeatForever(animateAction), withKey: "animation")
        } else {
            // 1회 재생 후 타이핑(기본)으로 복귀
            let sequence = SKAction.sequence([
                animateAction,
                SKAction.run { [weak self] in
                    DispatchQueue.main.async {
                        self?.loadAndPlay(state: self?.defaultReturnState ?? .typing)
                    }
                }
            ])
            characterNode.run(sequence, withKey: "animation")
        }
    }

    // MARK: - 텍스처 로드 헬퍼
    private func loadTextures(for state: AnimationState) -> [SKTexture] {
        var textures: [SKTexture] = []
        let subdir = "Sprites/\(characterID)"

        for i in 1...60 {
            let imageName = String(format: "%@_%@_%03d", characterID, state.rawValue, i)
            let exists = Bundle.main.path(forResource: imageName, ofType: "png", inDirectory: subdir) != nil
                      || Bundle.main.path(forResource: imageName, ofType: "png") != nil
                      || NSImage(named: imageName) != nil
            if exists {
                textures.append(SKTexture(imageNamed: imageName))
            } else {
                break
            }
        }
        return textures
    }

    // MARK: - 폴백 이미지 표시/숨기기
    private func showEmojiFallback() {
        guard let fallback = fallbackImageNode else { return }
        characterNode.isHidden = true
        fallback.isHidden = false
    }

    private func hideEmojiFallback() {
        fallbackImageNode?.isHidden = true
        characterNode.isHidden = false
    }

    // MARK: - 드래그 인터랙션
    func startDragging() {
        loadAndPlay(state: .lifted)
        let wobble = SKAction.sequence([
            SKAction.rotate(byAngle: 0.1, duration: 0.08),
            SKAction.rotate(byAngle: -0.2, duration: 0.16),
            SKAction.rotate(byAngle: 0.1, duration: 0.08)
        ])
        characterNode.run(SKAction.repeatForever(wobble), withKey: "wobble")
    }

    func stopDragging() {
        characterNode.removeAction(forKey: "wobble")
        characterNode.run(SKAction.rotate(toAngle: 0, duration: 0.2, shortestUnitArc: true))
        loadAndPlay(state: .landing)
    }

    // MARK: - 크기 조절
    func fitCharacterToScene(basedOn sizeList: [CGSize]? = nil) {
        guard !characterNode.isHidden else { return }
        
        var refWidth = characterNode.size.width
        var refHeight = characterNode.size.height
        
        if let sizes = sizeList, !sizes.isEmpty {
            refWidth = sizes.map { $0.width }.max() ?? refWidth
            refHeight = sizes.map { $0.height }.max() ?? refHeight
        }
        
        guard refWidth > 0, refHeight > 0 else { return }

        let scaleX = size.width  / refWidth
        let scaleY = size.height / refHeight
        characterNode.setScale(min(scaleX, scaleY) * 0.95)
    }
}
