import Foundation

// MARK: - CharacterSpriteAssetPolicy
// 스프라이트 에셋 준비 상태를 정적으로 검수한다.
// 런타임 SpriteKit 코드를 건드리지 않는다.
// Release 노출 판단은 CharacterSpriteManifest.releaseVisible 기준.

enum CharacterSpriteAssetPolicy {

    // MARK: - 검수 결과

    struct ValidationResult: Sendable {
        let characterID: String
        let missingRequiredStates: [String]
        let missingOptionalStates: [String]
        let malformedFiles: [String]       // 파일명 컨벤션 위반
        let totalFrameCount: Int
        var isReadyForRelease: Bool {
            missingRequiredStates.isEmpty && malformedFiles.isEmpty
        }
    }

    // MARK: - 공개 API

    /// 치코 스프라이트 준비 상태 검수.
    /// 런타임 번들 경로(resourcePath)를 직접 탐색.
    static func validate(manifest: CharacterSpriteManifest) -> ValidationResult {
        guard let resourcePath = Bundle.main.resourcePath else {
            return ValidationResult(
                characterID: manifest.characterID,
                missingRequiredStates: manifest.requiredStates,
                missingOptionalStates: manifest.optionalStates,
                malformedFiles: [],
                totalFrameCount: 0
            )
        }

        let spriteDir = "\(resourcePath)/\(manifest.runtimePath)"
        let fm = FileManager.default

        guard let files = try? fm.contentsOfDirectory(atPath: spriteDir) else {
            return ValidationResult(
                characterID: manifest.characterID,
                missingRequiredStates: manifest.requiredStates,
                missingOptionalStates: manifest.optionalStates,
                malformedFiles: [],
                totalFrameCount: 0
            )
        }

        let pngFiles = files.filter { $0.hasSuffix(".png") }
        let charID = manifest.characterID

        // 파일명 컨벤션 검사: {charID}_{state}_{NNN}.png
        let convention = try? NSRegularExpression(
            pattern: "^\(NSRegularExpression.escapedPattern(for: charID))_([a-zA-Z_]+)_(\\d{3})\\.png$"
        )
        var malformed: [String] = []
        var stateFrames: [String: Int] = [:]

        for file in pngFiles {
            let range = NSRange(file.startIndex..., in: file)
            if let conv = convention, conv.firstMatch(in: file, range: range) != nil {
                // 상태 추출
                if let match = conv.firstMatch(in: file, range: range) {
                    let stateRange = Range(match.range(at: 1), in: file)!
                    let state = String(file[stateRange])
                    stateFrames[state, default: 0] += 1
                }
            } else {
                malformed.append(file)
            }
        }

        let foundStates = Set(stateFrames.keys)
        let missingRequired = manifest.requiredStates.filter { !foundStates.contains($0) }
        let missingOptional = manifest.optionalStates.filter { !foundStates.contains($0) }
        let total = pngFiles.count

        return ValidationResult(
            characterID: manifest.characterID,
            missingRequiredStates: missingRequired,
            missingOptionalStates: missingOptional,
            malformedFiles: malformed,
            totalFrameCount: total
        )
    }

    /// 치코 검수 — shortcut
    static func validateChiko() -> ValidationResult {
        validate(manifest: .chiko)
    }

    /// Release 가능 여부 판단
    static func isReadyForRelease(characterID: String) -> Bool {
        guard let manifest = CharacterSpriteManifest.all.first(where: { $0.characterID == characterID }) else {
            return false
        }
        guard manifest.releaseVisible else { return false }
        return validate(manifest: manifest).isReadyForRelease
    }

    // MARK: - 요약 보고

    /// 콘솔용 짧은 상태 요약
    static func summary(for manifest: CharacterSpriteManifest) -> String {
        let result = validate(manifest: manifest)
        var parts: [String] = []
        parts.append("total=\(result.totalFrameCount)")
        if result.missingRequiredStates.isEmpty {
            parts.append("required=✅")
        } else {
            parts.append("missingRequired=\(result.missingRequiredStates.joined(separator: ","))")
        }
        if !result.missingOptionalStates.isEmpty {
            parts.append("missingOptional=\(result.missingOptionalStates.count)")
        }
        if !result.malformedFiles.isEmpty {
            parts.append("malformed=\(result.malformedFiles.count)")
        }
        parts.append("releaseReady=\(result.isReadyForRelease)")
        return "[\(manifest.characterID)] " + parts.joined(separator: " ")
    }
}
