import SwiftUI

// MARK: - WatcherRow model
private struct WatcherRowModel: Identifiable {
    var id: String
    var label: String
}

// MARK: - MenuBarView

struct MenuBarView: View {
    @EnvironmentObject var workerManager: WorkerManager
    @State private var config: AppConfig = .init()
    @Environment(\.openWindow) private var openWindow

    // MARK: - Derived data

    private var rows: [WatcherRowModel] {
        config.watchers.map { WatcherRowModel(id: $0.id, label: $0.label) }
    }

    private func status(for row: WatcherRowModel) -> WorkerStatus {
        workerManager.statuses[row.id] ?? .stopped
    }

    private var runningCount: Int {
        rows.filter { status(for: $0).isRunning }.count
    }

    private var aggregateColor: Color {
        let agg = workerManager.aggregateStatus
        switch agg {
        case .allRunning: return .green
        case .partial:    return .orange
        case .allStopped: return .secondary
        case .error:      return .red
        }
    }

    private var subtitleText: String {
        let total = rows.count
        let running = runningCount
        if running == 0 { return "All stopped" }
        if running == total { return "All \(total) running" }
        return "\(running) of \(total) running"
    }

    private var isAllRunning: Bool {
        runningCount == rows.count && !rows.isEmpty
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            watcherListSection
            Divider()
            actionSection
            Divider()
            quitSection
        }
        .frame(width: 300)
        .task {
            config = await ConfigStore.shared.config
        }
    }

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
        HStack(alignment: .top, spacing: 8) {
            // 状态圆点
            Circle()
                .fill(aggregateColor)
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            // 标题 + 副标题
            VStack(alignment: .leading, spacing: 2) {
                Text("Molly")
                    .font(.headline)
                Text(subtitleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 全局操作按钮
            if isAllRunning {
                Button {
                    Task { await workerManager.stopAll() }
                } label: {
                    Label("Stop All", systemImage: "stop.fill")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Button {
                    Task { await workerManager.startEnabled() }
                } label: {
                    Label("Start All", systemImage: "play.fill")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Watcher List Section

    @ViewBuilder
    private var watcherListSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WATCHERS")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            ForEach(rows) { row in
                WatcherCard(
                    label: row.label,
                    status: status(for: row),
                    onToggle: {
                        Task { await workerManager.toggle(id: row.id) }
                    }
                )
                .padding(.horizontal, 8)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Action Section

    @ViewBuilder
    private var actionSection: some View {
        VStack(spacing: 0) {
            ActionRow(label: "Preferences…", shortcut: "⌘,") {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    // MARK: - Quit Section

    @ViewBuilder
    private var quitSection: some View {
        ActionRow(label: "Quit Molly", shortcut: "⌘Q", showChevron: false) {
            Task { await WorkerManager.shared.stopAll() }
            NSApp.terminate(nil)
        }
    }
}

// MARK: - WatcherCard

private struct WatcherCard: View {
    let label: String
    let status: WorkerStatus
    let onToggle: () -> Void

    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 1.0

    private var statusColor: Color {
        switch status {
        case .idle:       return .green
        case .processing: return .blue
        case .error:      return .red
        case .stopped:    return .secondary
        case .starting:   return .orange
        }
    }

    private var statusLabel: String {
        switch status {
        case .idle:             return "Running"
        case .processing:       return "Processing"
        case .error:            return "Error"
        case .stopped:          return "Stopped"
        case .starting:         return "Starting…"
        }
    }

    private var isProcessing: Bool {
        if case .processing = status { return true }
        return false
    }

    private var isOn: Binding<Bool> {
        Binding(
            get: { status.isRunning },
            set: { _ in onToggle() }
        )
    }

    var body: some View {
        HStack(spacing: 8) {
            // 状态圆点（processing 时有脉冲动画）
            ZStack {
                if isProcessing {
                    Circle()
                        .fill(statusColor.opacity(0.4))
                        .frame(width: 8, height: 8)
                        .scaleEffect(pulseScale)
                        .opacity(pulseOpacity)
                }
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }
            .frame(width: 12)
            .onAppear {
                guard isProcessing else { return }
                withAnimation(
                    .easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: false)
                ) {
                    pulseScale = 1.8
                    pulseOpacity = 0
                }
            }

            // Worker 名称
            Text(label)
                .font(.body)
                .lineLimit(1)

            Spacer()

            // 状态文字
            Text(statusLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Toggle
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.background.secondary)
        )
    }
}

// MARK: - ActionRow

private struct ActionRow: View {
    let label: String
    let shortcut: String
    var showChevron: Bool = true
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.body)
                Spacer()
                Text(shortcut)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background(
                isHovered
                    ? Color.primary.opacity(0.06)
                    : Color.clear
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
