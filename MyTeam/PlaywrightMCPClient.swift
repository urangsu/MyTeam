import Foundation

actor PlaywrightMCPClient {
    static let shared = PlaywrightMCPClient()

    func probeHealth(timeout: TimeInterval = 6) async -> PlaywrightMCPHealth {
        async let node = PlaywrightMCPProcess.run(executable: "node", arguments: ["--version"], timeout: 2)
        async let npx = PlaywrightMCPProcess.run(executable: "npx", arguments: ["--version"], timeout: 3)
        let nodeResult = await node
        let npxResult = await npx

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
                lastError: "node 실행 실패: \(nodeResult.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines))"
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
                lastError: "npx 실행 실패: \(npxResult.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines))"
            )
        }

        let help = await PlaywrightMCPProcess.run(
            executable: "npx",
            arguments: ["@playwright/mcp@latest", "--help"],
            timeout: timeout
        )
        guard help.exitCode == 0 else {
            let reason = help.timedOut
                ? "Playwright MCP help probe timeout"
                : help.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
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
                lastError: reason.isEmpty ? "Playwright MCP 실행 확인에 실패했습니다." : reason
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
                lastError: capability.error
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
            lastError: "Playwright MCP는 실행 가능하지만 initialize/tools/list 검증에 실패했습니다."
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
        lastError: String?
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
            lastError: lastError?.isEmpty == true ? nil : lastError
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
        await Task.detached(priority: .utility) {
            probeToolCapabilitiesSync(timeout: timeout)
        }.value
    }

    func navigateAndSnapshot(url: URL, timeout: TimeInterval = 18) async -> PlaywrightMCPToolCallResult {
        await Task.detached(priority: .utility) {
            navigateAndSnapshotSync(url: url, timeout: timeout)
        }.value
    }
}

nonisolated private func probeToolCapabilitiesSync(timeout: TimeInterval) -> PlaywrightMCPClient.CapabilityProbe? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["npx", "@playwright/mcp@latest"]

    let inputPipe = Pipe()
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardInput = inputPipe
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    final class BufferBox: @unchecked Sendable {
        var data = Data()
        let lock = NSLock()
        func append(_ chunk: Data) {
            lock.lock()
            data.append(chunk)
            lock.unlock()
        }
        func string() -> String {
            lock.lock()
            defer { lock.unlock() }
            return String(data: data, encoding: .utf8) ?? ""
        }
    }

    let output = BufferBox()
    let error = BufferBox()
    outputPipe.fileHandleForReading.readabilityHandler = { handle in
        output.append(handle.availableData)
    }
    errorPipe.fileHandleForReading.readabilityHandler = { handle in
        error.append(handle.availableData)
    }

    do {
        try process.run()
    } catch {
        return PlaywrightMCPClient.CapabilityProbe(initialized: false, toolNames: [], error: error.localizedDescription)
    }

    let initialize = """
    {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"MyTeam","version":"1.0"}}}
    """
    let initialized = #"{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}"#
    let listTools = #"{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}"#
    let payload = [initialize, initialized, listTools].joined(separator: "\n") + "\n"
    if let data = payload.data(using: .utf8) {
        inputPipe.fileHandleForWriting.write(data)
    }

    let deadline = Date().addingTimeInterval(timeout)
    var response = ""
    while Date() < deadline {
        response = output.string()
        if response.contains(#""id":2"#) || response.contains(#""id": 2"#) {
            break
        }
        Thread.sleep(forTimeInterval: 0.05)
    }

    outputPipe.fileHandleForReading.readabilityHandler = nil
    errorPipe.fileHandleForReading.readabilityHandler = nil
    if process.isRunning {
        process.terminate()
    }

    response = output.string()
    let errorText = error.string().trimmingCharacters(in: .whitespacesAndNewlines)
    guard response.contains(#""id":1"#) || response.contains(#""id": 1"#) else {
        return PlaywrightMCPClient.CapabilityProbe(initialized: false, toolNames: [], error: errorText.isEmpty ? "MCP initialize 응답 없음" : errorText)
    }

    let toolNames = extractToolNames(from: response)
    let hasListResponse = response.contains(#""id":2"#) || response.contains(#""id": 2"#)
    return PlaywrightMCPClient.CapabilityProbe(
        initialized: hasListResponse,
        toolNames: toolNames,
        error: hasListResponse ? nil : (errorText.isEmpty ? "tools/list 응답 없음" : errorText)
    )
}

