import Foundation

// MARK: - DownloadsFolderWatcher
// Round 243A-OBSERVE: 다운로드 폴더 감시 (기본 OFF).
//
// 정책:
// - isEnabled = false (기본값, 사용자가 명시 활성화 필요)
// - 파일명/확장자/크기/생성시각 감지만 허용
// - 파일 내용 자동 분석 금지
// - 사용자 확인 없이 room에 자동 attach 금지
// - macOS sandbox/보안 범위 접근 제한 준수
//
// TODO (Mac local build phase):
// - FSEvents / DispatchSource 실제 구현
// - security-scoped bookmark 저장
// - sandbox entitlement 추가 (com.apple.security.files.downloads.read-only)

@MainActor
final class DownloadsFolderWatcher: ObservableObject {

    static let shared = DownloadsFolderWatcher()
    private init() {}

    // MARK: - State

    /// 기본 OFF — 사용자가 명시적으로 켜야 동작
    @Published private(set) var isEnabled: Bool = false

    /// 실제 감시 중인지 여부
    @Published private(set) var isRunning: Bool = false

    /// 마지막 파일 감지 시각
    @Published private(set) var lastDetectedAt: Date? = nil

    /// 현재 감시 중인 폴더 URL
    var watchedFolderURL: URL? {
        guard isEnabled else { return nil }
        return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    }

    // MARK: - Control

    /// 다운로드 폴더 감시 시작 (사용자 명시 활성화 후)
    func startWatchingDownloads() {
        guard isEnabled else {
            AppLog.info("[DownloadsFolderWatcher] not started: isEnabled = false")
            return
        }
        guard !isRunning else { return }
        guard let folderURL = watchedFolderURL else {
            AppLog.info("[DownloadsFolderWatcher] downloads folder not available")
            return
        }
        AppLog.info("[DownloadsFolderWatcher] starting watcher at \(folderURL.lastPathComponent)")
        // TODO (Mac local): FSEvents / DispatchSource 구현
        // let stream = FSEventStreamCreate(...)
        isRunning = true
    }

    func stopWatchingDownloads() {
        guard isRunning else { return }
        // TODO (Mac local): FSEventStreamStop + FSEventStreamInvalidate
        isRunning = false
        AppLog.info("[DownloadsFolderWatcher] stopped")
    }

    /// 사용자 명시 활성화
    func enable() {
        isEnabled = true
        startWatchingDownloads()
    }

    /// 비활성화
    func disable() {
        isEnabled = false
        stopWatchingDownloads()
    }

    // MARK: - File Detection (Skeleton)

    /// 새 파일 감지 시 호출 — LocalObservationService에 전달
    /// contentAnalysis는 하지 않음. 메타데이터만.
    func handleDetectedFile(at url: URL) {
        guard isEnabled else { return }
        let ext = url.pathExtension.lowercased()
        guard ObservationPermissionPolicy.DownloadsWatcherPolicy.monitoredExtensions.contains(ext) else {
            AppLog.info("[DownloadsFolderWatcher] ignored extension: .\(ext)")
            return
        }
        let fileSize: Int64? = {
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            return attrs?[.size] as? Int64
        }()
        guard let size = fileSize,
              size >= ObservationPermissionPolicy.DownloadsWatcherPolicy.minimumFileSizeBytes else {
            return
        }
        let kind = ObservationContentKind.from(fileExtension: ext)
        let displayName = url.lastPathComponent   // full path는 노출하지 않음
        lastDetectedAt = Date()
        Task { @MainActor in
            LocalObservationService.shared.detect(
                source: .downloadsFolder,
                fileURL: url,
                displayName: displayName,
                contentKind: kind,
                fileSizeBytes: fileSize
                // roomID: nil → pending attach
            )
        }
        AppLog.info("[DownloadsFolderWatcher] detected: \(displayName)")
    }

    // MARK: - macOS 권한 안내

    /// 샌드박스 환경에서 다운로드 폴더 접근 권한 안내 문구
    var permissionGuidanceMessage: String {
        "다운로드 폴더를 확인하려면 시스템 설정 → 개인 정보 보호에서 MyTeam의 파일 접근을 허용해 주세요."
    }
}
