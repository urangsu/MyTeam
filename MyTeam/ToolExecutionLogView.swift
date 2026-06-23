import AppKit
import SwiftUI

struct ToolExecutionLogView: View {
    @ObservedObject var store: ToolExecutionLogStore
    @State private var showsAllEntries = false
    @State private var selectedEntry: ToolExecutionLogEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("최근 실행")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                if !store.entries.isEmpty {
                    Button("지우기") {
                        store.clear()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if store.entries.isEmpty {
                Text("아직 실행 기록이 없습니다.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(store.entries.prefix(3)) { entry in
                        logRow(entry)
                    }

                    if store.entries.count > 3 {
                        DisclosureGroup(isExpanded: $showsAllEntries) {
                            VStack(spacing: 6) {
                                ForEach(store.entries.dropFirst(3)) { entry in
                                    logRow(entry)
                                }
                            }
                            .padding(.top, 4)
                        } label: {
                            Text("전체 보기 \(store.entries.count)건")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedEntry) { entry in
            ToolExecutionLogDetailView(entry: entry)
                .frame(minWidth: 420, minHeight: 320)
        }
    }

    private func logRow(_ entry: ToolExecutionLogEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: iconName(for: entry.state))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint(for: entry.state))
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                    Text(label(for: entry.state))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(tint(for: entry.state))
                    if let duration = entry.durationMs {
                        Text("\(duration)ms")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(duration > 4000 ? .orange : .secondary)
                    }
                }

                Text(detail(for: entry))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            if entry.artifactFilename != nil {
                Button {
                    selectedEntry = entry
                } label: {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .help("결과 상세 보기")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedEntry = entry
        }
        .padding(8)
        .background(Color(NSColor.windowBackgroundColor), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func detail(for entry: ToolExecutionLogEntry) -> String {
        if let failure = entry.failureMessage, !failure.isEmpty {
            return failure
        }
        if let summary = entry.resultSummary, !summary.isEmpty {
            return summary
        }
        if let provider = entry.provider {
            return "\(provider.displayName) · \(entry.permissionLevel.rawValue) · \(pathLabel(entry.path))"
        }
        return "\(entry.permissionLevel.rawValue) · \(pathLabel(entry.path))"
    }

    private func iconName(for state: ToolExecutionLogState) -> String {
        switch state {
        case .running: return "clock"
        case .succeeded: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .blocked: return "lock.fill"
        }
    }

    private func label(for state: ToolExecutionLogState) -> String {
        switch state {
        case .running: return "실행 중"
        case .succeeded: return "완료"
        case .failed: return "실패"
        case .blocked: return "차단"
        }
    }

    private func tint(for state: ToolExecutionLogState) -> Color {
        switch state {
        case .running: return .blue
        case .succeeded: return .green
        case .failed: return .orange
        case .blocked: return .secondary
        }
    }

    private func pathLabel(_ path: ToolExecutionPath) -> String {
        switch path {
        case .toolCard: return "업무 카드"
        case .chatFastPath: return "채팅 빠른 실행"
        case .planner: return "계획 실행"
        }
    }
}

struct ToolExecutionLogDetailView: View {
    let entry: ToolExecutionLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.displayName)
                        .font(.system(size: 18, weight: .bold))
                    Text(statusText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(statusTint)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                detailRow("실행 경로", pathLabel(entry.path))
                detailRow("권한", entry.permissionLevel.rawValue)
                if let duration = entry.durationMs {
                    detailRow("소요 시간", "\(duration)ms")
                }
                if let provider = entry.provider {
                    detailRow("연결", provider.displayName)
                }
                if entry.timedOut {
                    detailRow("상태", "시간 초과")
                }
            }

            if let failure = entry.failureMessage, !failure.isEmpty {
                detailBlock(title: "실패 원인", text: failure)
            } else if let summary = entry.resultSummary, !summary.isEmpty {
                detailBlock(title: "요약", text: summary)
            } else {
                detailBlock(title: "상세", text: "저장된 상세 결과가 없습니다. 다음 실행부터 결과 요약과 artifact가 함께 남습니다.")
            }

            if entry.artifactID != nil || entry.artifactFilename != nil {
                WorkArtifactDetailView(
                    artifactID: entry.artifactID,
                    filename: entry.artifactFilename
                )
            }

            Spacer()
        }
        .padding(18)
    }

    private var statusText: String {
        switch entry.state {
        case .running: return "실행 중"
        case .succeeded: return "완료"
        case .failed: return "실패"
        case .blocked: return "차단"
        }
    }

    private var statusTint: Color {
        switch entry.state {
        case .running: return .blue
        case .succeeded: return .green
        case .failed: return .orange
        case .blocked: return .secondary
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.system(size: 11))
                .textSelection(.enabled)
        }
    }

    private func detailBlock(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.system(size: 11))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color(NSColor.windowBackgroundColor), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }

    private func pathLabel(_ path: ToolExecutionPath) -> String {
        switch path {
        case .toolCard: return "업무 카드"
        case .chatFastPath: return "채팅 빠른 실행"
        case .planner: return "계획 실행"
        }
    }
}

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
