import Foundation

struct ProcessOutput: Sendable {
    let stdout: Data
    let stderr: Data
    let terminationStatus: Int32
}

enum ProcessRunnerError: LocalizedError {
    case launchFailed(String)
    case failed(executable: String, status: Int32, stderr: String)

    var errorDescription: String? {
        switch self {
        case let .launchFailed(message): message
        case let .failed(executable, status, stderr):
            stderr.isEmpty
                ? "\(executable) exited with status \(status)."
                : "\(executable) exited with status \(status): \(stderr)"
        }
    }
}

enum ProcessRunner {
    static func run(
        executable: URL,
        arguments: [String],
        currentDirectory: URL? = nil,
        environment: [String: String]? = nil
    ) async throws -> ProcessOutput {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.executableURL = executable
            process.arguments = arguments
            process.currentDirectoryURL = currentDirectory
            process.environment = environment
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            do {
                try process.run()
            } catch {
                throw ProcessRunnerError.launchFailed(error.localizedDescription)
            }

            let stdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let stderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let output = ProcessOutput(
                stdout: stdout,
                stderr: stderr,
                terminationStatus: process.terminationStatus
            )

            guard output.terminationStatus == 0 else {
                let message = String(decoding: output.stderr, as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                throw ProcessRunnerError.failed(
                    executable: executable.path,
                    status: output.terminationStatus,
                    stderr: message
                )
            }
            return output
        }.value
    }
}
