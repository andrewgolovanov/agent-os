import SwiftUI

struct TaskCardView: View {
    let task: AgentOSTask
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(task.title)
                    .font(.headline)
                    .lineLimit(2)
                Spacer(minLength: 8)
                Image(systemName: task.status.systemImage)
                    .foregroundStyle(task.status.tint)
            }

            if !task.summary.isEmpty {
                Text(task.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            HStack(spacing: 8) {
                ForEach(task.projects.prefix(2), id: \.self) { project in
                    Text(project)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !task.codexThreads.isEmpty {
                    Label("\(task.codexThreads.count)", systemImage: "terminal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        }
        .contentShape(Rectangle())
    }
}
