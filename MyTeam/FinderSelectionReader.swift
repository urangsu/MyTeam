import Foundation

// MARK: - FinderSelectionReader
// Round 243A-OBSERVE → Round 274: NSAppleScript 실제 구현.
//
// 정책:
// - 명시적 사용자 요청 필요
// - 권한/샌드박스 실패 시 "파일을 끌어다 놓아 주세요" fallback
// - app-sandbox = false이므로 NSAppleScript 직접 사용 가능
// - macOS Privacy > Automation > Finder 권한은 런타임에 사용자 승인

enum FinderSelectionReaderError: LocalizedError {
    case notImplementedYet
    case accessibilityPermissionDenied
    case noFilesSelected
    case sandboxRestriction

    var errorDescription: String? {
        switch self {
        case .notImplementedYet:
            return "Finder 선택 읽기는 다음 업데이트에서 제공됩니다. 파일을 끌어다 놓아 주세요."
        case .accessibilityPermissionDenied:
            return "Finder 접근 권한이 필요합니다. 시스템 설정 → 개인 정보 보호 → 접근성에서 MyTeam을 허용해 주세요."
        case .noFilesSelected:
            return "Finder에서 파일을 선택한 후 다시 시도해 주세요."
        case .sandboxRestriction:
            return "파일을 끌어다 놓아 주세요."
        }
    }

    /// 사용자에게 보여줄 fallback 안내
    var fallbackGuidance: String {
        "파일을 채팅창에 끌어다 놓으면 바로 분석할 수 있어요."
    }
}

enum FinderSelectionReader {

    // MARK: - Public API

    /// Finder 선택 파일 읽기 — NSAppleScript 구현
    /// app-sandbox = false이므로 직접 사용 가능.
    /// macOS > 시스템 설정 > 개인 정보 보호 > 자동화 > Finder 권한이 없으면 -1743 오류.
    static func readCurrentFinderSelection() async throws -> [LocalObservation] {
        // Step 1: AppleScript는 백그라운드 스레드에서 실행 (blocking)
        let posixPaths = try await fetchFinderSelectionPaths()
        guard !posixPaths.isEmpty else { throw FinderSelectionReaderError.noFilesSelected }
        // Step 2: LocalObservation 생성 — @MainActor 격리 타입이므로 MainActor에서 실행
        return await MainActor.run {
            posixPaths.compactMap { posixPath -> LocalObservation? in
                let url = URL(fileURLWithPath: posixPath)
                let ext = url.pathExtension.lowercased()
                let fileSize: Int64? = {
                    let attrs = try? FileManager.default.attributesOfItem(atPath: posixPath)
                    return attrs?[.size] as? Int64
                }()
                let kind = ObservationContentKind.from(fileExtension: ext)
                return LocalObservation(
                    source: .finderSelection,
                    fileURL: url,
                    displayName: url.lastPathComponent,
                    contentKind: kind,
                    fileSizeBytes: fileSize,
                    userVisibleSummary: url.lastPathComponent
                )
            }
        }
    }

    /// AppleScript로 Finder 선택 파일의 POSIX 경로 목록을 반환 (백그라운드 스레드).
    private static func fetchFinderSelectionPaths() async throws -> [String] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let appleScriptSource = """
                tell application "Finder"
                    set selectedItems to selection as alias list
                    set pathList to {}
                    repeat with anItem in selectedItems
                        set end of pathList to POSIX path of anItem
                    end repeat
                    return pathList
                end tell
                """
                var errorDict: NSDictionary?
                guard let script = NSAppleScript(source: appleScriptSource) else {
                    continuation.resume(throwing: FinderSelectionReaderError.notImplementedYet)
                    return
                }
                let result = script.executeAndReturnError(&errorDict)
                if let appleScriptError = errorDict {
                    let code = (appleScriptError[NSAppleScript.errorNumber] as? Int) ?? 0
                    // -1743: not authorized, -1744: requires user interaction
                    if code == -1743 || code == -1744 {
                        continuation.resume(throwing: FinderSelectionReaderError.accessibilityPermissionDenied)
                    } else {
                        continuation.resume(throwing: FinderSelectionReaderError.sandboxRestriction)
                    }
                    return
                }
                let count = result.numberOfItems
                guard count > 0 else {
                    continuation.resume(throwing: FinderSelectionReaderError.noFilesSelected)
                    return
                }
                var paths: [String] = []
                for i in 1...count {
                    if let item = result.atIndex(i), let path = item.stringValue {
                        paths.append(path)
                    }
                }
                continuation.resume(returning: paths)
            }
        }
    }

    /// 자동화 권한 상태 확인
    /// macOS Privacy > Automation에서 Finder 접근 권한이 있는지 사전 확인.
    static func checkPermissionStatus() -> PermissionStatus {
        // NSAppleScript 실행 전 probe: 간단한 Finder tell로 권한 확인
        let probe = "tell application \"Finder\" to return name of window 1"
        var errorDict: NSDictionary?
        guard let script = NSAppleScript(source: probe) else { return .unknown }
        _ = script.executeAndReturnError(&errorDict)
        if let error = errorDict {
            let code = (error[NSAppleScript.errorNumber] as? Int) ?? 0
            if code == -1743 || code == -1744 { return .denied }
            // -1728: object not found (no open Finder window) — permission OK
            return code == -1728 ? .granted : .unknown
        }
        return .granted
    }

    enum PermissionStatus {
        case granted
        case denied
        case unknown
        case notRequired   // sandbox fallback
    }

    // MARK: - Fallback Message

    static var fallbackMessage: String {
        "파일을 채팅창에 끌어다 놓으면 바로 분석할 수 있어요."
    }

}
