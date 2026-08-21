import Foundation

enum FocusDateBucket: Int, CaseIterable, Identifiable {
    case today
    case yesterday
    case thisWeek
    case lastWeek
    case earlier

    var id: Self { self }

    var title: String {
        switch self {
        case .today: "Today"
        case .yesterday: "Yesterday"
        case .thisWeek: "This Week"
        case .lastWeek: "Last Week"
        case .earlier: "Earlier"
        }
    }
}

struct FocusTaskSection: Identifiable {
    let bucket: FocusDateBucket
    let tasks: [AgentOSTask]

    var id: FocusDateBucket { bucket }
    var title: String { bucket.title }
}

enum FocusListRow: Identifiable {
    case section(FocusDateBucket)
    case task(AgentOSTask)

    var id: String {
        switch self {
        case let .section(bucket): "section:\(bucket.rawValue)"
        case let .task(task): "task:\(task.id)"
        }
    }
}

enum FocusDateSections {
    static func make(
        from tasks: [AgentOSTask],
        relativeTo now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> [FocusTaskSection] {
        let grouped = Dictionary(grouping: tasks) { task in
            bucket(for: task.updatedAt, relativeTo: now, calendar: calendar)
        }

        return FocusDateBucket.allCases.compactMap { bucket in
            guard let tasks = grouped[bucket], !tasks.isEmpty else { return nil }
            return FocusTaskSection(bucket: bucket, tasks: tasks)
        }
    }

    static func rows(
        from tasks: [AgentOSTask],
        relativeTo now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> [FocusListRow] {
        make(from: tasks, relativeTo: now, calendar: calendar).flatMap { section in
            [.section(section.bucket)] + section.tasks.map(FocusListRow.task)
        }
    }

    static func bucket(
        for timestamp: String,
        relativeTo now: Date,
        calendar: Calendar
    ) -> FocusDateBucket {
        guard let date = parse(timestamp) else { return .earlier }

        let startOfToday = calendar.startOfDay(for: now)
        if date >= startOfToday {
            return .today
        }

        guard let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) else {
            return .earlier
        }
        if date >= startOfYesterday {
            return .yesterday
        }

        guard let startOfThisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start else {
            return .earlier
        }
        if date >= startOfThisWeek {
            return .thisWeek
        }

        guard let startOfLastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfThisWeek) else {
            return .earlier
        }
        return date >= startOfLastWeek ? .lastWeek : .earlier
    }

    private static func parse(_ timestamp: String) -> Date? {
        if let date = try? Date(
            timestamp,
            strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        ) {
            return date
        }
        return try? Date(timestamp, strategy: Date.ISO8601FormatStyle())
    }
}

enum FocusListLayout {
    static func sectionTopPadding(addsContentPadding: Bool) -> CGFloat {
        AgentOSMetrics.focusSectionHeaderTopPadding
            + (addsContentPadding ? AgentOSMetrics.focusContentTopPadding : 0)
    }
}
