import Foundation

// MARK: - LineBuffer
final class LineBuffer: @unchecked Sendable {
    nonisolated(unsafe) private var pendingData = Data()
    private let lock = NSLock()

    nonisolated init() {}
    
    nonisolated func appendAndExtractLines(_ data: Data) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        
        pendingData.append(data)
        var lines: [String] = []
        
        while let newlineIndex = pendingData.firstIndex(of: 0x0a) { // '\n'
            let lineData = pendingData.subdata(in: 0..<newlineIndex)
            if let line = String(data: lineData, encoding: .utf8) {
                lines.append(line)
            }
            pendingData.removeSubrange(0...newlineIndex)
        }
        
        return lines
    }
    
    nonisolated func clear() {
        lock.lock()
        pendingData = Data()
        lock.unlock()
    }
}

// MARK: - MCPResponse Struct
struct MCPResponse: Sendable {
    let id: Int
    let ok: Bool
    let text: String
    let toolNames: [String]?
    let error: String?
}

// MARK: - PlaywrightMCPClient Actor
actor PlaywrightMCPClient {
    static let shared = PlaywrightMCPClient()

    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?

    private let stdoutBuffer = LineBuffer()
    private var lastErrorLog = ""

    private var nextRequestID = 10
    private var isInitialized = false
    private var cachedCapabilities: CapabilityProbe?

    // Continuation map for pending async JSON-RPC requests
    private var pending: [Int: CheckedContinuation<MCPResponse, Error>] = [:]

    private init() {}

    private func terminateProcess() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        if let process = process, process.isRunning {
            process.terminate()
        }
        process = nil
        inputPipe = nil
        outputPipe = nil
        errorPipe = nil
        stdoutBuffer.clear()
        isInitialized = false
        initTask = nil
        
        let remaining = pending
        pending.removeAll()
        for (_, continuation) in remaining {
            continuation.resume(throwing: NSError(
                domain: "PlaywrightMCPClient",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Process terminated or restarted"]
            ))
        }
    }

    private func handleStdoutData(_ chunk: Data) {
        let lines = stdoutBuffer.appendAndExtractLines(chunk)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            AppLog.debug("MCP STDOUT: \(trimmed)", .legacy)
            
            if let response = parseLine(trimmed) {
                if let continuation = pending.removeValue(forKey: response.id) {
                    continuation.resume(returning: response)
                }
            }
        }
    }

    private func handleStderrData(_ chunk: Data) {
        if let str = String(data: chunk, encoding: .utf8) {
            AppLog.warning("MCP STDERR: \(str)", .legacy)
            lastErrorLog = String((lastErrorLog + str).suffix(4096))
        }
    }

    // MARK: - Initialization guard

    /// In-flight initialization task, shared by concurrent callers.
    ///
    /// Root cause of "invalid reuse after initialization failure":
    /// multiple concurrent callers (e.g. `probeHealth` + `navigateAndSnapshot`)
    /// each saw `isInitialized == false` and raced to call `terminateProcess()`,
    /// killing each other's pending continuations.
    /// Solution: store one shared Task; every additional caller awaits its value
    /// instead of starting a competing initialization.
    private var initTask: Task<Bool, Never>?

    private func ensureProcessRunning() async -> Bool {
        // Fast path: already running and fully initialized.
        if let process = process, process.isRunning, isInitialized {
            return true
        }

        // If another caller already started initialization, share that result.
        if let existing = initTask {
            return await existing.value
        }

        // Slow path: no process yet — kick off initialization.
        // initTask is cleared by terminateProcess() or by us after the task completes.
        let task = Task<Bool, Never> { [weak self] in
            guard let self else { return false }
            return await self._doInitialize()
        }
        initTask = task
        let result = await task.value
        // Only clear if terminateProcess() hasn't already reset initTask.
        if initTask != nil {
            initTask = nil
        }
        return result
    }

    private func _doInitialize() async -> Bool {
        terminateProcess()
        lastErrorLog = ""

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = ["npx", "--no-install", "@playwright/mcp", "--headless"]

        let inPipe = Pipe()
        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardInput = inPipe
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            Task { [weak self] in
                await self?.handleStdoutData(chunk)
            }
        }
        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            Task { [weak self] in
                await self?.handleStderrData(chunk)
            }
        }

        do {
            try proc.run()
        } catch {
            AppLog.error("Failed to run Playwright MCP process: \(error)", .legacy)
            return false
        }

        process = proc
        inputPipe = inPipe
        outputPipe = outPipe
        errorPipe = errPipe

        do {
            let _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<MCPResponse, Error>) in
                pending[1] = continuation
                let initialize = """
                {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"MyTeam","version":"1.0"}}}
                \n
                """
                if let data = initialize.data(using: .utf8) {
                    inPipe.fileHandleForWriting.write(data)
                } else {
                    pending.removeValue(forKey: 1)
                    continuation.resume(throwing: NSError(domain: "PlaywrightMCPClient", code: -4, userInfo: [NSLocalizedDescriptionKey: "Invalid payload"]))
                }
            }

            // Send initialized notification
            let initializedNotification = #"{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}"# + "\n"
            if let data = initializedNotification.data(using: .utf8) {
                inPipe.fileHandleForWriting.write(data)
            }

            isInitialized = true
            return true
        } catch {
            AppLog.error("MCP initialize failed: \(error)", .legacy)
            terminateProcess()
            return false
        }
    }

    private func sendRequest(method: String, params: [String: Any]) async throws -> MCPResponse {
        let success = await ensureProcessRunning()
        guard success, let inPipe = inputPipe else {
            throw NSError(domain: "PlaywrightMCPClient", code: -2, userInfo: [NSLocalizedDescriptionKey: "Process not running"])
        }

        let requestID = nextRequestID
        nextRequestID += 1

        let request: [String: Any] = [
            "jsonrpc": "2.0",
            "id": requestID,
            "method": method,
            "params": params
        ]

        guard JSONSerialization.isValidJSONObject(request),
              let data = try? JSONSerialization.data(withJSONObject: request),
              let line = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "PlaywrightMCPClient", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid request serialization"])
        }

        return try await withCheckedThrowingContinuation { continuation in
            pending[requestID] = continuation

            let payload = line + "\n"
            if let payloadData = payload.data(using: .utf8) {
                inPipe.fileHandleForWriting.write(payloadData)
            } else {
                pending.removeValue(forKey: requestID)
                continuation.resume(throwing: NSError(domain: "PlaywrightMCPClient", code: -4, userInfo: [NSLocalizedDescriptionKey: "Invalid payload encoding"]))
            }
        }
    }

    func probeHealth(timeout: TimeInterval = 6) async -> PlaywrightMCPHealth {
        async let node = PlaywrightMCPProcess.run(executable: "node", arguments: ["--version"], timeout: 2)
        async let npx = PlaywrightMCPProcess.run(executable: "npx", arguments: ["--version"], timeout: 3)
        async let versionResult = PlaywrightMCPProcess.run(
            executable: "npx",
            arguments: ["--no-install", "@playwright/mcp", "--version"],
            timeout: 3
        )
        
        let nodeResult = await node
        let npxResult = await npx
        let versionRes = await versionResult

        let mcpVersion: String?
        if versionRes.exitCode == 0 {
            let output = versionRes.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            if output.lowercased().hasPrefix("version ") {
                mcpVersion = String(output.dropFirst(8)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                mcpVersion = output
            }
        } else {
            mcpVersion = nil
        }

        guard nodeResult.exitCode == 0 else {
            return health(
                nodeAvailable: false,
                npxAvailable: npxResult.exitCode == 0,
                mcpLaunchable: false,
                initialized: false,
                snapshotCapable: false,
                navigateCapable: false,
                clickCapable: false,
                screenshotCapable: false,
                toolNames: [],
                lastError: "node 실행 실패: \(nodeResult.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines))",
                version: mcpVersion
            )
        }
        guard npxResult.exitCode == 0 else {
            return health(
                nodeAvailable: true,
                npxAvailable: false,
                mcpLaunchable: false,
                initialized: false,
                snapshotCapable: false,
                navigateCapable: false,
                clickCapable: false,
                screenshotCapable: false,
                toolNames: [],
                lastError: "npx 실행 실패: \(npxResult.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines))",
                version: mcpVersion
            )
        }

        let help = await PlaywrightMCPProcess.run(
            executable: "npx",
            arguments: ["--no-install", "@playwright/mcp", "--help"],
            timeout: timeout
        )
        guard help.exitCode == 0 else {
            let reason = help.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            return health(
                nodeAvailable: true,
                npxAvailable: true,
                mcpLaunchable: false,
                initialized: false,
                snapshotCapable: false,
                navigateCapable: false,
                clickCapable: false,
                screenshotCapable: false,
                toolNames: [],
                lastError: reason.isEmpty ? "Playwright MCP 실행 확인에 실패했습니다." : reason,
                version: mcpVersion
            )
        }

        let capability = await probeToolCapabilities(timeout: timeout)
        if let capability {
            return health(
                nodeAvailable: true,
                npxAvailable: true,
                mcpLaunchable: true,
                initialized: capability.initialized,
                snapshotCapable: capability.hasSnapshot,
                navigateCapable: capability.hasNavigate,
                clickCapable: capability.hasClick,
                screenshotCapable: capability.hasScreenshot,
                toolNames: capability.toolNames,
                lastError: capability.error,
                version: mcpVersion
            )
        }

        return health(
            nodeAvailable: true,
            npxAvailable: true,
            mcpLaunchable: true,
            initialized: false,
            snapshotCapable: false,
            navigateCapable: false,
            clickCapable: false,
            screenshotCapable: false,
            toolNames: [],
            lastError: "Playwright MCP는 실행 가능하지만 initialize/tools/list 검증에 실패했습니다.",
            version: mcpVersion
        )
    }

    private func health(
        nodeAvailable: Bool,
        npxAvailable: Bool,
        mcpLaunchable: Bool,
        initialized: Bool,
        snapshotCapable: Bool,
        navigateCapable: Bool,
        clickCapable: Bool,
        screenshotCapable: Bool,
        toolNames: [String],
        lastError: String?,
        version: String?
    ) -> PlaywrightMCPHealth {
        PlaywrightMCPHealth(
            nodeAvailable: nodeAvailable,
            npxAvailable: npxAvailable,
            mcpLaunchable: mcpLaunchable,
            initialized: initialized,
            snapshotCapable: snapshotCapable,
            navigateCapable: navigateCapable,
            clickCapable: clickCapable,
            screenshotCapable: screenshotCapable,
            toolNames: toolNames.sorted(),
            checkedAt: Date(),
            lastError: lastError?.isEmpty == true ? nil : lastError,
            version: version
        )
    }

    fileprivate struct CapabilityProbe: Sendable {
        let initialized: Bool
        let toolNames: [String]
        let error: String?

        var hasSnapshot: Bool { toolNames.contains(PlaywrightMCPToolName.snapshot.rawValue) }
        var hasNavigate: Bool { toolNames.contains(PlaywrightMCPToolName.navigate.rawValue) }
        var hasClick: Bool { toolNames.contains(PlaywrightMCPToolName.click.rawValue) }
        var hasScreenshot: Bool { toolNames.contains(PlaywrightMCPToolName.screenshot.rawValue) }
    }

    private func probeToolCapabilities(timeout: TimeInterval) async -> CapabilityProbe? {
        if let cached = cachedCapabilities {
            return cached
        }
        let success = await ensureProcessRunning()
        guard success else {
            return CapabilityProbe(initialized: false, toolNames: [], error: lastErrorLog)
        }

        do {
            let response = try await sendRequest(method: "tools/list", params: [:])
            let cap = CapabilityProbe(initialized: true, toolNames: response.toolNames ?? [], error: response.error)
            cachedCapabilities = cap
            return cap
        } catch {
            return CapabilityProbe(initialized: false, toolNames: [], error: error.localizedDescription)
        }
    }

    func navigateAndSnapshot(url: URL, timeout: TimeInterval = 18) async -> PlaywrightMCPToolCallResult {
        let success = await ensureProcessRunning()
        guard success else {
            return PlaywrightMCPToolCallResult(ok: false, text: "", error: "Playwright MCP 프로세스가 준비되지 않았습니다.")
        }

        do {
            // Step 1: Navigate
            let navigateResponse = try await sendRequest(
                method: "tools/call",
                params: [
                    "name": PlaywrightMCPToolName.navigate.rawValue,
                    "arguments": ["url": url.absoluteString]
                ]
            )

            guard navigateResponse.ok else {
                return PlaywrightMCPToolCallResult(ok: false, text: "", error: navigateResponse.error ?? "browser_navigate 실패")
            }

            // Step 2: Snapshot (Only if navigate succeeded!)
            let snapshotResponse = try await sendRequest(
                method: "tools/call",
                params: [
                    "name": PlaywrightMCPToolName.snapshot.rawValue,
                    "arguments": [:]
                ]
            )

            guard snapshotResponse.ok else {
                return PlaywrightMCPToolCallResult(ok: false, text: "", error: snapshotResponse.error ?? "browser_snapshot 실패")
            }

            let text = snapshotResponse.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                return PlaywrightMCPToolCallResult(ok: false, text: "", error: "DOM snapshot text가 비어 있습니다.")
            }

            return PlaywrightMCPToolCallResult(ok: true, text: text, error: nil)

        } catch {
            return PlaywrightMCPToolCallResult(ok: false, text: "", error: error.localizedDescription)
        }
    }
}

// MARK: - JSON-RPC Parser Helper
nonisolated private func parseLine(_ line: String) -> MCPResponse? {
    guard let data = line.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return nil
    }

    guard let id = json["id"] as? Int else {
        return nil
    }

    if let errorObj = json["error"] as? [String: Any] {
        let msg = errorObj["message"] as? String ?? "Unknown MCP error"
        return MCPResponse(id: id, ok: false, text: "", toolNames: nil, error: msg)
    }

    if let result = json["result"] as? [String: Any] {
        // tools/list response
        if let tools = result["tools"] as? [[String: Any]] {
            let names = tools.compactMap { $0["name"] as? String }
            return MCPResponse(id: id, ok: true, text: "", toolNames: names, error: nil)
        }

        // tools/call response
        if let content = result["content"] as? [[String: Any]] {
            var texts: [String] = []
            for item in content {
                if let type = item["type"] as? String, type == "text", let text = item["text"] as? String {
                    texts.append(text)
                }
            }
            return MCPResponse(id: id, ok: true, text: texts.joined(separator: "\n\n"), toolNames: nil, error: nil)
        }

        return MCPResponse(id: id, ok: true, text: "", toolNames: nil, error: nil)
    }

    return nil
}
