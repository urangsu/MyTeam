import Foundation

// MARK: - Supertonic3ModelLocator
// Round 248TTS-A: 로컬 모델 파일 탐색 (Manifest 기반).
//
// 정책 (Round 248TTS-A):
// - Supertonic3ModelManifest 기반 파일 탐색 (candidate filenames 지원)
// - App Store / Direct: bundled Resources/Supertonic3/onnx only
// - Developer: external ~/.cache/supertonic3/onnx allowed for iteration
// - 파일 크기 > 0 체크 (유효성 확인)
// - 자동 다운로드 없음 — 사용자가 직접 다운로드
// - full path 일반 UI에 노출 안 함 (redacted path 사용)

enum Supertonic3ModelLocator {

    // MARK: - Model File Check Result

    struct ModelFileCheck: Sendable {
        let logicalName: String
        let foundURL: URL?
        let missingCandidates: [String]
    }

    // MARK: - Model Check Result

    struct ModelCheckResult: Sendable {
        let directoryURL: URL
        let files: [ModelFileCheck]
        let optionalFiles: [ModelFileCheck]
        let isAvailable: Bool
        let missingFiles: [String]
        let totalFoundSizeBytes: Int64
        let source: Supertonic3ModelSource

        /// Safe nonisolated placeholder used as @State default in SwiftUI views.
        /// Avoids @MainActor isolation inference from FileManager calls.
        /// Replaced with real data in .onAppear / .task.
        static let checking = ModelCheckResult(
            directoryURL: URL(fileURLWithPath: NSHomeDirectory() + "/.cache/supertonic3/onnx"),
            files: [],
            optionalFiles: [],
            isAvailable: false,
            missingFiles: [],
            totalFoundSizeBytes: 0,
            source: .externalCacheDeveloperOnly
        )

        nonisolated var foundFiles: [String] {
            files.compactMap { $0.foundURL?.lastPathComponent }
        }

        nonisolated var modelDirectoryExists: Bool {
            FileManager.default.fileExists(atPath: directoryURL.path)
        }

        nonisolated var redactedDirectory: String {
            if let home = FileManager.default.homeDirectoryForCurrentUser as URL? {
                let path = directoryURL.path
                if let range = path.range(of: home.path) {
                    return "~" + path[range.upperBound...]
                }
            }
            return directoryURL.lastPathComponent
        }

        nonisolated var sourceLabel: String {
            switch source {
            case .bundled:
                return "bundled"
            case .appSupport:
                return "app support"
            case .externalCacheDeveloperOnly:
                return "developer external cache"
            }
        }
    }

    // MARK: - Public API

    /// 모델 파일 존재 여부 확인 (manifest 기반)
    nonisolated static func checkModel() -> ModelCheckResult {
        let source = Supertonic3ModelSourcePolicy.preferredSource
        let dirToCheck: URL
        let voiceStylesDir: URL
        do {
            switch source {
            case .bundled:
                dirToCheck = try Supertonic3BundledModelLocator.modelDirectoryURL()
                voiceStylesDir = try Supertonic3BundledModelLocator.voiceStylesDirectoryURL()
            case .appSupport:
                dirToCheck = try Supertonic3AppSupportModelLocator.modelDirectoryURL()
                voiceStylesDir = try Supertonic3AppSupportModelLocator.voiceStylesDirectoryURL()
            case .externalCacheDeveloperOnly:
                dirToCheck = try Supertonic3ExternalCacheModelLocator.modelDirectoryURL()
                voiceStylesDir = try Supertonic3ExternalCacheModelLocator.voiceStylesDirectoryURL()
            }
        } catch {
            return unavailableResult(source: source, directoryURL: placeholderDirectory(for: source), missingFiles: [error.localizedDescription])
        }

        var requiredFound: [ModelFileCheck] = []
        var optionalFound: [ModelFileCheck] = []
        var missingFiles: [String] = []
        var totalSize: Int64 = 0

        // Check required files
        for requiredFile in Supertonic3ModelManifest.requiredFiles {
            let check = checkModelFile(
                logicalName: requiredFile.logicalName,
                candidates: requiredFile.candidateFilenames,
                in: dirToCheck
            )
            requiredFound.append(check)

            if let foundURL = check.foundURL {
                if let attrs = try? FileManager.default.attributesOfItem(atPath: foundURL.path),
                   let size = attrs[.size] as? Int64 {
                    totalSize += size
                }
            } else if requiredFile.required {
                missingFiles.append(requiredFile.logicalName)
            }
        }

        // Check optional files
        for optionalFile in Supertonic3ModelManifest.optionalFiles {
            let check = checkModelFile(
                logicalName: optionalFile.logicalName,
                candidates: optionalFile.candidateFilenames,
                in: dirToCheck
            )
            optionalFound.append(check)
        }

        for preset in Supertonic3TTSConfig.availableVoicePresets {
            let url = voiceStylesDir.appendingPathComponent("\(preset).json")
            if !FileManager.default.fileExists(atPath: url.path) {
                missingFiles.append("voice_styles/\(preset).json")
            }
        }

        return ModelCheckResult(
            directoryURL: dirToCheck,
            files: requiredFound,
            optionalFiles: optionalFound,
            isAvailable: missingFiles.isEmpty,
            missingFiles: missingFiles,
            totalFoundSizeBytes: totalSize,
            source: source
        )
    }

