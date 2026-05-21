import SwiftUI

struct AccountingTaxSummaryCardView: View {
    let text: String
    let isDarkMode: Bool

    private var parsed: AccountingTaxParsed { AccountingTaxParsed(text: text) }

    private var cardFill: Color {
        isDarkMode ? Color.white.opacity(0.08) : Color(red: 0.93, green: 0.98, blue: 0.96)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            if !parsed.taxType.isEmpty {
                taxTypeRow
            }
            if !parsed.lineItems.isEmpty {
                calculationTable
            }
            if !parsed.notes.isEmpty {
                notesSection
            }
            if parsed.lineItems.isEmpty && parsed.notes.isEmpty {
                Text(text)
                    .font(.system(size: 13))
                    .foregroundColor(isDarkMode ? .white : .black)
                    .textSelection(.enabled)
            }
            // Disclaimer — always visible (policy-critical)
            disclaimer
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(cardFill))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.teal.opacity(isDarkMode ? 0.22 : 0.18), lineWidth: 1))
        .frame(maxWidth: 320, alignment: .leading)
    }

    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "percent")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.teal)
                    Text("세금·세무 계산 참고")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(isDarkMode ? .white : .black)
                }
                Text("참고용 계산")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color.teal.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.teal.opacity(0.14)))
            }
            Spacer()
        }
    }

    private var taxTypeRow: some View {
        HStack(spacing: 6) {
            Text(parsed.taxType)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.teal)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.teal.opacity(0.10)))
            if !parsed.taxRate.isEmpty {
                Text(parsed.taxRate)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.teal)
            }
        }
    }

    private var calculationTable: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("계산 내역")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            ForEach(parsed.lineItems.indices, id: \.self) { idx in
                let item = parsed.lineItems[idx]
                HStack {
                    Text(item.label)
                        .font(.system(size: 12))
                        .foregroundColor(isDarkMode ? .white.opacity(0.85) : .primary)
                    Spacer()
                    Text(item.amount)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(item.isTotal ? .teal : (isDarkMode ? .white : .black))
                }
                .padding(.vertical, 3)
                if item.isTotal {
                    Divider().opacity(0.4)
                }
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("참고 사항")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            ForEach(parsed.notes.prefix(3), id: \.self) { note in
                HStack(alignment: .top, spacing: 6) {
                    Text("·")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(note)
                        .font(.system(size: 12))
                        .foregroundColor(isDarkMode ? .white.opacity(0.8) : .secondary)
                }
            }
        }
    }

    // Always visible — legal disclaimer (non-collapsible; removing or wrapping in DisclosureGroup is prohibited)
    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundColor(.orange)
            Text("세무·회계 판단은 실제 증빙과 계약 구조에 따라 달라질 수 있으므로 전문가 확인이 필요합니다.")
                .font(.system(size: 11))
                .foregroundColor(.orange.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.08)))
    }
}

// MARK: - Parser

private struct AccountingTaxParsed {
    struct LineItem {
        let label: String
        let amount: String
        let isTotal: Bool
    }

    let taxType: String
    let taxRate: String
    let lineItems: [LineItem]
    let notes: [String]

    init(text: String) {
        let lines = text.components(separatedBy: "\n")
        var taxType = ""
        var taxRate = ""
        var lineItems: [LineItem] = []
        var notes: [String] = []
        var inNotes = false

        let taxKeywords = ["부가가치세", "VAT", "소득세", "종합소득세", "법인세", "원천세", "지방세", "재산세", "취득세"]
        for kw in taxKeywords {
            if text.contains(kw) { taxType = kw; break }
        }

        let ratePattern = #"(\d+(\.\d+)?%)"#
        if let range = text.range(of: ratePattern, options: .regularExpression) {
            taxRate = String(text[range])
        }

        for line in lines {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.isEmpty { continue }
            if t.lowercased().contains("참고") || t.lowercased().contains("note") {
                inNotes = true; continue
            }
            if t.hasPrefix("#") { inNotes = false; continue }

            if inNotes && (t.hasPrefix("- ") || t.hasPrefix("• ")) {
                notes.append(t.replacingOccurrences(of: "^[-•] ", with: "", options: .regularExpression))
            }

            // Parse "label: amount" or table rows
            if t.hasPrefix("|") {
                let cols = t.split(separator: "|", omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                if cols.count >= 3 {
                    let label = cols.indices.contains(1) ? cols[1] : ""
                    let amount = cols.indices.contains(2) ? cols[2] : ""
                    if !label.isEmpty && !amount.isEmpty && !label.lowercased().contains("항목") {
                        let isTotal = label.contains("합계") || label.contains("총") || label.contains("납부")
                        lineItems.append(LineItem(label: label, amount: amount, isTotal: isTotal))
                    }
                }
            } else if t.contains(":") {
                let parts = t.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count == 2 {
                    let amountRegex = #"[\d,\.]+\s*(원|만원|억|%)"#
                    if let _ = parts[1].range(of: amountRegex, options: .regularExpression) {
                        let isTotal = parts[0].contains("합계") || parts[0].contains("총") || parts[0].contains("납부")
                        lineItems.append(LineItem(label: parts[0], amount: parts[1], isTotal: isTotal))
                    }
                }
            }
        }

        self.taxType = taxType
        self.taxRate = taxRate
        self.lineItems = lineItems
        self.notes = notes
    }
}

#if DEBUG
#Preview {
    AccountingTaxSummaryCardView(
        text: """
        # 부가가치세 계산

        공급가액: 1,000,000원
        부가가치세 (10%): 100,000원
        합계: 1,100,000원

        참고
        - 과세사업자 기준입니다
        - 면세 품목은 제외됩니다
        """,
        isDarkMode: false
    )
    .padding()
}
#endif
