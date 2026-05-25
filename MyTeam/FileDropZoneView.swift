import SwiftUI
import UniformTypeIdentifiers

struct FileDropZoneView: View {
    @State private var isTargeted = false
    @State private var processingFile: FileIntakeRequest?
    @State private var result: FileIntakeResult?
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("파일 처리")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                if let error = errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            .padding(16)
            .background(Color(.controlBackgroundColor))

            Divider()

            // Main content
            ZStack {
                // Drop zone
                dropZoneView
                    .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                        handleDrop(providers: providers)
                        return true
                    }

                // Result view (overlays drop zone if file processed)
                if let result = result {
                    resultView(for: result)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.controlBackgroundColor))
    }

    // MARK: - Drop Zone View

    private var dropZoneView: some View {
        VStack(spacing: 16) {
            if isProcessing {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.5, anchor: .center)
                    Text("파일 처리 중...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            } else {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.teal.opacity(0.6))

                VStack(spacing: 4) {
                    Text("파일을 여기로 드래그하세요")
                        .font(.system(size: 16, weight: .semibold))
                    Text("PDF, XLSX, DOCX, TXT 등")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    style: StrokeStyle(lineWidth: 2, dash: [8])
                )
                .foregroundColor(.teal.opacity(isTargeted ? 0.8 : 0.3))
        )
        .background(
            Color.teal.opacity(isTargeted ? 0.05 : 0.01)
        )
        .padding(16)
    }

    // MARK: - Result View

    @ViewBuilder
    private func resultView(for result: FileIntakeResult) -> some View {
        VStack(spacing: 12) {
            // Status indicator
            HStack(spacing: 8) {
                Image(systemName: statusIcon(for: result.status))
                    .foregroundColor(statusColor(for: result.status))
                    .font(.system(size: 16, weight: .semibold))

                Text(result.request.originalFilename)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                Button(action: resetView) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("다른 파일 처리")
            }
            .padding(12)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)

            // Content display
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // File metadata
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 12) {
                            Text("파일 크기")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 50, alignment: .leading)
                            Text(formatFileSize(result.request.fileSizeBytes))
                                .font(.system(size: 11, design: .monospaced))
                        }
                        HStack(spacing: 12) {
                            Text("확장자")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 50, alignment: .leading)
                            Text(result.request.fileExtension.uppercased())
                                .font(.system(size: 11, design: .monospaced))
                        }
                    }
                    .padding(8)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(6)

                    // Status message
                    if !result.userMessage.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.blue)
                            Text(result.userMessage)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                    }

                    // Extracted content
                    if let text = result.extractedText, !text.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("추출된 내용")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)

                            TextEditor(text: .constant(text))
                                .font(.system(size: 11, design: .monospaced))
                                .frame(minHeight: 150)
                                .background(Color(.controlBackgroundColor))
                                .cornerRadius(6)
                                .lineLimit(.max)
                        }
                    }
                }
                .padding(12)
            }

            // Action buttons
            HStack(spacing: 12) {
                if let text = result.extractedText, !text.isEmpty {
                    Button(action: copyToClipboard) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.doc")
                            Text("복사")
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                Button(action: resetView) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("다시")
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
            }
            .padding(12)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
        .padding(16)
    }

    // MARK: - File Handling

    private func handleDrop(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }

        provider.loadFileRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { url, error in
            guard let url = url, error == nil else {
                DispatchQueue.main.async {
                    self.errorMessage = "파일을 읽을 수 없습니다"
                }
                return
            }

            DispatchQueue.main.async {
                self.processFile(url: url)
            }
        }
    }

    private func processFile(url: URL) {
        isProcessing = true
        errorMessage = nil
        result = nil

        Task {
            do {
                // Create intake request
                let request = try FileIntakeService.makeRequest(
                    fileURL: url,
                    source: .dragAndDrop
                )

                // Read and process file
                let intakeResult = FileIntakeService.readText(from: request)

                // Update UI
                DispatchQueue.main.async {
                    self.processingFile = request
                    self.result = intakeResult
                    self.isProcessing = false

                    // Show error if processing failed
                    if intakeResult.status == .readFailed {
                        self.errorMessage = intakeResult.userMessage
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isProcessing = false
                }
            }
        }
    }

    private func resetView() {
        result = nil
        processingFile = nil
        errorMessage = nil
    }

    private func copyToClipboard() {
        guard let text = result?.extractedText else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    // MARK: - Helpers

    private func statusIcon(for status: FileIntakeResult.Status) -> String {
        switch status {
        case .ready: return "checkmark.circle.fill"
        case .blocked: return "xmark.circle.fill"
        case .tooLarge: return "exclamationmark.circle.fill"
        case .empty: return "doc.circle.fill"
        case .readFailed: return "exclamationmark.triangle.fill"
        case .planned: return "clock.circle.fill"
        }
    }

    private func statusColor(for status: FileIntakeResult.Status) -> Color {
        switch status {
        case .ready: return .green
        case .blocked: return .red
        case .tooLarge: return .orange
        case .empty: return .gray
        case .readFailed: return .red
        case .planned: return .blue
        }
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

#Preview {
    FileDropZoneView()
        .frame(width: 600, height: 400)
}
