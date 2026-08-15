import Foundation

actor CodexAppServerService {
    enum ServiceError: LocalizedError {
        case executableMissing
        case invalidResponse(String)
        case serverError(String)
        case serverExited(Int32)

        var errorDescription: String? {
            switch self {
            case .executableMissing:
                "Could not find a local Codex executable."
            case let .invalidResponse(message):
                "Invalid Codex App Server response: \(message)"
            case let .serverError(message):
                "Codex App Server error: \(message)"
            case let .serverExited(status):
                "Codex App Server exited with status \(status)."
            }
        }
    }

    private var process: Process?
    private var inputHandle: FileHandle?
    private var outputBuffer = Data()
    private var nextRequestID = 1
    private var pending: [Int: CheckedContinuation<Data, Error>] = [:]

    deinit {
        process?.terminate()
    }

    func createTask(
        workingDirectory: URL,
        title: String
    ) async throws -> String {
        try validateWorkingDirectory(workingDirectory)
        try await ensureServer(currentDirectory: workingDirectory)

        let started = try await request(
            method: "thread/start",
            params: [
                "cwd": workingDirectory.path,
                "approvalPolicy": "never",
                "sandbox": "workspace-write",
                "serviceName": "agent-os",
                "threadSource": "agent-os",
                "ephemeral": false,
            ]
        )
        let startResult = try resultObject(from: started)
        guard
            let thread = startResult["thread"] as? [String: Any],
            let threadID = thread["id"] as? String
        else {
            throw ServiceError.invalidResponse("thread/start omitted thread.id")
        }

        _ = try await request(
            method: "thread/name/set",
            params: ["threadId": threadID, "name": title]
        )
        return threadID
    }

    private func ensureServer(currentDirectory: URL) async throws {
        if process?.isRunning == true { return }
        guard let executable = locateCodex() else {
            throw ServiceError.executableMissing
        }

        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = executable
        process.arguments = ["app-server", "--stdio"]
        process.currentDirectoryURL = currentDirectory
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.environment = sanitizedEnvironment()

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { await self?.consume(data) }
        }
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }
        process.terminationHandler = { [weak self] process in
            Task { await self?.handleExit(process.terminationStatus) }
        }

        do {
            try process.run()
        } catch {
            throw ServiceError.serverError(error.localizedDescription)
        }

        self.process = process
        inputHandle = inputPipe.fileHandleForWriting
        _ = try await request(
            method: "initialize",
            params: [
                "clientInfo": [
                    "name": "agent-os",
                    "title": "Agent OS",
                    "version": "0.1.0",
                ],
                "capabilities": [:],
            ]
        )
        try send(["method": "initialized", "params": [:]])
    }

    private func request(method: String, params: [String: Any]) async throws -> Data {
        let requestID = nextRequestID
        nextRequestID += 1
        return try await withCheckedThrowingContinuation { continuation in
            pending[requestID] = continuation
            do {
                try send(["id": requestID, "method": method, "params": params])
            } catch {
                pending.removeValue(forKey: requestID)
                continuation.resume(throwing: error)
            }
        }
    }

    private func send(_ object: [String: Any]) throws {
        guard let inputHandle else {
            throw ServiceError.serverError("stdin is unavailable")
        }
        var data = try JSONSerialization.data(withJSONObject: object)
        data.append(0x0A)
        try inputHandle.write(contentsOf: data)
    }

    private func consume(_ data: Data) {
        outputBuffer.append(data)
        while let newline = outputBuffer.firstIndex(of: 0x0A) {
            let line = outputBuffer.subdata(in: outputBuffer.startIndex ..< newline)
            outputBuffer.removeSubrange(outputBuffer.startIndex ... newline)
            guard !line.isEmpty else { continue }
            resolve(line)
        }
    }

    private func resolve(_ line: Data) {
        guard
            let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
            let requestID = object["id"] as? Int,
            let continuation = pending.removeValue(forKey: requestID)
        else { return }
        continuation.resume(returning: line)
    }

    private func resultObject(from data: Data) throws -> [String: Any] {
        guard let response = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ServiceError.invalidResponse("not a JSON object")
        }
        if let error = response["error"] as? [String: Any] {
            throw ServiceError.serverError(error["message"] as? String ?? "unknown error")
        }
        guard let result = response["result"] as? [String: Any] else {
            throw ServiceError.invalidResponse("missing result")
        }
        return result
    }

    private func handleExit(_ status: Int32) {
        process = nil
        inputHandle = nil
        let continuations = pending.values
        pending.removeAll()
        for continuation in continuations {
            continuation.resume(throwing: ServiceError.serverExited(status))
        }
    }

    private func validateWorkingDirectory(_ directory: URL) throws {
        var isDirectory: ObjCBool = false
        guard
            directory.isFileURL,
            directory.path != "/",
            FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
            isDirectory.boolValue
        else {
            throw CocoaError(.fileNoSuchFile)
        }
    }

    private func locateCodex() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent(".local/bin/codex"),
            URL(fileURLWithPath: "/Applications/ChatGPT.app/Contents/Resources/codex"),
            URL(fileURLWithPath: "/usr/local/bin/codex"),
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    private func sanitizedEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        [
            "CODEX_CI",
            "CODEX_INTERNAL_ORIGINATOR_OVERRIDE",
            "CODEX_PERMISSION_PROFILE",
            "CODEX_SESSION_ID",
            "CODEX_SHELL",
            "CODEX_THREAD_ID",
        ].forEach { environment.removeValue(forKey: $0) }
        return environment
    }
}
