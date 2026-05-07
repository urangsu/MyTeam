import SwiftUI

// MARK: - CodeBlockView
/// Markdown fenced code block을 렌더링하는 뷰
/// 언어명 표시, 복사 버튼, monospaced font 적용
struct CodeBlockView: View {
    let code: String
    let language: String?
    let isDarkMode: Bool

    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 헤더: 언어명 + 복사 버튼
            HStack {
                Text(language ?? "code")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: copyCode) {
                    Label("복사", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("코드 복사")
            }
            .padding(8)
            .background(isDarkMode ? Color(white: 0.15) : Color(white: 0.95))

            Divider()

            // 코드 내용
            ScrollView(.horizontal) {
                Text(code)
                    .font(.system(.caption, design: .monospaced))
                    .lineSpacing(1)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(isDarkMode ? Color(white: 0.1) : Color(white: 0.98))
            .frame(minHeight: 60)
        }
        .border(isDarkMode ? Color(white: 0.2) : Color(white: 0.9))
        .cornerRadius(6)
    }

    // MARK: - Private Methods

    /// 코드를 클립보드에 복사한다.
    private func copyCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)

        // 피드백: 잠시 "복사됨" 표시
        isCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isCopied = false
        }

        AppLog.info("[CodeBlockView] 코드 복사 (\(language ?? "code"), \(code.count)자)")
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        CodeBlockView(
            code: """
            let message = "Hello, World!"
            print(message)
            """,
            language: "swift",
            isDarkMode: false
        )

        CodeBlockView(
            code: """
            def hello():
                print("Hello, Python!")
            """,
            language: "python",
            isDarkMode: false
        )

        CodeBlockView(
            code: "console.log('Hello');",
            language: nil,
            isDarkMode: false
        )
    }
    .padding()
}
