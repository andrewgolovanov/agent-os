import SwiftUI

struct BoardView: View {
    let tasks: [AgentOSTask]
    @Binding var selectedTaskID: String?

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 14) {
                ForEach(TaskStatus.boardColumns) { status in
                    boardColumn(status)
                }
            }
            .padding()
        }
        .navigationTitle("Board")
    }

    private func boardColumn(_ status: TaskStatus) -> some View {
        let columnTasks = tasks.filter { $0.status == status }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(status.displayName, systemImage: status.systemImage)
                    .font(.headline)
                    .foregroundStyle(status.tint)
                Spacer()
                Text(columnTasks.count, format: .number)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if columnTasks.isEmpty {
                ContentUnavailableView("No tasks", systemImage: "tray")
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ForEach(columnTasks) { task in
                    Button {
                        selectedTaskID = task.id
                    } label: {
                        TaskCardView(task: task, isSelected: selectedTaskID == task.id)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 286, alignment: .top)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
