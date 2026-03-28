import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

@main
struct MollyApp: App {
    @StateObject private var workerManager = WorkerManager.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(workerManager)
        } label: {
            MenuBarLabel(status: workerManager.aggregateStatus)
        }
        .menuBarExtraStyle(.window)

        Window("Molly Settings", id: "settings") {
            PreferencesView()
                .environmentObject(workerManager)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 620, height: 520)
    }
}

struct MenuBarLabel: View {
    let status: AggregateStatus

    var body: some View {
        Image(systemName: imageName)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(statusColor)
    }

    private var imageName: String {
        switch status {
        case .allRunning: return "wand.and.stars"
        case .partial: return "wand.and.stars.inverse"
        case .allStopped: return "wand.and.stars"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch status {
        case .allRunning: return .green
        case .partial: return .orange
        case .allStopped: return .secondary
        case .error: return .red
        }
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock — equivalent to LSUIElement = YES in Info.plist
        NSApp.setActivationPolicy(.accessory)

        // Workers start via WorkerManager.init() after syncFromConfig()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false  // Stay alive as menu bar app when windows are closed
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Stop all daemon workers before quitting so child processes don't become orphans
        Task { @MainActor in
            await WorkerManager.shared.stopAll()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
