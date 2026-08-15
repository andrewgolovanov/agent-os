import SwiftUI

struct ContentView: View {
    let store: AgentOSStore
    @SceneStorage("agent-os.scope") private var scope = "focus"
    @SceneStorage("agent-os.selected-task") private var selectedTaskID: String?
    @State private var searchText = ""
    @State private var showsNewTask = false

    private var visibleTasks: [AgentOSTask] {
        let scoped: [AgentOSTask]
        if scope == "focus" {
            scoped = store.attentionTasks
        } else if let project = scopeProject {
            scoped = store.unfinishedTasks.filter { $0.projects.contains(project) }
        } else {
            scoped = store.unfinishedTasks
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return scoped }
        return scoped.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.summary.localizedCaseInsensitiveContains(query)
                || $0.nextAction.localizedCaseInsensitiveContains(query)
        }
    }

    private var scopeProject: String? {
        guard scope.hasPrefix("project:") else { return nil }
        return String(scope.dropFirst("project:".count))
    }

    private var selectedTask: AgentOSTask? {
        guard let selectedTaskID else { return nil }
        return store.tasks.first { $0.id == selectedTaskID }
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(projects: store.projects, tasks: store.tasks, selection: $scope)
                .navigationSplitViewColumnWidth(min: 210, ideal: 240)
        } content: {
            Group {
                if scope == "focus" {
                    FocusView(tasks: visibleTasks, selectedTaskID: $selectedTaskID)
                } else {
                    BoardView(tasks: visibleTasks, selectedTaskID: $selectedTaskID)
                }
            }
            .navigationSplitViewColumnWidth(min: 520, ideal: 760)
        } detail: {
            TaskInspectorView(
                task: selectedTask,
                isBusy: store.busyTaskID == selectedTaskID,
                onStatusChange: { status in
                    guard let selectedTaskID else { return }
                    Task { await store.updateStatus(taskID: selectedTaskID, status: status) }
                },
                onOpenNewCodex: {
                    guard let selectedTaskID else { return }
                    Task { await store.openNewCodexTask(taskID: selectedTaskID) }
                },
                onOpenCodex: { threadID in
                    Task { await store.openCodexTask(threadID: threadID) }
                }
            )
            .navigationSplitViewColumnWidth(min: 300, ideal: 360)
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search outcomes")
        .toolbar {
            ToolbarItemGroup {
                if store.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task { await store.refresh() }
                }
                .keyboardShortcut("r", modifiers: [.command])
                Button("New outcome", systemImage: "plus") {
                    showsNewTask = true
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let message = store.errorMessage ?? store.noticeMessage {
                HStack {
                    Image(systemName: store.errorMessage == nil ? "info.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(store.errorMessage == nil ? .blue : .orange)
                    Text(message)
                        .font(.callout)
                        .lineLimit(2)
                    Spacer()
                    Button("Dismiss") {
                        store.errorMessage = nil
                        store.noticeMessage = nil
                    }
                }
                .padding(10)
                .background(.bar)
            }
        }
        .sheet(isPresented: $showsNewTask) {
            NewTaskSheet(store: store)
        }
        .task {
            await store.bootstrap()
        }
    }
}
