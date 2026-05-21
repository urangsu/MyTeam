import Foundation

// MARK: - Supertonic3ModelLocator
// Round 248TTS-A: 로컬 모델 파일 탐색 (Manifest 기반).
//
// 정책 (Round 248TTS-A):
// - Supertonic3ModelManifest 기반 파일 탐색 (candidate filenames 지원)
// - ~/Library/Application Support/MyTeam/Models/Supertonic3 먼저 확인
// - ~/.cache/supertonic3/onnx/ 다음 확인
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

        var foundFiles: [String] {
            files.compactMap { $0.foundURL?.lastPathComponent }
        }

        var modelDirectoryExists: Bool {
            FileManager.default.fileExists(atPath: directoryURL.path)
        }

        var redactedDirectory: String {
            if let home = FileManager.default.homeDirectoryForCurrentUser as URL? {
                let path = directoryURL.path
                if let range = path.range(of: home.path) {
                    return "~" + path[range.upperBound...]
                }
            }
            return directoryURL.lastPathComponent
        }
    }

    // MARK: - Public API

    /// 모델 파일 존재 여부 확인 (manifest 기반)
    static func checkModel() -> ModelCheckResult {
        // Try preferred directory first, then fallback
        let preferredDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MyTeam/Models/Supertonic3")
        let fallbackDir = Supertonic3TTSConfig.modelDirectoryURL

        let dirToCheck = FileManager.default.fileExists(atPath: preferredDir.path) ? preferredDir : fallbackDir

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

        return ModelCheckResult(
            directoryURL: dirToCheck,
            files: requiredFound,
            optionalFiles: optionalFound,
            isAvailable: missingFiles.isEmpty,
            missingFiles: missingFiles,
            totalFoundSizeBytes: totalSize
        )
    }

    /// 빠른 가용성 확인
    static func isModelAvailable() -> Bool {
        checkModel().isAvailable
    }

    // MARK: - User-facing Messages

    static func statusMessage() -> String {
        let result = checkModel()
        if result.isAvailable {
            let mb = result.totalFoundSizeBytes / 1_048_576
            return "모델 준비됨 (\(mb) MB, \(result.redactedDirectory))"
        } else if !result.missingFiles.isEmpty {
            return "누락: \(result.missingFiles.joined(separator: ", "))"
        } else {
            return "모델 경로를 설정해야 합니다"
        }
    }

    static func downloadGuideMessage() -> String {
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
        라이선스: MIT + OpenRAIL-M (상업 허용)
        """
    }

    // MARK: - Private Helpers

    private static func checkModelFile(
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
