import SwiftUI

struct DiagnosticsResultCardView: View {
    let text: String
    let isDarkMode: Bool

    @State private var isExpanded = false

    private var parsed: DiagnosticsParsed { DiagnosticsParsed(text: text) }

    private var cardFill: Color {
        isDarkMode ? Color.white.opacity(0.08) : Color(red: 0.95, green: 0.95, blue: 0.97)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            summaryRow
            if isExpanded {
                Divider().opacity(0.4)
                detailRows
            }
            expandToggle
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(cardFill))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(isDarkMode ? 0.22 : 0.18), lineWidth: 1))
        .frame(maxWidth: 320, alignment: .leading)
    }

    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "stethoscope")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.indigo)
                    Text("시스템 진단")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(isDarkMode ? .white : .black)
                }
                Text("디버그")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color.indigo.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.indigo.opacity(0.12)))
            }
            Spacer()
            healthDot(parsed.overallHealth)
        }
    }

    private var summaryRow: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ], spacing: 8) {
            ForEach(parsed.summary.prefix(4), id: \.label) { item in
                HStack(spacing: 6) {
                    healthDot(item.health)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(item.value)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(isDarkMode ? .white : .black)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(isDarkMode ? 0.2 : 0.04)))
            }
        }
    }

    private var detailRows: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(parsed.details, id: \.label) { item in
                HStack(spacing: 8) {
                    healthDot(item.health)
                    Text(item.label)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(item.value)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isDarkMode ? .white : .black)
                        .lineLimit(1)
                }
            }
            if parsed.details.isEmpty {
                Text(text)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var expandToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() }
        } label: {
            HStack(spacing: 4) {
                Text(isExpanded ? "접기" : "상세 보기")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.indigo)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(.indigo)
            }
        }
        .buttonStyle(.plain)
    }

    private func healthDot(_ health: DiagnosticsHealth) -> some View {
        Circle()
            .fill(health.color)
            .frame(width: 8, height: 8)
    }
}

// MARK: - Data Model

enum DiagnosticsHealth {
    case good, warning, error, unknown
    var color: Color {
        switch self {
        case .good: return .green
        case .warning: return .orange
        case .error: return .red
        case .unknown: return .gray
        }
    }
}

private struct DiagnosticItem {
    let label: String
    let value: String
    let health: DiagnosticsHealth
}

private struct DiagnosticsParsed {
    let overallHealth: DiagnosticsHealth
    let summary: [DiagnosticItem]
    let details: [DiagnosticItem]

    init(text: String) {
        let lines = text.components(separatedBy: "\n")
        var items: [DiagnosticItem] = []

        for line in lines {
            let t = line.trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty && !t.hasPrefix("#") && !t.hasPrefix("---") else { continue }

            // Parse "key: value" or "key — value" format
            for sep in [":", "—", "-"] {
                if let range = t.range(of: sep) {
                    let label = String(t[t.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                    let value = String(t[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                    if !label.isEmpty && !value.isEmpty {
                        let health: DiagnosticsHealth
                        let lower = value.lowercased()
                        if lower.contains("pass") || lower.contains("ok") || lower.contains("✅") || lower.contains("true") {
                            health = .good
                        } else if lower.contains("warn") || lower.contains("⚠") || lower.contains("yellow") {
                            health = .warning
                        } else if lower.contains("fail") || lower.contains("error") || lower.contains("❌") {
                            health = .error
                        } else {
                            health = .unknown
                        }
                        items.append(DiagnosticItem(label: label, value: value, health: health))
                        break
                    }
                }
            }
        }

        let errorCount = items.filter { $0.health == .error }.count
        let warnCount = items.filter { $0.health == .warning }.count
        if errorCount > 0 { self.overallHealth = .error }
        else if warnCount > 0 { self.overallHealth = .warning }
        else if !items.isEmpty { self.overallHealth = .good }
        else { self.overallHealth = .unknown }

        self.summary = Array(items.prefix(4))
        self.details = items.count > 4 ? Array(items.dropFirst(4)) : []
    }
}

#if DEBUG
#Preview {
    DiagnosticsResultCardView(
        text: """
        빌드 설정: Release
        워크플로우 실행 중: false
        Artifact 상태: PASS
        Artifact 총 개수: 12
        유효 Artifact: 12
        누락 파일: 0
        """,
        isDarkMode: false
    )
    .padding()
}
#endif
