import Foundation

enum AgentOSSourceStatusTone: String, Sendable {
    case positive
    case merged
    case warning
    case neutral
    case negative
    case information
}

struct AgentOSSourceMetadata: Equatable, Sendable {
    let title: String
    let context: String
    let status: String?
    let statusTone: AgentOSSourceStatusTone
    let secondaryStatus: String?
    let secondaryStatusTone: AgentOSSourceStatusTone?

    init(
        title: String,
        context: String,
        status: String?,
        statusTone: AgentOSSourceStatusTone,
        secondaryStatus: String?,
        secondaryStatusTone: AgentOSSourceStatusTone? = nil
    ) {
        self.title = title
        self.context = context
        self.status = status
        self.statusTone = statusTone
        self.secondaryStatus = secondaryStatus
        self.secondaryStatusTone = secondaryStatusTone
    }
}

struct GitHubPullRequestPayload: Decodable, Sendable {
    let number: Int
    let title: String
    let state: String
    let isDraft: Bool
    let mergedAt: String?
    let reviewDecision: String?
    let headRefName: String
    let baseRefName: String

    var status: String {
        if mergedAt != nil || state.uppercased() == "MERGED" { return "Merged" }
        if isDraft { return "Draft" }
        if state.uppercased() == "OPEN" { return "Open" }
        return "Closed"
    }

    var statusTone: AgentOSSourceStatusTone {
        switch status {
        case "Merged": .merged
        case "Open": .positive
        case "Draft": .neutral
        default: .negative
        }
    }

    var reviewStatus: String? {
        switch reviewDecision?.uppercased() {
        case "APPROVED": "Approved"
        case "CHANGES_REQUESTED": "Changes requested"
        case "REVIEW_REQUIRED": "Review required"
        default: nil
        }
    }

    var reviewStatusTone: AgentOSSourceStatusTone? {
        switch reviewDecision?.uppercased() {
        case "APPROVED": .positive
        case "CHANGES_REQUESTED": .negative
        case "REVIEW_REQUIRED": .warning
        default: nil
        }
    }
}

enum AgentOSSourcePresentation {
    static func localMetadata(for item: AgentOSSourceItem) -> AgentOSSourceMetadata {
        guard let url = URL(string: item.link.url) else {
            return AgentOSSourceMetadata(
                title: "Source",
                context: item.link.identity,
                status: nil,
                statusTone: .neutral,
                secondaryStatus: nil
            )
        }

        switch item.kind {
        case .slackThread:
            return slackMetadata(url: url, title: "Slack thread")
        case .pullRequest:
            return pullRequestMetadata(url: url)
        case .figma:
            return figmaMetadata(url: url)
        case .deployment:
            return AgentOSSourceMetadata(
                title: "Deployment preview",
                context: hostAndPath(url),
                status: nil,
                statusTone: .neutral,
                secondaryStatus: nil
            )
        case .other:
            return otherMetadata(url: url, fallback: item.link.identity)
        }
    }

    static func pullRequestMetadata(
        payload: GitHubPullRequestPayload,
        url: URL
    ) -> AgentOSSourceMetadata {
        let repository = githubRepository(url) ?? url.host() ?? "GitHub"
        return AgentOSSourceMetadata(
            title: payload.title,
            context: "\(repository) · PR #\(payload.number) · \(payload.baseRefName) ← \(payload.headRefName)",
            status: payload.status,
            statusTone: payload.statusTone,
            secondaryStatus: payload.reviewStatus,
            secondaryStatusTone: payload.reviewStatusTone
        )
    }

    private static func pullRequestMetadata(url: URL) -> AgentOSSourceMetadata {
        let components = pathComponents(url)
        let number = components.count >= 4 && components[2] == "pull" ? components[3] : nil
        return AgentOSSourceMetadata(
            title: number.map { "Pull request #\($0)" } ?? "GitHub pull request",
            context: githubRepository(url) ?? hostAndPath(url),
            status: nil,
            statusTone: .neutral,
            secondaryStatus: nil
        )
    }

    private static func slackMetadata(url: URL, title: String) -> AgentOSSourceMetadata {
        let workspace = (url.host() ?? "Slack").replacingOccurrences(of: ".slack.com", with: "")
        let components = pathComponents(url)
        let channel = components.count >= 2 && components[0] == "archives" ? components[1] : nil
        let timestamp = components.first(where: { $0.hasPrefix("p") }).flatMap(slackDate)
        let context = [
            workspace,
            channel.map { "channel \($0)" },
            timestamp?.formatted(date: .abbreviated, time: .shortened),
        ]
        .compactMap { $0 }
        .joined(separator: " · ")

        return AgentOSSourceMetadata(
            title: title,
            context: context,
            status: nil,
            statusTone: .neutral,
            secondaryStatus: nil
        )
    }

    private static func figmaMetadata(url: URL) -> AgentOSSourceMetadata {
        let components = pathComponents(url)
        let name = components.count >= 3 ? components[2].replacingOccurrences(of: "-", with: " ") : nil
        return AgentOSSourceMetadata(
            title: name?.removingPercentEncoding ?? "Figma design",
            context: "Figma design file",
            status: nil,
            statusTone: .neutral,
            secondaryStatus: nil
        )
    }

    private static func otherMetadata(url: URL, fallback: String) -> AgentOSSourceMetadata {
        let host = url.host() ?? ""
        if host.hasSuffix("slack.com"), url.path.hasPrefix("/docs/") {
            return slackMetadata(url: url, title: "Slack document")
        }
        if host == "github.com", let repository = githubRepository(url) {
            return AgentOSSourceMetadata(
                title: "GitHub repository",
                context: repository,
                status: nil,
                statusTone: .neutral,
                secondaryStatus: nil
            )
        }
        if host == "gist.github.com" {
            return AgentOSSourceMetadata(
                title: "GitHub Gist",
                context: hostAndPath(url),
                status: nil,
                statusTone: .neutral,
                secondaryStatus: nil
            )
        }
        if host.contains("youtube.com") || host == "youtu.be" {
            return AgentOSSourceMetadata(
                title: "YouTube reference",
                context: hostAndPath(url),
                status: nil,
                statusTone: .neutral,
                secondaryStatus: nil
            )
        }
        return AgentOSSourceMetadata(
            title: host.isEmpty ? "Source" : host,
            context: hostAndPath(url, fallback: fallback),
            status: nil,
            statusTone: .neutral,
            secondaryStatus: nil
        )
    }

    private static func githubRepository(_ url: URL) -> String? {
        let components = pathComponents(url)
        guard components.count >= 2 else { return nil }
        return "\(components[0])/\(components[1])"
    }

    private static func hostAndPath(_ url: URL, fallback: String = "Source") -> String {
        let host = url.host() ?? fallback
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return path.isEmpty ? host : "\(host)/\(path)"
    }

    private static func pathComponents(_ url: URL) -> [String] {
        url.pathComponents.filter { $0 != "/" }
    }

    private static func slackDate(_ component: String) -> Date? {
        let digits = component.dropFirst()
        guard digits.count >= 10, let seconds = TimeInterval(digits.prefix(10)) else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }
}
