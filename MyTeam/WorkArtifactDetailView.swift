import AppKit
import SwiftUI

struct WorkArtifactDetailView: View {
    let artifactID: String?
    let filename: String?
    @State private var loadedArtifact: IndexedArtifact?
    @State private var loadedText: String?
    @State private var didLoad = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("저장된 결과")
                .font(.system(size: 12, weight: .semibold))

            if let artifact = loadedArtifact {
                VStack(alignment: .leading, spacing: 4) {
                    detailRow("제목", artifact.title)
                    detailRow("파일", artifact.filename)
                    detailRow("상태", artifact.healthStatus.rawValue)
                }

                if let artifactText = loadedText, !artifactText.isEmpty {
                    ScrollView {
                        Text(artifactText)
                            .font(.system(size: 11))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    }
                    .frame(minHeight: 120, maxHeight: 260)
                    .background(Color(NSColor.windowBackgroundColor), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                } else if !artifact.preview.isEmpty {
                    Text(artifact.preview)
                        .font(.system(size: 11))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(NSColor.windowBackgroundColor), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                } else {
                    Text("앱 내부에서 읽을 수 있는 본문이 없습니다.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            } else if !didLoad {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text("저장된 결과를 찾을 수 없습니다.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: "\(artifactID ?? "")|\(filename ?? "")") {
            await loadArtifact()
        }
    }

    private func loadArtifact() async {
        let artifacts = await ArtifactStore.shared.loadArtifacts()
        let artifact: IndexedArtifact?
        if let artifactID,
           let match = artifacts.first(where: { $0.id == artifactID }) {
            artifact = match
        } else if let filename {
            artifact = artifacts.first(where: { $0.filename == filename || $0.relativePath == filename })
        } else {
            artifact = nil
        }

        let text: String?
        if let artifact,
           let url = artifact.resolvedURL(in: ArtifactStore.shared.workspaceURL),
           let data = try? Data(contentsOf: url),
           let raw = String(data: data, encoding: .utf8) {
            text = String(raw.prefix(20_000)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            text = nil
        }

        await MainActor.run {
            loadedArtifact = artifact
            loadedText = text
            didLoad = true
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)
            Text(value)
                .font(.system(size: 10))
                .lineLimit(1)
                .textSelection(.enabled)
        }
    }
}
