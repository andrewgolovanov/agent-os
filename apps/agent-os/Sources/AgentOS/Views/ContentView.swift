import SwiftUI

struct ContentView: View {
    let store: AgentOSStore
    @SceneStorage("agent-os.scope") private var scope = "focus"
    @State private var selectedTaskID: String?
    @State private var showsTaskInspector = false
    @State private var sidebarWidth: CGFloat = AgentOSMetrics.sidebarWidth
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

    private var taskSelection: Binding<String?> {
        Binding(
            get: { selectedTaskID },
            set: { taskID in
                withoutAnimation {
                    selectedTaskID = taskID
                    showsTaskInspector = taskID != nil
                }
            }
        )
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(projects: store.projects, tasks: store.tasks, selection: $scope)
                .navigationSplitViewColumnWidth(
                    min: 210,
                    ideal: AgentOSMetrics.sidebarWidth,
                    max: AgentOSMetrics.sidebarWidth
                )
        } detail: {
            HSplitView {
                ZStack {
                    scopedContent
                        .allowsHitTesting(!showsTaskInspector)
                        .accessibilityHidden(showsTaskInspector)

                    if showsTaskInspector {
                        AgentOSTheme.inspectorBackdrop
                            .contentShape(Rectangle())
                            .onTapGesture(perform: closeInspector)
                            .accessibilityHidden(true)
                    }
                }
                .frame(minWidth: 560, maxWidth: .infinity, maxHeight: .infinity)

                if showsTaskInspector, let selectedTask {
                    TaskInspectorView(
                        task: selectedTask,
                        isBusy: store.busyTaskID == selectedTask.id,
                        sourceMetadata: store.sourceMetadata,
                        loadingSourceIDs: store.loadingSourceIDs,
                        onClose: closeInspector,
                        onStatusChange: { status in
                            Task { await store.updateStatus(taskID: selectedTask.id, status: status) }
                        },
                        onOpenNewCodex: {
                            Task { await store.openNewCodexTask(taskID: selectedTask.id) }
                        },
                        onOpenCodex: { threadID in
                            Task { await store.openCodexTask(threadID: threadID) }
                        }
                    )
                    .frame(minWidth: 360, idealWidth: 420, maxWidth: 520, maxHeight: .infinity)
                    .task(id: "\(selectedTask.id):\(selectedTask.updatedAt)") {
                        await store.loadSourceMetadata(for: selectedTask)
                    }
                }
            }
            .background(AgentOSTheme.canvas)
            .animation(nil, value: showsTaskInspector)
        }
        .onPreferenceChange(SidebarWidthPreferenceKey.self) { sidebarWidth = $0 }
        .background {
            WindowSidebarDivider(sidebarWidth: sidebarWidth)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search outcomes")
        .tint(AgentOSTheme.accent)
        .toolbar {
            ToolbarItemGroup {
                if store.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task { await store.refresh() }
                }
                .foregroundStyle(AgentOSTheme.textPrimary)
                .help("Sync Task Board")
                .keyboardShortcut("r", modifiers: [.command])
                Button("New outcome", systemImage: "plus") {
                    showsNewTask = true
                }
                .foregroundStyle(AgentOSTheme.textPrimary)
                .help("Create a new outcome")
                .keyboardShortcut("n", modifiers: [.command])
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let message = store.errorMessage ?? store.noticeMessage {
                HStack {
                    Image(systemName: store.errorMessage == nil ? "info.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(store.errorMessage == nil ? AgentOSTheme.information : AgentOSTheme.warning)
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(AgentOSTheme.textPrimary)
                        .lineLimit(2)
                    Spacer()
                    Button("Dismiss") {
                        store.errorMessage = nil
                        store.noticeMessage = nil
                    }
                }
                .padding(10)
                .background(AgentOSTheme.surface)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(AgentOSTheme.border)
                        .frame(height: 1)
                }
            }
        }
        .sheet(isPresented: $showsNewTask) {
            NewTaskSheet(store: store)
        }
        .task {
            await store.bootstrap()
        }
        .onChange(of: scope) { _, _ in
            closeInspector()
        }
        .onChange(of: store.tasks.map(\.id)) { _, taskIDs in
            guard let selectedTaskID, !taskIDs.contains(selectedTaskID) else { return }
            closeInspector()
        }
        .onOpenURL { url in
            switch AgentOSDeepLink.destination(for: url) {
            case .board:
                scope = "board"
                closeInspector()
                Task { await store.refresh() }
            case .focus:
                scope = "focus"
                closeInspector()
                Task { await store.refresh() }
            case nil:
                break
            }
        }
    }

    private func closeInspector() {
        withoutAnimation {
            showsTaskInspector = false
            selectedTaskID = nil
        }
    }

    @ViewBuilder
    private var scopedContent: some View {
        if scope == "focus" {
            FocusView(
                projects: store.projects,
                tasks: visibleTasks,
                selectedTaskID: taskSelection
            )
        } else {
            BoardView(tasks: visibleTasks, selectedTaskID: taskSelection)
        }
    }

    private func withoutAnimation(_ updates: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, updates)
    }
}
