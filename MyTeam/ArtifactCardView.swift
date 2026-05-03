import SwiftUI

// MARK: - ArtifactCardView

struct ArtifactCardView: View {
    let artifact: IndexedArtifact

    @State private var copied = false

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
                Button("열기") { openFile() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                Button("Finder") { revealInFinder() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button(copied ? "복사됨" : "경로 복사") { copyPath() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
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

    private func openFile() {
        NSWorkspace.shared.open(URL(fileURLWithPath: artifact.path))
    }

    private func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: artifact.path)])
    }

    private func copyPath() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(artifact.path, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
    }
}
