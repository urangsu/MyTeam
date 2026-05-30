import Foundation

struct ProcessRunResult: Sendable, Equatable {
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let timedOut: Bool

    nonisolated var combinedOutput: String {
        [stdout, stderr].filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

enum PlaywrightMCPProcess {
    static func run(
        executable: String,
        arguments: [String],
        timeout: TimeInterval = 5
    ) async -> ProcessRunResult {
        await Task.detached(priority: .utility) {
            runSync(executable: executable, arguments: arguments, timeout: timeout)
        }.value
    }

    nonisolated private static func runSync(
        executable: String,
        arguments: [String],
        timeout: TimeInterval
    ) -> ProcessRunResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executable] + arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            return ProcessRunResult(exitCode: -1, stdout: "", stderr: error.localizedDescription, timedOut: false)
        }

        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            semaphore.signal()
        }

        let waitResult = semaphore.wait(timeout: .now() + timeout)
        let timedOut = waitResult == .timedOut
        if timedOut && process.isRunning {
            process.terminate()
        }
        if process.isRunning {
            process.waitUntilExit()
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        return ProcessRunResult(
            exitCode: timedOut ? -2 : process.terminationStatus,
            stdout: stdout,
            stderr: stderr,
            timedOut: timedOut
        )
    }
}
