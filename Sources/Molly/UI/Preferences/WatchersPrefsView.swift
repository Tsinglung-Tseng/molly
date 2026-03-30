import SwiftUI

// MARK: - WatchersPrefsView

struct WatchersPrefsView: View {
    @ObservedObject private var workerManager = WorkerManager.shared
    @State private var config: AppConfig = .init()
    @State private var editingWatcher: WatcherDefinition? = nil
    @State private var showingAddSheet = false
    @State private var deletingWatcher: WatcherDefinition? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    sectionHeader("Watchers")
                    Spacer()
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("Add Watcher", systemImage: "plus")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.accentColor)
                    .padding(.trailing, 16)
                }

                if config.watchers.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Image(systemName: "wand.and.rays")
                                .font(.largeTitle)
                                .foregroundStyle(.tertiary)
                            Text("No watchers")
                                .foregroundStyle(.secondary)
                            Text("Add a watcher to run daemon processes when files change.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 16)
                        Spacer()
                    }
                } else {
                    ForEach(config.watchers) { watcher in
                        WatcherRowView(
                            watcher: watcher,
                            status: workerManager.statuses[watcher.id] ?? .stopped,
                            onToggle: { toggle(watcher) },
                            onEdit: { editingWatcher = watcher },
                            onDelete: { deletingWatcher = watcher }
                        )
                        if watcher.id != config.watchers.last?.id {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            config = await ConfigStore.shared.config
        }
        // Edit existing
        .sheet(item: $editingWatcher) { watcher in
            WatcherEditView(existing: watcher) { updated in
                Task {
                    try? await ConfigStore.shared.update { cfg in
                        guard let idx = cfg.watchers.firstIndex(where: { $0.id == updated.id }) else { return }
                        cfg.watchers[idx] = updated
                    }
                    config = await ConfigStore.shared.config
                    await WorkerManager.shared.syncFromConfig()
                }
            }
        }
        // Add new
        .sheet(isPresented: $showingAddSheet) {
            WatcherEditView(existing: nil) { newWatcher in
                Task {
                    try? await ConfigStore.shared.update { cfg in
                        cfg.watchers.append(newWatcher)
                    }
                    config = await ConfigStore.shared.config
                    await WorkerManager.shared.syncFromConfig()
                }
            }
        }
        // Delete confirmation
        .confirmationDialog(
            "Delete \"\(deletingWatcher?.label ?? "")\"?",
            isPresented: Binding(get: { deletingWatcher != nil }, set: { if !$0 { deletingWatcher = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let w = deletingWatcher else { return }
                deletingWatcher = nil
                Task {
                    try? await ConfigStore.shared.update { cfg in
                        cfg.watchers.removeAll { $0.id == w.id }
                    }
                    config = await ConfigStore.shared.config
                    await WorkerManager.shared.syncFromConfig()
                }
            }
            Button("Cancel", role: .cancel) { deletingWatcher = nil }
        } message: {
            Text("This watcher will be permanently removed.")
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
    }

    private func toggle(_ watcher: WatcherDefinition) {
        Task {
            await WorkerManager.shared.toggle(id: watcher.id)
            config = await ConfigStore.shared.config
        }
    }
}

// MARK: - WatcherRowView

private struct WatcherRowView: View {
    let watcher: WatcherDefinition
    let status: WorkerStatus
    let onToggle: () -> Void
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    @State private var isHovering = false

    private var statusColor: Color {
        switch status {
        case .idle:       return .green
        case .processing: return .blue
        case .error:      return .red
        case .stopped:    return .secondary
        case .starting:   return .orange
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                    Text(watcher.label)
                        .font(.body)
                }
                HStack(spacing: 3) {
                    Text(actionSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { onEdit?() }

            if let onEdit {
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.borderless)
            }

            if let onDelete {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }

            Toggle("", isOn: Binding(get: { status.isRunning }, set: { _ in onToggle() }))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(isHovering ? Color.primary.opacity(0.04) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        .onHover { isHovering = $0 }
    }

    private var actionSummary: String {
        let path = watcher.watchPath.isEmpty ? "vault root" : watcher.watchPath
        if watcher.startCmd.isEmpty {
            return "Watch \(path)"
        }
        let preview = watcher.startCmd.count > 40 ? String(watcher.startCmd.prefix(40)) + "…" : watcher.startCmd
        return "Watch \(path) → \(preview)"
    }
}

// MARK: - WatcherEditView

struct WatcherEditView: View {
    @Environment(\.dismiss) private var dismiss

    let existing: WatcherDefinition?
    let onSave: (WatcherDefinition) -> Void

    @State private var label: String
    @State private var watchPath: String
    @State private var recursive: Bool
    @State private var debounceSec: Double
    @State private var fileFilter: String
    @State private var startCmd: String
    @State private var startCwd: String

    init(existing: WatcherDefinition?, onSave: @escaping (WatcherDefinition) -> Void) {
        self.existing = existing
        self.onSave = onSave

        let w = existing ?? WatcherDefinition(
            id: UUID().uuidString,
            label: "",
            watchPath: ""
        )
        _label       = State(initialValue: w.label)
        _watchPath   = State(initialValue: w.watchPath)
        _recursive   = State(initialValue: w.recursive)
        _debounceSec = State(initialValue: w.debounceSec)
        _fileFilter  = State(initialValue: w.fileFilter)
        _startCmd    = State(initialValue: w.startCmd)
        _startCwd    = State(initialValue: w.startCwd)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(existing == nil ? "Add Watcher" : "Edit Watcher").font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { commit() }
                    .buttonStyle(.borderedProminent)
                    .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()

            Divider()

            Form {
                Section("General") {
                    LabeledContent("Name:") {
                        TextField("", text: $label)
                            .textFieldStyle(.roundedBorder)
                    }
                    LabeledContent("Watcher path:") {
                        TextField("", text: $watchPath)
                            .textFieldStyle(.roundedBorder)
                    }
                    Toggle("Include subdirectories", isOn: $recursive)
                    LabeledContent("Debounce (sec):") {
                        TextField("", value: $debounceSec, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 72)
                    }
                    LabeledContent("File filter:") {
                        TextField("", text: $fileFilter)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                Section("Daemon Process") {
                    LabeledContent("Start command:") {
                        TextField("", text: $startCmd)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                    LabeledContent("Working directory:") {
                        TextField("", text: $startCwd)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 500, height: 560)
    }

    private func commit() {
        let def = WatcherDefinition(
            id: existing?.id ?? UUID().uuidString,
            label: label.trimmingCharacters(in: .whitespaces),
            enabled: existing?.enabled ?? false,
            watchPath: watchPath,
            recursive: recursive,
            debounceSec: max(0.5, debounceSec),
            fileFilter: fileFilter.isEmpty ? "*.md" : fileFilter,
            builtinPreset: existing?.builtinPreset,
            startCmd: startCmd,
            startCwd: startCwd,
            startEnv: existing?.startEnv ?? [:]
        )
        onSave(def)
        dismiss()
    }
}
