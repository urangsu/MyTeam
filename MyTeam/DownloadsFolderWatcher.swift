import Foundation
import CoreServices
import Combine

// MARK: - DownloadsFolderWatcher
// Round 243A-OBSERVE → Round 274: FSEventStream 실제 구현.
//
// 정책:
// - isEnabled = false (기본값, 사용자가 명시 활성화 필요)
// - 파일명/확장자/크기/생성시각 감지만 허용
// - 파일 내용 자동 분석 금지
// - 사용자 확인 없이 room에 자동 attach 금지
// - app-sandbox = false이므로 FSEvents 직접 사용 가능

@MainActor
final class DownloadsFolderWatcher: ObservableObject {

    static let shared = DownloadsFolderWatcher()
    private init() {}

    // MARK: - Implementation Level (Round 274: FSEventStream 구현)
    let implementationLevel: ImplementationLevel = .runtimeAvailable

    // MARK: - FSEvents private state
    private var eventStream: FSEventStreamRef?
    private let eventQueue = DispatchQueue(label: "com.myteam.downloads-watcher", qos: .utility)

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
        startFSEventStream(for: folderURL)
        isRunning = true
    }

    func stopWatchingDownloads() {
        guard isRunning else { return }
        stopFSEventStream()
        isRunning = false
        AppLog.info("[DownloadsFolderWatcher] stopped")
    }

    // MARK: - FSEventStream lifecycle

    private func startFSEventStream(for folderURL: URL) {
        // 캡처 대상: self를 Unmanaged로 전달 (retain/release 없이 weak ref처럼 사용)
        // eventStream이 살아있는 동안 self도 살아있으므로 안전
        let selfPtr = Unmanaged.passRetained(self).toOpaque()
        var ctx = FSEventStreamContext(
            version: 0,
            info: selfPtr,
            retain: nil,
            release: { ptr in
                guard let ptr else { return }
                Unmanaged<DownloadsFolderWatcher>.fromOpaque(ptr).release()
            },
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { (_, clientCallBackInfo, numEvents, eventPaths, _, _) in
            guard let info = clientCallBackInfo else { return }
            let watcher = Unmanaged<DownloadsFolderWatcher>.fromOpaque(info).takeUnretainedValue()
            guard let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] else { return }
            for path in paths {
                // FSEvents는 디렉토리 변경을 보고하므로 해당 디렉토리의 파일 목록을 검사
                let dirURL = URL(fileURLWithPath: path, isDirectory: true)
                let items = (try? FileManager.default.contentsOfDirectory(
                    at: dirURL, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
                    options: [.skipsHiddenFiles]
                )) ?? []
                for item in items {
                    Task { @MainActor in
                        watcher.handleDetectedFile(at: item)
                    }
                }
            }
        }

        let pathsToWatch = [folderURL.path] as CFArray
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &ctx,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            2.0,    // 2초 latency: 빈번한 파일 복사에서 중복 이벤트 줄임
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        ) else {
            AppLog.error("[DownloadsFolderWatcher] FSEventStreamCreate 실패")
            return
        }
        FSEventStreamSetDispatchQueue(stream, eventQueue)
        FSEventStreamStart(stream)
        eventStream = stream
        AppLog.info("[DownloadsFolderWatcher] FSEventStream 시작: \(folderURL.path)")
    }

    private func stopFSEventStream() {
        guard let stream = eventStream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        eventStream = nil
        AppLog.info("[DownloadsFolderWatcher] FSEventStream 정지")
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
