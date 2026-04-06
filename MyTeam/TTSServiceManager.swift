import Foundation

/// Manages the lifecycle of the Chatterbox TTS HTTP service
/// Ensures the service is running when needed
class TTSServiceManager: NSObject {
    static let shared = TTSServiceManager()

    private var process: Process?
    private let serviceURL = "http://127.0.0.1:9999"
    private var healthCheckTimer: Timer?

    private override init() {
        super.init()
    }

    /// Start the TTS service if not already running
    /// 배포 환경에서는 Python 서버가 없으므로 즉시 반환
    func ensureServiceRunning() {
        // 먼저 Python 환경이 존재하는지 빠르게 확인
        let chatterboxPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/TTS맨/chatterbox")
        let pythonVenvPath = chatterboxPath.appendingPathComponent(".venv/bin/python3")

        guard FileManager.default.fileExists(atPath: pythonVenvPath.path) else {
            print("[TTSService] ℹ️ Python 환경 없음 → TTS 서비스 건너뜀 (Apple TTS 사용)")
            return
        }

        // First, check if service is already running
        if isServiceRunning() {
            print("[TTSService] ✅ Service already running")
            // 서비스 가용성 알림
            Task { await OnDeviceTTSManager.shared.checkServiceAvailability() }
            return
        }

        startService()
    }

    /// Check if the TTS service is responding
    private func isServiceRunning() -> Bool {
        guard let url = URL(string: "\(serviceURL)/health") else { return false }

        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0

        let semaphore = DispatchSemaphore(value: 0)
        var isRunning = false

        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                isRunning = true
            }
            semaphore.signal()
        }.resume()

        _ = semaphore.wait(timeout: .now() + 2.0)
        return isRunning
    }

    /// Start the TTS service process
    private func startService() {
        let chatterboxPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/TTS맨/chatterbox")

        let pythonVenvPath = chatterboxPath.appendingPathComponent(".venv/bin/python3")
        let servicePath = chatterboxPath.appendingPathComponent("tts_service.py")

        guard FileManager.default.fileExists(atPath: pythonVenvPath.path),
              FileManager.default.fileExists(atPath: servicePath.path) else {
            print("[TTSService] ❌ Python environment or service script not found")
            print("  Python: \(pythonVenvPath.path)")
            print("  Service: \(servicePath.path)")
            return
        }

        process = Process()
        process?.executableURL = pythonVenvPath
        process?.arguments = [servicePath.path]

        // Set environment
        var environment = ProcessInfo.processInfo.environment
        environment["TTS_PORT"] = "9999"
        process?.environment = environment

        // Redirect output
        let pipe = Pipe()
        process?.standardOutput = pipe
        process?.standardError = pipe

        do {
            try process?.run()
            print("[TTSService] 🚀 Service started (PID: \(process?.processIdentifier ?? -1))")

            // Start health check timer
            startHealthCheck()

            // 서버 시작 후 가용성 체크 (3초 대기 후)
            DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) {
                Task { await OnDeviceTTSManager.shared.checkServiceAvailability() }
            }

        } catch {
            print("[TTSService] ❌ Failed to start service: \(error)")
        }
    }

    /// Stop the TTS service
    func stopService() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil

        if let process = process, process.isRunning {
            process.terminate()
            print("[TTSService] ⏹️ Service stopped")
        }
        process = nil
    }

    /// Start periodic health checks
    private func startHealthCheck() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            if let self = self, !self.isServiceRunning() {
                print("[TTSService] ⚠️ Service health check failed, attempting restart...")
                self.startService()
            }
        }
    }

    deinit {
        stopService()
    }
}