nonisolated private func extractToolNames(from text: String) -> [String] {
    let pattern = #""name"\s*:\s*"([^"]+)""#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return regex.matches(in: text, range: range).compactMap { match in
        guard let matchRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[matchRange])
    }
}

nonisolated private func navigateAndSnapshotSync(url: URL, timeout: TimeInterval) -> PlaywrightMCPToolCallResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["npx", "@playwright/mcp@latest", "--headless"]

    let inputPipe = Pipe()
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardInput = inputPipe
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    final class BufferBox: @unchecked Sendable {
        var data = Data()
        let lock = NSLock()
        func append(_ chunk: Data) {
            lock.lock()
            data.append(chunk)
            lock.unlock()
        }
        func string() -> String {
            lock.lock()
            defer { lock.unlock() }
            return String(data: data, encoding: .utf8) ?? ""
        }
    }

    let output = BufferBox()
    let error = BufferBox()
    outputPipe.fileHandleForReading.readabilityHandler = { handle in
        output.append(handle.availableData)
    }
    errorPipe.fileHandleForReading.readabilityHandler = { handle in
        error.append(handle.availableData)
    }

    do {
        try process.run()
    } catch {
        return PlaywrightMCPToolCallResult(ok: false, text: "", error: error.localizedDescription)
    }

    let payloadObjects: [[String: Any]] = [
        [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": [
                "protocolVersion": "2024-11-05",
                "capabilities": [:],
                "clientInfo": ["name": "MyTeam", "version": "1.0"]
            ]
        ],
        [
            "jsonrpc": "2.0",
            "method": "notifications/initialized",
            "params": [:]
        ],
        [
            "jsonrpc": "2.0",
            "id": 3,
            "method": "tools/call",
            "params": [
                "name": PlaywrightMCPToolName.navigate.rawValue,
                "arguments": ["url": url.absoluteString]
            ]
        ],
        [
            "jsonrpc": "2.0",
            "id": 4,
            "method": "tools/call",
            "params": [
                "name": PlaywrightMCPToolName.snapshot.rawValue,
                "arguments": [:]
            ]
        ]
    ]

    let lines = payloadObjects.compactMap { object -> String? in
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object),
              let line = String(data: data, encoding: .utf8) else {
            return nil
        }
        return line
    }
    if let data = (lines.joined(separator: "\n") + "\n").data(using: .utf8) {
        inputPipe.fileHandleForWriting.write(data)
    }

    let deadline = Date().addingTimeInterval(timeout)
    var response = ""
    while Date() < deadline {
        response = output.string()
        if response.contains(#""id":4"#) || response.contains(#""id": 4"#) {
            break
        }
        Thread.sleep(forTimeInterval: 0.08)
    }

    outputPipe.fileHandleForReading.readabilityHandler = nil
    errorPipe.fileHandleForReading.readabilityHandler = nil
    if process.isRunning {
        process.terminate()
    }

    response = output.string()
    let errorText = error.string().trimmingCharacters(in: .whitespacesAndNewlines)
    guard response.contains(#""id":4"#) || response.contains(#""id": 4"#) else {
        return PlaywrightMCPToolCallResult(ok: false, text: "", error: errorText.isEmpty ? "browser_snapshot 응답 없음" : errorText)
    }

    let text = extractMCPTextPayloads(from: response).joined(separator: "\n\n")
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return PlaywrightMCPToolCallResult(ok: false, text: "", error: "DOM snapshot text가 비어 있습니다.")
    }
    return PlaywrightMCPToolCallResult(ok: true, text: text, error: nil)
}

nonisolated private func extractMCPTextPayloads(from text: String) -> [String] {
    let lines = text.components(separatedBy: .newlines)
    var payloads: [String] = []
    for line in lines where line.contains(#""text""#) {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = object["result"] as? [String: Any],
              let content = result["content"] as? [[String: Any]] else {
            continue
        }
        for item in content {
            if let itemText = item["text"] as? String {
                payloads.append(itemText)
            }
        }
    }
    if !payloads.isEmpty { return payloads }

    let pattern = #""text"\s*:\s*"((?:\\"|[^"])*)""#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return regex.matches(in: text, range: range).compactMap { match in
        guard let matchRange = Range(match.range(at: 1), in: text) else { return nil }
        let raw = String(text[matchRange])
        return raw.replacingOccurrences(of: #"\""#, with: #"""#)
    }
}
