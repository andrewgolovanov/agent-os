import SwiftUI

struct NewTaskSheet: View {
    let store: AgentOSStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var project = ""
    @State private var goal = ""
    @State private var nextAction = ""
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Agent OS outcome")
                .font(.title2.weight(.semibold))

            Form {
                TextField("Title", text: $title)
                Picker("Project", selection: $project) {
                    Text("Unassigned").tag("")
                    ForEach(store.projects) { project in
                        Text(project.displayName).tag(project.key)
                    }
                }
                TextField("Goal", text: $goal, axis: .vertical)
                    .lineLimit(2 ... 4)
                TextField("Next action", text: $nextAction, axis: .vertical)
                    .lineLimit(2 ... 4)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create") {
                    isSaving = true
                    Task {
                        let created = await store.createTask(
                            title: title,
                            project: project.isEmpty ? nil : project,
                            goal: goal,
                            nextAction: nextAction
                        )
                        isSaving = false
                        if created { dismiss() }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isSaving || title.isEmpty || goal.isEmpty || nextAction.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 480)
    }
}
