import SwiftUI
import AppKit

enum KoreanText {
    static func conversationTitle(with name: String) -> String {
        "\(name)\(hasFinalConsonant(name) ? "과" : "와")의 대화"
    }

    static func personalRoomDisplayName(roomName: String, agentName: String) -> String {
        let compact = roomName.trimmingCharacters(in: .whitespacesAndNewlines)
        let legacyDefaults = [
            "\(agentName)과의 대화",
            "\(agentName)와의 대화",
            "\(agentName) 대화 1"
        ]
        return legacyDefaults.contains(compact) ? "기본 대화" : compact
    }

    private static func hasFinalConsonant(_ text: String) -> Bool {
        guard let scalar = text.unicodeScalars.last else { return false }
        let value = Int(scalar.value)
        guard (0xAC00...0xD7A3).contains(value) else { return false }
        return (value - 0xAC00) % 28 != 0
    }
}

nonisolated enum ConversationReplyMode: Sendable, Equatable {
    case quick
    case casual
    case work
    case explicitDetail
}

enum ConversationReplyPolicy {
    nonisolated static let maximumCasualBubbles = 3
    nonisolated static let preferredBubbleCharacters = 100
    nonisolated static let longBubbleSplitCharacters = 140

    nonisolated static func mode(for userText: String, forceWork: Bool = false) -> ConversationReplyMode {
        if forceWork { return .work }

        let normalized = userText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if containsAny(normalized, ["자세히", "길게", "하나씩 설명", "단계별로 설명", "깊게 설명"]) {
            return .explicitDetail
        }
        if containsAny(normalized, [
            "공시", "재무", "주가", "시세", "뉴스", "날씨", "법령", "조문", "일정",
            "회의록", "보고서", "보고용", "문서", "분석", "검토", "정리해줘", "찾아줘",
            "코드", "설계", "개발", "오류", "버그", "파일", "표", "엑셀"
        ]) {
            return .work
        }
        if normalized.count <= 12 && containsAny(normalized, [
            "안녕", "고마워", "감사", "응", "네", "그래", "알겠어", "좋아", "잘 자", "잘자"
        ]) {
            return .quick
        }
        return .casual
    }

    nonisolated static func promptDirective(for mode: ConversationReplyMode) -> String {
        switch mode {
        case .quick:
            return "질문을 해결하는 가장 짧고 자연스러운 한 문장으로 답하세요."
        case .casual:
            return "일상 대화는 카카오톡처럼 짧고 자연스럽게 답하세요. 한 문단에 1~2문장만 쓰고, 필요한 내용만 남기세요."
        case .work:
            return "질문을 해결하는 가장 짧고 완전한 답변을 작성하세요. 필요한 근거와 다음 행동만 포함하고 사용자가 요청한 형식을 우선하세요."
        case .explicitDetail:
            return "사용자가 자세한 설명을 요청했습니다. 필요한 내용을 생략하지 말고 사용자가 요청한 순서와 깊이를 우선하세요."
        }
    }

    nonisolated private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }
}

enum CasualBubbleSegmenter {
    nonisolated static func segments(from text: String, mode: ConversationReplyMode) -> [String] {
        let normalized = normalizedForComparison(text)
        guard !normalized.isEmpty else { return [] }
        guard mode == .quick || mode == .casual else { return [text.trimmingCharacters(in: .whitespacesAndNewlines)] }
        guard !normalized.contains("```") else { return [text.trimmingCharacters(in: .whitespacesAndNewlines)] }

        var units = sentenceUnits(from: normalized)
        if mode == .quick {
            return [normalized]
        }
        units = units.flatMap(splitLongUnit)
        return cappedSegments(units)
    }

