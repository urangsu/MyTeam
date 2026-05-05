import SwiftUI
import AppKit

// MARK: - 흔들기 이펙트 (AgentChatView에서 분리)
struct JiggleEffect: ViewModifier {
    var isJiggling: Bool
    @State private var angle: Double = 0

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isJiggling ? angle : 0))
            .onAppear {
                if isJiggling {
                    withAnimation(
                        .easeInOut(duration: 0.24)
                        .repeatForever(autoreverses: true)
                    ) { angle = 2.5 }
                }
            }
            .onChange(of: isJiggling) { _, newVal in
                if newVal {
                    withAnimation(
                        .easeInOut(duration: 0.24)
                        .repeatForever(autoreverses: true)
                    ) { angle = 2.5 }
                } else {
                    withAnimation(.easeOut(duration: 0.1)) { angle = 0 }
                }
            }
    }
}

extension View {
    func jiggle(_ active: Bool) -> some View {
        modifier(JiggleEffect(isJiggling: active))
    }
}

// MARK: - iMessage 말풍선 (복사 + 텍스트 선택)
struct IMMessageBubble: View {
    let text: String
    let isUser: Bool
    let agentName: String
    let agentImageName: String
    let agentColor: Color
    let isDarkMode: Bool
    let timestamp: Date?
    var sources: [AgentWindowManager.SourceReference] = []

    private var bubbleBg: Color {
        isUser ? .blue : (isDarkMode ? Color.white.opacity(0.11) : Color.black.opacity(0.07))
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isUser {
                if agentImageName.isEmpty {
                    Image(systemName: "person.2.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .foregroundColor(.gray.opacity(0.5))
                } else {
                    Image(agentImageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                }
            } else {
                Spacer()
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 3) {
                if !isUser {
                    Text(agentName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(agentColor.opacity(0.85))
                }

                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(isUser ? .white : (isDarkMode ? .white : .black))
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 18).fill(bubbleBg))
                    .frame(maxWidth: 260, alignment: isUser ? .trailing : .leading)
                    .contextMenu {
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(text, forType: .string)
                        }) {
                            Label("복사", systemImage: "doc.on.doc")
                        }
                    }

                if !sources.isEmpty {
                    SourceChipsView(sources: sources, isDarkMode: isDarkMode)
                        .frame(maxWidth: 260, alignment: .leading)
                }

                if let ts = timestamp {
                    Text(ts, style: .time)
                        .font(.system(size: 9))
                        .foregroundColor(.gray.opacity(0.5))
                }
            }

            if isUser { Spacer().frame(width: 8) }
        }
    }
}

struct SourceChipsView: View {
    let sources: [AgentWindowManager.SourceReference]
    let isDarkMode: Bool

    private var visibleSources: [AgentWindowManager.SourceReference] {
        Array(sources.prefix(2))
    }

    var body: some View {
        HStack(spacing: 4) {
            Text("출처")
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(.secondary)

            ForEach(visibleSources) { source in
                Button(action: { open(source) }) {
                    HStack(spacing: 3) {
                        Image(systemName: "link")
                            .font(.system(size: 7, weight: .bold))
                        Text(sourceTitle(source))
                            .lineLimit(1)
                    }
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .help(source.url)
            }

            if sources.count > visibleSources.count {
                Text("+\(sources.count - visibleSources.count)")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func sourceTitle(_ source: AgentWindowManager.SourceReference) -> String {
        if !source.title.isEmpty { return source.title }
        guard let host = URL(string: source.url)?.host else { return source.provider }
        return host.replacingOccurrences(of: "www.", with: "")
    }

    private func open(_ source: AgentWindowManager.SourceReference) {
        guard let url = URL(string: source.url) else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - DateSeparator
struct DateSeparator: View {
    let date: Date
    var body: some View {
        HStack {
            Spacer()
            Text(date, style: .date)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gray.opacity(0.6))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.gray.opacity(0.1)))
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 첨부파일 칩 (입력창 미리보기)
struct AttachmentChip: View {
    let attachment: ChatAttachment
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: iconName)
                .font(.system(size: 11))
                .foregroundColor(iconColor)
            Text(attachment.fileName)
                .font(.system(size: 11))
                .lineLimit(1)
                .frame(maxWidth: 100)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.15)))
    }

    private var iconName: String {
        switch attachment.type {
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        case .text: return "doc.text"
        case .document: return "doc.fill"
        case .other: return "paperclip"
        }
    }

    private var iconColor: Color {
        switch attachment.type {
        case .image: return .blue
        case .pdf: return .red
        case .text: return .green
        case .document: return .orange
        case .other: return .gray
        }
    }
}

// MARK: - ChatBubble (호환용)
struct ChatBubble: View {
    let message: String; let isUser: Bool; let imageName: String; let isDarkMode: Bool; let accentColor: Color
    var body: some View {
        IMMessageBubble(text: message, isUser: isUser, agentName: "", agentImageName: imageName, agentColor: accentColor, isDarkMode: isDarkMode, timestamp: nil)
    }
}

// MARK: - 타이핑 인디케이터 (카톡 "..." 애니메이션)
struct TypingIndicatorView: View {
    let agentName: String
    let agentColor: Color
    @State private var dotPhase: Int = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            // 에이전트 이름 (캐릭터 색상)
            Text(agentName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(agentColor)

            // 말풍선 형태의 "..."
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(agentColor.opacity(dotPhase == i ? 1.0 : 0.3))
                        .frame(width: 6, height: 6)
                        .offset(y: dotPhase == i ? -3 : 0)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.12))
            )

            Spacer()
        }
        .padding(.leading, 4)
        .padding(.vertical, 2)
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                dotPhase = (dotPhase + 1) % 3
            }
        }
    }
}
// MARK: - SkillResultCardView
/// 스킬 실행 결과를 카드 형태로 표시 (예: 글자 수 세기)
struct SkillResultCardView: View {
    let skillID: String
    let text: String
    let isDarkMode: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .bold))
                Text(skillName)
                    .font(.system(size: 10, weight: .bold))
                Spacer()
                Text("Local")
                    .font(.system(size: 8, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(3)
            }
            .foregroundColor(.secondary)
            
            Text(text)
                .font(.system(size: 13))
                .lineSpacing(4)
                .foregroundColor(isDarkMode ? .white : .black)
                .textSelection(.enabled)
            
            HStack {
                Spacer()
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("복사")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05), lineWidth: 0.5)
                )
        )
        .frame(maxWidth: 280)
    }
    
    private var skillName: String {
        switch skillID {
        case "korean.character-count": return "글자 수 세기"
        default: return "Skill Result"
        }
    }
}
