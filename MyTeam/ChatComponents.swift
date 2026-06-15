import SwiftUI
import AppKit

enum ChatTypingPolicy {
    nonisolated static let normalCharactersPerSecond: Double = 18
    nonisolated static let fastCharactersPerSecond: Double = 26
    nonisolated static let punctuationPauseNanoseconds: UInt64 = 140_000_000
    nonisolated static let maxAnimatedCharacters: Int = 220

    nonisolated static func shouldAnimate(
        text: String,
        isUser: Bool,
        isSkillResult: Bool = false
    ) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isUser, !isSkillResult else { return false }
        guard !trimmed.isEmpty, trimmed.count <= maxAnimatedCharacters else { return false }
        guard !trimmed.contains("```") else { return false }
        guard !trimmed.contains("|---") else { return false }
        if trimmed.split(separator: "\n").count > 4 { return false }
        if trimmed.contains("\n- ") || trimmed.contains("\n1. ") { return false }
        return true
    }
}

struct TypewriterTextView: View {
    let text: String
    let isEnabled: Bool
    let charactersPerSecond: Double
    let punctuationPauseNanoseconds: UInt64
    let maxAnimatedCharacters: Int
    let onFinished: (() -> Void)?

    @State private var displayedText: String = ""
    @State private var renderTask: Task<Void, Never>?

    init(
        text: String,
        isEnabled: Bool = true,
        charactersPerSecond: Double = ChatTypingPolicy.normalCharactersPerSecond,
        punctuationPauseNanoseconds: UInt64 = ChatTypingPolicy.punctuationPauseNanoseconds,
        maxAnimatedCharacters: Int = ChatTypingPolicy.maxAnimatedCharacters,
        onFinished: (() -> Void)? = nil
    ) {
        self.text = text
        self.isEnabled = isEnabled
        self.charactersPerSecond = charactersPerSecond
        self.punctuationPauseNanoseconds = punctuationPauseNanoseconds
        self.maxAnimatedCharacters = maxAnimatedCharacters
        self.onFinished = onFinished
    }

    var body: some View {
        Text(displayedText.isEmpty && !text.isEmpty ? " " : displayedText)
            .onAppear { startRendering() }
            .onDisappear { cancelRendering() }
            .onChange(of: text) { _, _ in startRendering() }
            .onChange(of: isEnabled) { _, _ in startRendering() }
    }

    private func startRendering() {
        cancelRendering()
        guard isEnabled, !text.isEmpty, text.count <= maxAnimatedCharacters else {
            displayedText = text
            onFinished?()
            return
        }
        displayedText = ""
        let characters = Array(text)
        let baseDelay = UInt64(max(12_000_000, 1_000_000_000 / max(1, Int(charactersPerSecond))))
        renderTask = Task {
            var current = ""
            for character in characters {
                if Task.isCancelled { return }
                current.append(character)
                await MainActor.run {
                    displayedText = current
                }
                let delay = punctuationCharacters.contains(character)
                    ? baseDelay + punctuationPauseNanoseconds
                    : baseDelay
                try? await Task.sleep(nanoseconds: delay)
            }
            if !Task.isCancelled {
                await MainActor.run {
                    onFinished?()
                }
            }
        }
    }

    private func cancelRendering() {
        renderTask?.cancel()
        renderTask = nil
    }

    private var punctuationCharacters: Set<Character> {
        [".", ",", "!", "?", "…", "。", "，", "！", "？"]
    }
}

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
    var enableTypewriter: Bool = false

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

                // Assistant/System 메시지는 Markdown으로 렌더링, User는 plain text 유지
                if isUser {
                    Text(text)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .textSelection(.enabled)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 18).fill(bubbleBg))
                        .frame(maxWidth: 260, alignment: .trailing)
                        .contextMenu {
                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(text, forType: .string)
                            }) {
                                Label("복사", systemImage: "doc.on.doc")
                            }
                        }
                } else {
                    Group {
                        if enableTypewriter {
                            TypewriterTextView(text: text)
                                .font(.system(size: 14))
                                .foregroundColor(isDarkMode ? .white.opacity(0.92) : .black.opacity(0.88))
                        } else {
                            MarkdownTextView(
                                text: text,
                                isDarkMode: isDarkMode
                            )
                        }
                    }
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 18).fill(bubbleBg))
                    .frame(maxWidth: 480, alignment: .leading)
                    .contextMenu {
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(text, forType: .string)
                        }) {
                            Label("복사", systemImage: "doc.on.doc")
                        }
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
    @State private var animationTimer: Timer? = nil

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
        .onDisappear { stopAnimation() }
    }

    private func startAnimation() {
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                dotPhase = (dotPhase + 1) % 3
            }
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
}
