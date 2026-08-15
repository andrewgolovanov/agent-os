import AppKit
import Foundation

@MainActor
enum CodexHandoffService {
    enum HandoffError: LocalizedError {
        case applicationMissing
        case invalidThreadID
        case pasteboardUnavailable

        var errorDescription: String? {
            switch self {
            case .applicationMissing:
                "The installed Codex desktop application could not be located."
            case .invalidThreadID:
                "The Codex task ID could not be converted into a handoff URL."
            case .pasteboardUnavailable:
                "The prepared Codex prompt could not be copied to the clipboard."
            }
        }
    }

    static func copyPrompt(_ prompt: String) throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(prompt, forType: .string) else {
            throw HandoffError.pasteboardUnavailable
        }
    }

    static func open(threadID: String) async throws {
        guard let url = URL(string: "codex://threads/\(threadID)") else {
            throw HandoffError.invalidThreadID
        }
        let systemWorkspace = NSWorkspace.shared
        guard let applicationURL = systemWorkspace.urlForApplication(withBundleIdentifier: "com.openai.codex") else {
            throw HandoffError.applicationMissing
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = false
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            systemWorkspace.open(
                [url],
                withApplicationAt: applicationURL,
                configuration: configuration
            ) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