    /// 빠른 가용성 확인
    nonisolated static func isModelAvailable() -> Bool {
        checkModel().isAvailable
    }

    // MARK: - User-facing Messages

    nonisolated static func statusMessage() -> String {
        let result = checkModel()
        if result.isAvailable {
            let mb = result.totalFoundSizeBytes / 1_048_576
            return "모델 준비됨 (\(mb) MB, \(result.sourceLabel), \(result.redactedDirectory))"
        } else if !result.missingFiles.isEmpty {
            return "누락: \(result.missingFiles.joined(separator: ", "))"
        } else {
            return "모델 경로를 설정해야 합니다"
        }
    }

    nonisolated static func downloadGuideMessage() -> String {
        """
        Supertonic3 모델 다운로드 방법:

        1. Python 권장:
           pip install supertonic
           python -c "from supertonic import TTS; model = TTS(model_name='supertonic-3', gpu=False); print(model.synthesize('안녕', language='ko'))"

        2. 직접 HuggingFace에서:
           huggingface-cli download Supertone/supertonic-3 --include 'onnx/*'
           → ~/.cache/supertonic3/onnx/ 에 자동 저장

        3. MyTeam 설정:
           Settings > Developer Lab > TTS > Supertonic3 Model Path
           → 다운로드한 model_name/onnx 경로 선택

        필요 파일:
        - text_encoder.onnx (또는 encoder.onnx)
        - duration_predictor.onnx (또는 duration.onnx)
        - vector_estimator.onnx (또는 estimator.onnx)
        - vocoder.onnx

        총 용량 (~398 MB)
        라이선스/상업 사용/모델 재배포/App Store 번들 정책은 제품 gate에서 별도 검토해야 합니다.
        """
    }

    // MARK: - Private Helpers

    nonisolated private static func unavailableResult(
        source: Supertonic3ModelSource,
        directoryURL: URL,
        missingFiles: [String]
    ) -> ModelCheckResult {
        ModelCheckResult(
            directoryURL: directoryURL,
            files: [],
            optionalFiles: [],
            isAvailable: false,
            missingFiles: missingFiles,
            totalFoundSizeBytes: 0,
            source: source
        )
    }

    nonisolated private static func placeholderDirectory(for source: Supertonic3ModelSource) -> URL {
        switch source {
        case .bundled:
            return URL(fileURLWithPath: "/__missing_bundled_supertonic3__/onnx", isDirectory: true)
        case .appSupport:
            return URL(fileURLWithPath: "/__missing_app_support_supertonic3__/onnx", isDirectory: true)
        case .externalCacheDeveloperOnly:
            return URL(fileURLWithPath: "/__external_cache_not_allowed__/onnx", isDirectory: true)
        }
    }

    nonisolated private static func checkModelFile(
        logicalName: String,
        candidates: [String],
        in directory: URL
    ) -> ModelFileCheck {
        for candidate in candidates {
            let fileURL = directory.appendingPathComponent(candidate)
            if FileManager.default.fileExists(atPath: fileURL.path),
               let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let size = attrs[.size] as? Int64,
               size > 0 {
                return ModelFileCheck(
                    logicalName: logicalName,
                    foundURL: fileURL,
                    missingCandidates: []
                )
            }
        }

        return ModelFileCheck(
            logicalName: logicalName,
            foundURL: nil,
            missingCandidates: candidates
        )
    }
}
