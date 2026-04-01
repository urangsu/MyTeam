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
