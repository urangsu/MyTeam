import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct FileIntakeView: View {
    @Environment(\.dismiss) private var dismiss
    let onResult: (FileIntakeResult) -> Void
    let onPromptAction: ((String) -> Void)?

    @State private var isImporting = false
    @State private var isDropTargeted = false
    @State private var lastResult: FileIntakeResult?
    @State private var statusMessage = "txt, md, csv 파일을 먼저 지원합니다."

    init(
        onResult: @escaping (FileIntakeResult) -> Void,
        onPromptAction: ((String) -> Void)? = nil
    ) {
        self.onResult = onResult
        self.onPromptAction = onPromptAction
    }

    private var allowedTypes: [UTType] {
        [.item]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("파일로 작업하기")
                        .font(.system(size: 17, weight: .semibold))
                    Text("txt, md, csv 파일을 먼저 지원합니다.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.secondary.opacity(0.05))
                    )
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "tray.and.arrow.down")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text("파일을 여기에 놓기")
                                .font(.system(size: 12, weight: .medium))
                            Text("PDF, Word, Excel, PPT는 준비 중입니다.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .padding(18)
                    }
                    .frame(height: 140)
                    .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                        loadFirstURL(from: providers)
                        return true
                    }

                Button("파일 선택") {
                    isImporting = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Text(statusMessage)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if let result = lastResult {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(result.request.originalFilename)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(statusLabel(for: result.status))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.secondary.opacity(0.12)))
                    }

                    HStack(spacing: 8) {
                        Text("상태: \(result.status.rawValue)")
                        Text("크기: \(ByteCountFormatter.string(fromByteCount: result.request.fileSizeBytes, countStyle: .file))")
                        if let extractedText = result.extractedText {
                            Text("문자 수: \(extractedText.count)")
                        }
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                    Text(result.userMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    if result.status == .ready, let extractedText = result.extractedText, !extractedText.isEmpty {
                        let previewText = String(extractedText.prefix(500))
                        ScrollView {
                            Text(previewText)
                                .font(.system(size: 11, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .frame(height: 110)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.06)))

                        VStack(alignment: .leading, spacing: 6) {
                            Text("다음 작업")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)

                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 108), spacing: 6)],
                                alignment: .leading,
                                spacing: 6
                            ) {
                                followUpButton(title: "이 파일 요약하기", prompt: "이 파일 요약해줘")
                                followUpButton(title: "보고서로 만들기", prompt: "이 파일 보고서로 만들어줘")
                                followUpButton(title: "체크리스트 만들기", prompt: "이 파일 체크리스트 만들어줘")
                                followUpButton(title: "표로 정리하기", prompt: "이 파일 내용을 표로 정리해줘")
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: 460, height: 380)
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: allowedTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    handle(url: url, source: .filePicker)
                }
            case .failure:
                statusMessage = "파일 선택을 취소했습니다."
            }
        }
    }

    private func loadFirstURL(from providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            DispatchQueue.main.async {
                self.handle(url: url, source: .dragAndDrop)
            }
        }
    }

    private func handle(url: URL, source: FileIntakeRequest.Source) {
        do {
            let request = try FileIntakeService.makeRequest(fileURL: url, source: source)
            let result = FileIntakeService.readText(from: request)
            lastResult = result
            statusMessage = result.userMessage
            onResult(result)
        } catch {
            let fallbackMessage = "파일을 읽지 못했습니다. 권한이 없거나 지원하지 않는 인코딩일 수 있습니다."
            let request = FileIntakeRequest(
                id: UUID(),
                source: source,
                fileURL: url,
                originalFilename: url.lastPathComponent,
                fileExtension: url.pathExtension.lowercased(),
                fileSizeBytes: 0,
                requestedDocumentType: nil,
                createdAt: Date()
            )
            let result = FileIntakeResult(
                status: .readFailed,
                request: request,
                extractedText: nil,
                userMessage: fallbackMessage
            )
            lastResult = result
            statusMessage = result.userMessage
            onResult(result)
        }
    }

    private func statusLabel(for status: FileIntakeResult.Status) -> String {
        switch status {
        case .ready: return "준비됨"
        case .planned: return "준비 중"
        case .blocked: return "차단됨"
        case .tooLarge: return "용량 초과"
        case .readFailed: return "읽기 실패"
        case .empty: return "빈 파일"
        case .unsupported: return "미지원"
        }
    }

    @ViewBuilder
    private func followUpButton(title: String, prompt: String) -> some View {
        Button {
            onPromptAction?(prompt)
        } label: {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundStyle(.primary)
                .background(
                    Capsule()
                        .fill(Color.secondary.opacity(0.10))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(prompt)
    }
}
