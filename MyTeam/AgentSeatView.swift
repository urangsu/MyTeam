import SwiftUI

// MARK: - AgentSeatView (TeamTableView에서 분리)
struct AgentSeatView: View {
    let config: AgentWindowManager.AgentConfig
    var isDragging: Bool
    var isSpeaking: Bool
    var isThinking: Bool
    var speechText: String?
    var isSelected: Bool
    var onTap: () -> Void

    @State private var isHovered = false

    // 사용자가 요청한 '3문장(또는 3줄) 단위 분절' 로직
    var speechParagraphs: [String] {
        guard let text = speechText, !text.isEmpty else { return [] }
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".?!"))
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        var result: [String] = []
        var current: String = ""
        for (index, sentence) in sentences.enumerated() {
            current += sentence + (index < sentences.count ? ". " : " ")
            if (index + 1) % 3 == 0 {
                result.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            }
        }
        if !current.isEmpty {
            result.append(current.trimmingCharacters(in: .whitespaces))
        }
        return result
    }

    var body: some View {
        VStack(spacing: 4) {
            // 말풍선 (문단 분절 또는 로딩 스피너)
            if isThinking {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.6)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .offset(y: -10)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else if isSpeaking, !speechParagraphs.isEmpty {
                VStack(spacing: 4) {
                    ForEach(speechParagraphs, id: \.self) { paragraph in
                        Text(paragraph)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .multilineTextAlignment(.center)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(config.color.opacity(0.85))
                            )
                    }
                }
                .offset(y: -10)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                Color.clear.frame(height: 10)
            }

            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.pink, lineWidth: 2)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.pink.opacity(0.1)))
                        .frame(width: 100, height: 100)
                } else {
                    Color.clear.frame(width: 100, height: 100)
                }

                if isHovered && !isDragging {
                    VStack(spacing: 2) {
                        Text(config.name).font(.system(size: 11, weight: .bold))
                        Text(config.role).font(.system(size: 9))
                    }
                    .foregroundColor(.white).padding(.horizontal, 8).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 10).fill(config.color.opacity(0.9)))
                    .offset(y: -40)
                    .transition(.opacity.combined(with: .scale))
                }

                // SpriteKit 캐릭터 (spriteName이 있을 때) / 이미지 폴백
                if let spriteName = config.spriteName {
                    // 감정 상태 우선순위: 드래그 > agentEmotions(AI 감지) > 기본 타이핑
                    let emotionState: AnimationState = {
                        if isDragging { return .drag }
                        if let emotion = AgentWindowManager.shared.agentEmotions[config.id] {
                            return emotion
                        }
                        return .typing
                    }()
                    SpriteAgentView(
                        characterID: spriteName,
                        fallbackImageName: config.fallbackImageName,
                        state: emotionState
                    )
                    .frame(width: 100, height: 140)
                    .rotationEffect(.degrees(isDragging ? config.dragRotation : 0))
                    .scaleEffect(isHovered && !isDragging ? 1.1 : 1.0)
                } else if !config.fallbackImageName.isEmpty {
                    Image(config.fallbackImageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                        .rotationEffect(.degrees(isDragging ? config.dragRotation : 0))
                        .scaleEffect(isHovered && !isDragging ? 1.1 : 1.0)
                } else {
                    Text(isDragging ? config.dragEmoji : config.emoji)
                        .font(.system(size: 50))
                        .rotationEffect(.degrees(isDragging ? config.dragRotation : 0))
                        .scaleEffect(isHovered && !isDragging ? 1.1 : 1.0)
                }
            }

            HStack(spacing: 3) {
                Circle()
                    .fill(isSpeaking ? Color.yellow : Color.green)
                    .frame(width: 4, height: 4)
                    .shadow(color: isSpeaking ? .yellow : .green, radius: 2)
                Text(isSpeaking ? "말하는 중" : "대기 중")
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
            }
        }
        .frame(width: 100)
        .contentShape(Rectangle())
        .onHover { h in isHovered = h }
        .onTapGesture(count: 2) {
            let fallback = ["안녕하세요!", "네, 불렀나요?", "무엇을 도와드릴까요?", "여기 있습니다!"]
            let text = CharacterDialogues.randomLine(for: config.name, state: .greeting) ?? fallback.randomElement()!
            if let rid = AgentWindowManager.shared.currentRoomID {
                AgentWindowManager.shared.addChatLog(roomID: rid, agentID: config.id, agentName: config.name, text: text, isUser: false, isSystem: true)
            }
            if !AgentWindowManager.shared.isSilentMode {
                AgentWindowManager.shared.setAgentSpeaking(agentID: config.id, text: text)
                SpeechManager.shared.speak(text: text, agentID: config.id, characterName: config.name)
            }
        }
        .onTapGesture { onTap() }
    }
}
