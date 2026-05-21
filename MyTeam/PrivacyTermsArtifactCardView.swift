import SwiftUI

struct PrivacyTermsArtifactCardView: View {
    let text: String
    let isDarkMode: Bool

    private var parsed: PrivacyTermsParsed { PrivacyTermsParsed(text: text) }

    private var cardFill: Color {
        isDarkMode ? Color.white.opacity(0.08) : Color(red: 0.94, green: 0.96, blue: 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            docTypeRow
            if !parsed.sections.isEmpty {
                sectionsPreview
            }
            if !parsed.customizeItems.isEmpty {
                customizeSection
            }
            if parsed.sections.isEmpty && parsed.customizeItems.isEmpty {
                Text(text)
                    .font(.system(size: 13))
                    .foregroundColor(isDarkMode ? .white : .black)
                    .textSelection(.enabled)
            }
            artifactIndicator
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(cardFill))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.blue.opacity(isDarkMode ? 0.22 : 0.18), lineWidth: 1))
        .frame(maxWidth: 320, alignment: .leading)
    }

    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                    Text("개인정보처리방침·이용약관")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(isDarkMode ? .white : .black)
                }
                Text("AI 생성")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color.blue.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.blue.opacity(0.12)))
            }
            Spacer()
        }
    }

    private var docTypeRow: some View {
        HStack(spacing: 6) {
            ForEach(parsed.docTypes, id: \.self) { dtype in
                Text(dtype)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.10)))
            }
        }
    }

    private var sectionsPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("생성된 섹션")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            ForEach(parsed.sections.prefix(5), id: \.self) { section in
                HStack(spacing: 6) {
                    Image(systemName: "doc.plaintext")
                        .font(.system(size: 10))
                        .foregroundColor(.blue.opacity(0.6))
                    Text(section)
                        .font(.system(size: 12))
                        .foregroundColor(isDarkMode ? .white : .primary)
                }
            }
            if parsed.sections.count > 5 {
                Text("+ \(parsed.sections.count - 5)개 섹션 더...")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var customizeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "pencil.circle")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
                Text("수정 필요 항목")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.orange)
            }
            ForEach(parsed.customizeItems.prefix(4), id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    Text("○")
                        .font(.system(size: 11))
                        .foregroundColor(.orange.opacity(0.7))
                    Text(item)
                        .font(.system(size: 12))
                        .foregroundColor(isDarkMode ? .white.opacity(0.85) : .primary)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.08)))
    }

    private var artifactIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundColor(.green)
            Text("Artifact로 저장됨")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Parser

private struct PrivacyTermsParsed {
    let docTypes: [String]
    let sections: [String]
    let customizeItems: [String]

    init(text: String) {
        let lower = text.lowercased()
        var types: [String] = []
        if lower.contains("개인정보처리방침") { types.append("개인정보처리방침") }
        if lower.contains("이용약관") { types.append("이용약관") }
        if lower.contains("쿠키") { types.append("쿠키 배너") }
        if types.isEmpty { types.append("법률 문서") }

        var sections: [String] = []
        var customizeItems: [String] = []

        let lines = text.components(separatedBy: "\n")
        var inCustomize = false
        for line in lines {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("## ") { sections.append(String(t.dropFirst(3))) }
            else if t.hasPrefix("# ") && !t.hasPrefix("## ") {
                let title = String(t.dropFirst(2))
                if !title.isEmpty { sections.append(title) }
            }
            if t.lowercased().contains("수정 필요") || t.lowercased().contains("customize") {
                inCustomize = true; continue
            }
            if inCustomize && (t.hasPrefix("- ") || t.hasPrefix("• ") || t.hasPrefix("* ")) {
                customizeItems.append(t.replacingOccurrences(of: "^[-•*] ", with: "", options: .regularExpression))
            }
            if inCustomize && t.hasPrefix("#") { inCustomize = false }
        }

        self.docTypes = types
        self.sections = sections
        self.customizeItems = customizeItems
    }
}

#if DEBUG
#Preview {
    PrivacyTermsArtifactCardView(
        text: """
        # 개인정보처리방침

        ## 제1조 (개인정보 수집 목적)
        ## 제2조 (수집하는 개인정보 항목)
        ## 제3조 (개인정보 보유 기간)
        ## 제4조 (개인정보 제3자 제공)

        수정 필요 항목
        - 서비스명 입력
        - 대표자 이름 입력
        - 연락처 정보 추가
        """,
        isDarkMode: false
    )
    .padding()
}
#endif
