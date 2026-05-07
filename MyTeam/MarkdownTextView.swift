import SwiftUI

// MARK: - MarkdownTextView
/// Markdown 문자열을 AttributedString 기반으로 렌더링하는 뷰
/// 외부 패키지 없이 native SwiftUI AttributedString(markdown:) 사용
struct MarkdownTextView: View {
    let text: String
    let isDarkMode: Bool
    let isUser: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !text.isEmpty {
                ForEach(parseBlocks(text), id: \.id) { block in
                    switch block.kind {
                    case .paragraph:
                        markdownParagraph(block.content)
                    case .codeBlock(let language):
                        CodeBlockView(code: block.content, language: language, isDarkMode: isDarkMode)
                    }
                }
            }
        }
        .textSelection(.enabled)
    }

    // MARK: - Private Methods

    /// 텍스트를 Markdown 블록으로 파싱한다.
    /// fenced code block (```) 을 감지하고 분리한다.
    private func parseBlocks(_ input: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = input.components(separatedBy: .newlines)

        var currentParagraph: [String] = []
        var inCodeBlock = false
        var codeBlockLanguage: String? = nil
        var codeBlockLines: [String] = []

        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                if !inCodeBlock {
                    // Code block 시작
                    if !currentParagraph.isEmpty {
                        let paragraphText = currentParagraph.joined(separator: "\n")
                        if !paragraphText.trimmingCharacters(in: .whitespaces).isEmpty {
                            blocks.append(MarkdownBlock(kind: .paragraph, content: paragraphText))
                        }
                        currentParagraph.removeAll()
                    }

                    inCodeBlock = true
                    // 언어명 추출
                    let marker = line.trimmingCharacters(in: .whitespaces)
                    let languagePart = String(marker.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    codeBlockLanguage = languagePart.isEmpty ? nil : languagePart
                    codeBlockLines.removeAll()
                } else {
                    // Code block 종료
                    inCodeBlock = false
                    let codeContent = codeBlockLines.joined(separator: "\n")
                    blocks.append(MarkdownBlock(kind: .codeBlock(language: codeBlockLanguage), content: codeContent))
                    codeBlockLines.removeAll()
                    codeBlockLanguage = nil
                }
            } else {
                if inCodeBlock {
                    codeBlockLines.append(line)
                } else {
                    currentParagraph.append(line)
                }
            }
        }

        // 미처리된 내용 처리
        if !currentParagraph.isEmpty {
            let paragraphText = currentParagraph.joined(separator: "\n")
            if !paragraphText.trimmingCharacters(in: .whitespaces).isEmpty {
                blocks.append(MarkdownBlock(kind: .paragraph, content: paragraphText))
            }
        }

        if inCodeBlock && !codeBlockLines.isEmpty {
            let codeContent = codeBlockLines.joined(separator: "\n")
            blocks.append(MarkdownBlock(kind: .codeBlock(language: codeBlockLanguage), content: codeContent))
        }

        return blocks.isEmpty ? [MarkdownBlock(kind: .paragraph, content: text)] : blocks
    }

    /// Markdown 텍스트를 AttributedString으로 렌더링한다.
    @ViewBuilder
    private func markdownParagraph(_ content: String) -> some View {
        let attributedString = parseMarkdownToAttributed(content)
        Text(attributedString)
            .lineSpacing(2)
    }

    /// Markdown 형식을 AttributedString으로 변환한다.
    /// 실패하면 일반 Text 반환.
    private func parseMarkdownToAttributed(_ markdown: String) -> AttributedString {
        do {
            return try AttributedString(markdown: markdown)
        } catch {
            // Parse 실패 시 fallback: 일반 문자열
            AppLog.warning("[MarkdownTextView] parse 실패: \(error), fallback to plain text")
            return AttributedString(markdown)
        }
    }
}

// MARK: - MarkdownBlock
private struct MarkdownBlock: Identifiable {
    let id = UUID()
    let kind: MarkdownBlockKind
    let content: String
}

private enum MarkdownBlockKind {
    case paragraph
    case codeBlock(language: String?)
}

// MARK: - Preview (temporarily disabled for debugging)
// #Preview {
//     VStack(spacing: 20) {
//         MarkdownTextView(
//             text: """
//             # 제목
//
//             안녕하세요. **굵게**, *기울임*, `inline code` 테스트입니다.
//
//             - 항목 1
//             - 항목 2
//
//             ```swift
//             let message = "Hello"
//             print(message)
//             ```
//
//             > 인용문입니다.
//
//             [링크](https://example.com)
//             """,
//             isDarkMode: false
//         )
//         .padding()
//
//         Divider()
//
//         MarkdownTextView(
//             text: "간단한 텍스트",
//             isDarkMode: false
//         )
//         .padding()
//     }
// }
