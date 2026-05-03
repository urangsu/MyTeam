import SwiftUI

// MARK: - ArtifactCardView

struct ArtifactCardView: View {
    let artifact: IndexedArtifact

    @State private var copied = false

    /// cloud artifact이면 URL(string:), local이면 URL(fileURLWithPath:).
    /// path가 비어 있거나 변환 실패 시 nil → 버튼 disabled.
    private var resolvedURL: URL? {
        guard !artifact.path.isEmpty else { return nil }
        if artifact.type == .cloud {
            return URL(string: artifact.path)
        }
        return URL(fileURLWithPath: artifact.path)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(typeEmoji)
                    .font(.title2)
                Text(artifact.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !artifact.preview.isEmpty {
                Text(artifact.preview)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }

            HStack(spacing: 8) {
                // 열기 — cloud: URL open, local: NSWorkspace file open
                Button("열기") { openArtifact() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(resolvedURL == nil)

                // Finder — cloud artifact에서는 숨김
                if artifact.type != .cloud {
                    Button("Finder") { revealInFinder() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(resolvedURL == nil)
                }

                // 경로/URL 복사
                Button(copied ? "복사됨" : "경로 복사") { copyPath() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(artifact.path.isEmpty)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.2)))
    }

    // MARK: - Helpers

    private var typeEmoji: String {
        switch artifact.type {
        case .report:       return "📄"
        case .presentation: return "📊"
        case .spreadsheet:  return "📈"
        case .text:         return "📝"
        case .cloud:        return "☁️"
        case .other:        return "📁"
        }
    }

    private var formattedDate: String {
        let iso = ISO8601DateFormatter()
        guard let date = iso.date(from: artifact.createdAt) else { return artifact.createdAt }
        let fmt = DateFormatter()
        fmt.dateFormat = "MM/dd HH:mm"
        return fmt.string(from: date)
    }

    private func openArtifact() {
        guard let url = resolvedURL else { return }
        NSWorkspace.shared.open(url)
    }

    private func revealInFinder() {
        guard let url = resolvedURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func copyPath() {
        guard !artifact.path.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(artifact.path, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
    }
}
