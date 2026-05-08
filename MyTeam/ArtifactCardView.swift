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

    private var fileExists: Bool {
        guard artifact.type != .cloud else { return resolvedURL != nil }
        return FileManager.default.fileExists(atPath: artifact.path)
    }

    private var canInteract: Bool {
        resolvedURL != nil && fileExists
    }

    private var typeLabel: String {
        switch artifact.type {
        case .report:       return "보고서"
        case .presentation: return "프레젠테이션"
        case .spreadsheet:  return "스프레드시트"
        case .text:         return "문서"
        case .cloud:        return "클라우드"
        case .other:        return "기타"
        }
    }

    private var storageLabel: String {
        artifact.type == .cloud ? "Cloud" : "Workspace"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(typeEmoji)
                    .font(.title2)
                Text(artifact.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(typeLabel)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
                Spacer()
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                Text("파일명: \(artifact.filename)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
                Text("저장 위치: \(storageLabel)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !artifact.preview.isEmpty {
                Text(artifact.preview)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }

            if artifact.type != .cloud && !fileExists {
                Text("파일을 찾을 수 없습니다.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                // 열기 — cloud: URL open, local: NSWorkspace file open
                Button("열기") { openArtifact() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(!canInteract)

                // Finder — cloud artifact에서는 숨김
                if artifact.type != .cloud {
                    Button("Finder에서 열기") { revealInFinder() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(!canInteract)
                }

                // 경로/URL 복사
                Button(copied ? "복사됨" : "경로 복사") { copyPath() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!canInteract)
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
        guard let url = resolvedURL, canInteract else { return }
        NSWorkspace.shared.open(url)
    }

    private func revealInFinder() {
        guard let url = resolvedURL, canInteract else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func copyPath() {
        guard !artifact.path.isEmpty, canInteract else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(artifact.path, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
    }
}
