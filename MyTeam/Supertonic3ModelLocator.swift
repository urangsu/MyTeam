import Foundation

// MARK: - Supertonic3ModelLocator
// Round 247TTS-SUPERTONIC3-POC: 로컬 모델 파일 탐색.
//
// 정책:
// - ~/.cache/supertonic3/onnx/ 경로에서 4개 ONNX 파일 존재 여부만 확인
// - 파일 내용 검증 없음 (파일 크기 > 0 체크만)
// - 자동 다운로드 없음 — 사용자가 직접 HuggingFace에서 다운로드
// - 모델 없어도 앱 시작 지연 없음 (앱 시작 시 탐색 안 함)

enum Supertonic3ModelLocator {

    // MARK: - ModelCheckResult

    struct ModelCheckResult: Sendable {
        let isAvailable: Bool        // true = 4개 파일 모두 존재 && 각 파일 크기 > 0
        let missingFiles: [String]   // 없는 파일 목록
        let foundFiles: [String]     // 있는 파일 목록
        let modelDirectoryExists: Bool
        let totalFoundSizeBytes: Int64
    }

    // MARK: - Public API

    /// 모델 파일 존재 여부 확인 (비동기 없음, 파일 I/O만)
    static func checkModel() -> ModelCheckResult {
        let dir = Supertonic3TTSConfig.modelDirectoryURL
        let fm = FileManager.default

        let dirExists = fm.fileExists(atPath: dir.path)
        var found: [String] = []
        var missing: [String] = []
        var totalSize: Int64 = 0

        for filename in Supertonic3TTSConfig.requiredModelFiles {
            let fileURL = dir.appendingPathComponent(filename)
            if fm.fileExists(atPath: fileURL.path),
               let attrs = try? fm.attributesOfItem(atPath: fileURL.path),
               let size = attrs[.size] as? Int64,
               size > 0 {
                found.append(filename)
                totalSize += size
            } else {
                missing.append(filename)
            }
        }

        return ModelCheckResult(
            isAvailable: missing.isEmpty,
            missingFiles: missing,
            foundFiles: found,
            modelDirectoryExists: dirExists,
            totalFoundSizeBytes: totalSize
        )
    }

    /// 빠른 가용성 확인 (4개 파일 모두 있으면 true)
    static func isModelAvailable() -> Bool {
        checkModel().isAvailable
    }

    // MARK: - User-facing Messages

    static func statusMessage() -> String {
        let result = checkModel()
        if result.isAvailable {
            let mb = result.totalFoundSizeBytes / 1_048_576
            return "모델 준비됨 (\(mb) MB)"
        } else if result.modelDirectoryExists {
            return "일부 파일 없음: \(result.missingFiles.joined(separator: ", "))"
        } else {
            return "모델 없음 — ~/.cache/supertonic3/onnx/ 에 ONNX 파일이 필요합니다"
        }
    }

    static func downloadGuideMessage() -> String {
        """
        Supertonic3 모델 다운로드 방법:

        1. Python (권장):
           pip install supertonic
           python -c "from supertonic import TTS; TTS(auto_download=True)"

        2. 직접 다운로드:
           huggingface-cli download Supertone/supertonic-3 --include 'onnx/*'
           → ~/.cache/supertonic3/onnx/ 에 저장

        필요 파일 (~398 MB 총):
        \(Supertonic3TTSConfig.requiredModelFiles.map { "  - \($0)" }.joined(separator: "\n"))
        """
    }
}
