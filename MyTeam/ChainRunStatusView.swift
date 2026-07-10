import SwiftUI
import AppKit

struct ChainRunStatusView: View {
    let chainRun: ChainRun
    let isDarkMode: Bool

    @State private var selectedSnapshot: BrowserSnapshotRecord? = nil
    @State private var showMissingAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(chainRun.chainID.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Text(chainRun.statusSummary)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(statusColor(chainRun.status))
            }

            HStack(spacing: 8) {
                pill(chainRun.sourceSummary, color: .blue)
                pill(chainRun.actionSummary, color: .purple)
                pill(chainRun.artifactSummary, color: .green)
                if browserSourceCount > 0 {
                    pill("브라우저 \(browserSourceCount)", color: .orange)
                }
            }

            if !browserSources.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(browserSources.prefix(3), id: \.id) { source in
                        Button {
                            if let snapshotID = source.snapshotID {
                                if let record = BrowserSnapshotStore.shared.get(snapshotID) {
                                    selectedSnapshot = record
                                } else {
                                    showMissingAlert = true
                                }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "globe")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.orange)
                                Text(source.title)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                if source.snapshotID != nil {
                                    Text("(DOM)")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(source.snapshotID == nil)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(chainRun.steps.enumerated()), id: \.element.id) { index, step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 16, height: 16)
                            .foregroundStyle(statusColor(step.status))
                            .background(statusColor(step.status).opacity(0.12))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(isDarkMode ? .white : .primary)
                                .lineLimit(1)
                            HStack(spacing: 6) {
                                Text(step.status.label)
                                    .font(.system(size: 9))
                                    .foregroundStyle(statusColor(step.status))
                                if let connectorID = step.connectorID, !connectorID.isEmpty {
                                    Text(connectorID)
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                if let durationText = step.durationText {
                                    Text(durationText)
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                if let summary = step.outputSummary, !summary.isEmpty {
                                    Text(summary)
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            if let detail = step.detail, !detail.isEmpty {
                                Text(detail)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            if let failureDetail = step.failureDetail, !failureDetail.isEmpty {
                                Text(ChainRun.userFacingFailureMessage(for: failureDetail))
                                    .font(.system(size: 9))
                                    .foregroundStyle(.red)
                                    .lineLimit(1)
                            }
                            if !step.sourceIDs.isEmpty {
                                Text("sources \(step.sourceIDs.count)")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(isDarkMode ? 0.35 : 0.55))
        .cornerRadius(10)
        .sheet(item: $selectedSnapshot) { record in
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.title ?? "브라우저 스냅샷")
                            .font(.headline)
                        Text(record.url)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("닫기") {
                        selectedSnapshot = nil
                    }
                }
                .padding([.top, .horizontal])

                Divider()

                ScrollView {
                    Text(record.text)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(NSColor.textBackgroundColor))
            }
            .frame(minWidth: 600, minHeight: 400)
        }
        .alert("스냅샷 없음", isPresented: $showMissingAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("이 브라우저 snapshot은 현재 세션에 남아 있지 않습니다. 다시 조회해 주세요.")
        }
    }

    private func statusColor(_ status: ChainStepStatus) -> Color {
        switch status {
        case .pending:
            return .secondary
        case .running:
            return .blue
        case .evidenceAvailable:
            return .teal
        case .planned:
            return .secondary
        case .succeeded:
            return .green
        case .failed:
            return .red
        case .skipped:
            return .orange
        }
    }

    private var browserSources: [ChainSourceReference] {
        chainRun.sources.filter { source in
            source.snapshotID != nil
                || source.provider.lowercased().contains("playwright")
                || source.sourceType == .browserDOM
                || source.sourceType == .trainSchedule
                || source.sourceType == .mapRoute
        }
    }

    private var browserSourceCount: Int {
        browserSources.count
    }

    private func pill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .cornerRadius(999)
            .lineLimit(1)
    }

    private func statusColor(_ status: ChainStatus) -> Color {
        switch status {
        case .pending:
            return .secondary
        case .running:
            return .blue
        case .projected:
            return .teal
        case .succeeded:
            return .green
        case .failed:
            return .red
        case .blocked:
            return .orange
        }
    }
}
