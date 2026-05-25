import SwiftUI

struct DocumentBoxView: View {
    @State private var selectedCategory: FileCategory = .allFiles

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Text("파일함")
                        .font(.system(size: 18, weight: .semibold))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()
                    .frame(height: 1)
            }
            .background(Color.white)

            // Category Tabs (KakaoTalk-style)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(FileCategory.allCases, id: \.self) { category in
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(category.color)
                                    .frame(width: 48, height: 48)

                                Text(category.icon)
                                    .font(.system(size: 24))
                            }

                            Text(category.label)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .frame(width: 70)
                        .padding(6)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .onTapGesture {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.white)

            // Files List (Date-organized)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(groupedFiles, id: \.date) { dateGroup in
                        // Date header
                        Text(dateGroup.date)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                        // Files
                        VStack(spacing: 0) {
                            ForEach(dateGroup.files, id: \.name) { file in
                                FileItemView(file: file)

                                Divider()
                                    .padding(.leading, 56)
                                    .opacity(0.3)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            Spacer()
        }
        .background(Color.white)
    }

    var groupedFiles: [(date: String, files: [FileItem])] {
        let allFiles = FileCategory.allFiles()
        let filteredFiles = selectedCategory == .allFiles ?
            allFiles :
            allFiles.filter { $0.category == selectedCategory }

        let grouped = Dictionary(grouping: filteredFiles) { $0.date }
        return grouped.sorted { $0.key > $1.key }
            .map { (date: $0.key, files: $0.value.sorted { $1.name < $0.name }) }
    }
}

enum FileCategory: CaseIterable, Hashable {
    case allFiles
    case phase1A
    case phase1B
    case phase1C
    case documentation
    case scripts

    var label: String {
        switch self {
        case .allFiles: return "전체"
        case .phase1A: return "Phase 1A"
        case .phase1B: return "Phase 1B"
        case .phase1C: return "Phase 1C"
        case .documentation: return "Docs"
        case .scripts: return "Scripts"
        }
    }

    var icon: String {
        switch self {
        case .allFiles: return "📁"
        case .phase1A: return "📄"
        case .phase1B: return "📊"
        case .phase1C: return "📝"
        case .documentation: return "📚"
        case .scripts: return "⚙️"
        }
    }

    var color: Color {
        switch self {
        case .allFiles: return Color(.systemGray3)
        case .phase1A: return Color(red: 0.2, green: 0.6, blue: 1)
        case .phase1B: return Color(red: 0.2, green: 0.85, blue: 0.2)
        case .phase1C: return Color(red: 1, green: 0.5, blue: 0.2)
        case .documentation: return Color(red: 0.5, green: 0.3, blue: 0.8)
        case .scripts: return Color(red: 0.6, green: 0.6, blue: 0.6)
        }
    }

    static func allFiles() -> [FileItem] {
        return [
            // Phase 1A (PDF) - 2026.5.23
            FileItem(
                name: "PDFFileExtractor.swift",
                size: "5.2 KB",
                date: "2026.5.23",
                icon: "📄",
                category: .phase1A
            ),
            FileItem(
                name: "PDFFileIntakeSpecification.md",
                size: "9.1 KB",
                date: "2026.5.23",
                icon: "📋",
                category: .documentation
            ),
            FileItem(
                name: "preflight_round279_pdf_intake.sh",
                size: "2.0 KB",
                date: "2026.5.23",
                icon: "✓",
                category: .scripts
            ),

            // Phase 1B (XLSX) - 2026.5.24
            FileItem(
                name: "XLSXFileExtractor.swift",
                size: "4.8 KB",
                date: "2026.5.24",
                icon: "📊",
                category: .phase1B
            ),
            FileItem(
                name: "XLSXFileIntakeSpecification.md",
                size: "7.6 KB",
                date: "2026.5.24",
                icon: "📋",
                category: .documentation
            ),
            FileItem(
                name: "preflight_round279_xlsx_intake.sh",
                size: "2.3 KB",
                date: "2026.5.24",
                icon: "✓",
                category: .scripts
            ),

            // Phase 1C (DOCX) - 2026.5.25
            FileItem(
                name: "DOCXFileExtractor.swift",
                size: "3.5 KB",
                date: "2026.5.25",
                icon: "⚙️",
                category: .phase1C
            ),
            FileItem(
                name: "DOCXFileIntakeSpecification.md",
                size: "8.2 KB",
                date: "2026.5.25",
                icon: "📋",
                category: .documentation
            ),
            FileItem(
                name: "preflight_round279_docx_intake.sh",
                size: "2.1 KB",
                date: "2026.5.25",
                icon: "✓",
                category: .scripts
            ),
        ]
    }
}

struct FileItem: Identifiable {
    let id = UUID()
    let name: String
    let size: String
    let date: String
    let icon: String
    let category: FileCategory
}

struct FileItemView: View {
    let file: FileItem

    var body: some View {
        HStack(spacing: 12) {
            Text(file.icon)
                .font(.system(size: 24))

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black)

                Text(file.size)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

#Preview {
    DocumentBoxView()
}