    /// Streaming uses only stable sentence boundaries. Long unpunctuated text stays in the active bubble.
    nonisolated static func streamingSegments(from text: String, mode: ConversationReplyMode) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard mode == .casual else { return trimmed.isEmpty ? [] : [trimmed] }
        let normalized = normalizedForComparison(text)
        guard !normalized.isEmpty else { return [] }
        return cappedSegments(sentenceUnits(from: normalized))
    }

    nonisolated static func normalizedForComparison(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    nonisolated private static func sentenceUnits(from text: String) -> [String] {
        let characters = Array(text)
        guard !characters.isEmpty else { return [] }

        var result: [String] = []
        var start = 0
        var index = 0
        while index < characters.count {
            let character = characters[index]
            let isBoundary: Bool
            if "!?。！？…".contains(character) {
                isBoundary = !isInsideURL(characters, at: index)
            } else if character == "." {
                let previousIsDigit = index > 0 && characters[index - 1].isNumber
                let nextIsDigit = index + 1 < characters.count && characters[index + 1].isNumber
                isBoundary = !previousIsDigit && !nextIsDigit && !isInsideURL(characters, at: index)
            } else {
                isBoundary = false
            }

            if isBoundary {
                var end = index + 1
                while end < characters.count && "!?。！？…".contains(characters[end]) {
                    end += 1
                }
                let unit = String(characters[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !unit.isEmpty { result.append(unit) }
                start = end
                index = end
                continue
            }
            index += 1
        }

        if start < characters.count {
            let tail = String(characters[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !tail.isEmpty { result.append(tail) }
        }
        return result.isEmpty ? [text] : result
    }

    nonisolated private static func isInsideURL(_ characters: [Character], at index: Int) -> Bool {
        var tokenStart = index
        while tokenStart > 0 && !characters[tokenStart - 1].isWhitespace { tokenStart -= 1 }
        var tokenEnd = index
        while tokenEnd + 1 < characters.count && !characters[tokenEnd + 1].isWhitespace { tokenEnd += 1 }
        let token = String(characters[tokenStart...tokenEnd]).lowercased()
        return token.hasPrefix("http://") || token.hasPrefix("https://") || token.hasPrefix("www.")
    }

    nonisolated private static func splitLongUnit(_ unit: String) -> [String] {
        guard unit.count > ConversationReplyPolicy.longBubbleSplitCharacters else { return [unit] }
        var remaining = unit[...]
        var chunks: [String] = []
        while remaining.count > ConversationReplyPolicy.longBubbleSplitCharacters {
            let preferredEnd = remaining.index(
                remaining.startIndex,
                offsetBy: min(ConversationReplyPolicy.preferredBubbleCharacters, remaining.count)
            )
            let hardEnd = remaining.index(
                remaining.startIndex,
                offsetBy: min(ConversationReplyPolicy.longBubbleSplitCharacters, remaining.count)
            )
            let prefix = remaining[..<hardEnd]
            let splitIndex = prefix.indices.reversed().first(where: {
                $0 <= preferredEnd && prefix[$0].isWhitespace
            })
                ?? prefix.indices.reversed().first(where: { prefix[$0].isWhitespace })
                ?? hardEnd
            let chunk = String(remaining[..<splitIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !chunk.isEmpty { chunks.append(chunk) }
            remaining = remaining[splitIndex...].drop(while: { $0.isWhitespace })
        }
        let tail = String(remaining).trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { chunks.append(tail) }
        return chunks
    }

    nonisolated private static func cappedSegments(_ units: [String]) -> [String] {
        let clean = units.filter { !$0.isEmpty }
        guard clean.count > ConversationReplyPolicy.maximumCasualBubbles else { return clean }
        return [clean[0], clean[1], clean.dropFirst(2).joined(separator: " ")]
    }
}

enum ChatTypingPolicy {
    nonisolated static let normalCharactersPerSecond: Double = 26
    nonisolated static let fastCharactersPerSecond: Double = 26
    nonisolated static let punctuationPauseNanoseconds: UInt64 = 90_000_000
    nonisolated static let maxAnimatedCharacters: Int = 100

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

struct CopyableMessageContainer<Content: View>: View {
    let text: String
    let isUser: Bool
    private let content: Content

    @State private var isHovered = false
    @State private var didCopy = false
    @State private var resetTask: Task<Void, Never>?
    @FocusState private var isFocused: Bool

    init(
        text: String,
        isUser: Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.text = text
        self.isUser = isUser
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 5) {
            if isUser { copyButton }
            content
            if !isUser { copyButton }
        }
        .contentShape(Rectangle())
        .textSelection(.enabled)
        .contextMenu {
            Button(action: copyFullText) {
                Label("복사", systemImage: "doc.on.doc")
            }
        }
        .focusable()
        .focused($isFocused)
        .onHover { isHovered = $0 }
        .onDisappear {
            resetTask?.cancel()
            resetTask = nil
        }
    }

    private var copyButton: some View {
        Button(action: copyFullText) {
            Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(didCopy ? Color.green : Color.secondary)
        .opacity(isHovered || isFocused || didCopy ? 1 : 0.28)
        .help(didCopy ? "복사됨" : "메시지 복사")
        .accessibilityLabel("메시지 복사")
    }

    private func copyFullText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        didCopy = true
        resetTask?.cancel()
        resetTask = Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { didCopy = false }
        }
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
                    CopyableMessageContainer(text: text, isUser: true) {
                        Text(text)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 18).fill(bubbleBg))
                            .frame(maxWidth: 260, alignment: .trailing)
                    }
                } else {
                    CopyableMessageContainer(text: text, isUser: false) {
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
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 18).fill(bubbleBg))
                        .frame(maxWidth: 480, alignment: .leading)
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
