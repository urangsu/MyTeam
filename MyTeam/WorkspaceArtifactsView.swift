import SwiftUI

// MARK: - WorkspaceArtifactsView

struct WorkspaceArtifactsView: View {
    @State private var artifacts: [IndexedArtifact] = []
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("생성된 파일")
                    .font(.headline)
                Spacer()
                if isLoading {
                    ProgressView().controlSize(.small)
                }
                Button(action: refresh) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("새로고침")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if artifacts.isEmpty {
                ContentUnavailableView(
                    "아직 생성된 파일이 없습니다",
                    systemImage: "doc.badge.plus",
                    description: Text("PPT, 엑셀, 보고서 등을 요청하면 여기에 표시됩니다.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(artifacts.reversed(), id: \.id) { artifact in
                            ArtifactCardView(artifact: artifact)
                                .padding(.horizontal, 12)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .task { await loadArtifacts() }
        .onReceive(NotificationCenter.default.publisher(for: .workflowCompleted)) { _ in
            Task { await loadArtifacts() }
        }
    }

    // MARK: - Helpers

    private func refresh() {
        Task { await loadArtifacts() }
    }

    @MainActor
    private func loadArtifacts() async {
        isLoading = true
        artifacts = await ArtifactStore.shared.loadArtifacts()
        isLoading = false
    }
}
