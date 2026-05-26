import SwiftUI
import AppKit

struct ConnectorStatusView: View {
    let health: ConnectorHealth
    var onRefresh: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("커넥터 상태")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                if let onRefresh {
                    Button {
                        onRefresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("상태 새로고침")
                }
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], alignment: .leading, spacing: 8) {
                connectorRow(title: "주가", status: health.stockQuote)
                connectorRow(title: "뉴스", status: health.newsSearch)
                connectorRow(title: "공시", status: health.disclosureSearch)
                connectorRow(title: "웹 조회", status: health.webFetch)
                connectorRow(title: "PDF 텍스트", status: health.pdfText)
                connectorRow(title: "이미지 OCR", status: health.imageOCR)
                connectorRow(title: "메일 읽기", status: health.mailRead)
                connectorRow(title: "캘린더 초안", status: health.calendarDraft)
                connectorRow(title: "지도", status: health.mapsSearch)
                connectorRow(title: "열차", status: health.trainSearch)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
        .cornerRadius(10)
    }

    @ViewBuilder
    private func connectorRow(title: String, status: ConnectorStatus) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                Text(status.label)
                    .font(.system(size: 10))
                    .foregroundStyle(statusColor(status).opacity(0.85))
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(statusColor(status).opacity(0.08))
        .cornerRadius(8)
        .help(status.reason ?? status.label)
    }

    private func statusColor(_ status: ConnectorStatus) -> Color {
        switch status {
        case .available:
            return .green
        case .approvalRequired:
            return .blue
        case .needsSetup:
            return .orange
        case .degraded:
            return .yellow
        case .unavailable:
            return .red
        }
    }
}
