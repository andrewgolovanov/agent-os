import SwiftUI

struct FocusView: View {
    let tasks: [AgentOSTask]
    @Binding var selectedTaskID: String?

    var body: some View {
        List(selection: $selectedTaskID) {
            ForEach(tasks) { task in
                HStack(spacing: 12) {
                    Image(systemName: task.status.systemImage)
                        .foregroundStyle(task.status.tint)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(task.nextAction)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Text(task.status.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .tag(task.id)
            }
        }
        .overlay {
            if tasks.isEmpty {
                ContentUnavailableView("Nothing needs attention", systemImage: "checkmark.circle")
            }
        }
        .navigationTitle("Focus")
    }
}
