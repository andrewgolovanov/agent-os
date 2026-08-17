import SwiftUI

struct ContentView: View {
    let store: AgentOSStore
    @SceneStorage("agent-os.scope") private var scope = "focus"
    @State private var selectedTaskID: String?
    @State private var showsTaskInspector = false
    @State private var inspectorWidth = AgentOSMetrics.inspectorIdealWidth
    @State private var inspectorResizeStartWidth: CGFloat?
    @State private var sidebarWidth: CGFloat = AgentOSMetrics.sidebarWidth
    @State private var searchText = ""
    @State private var showsNewTask = false
    @AppStorage(AgentOSAppearance.storageKey) private var storedAppearance = AgentOSAppearance.dark.rawValue

    private var appearance: AgentOSAppearance {
        AgentOSAppearance(rawValue: storedAppearance) ?? .dark
    }

    private var visibleTasks: [AgentOSTask] {
        let scoped: [AgentOSTask]
        if scope == "focus" {
            scoped = store.attentionTasks
        } else if scope == "done" {
            scoped = store.completedTasks
        } else if let project = scopeProject {
            scoped = store.unfinishedTasks.filter { $0.projects.contains(project) }
        } else if let label = scopeLabel {
            scoped = store.unfinishedTasks.filter { task in
                task.labels.contains { $0.key == label }
            }
        } else {
            scoped = store.unfinishedTasks
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return scoped }
        return scoped.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.summary.localizedCaseInsensitiveContains(query)
                || $0.goal.localizedCaseInsensitiveContains(query)
                || $0.nextAction.localizedCaseInsensitiveContains(query)
                || $0.projects.contains { $0.localizedCaseInsensitiveContains(query) }
                || $0.labels.contains { $0.name.localizedCaseInsensitiveContains(query) }
                || $0.sources.all.contains {
                    $0.url.localizedCaseInsensitiveContains(query)
                        || ($0.title?.localizedCaseInsensitiveContains(query) ?? false)
                }
        }
    }

    private var scopeProject: String? {
        guard scope.hasPrefix("project:") else { return nil }
        return String(scope.dropFirst("project:".count))
    }

    private var scopeLabel: String? {
        guard scope.hasPrefix("label:") else { return nil }
        return String(scope.dropFirst("label:".count))
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
            detailPane
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
                Button(appearance.toggleLabel, systemImage: appearance.toggleSystemImage) {
                    storedAppearance = appearance.toggled.rawValue
                }
                .foregroundStyle(AgentOSTheme.textPrimary)
                .help(appearance.toggleLabel)
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
            case .done:
                scope = "done"
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
            inspectorResizeStartWidth = nil
        }
    }

    private var detailPane: some View {
        ZStack(alignment: .trailing) {
            scopedContent
                .allowsHitTesting(!showsTaskInspector)
                .accessibilityHidden(showsTaskInspector)

            if showsTaskInspector {
                AgentOSTheme.inspectorBackdrop
                    .contentShape(Rectangle())
                    .onTapGesture(perform: closeInspector)
                    .accessibilityHidden(true)
            }

            if showsTaskInspector, let selectedTask {
                taskInspector(for: selectedTask)
                    .frame(width: inspectorWidth)
                    .frame(maxHeight: .infinity)
                    .overlay(alignment: .leading) {
                        inspectorResizeHandle
                    }
                    .zIndex(1)
            }
        }
        .frame(minWidth: 560, maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .background(AgentOSTheme.canvas)
        .animation(nil, value: showsTaskInspector)
    }

    private func taskInspector(for selectedTask: AgentOSTask) -> some View {
        TaskInspectorView(
            task: selectedTask,
            isBusy: store.busyTaskID == selectedTask.id,
            sourceMetadata: store.sourceMetadata,
            loadingSourceIDs: store.loadingSourceIDs,
            onClose: closeInspector,
            onStatusChange: { status in
                Task { await store.updateStatus(taskID: selectedTask.id, status: status) }
            },
            onCompletionFollowUpChange: { status in
                Task { await store.updateCompletionFollowUp(taskID: selectedTask.id, status: status) }
            },
            onCopyCompletionUpdate: {
                store.copyCompletionUpdate(taskID: selectedTask.id)
            },
            onOpenNewCodex: {
                Task { await store.openNewCodexTask(taskID: selectedTask.id) }
            },
            onOpenCodex: { threadID in
                Task { await store.openCodexTask(threadID: threadID) }
            }
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(AgentOSTheme.border)
                .frame(width: 1)
                .accessibilityHidden(true)
        }
        .task(id: "\(selectedTask.id):\(selectedTask.updatedAt)") {
            await store.loadSourceMetadata(for: selectedTask)
        }
    }

    private var inspectorResizeHandle: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: AgentOSMetrics.inspectorResizeHandleWidth)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if inspectorResizeStartWidth == nil {
                            inspectorResizeStartWidth = inspectorWidth
                        }
                        let startWidth = inspectorResizeStartWidth ?? inspectorWidth
                        inspectorWidth = AgentOSMetrics.clampedInspectorWidth(
                            startWidth - value.translation.width
                        )
                    }
                    .onEnded { _ in
                        inspectorResizeStartWidth = nil
                    }
            )
            .horizontalResizeCursor()
            .accessibilityElement()
            .accessibilityLabel("Task detail width")
            .accessibilityValue("\(Int(inspectorWidth)) points")
            .accessibilityAdjustableAction { direction in
                let delta: CGFloat = direction == .increment
                    ? AgentOSMetrics.inspectorResizeStep
                    : -AgentOSMetrics.inspectorResizeStep
                inspectorWidth = AgentOSMetrics.clampedInspectorWidth(inspectorWidth + delta)
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
            if scope == "done" {
                DoneView(
                    projects: store.projects,
                    tasks: visibleTasks,
                    selectedTaskID: taskSelection
                )
            } else {
                BoardView(tasks: visibleTasks, selectedTaskID: taskSelection)
            }
        }
    }

    private func withoutAnimation(_ updates: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, updates)
    }
}
