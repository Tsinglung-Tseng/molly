import Foundation
import SwiftUI

// MARK: - WorkerStatus

enum WorkerStatus: Sendable, Equatable {
    case stopped
    case starting
    case idle
    case processing(String = "")
    case error(String = "")

    var isRunning: Bool {
        switch self {
        case .idle, .processing, .starting: return true
        case .stopped, .error: return false
        }
    }

    var label: String {
        switch self {
        case .stopped: return "Stopped"
        case .starting: return "Starting…"
        case .idle: return "Running"
        case .processing(let s): return s.isEmpty ? "Processing" : s
        case .error(let s): return s.isEmpty ? "Error" : s
        }
    }

    var symbolName: String {
        switch self {
        case .stopped: return "stop.circle"
        case .starting: return "hourglass"
        case .idle: return "checkmark.circle"
        case .processing: return "arrow.triangle.2.circlepath"
        case .error: return "exclamationmark.triangle"
        }
    }
}

// MARK: - AggregateStatus

enum AggregateStatus: Sendable {
    case allRunning
    case partial
    case allStopped
    case error
}

// MARK: - WorkerError

enum WorkerError: Error, LocalizedError {
    case noVaultPath
    case missingClaudeBin
    case claudeFailed(Int)
    case indexingFailed(String)

    var errorDescription: String? {
        switch self {
        case .noVaultPath: return "Vault path not configured"
        case .missingClaudeBin: return "Claude binary not found"
        case .claudeFailed(let code): return "Claude exited with code \(code)"
        case .indexingFailed(let msg): return "Indexing failed: \(msg)"
        }
    }
}

// MARK: - DaemonHandle

/// Manages a single long-running child process.
private final class DaemonHandle: @unchecked Sendable {
    let id: WatcherID
    let label: String
    private var process: Process?
    private let log = MollyLogger.shared

    init(id: WatcherID, label: String) {
        self.id = id
        self.label = label
    }

    /// Launch the daemon process. Returns immediately; call `setStatus` on status changes.
    func start(
        cmd: String,
        cwd: String,
        env: [String: String],
        mollyEnv: [String: String],
        setStatus: @escaping @Sendable (WorkerStatus) -> Void
    ) {
        let p = Process()
        p.executableURL = URL(filePath: "/bin/zsh")
        // Use `exec` to replace zsh with the target process so there's no
        // intermediate shell. This ensures terminate() kills the actual daemon,
        // not just a wrapper shell that leaves orphaned children.
        // For compound commands (pipes, &&, etc.) fall back to process-group kill.
        let needsShell = cmd.contains("|") || cmd.contains("&&") || cmd.contains(";")
        p.arguments = ["-c", needsShell ? cmd : "exec \(cmd)"]
        p.currentDirectoryURL = URL(filePath: cwd)

        // Merge environment: inherit current + MOLLY_* + watcher-specific
        var merged = ProcessInfo.processInfo.environment
        for (k, v) in mollyEnv { merged[k] = v }
        for (k, v) in env { merged[k] = v }
        // Tag child with parent PID so orphans can be identified after a crash
        merged["MOLLY_PARENT_PID"] = "\(ProcessInfo.processInfo.processIdentifier)"
        p.environment = merged

        // Capture stdout — parse Molly Service Protocol lines
        let stdoutPipe = Pipe()
        p.standardOutput = stdoutPipe
        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let self else { return }
            let text = String(decoding: data, as: UTF8.self)
            for line in text.components(separatedBy: .newlines) where !line.isEmpty {
                if line == "MOLLY_READY" {
                    setStatus(.idle)
                    self.log.log("Ready", source: self.label)
                } else if line.hasPrefix("MOLLY_STATUS:") {
                    let payload = line.dropFirst("MOLLY_STATUS:".count).trimmingCharacters(in: .whitespaces)
                    if payload.hasPrefix("processing") {
                        let detail = payload.dropFirst("processing".count).trimmingCharacters(in: .whitespaces)
                        setStatus(.processing(String(detail)))
                    } else if payload == "idle" {
                        setStatus(.idle)
                    } else if payload.hasPrefix("error") {
                        let detail = payload.dropFirst("error".count).trimmingCharacters(in: .whitespaces)
                        setStatus(.error(String(detail)))
                    }
                } else {
                    // Regular stdout → log panel
                    self.log.log(line, source: self.label)
                }
            }
        }

        // Capture stderr → log panel
        let stderrPipe = Pipe()
        p.standardError = stderrPipe
        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let self else { return }
            let text = String(decoding: data, as: UTF8.self)
            for line in text.components(separatedBy: .newlines) where !line.isEmpty {
                self.log.log(line, source: self.label)
            }
        }

        p.terminationHandler = { [weak self] proc in
            guard let self else { return }
            let code = proc.terminationStatus
            if code == 0 {
                setStatus(.stopped)
                self.log.log("Exited normally", source: self.label)
            } else {
                setStatus(.error("exit \(code)"))
                self.log.log("Exited with code \(code)", source: self.label)
            }
        }

        do {
            try p.run()
            process = p
            setStatus(.starting)
            log.log("Started: \(cmd) (pid \(p.processIdentifier))", source: label)
        } catch {
            setStatus(.error(error.localizedDescription))
            log.log("Failed to start: \(error.localizedDescription)", source: label)
        }
    }

    func stop() {
        guard let p = process, p.isRunning else { return }
        let pid = p.processIdentifier

        // Kill the direct process
        kill(pid, SIGTERM)
        // Also kill any child processes (covers compound commands where exec isn't used)
        Self.killDescendants(of: pid, signal: SIGTERM)

        log.log("Sent SIGTERM to process tree (pid \(pid))", source: label)

        // Give it 3 seconds then force kill the whole tree
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self else { return }
            if kill(pid, 0) == 0 { // still alive?
                kill(pid, SIGKILL)
                Self.killDescendants(of: pid, signal: SIGKILL)
                self.log.log("Sent SIGKILL to process tree (pid \(pid))", source: self.label)
            }
        }
        process = nil
    }

    /// Kill all descendant processes of the given PID.
    static func killDescendants(of pid: Int32, signal: Int32) {
        // Use pgrep to find children, then recurse
        let task = Process()
        task.executableURL = URL(filePath: "/usr/bin/pgrep")
        task.arguments = ["-P", "\(pid)"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: data, as: UTF8.self)
        for line in output.split(separator: "\n") {
            if let childPid = Int32(line.trimmingCharacters(in: .whitespaces)) {
                // Recurse first (kill grandchildren before children)
                killDescendants(of: childPid, signal: signal)
                kill(childPid, signal)
            }
        }
    }

    var isRunning: Bool { process?.isRunning ?? false }
}

// MARK: - WorkerManager

/// Manages daemon worker processes. Each watcher with a non-empty `startCmd`
/// gets a child process spawned via `/bin/zsh -c`. Stdout is parsed for
/// Molly Service Protocol lines (MOLLY_READY, MOLLY_STATUS:).
@MainActor
final class WorkerManager: ObservableObject {
    static let shared = WorkerManager()

    @Published var statuses: [WatcherID: WorkerStatus] = [:]
    private var daemons: [WatcherID: DaemonHandle] = [:]
    private let log = MollyLogger.shared

    var aggregateStatus: AggregateStatus {
        guard !statuses.isEmpty else { return .allStopped }
        let values = Array(statuses.values)
        if values.allSatisfy({ if case .error = $0 { return true }; return false }) { return .error }
        if values.allSatisfy(\.isRunning) { return .allRunning }
        if values.contains(where: \.isRunning) { return .partial }
        return .allStopped
    }

    private init() {
        Task {
            await syncFromConfig()
            await startEnabled()
            log.log("Initialized with \(statuses.count) watcher(s)", source: "WorkerManager")
        }
    }

    // MARK: - Public API

    /// Reload watcher definitions from ConfigStore and reconcile statuses.
    func syncFromConfig() async {
        let cfg = await ConfigStore.shared.config
        var next: [WatcherID: WorkerStatus] = [:]
        for w in cfg.watchers {
            next[w.id] = statuses[w.id] ?? .stopped
        }
        // Remove daemons for watchers no longer in config
        for id in daemons.keys where next[id] == nil {
            daemons[id]?.stop()
            daemons.removeValue(forKey: id)
        }
        statuses = next
        log.log("Synced \(cfg.watchers.count) watcher(s) from config", source: "WorkerManager")
    }

    /// Start all enabled watchers that aren't already running.
    func startEnabled() async {
        let cfg = await ConfigStore.shared.config
        for w in cfg.watchers where w.enabled {
            if let existing = daemons[w.id], existing.isRunning { continue }
            startDaemon(for: w, config: cfg)
        }
    }

    /// Stop all watchers and kill their daemon processes.
    func stopAll() async {
        for (id, handle) in daemons {
            handle.stop()
            statuses[id] = .stopped
        }
        daemons.removeAll()

        log.log("All watchers stopped", source: "WorkerManager")
    }

    /// Toggle a single watcher on/off.
    func toggle(id: WatcherID) async {
        let current = statuses[id] ?? .stopped
        if current.isRunning {
            // Stop
            daemons[id]?.stop()
            daemons.removeValue(forKey: id)
            statuses[id] = .stopped
    
            try? await ConfigStore.shared.update { cfg in
                if let idx = cfg.watchers.firstIndex(where: { $0.id == id }) {
                    cfg.watchers[idx].enabled = false
                }
            }
            log.log("\(id) stopped", source: "WorkerManager")
        } else {
            // Start
            let cfg = await ConfigStore.shared.config
            guard let w = cfg.watchers.first(where: { $0.id == id }) else { return }
            startDaemon(for: w, config: cfg)
            try? await ConfigStore.shared.update { cfg in
                if let idx = cfg.watchers.firstIndex(where: { $0.id == id }) {
                    cfg.watchers[idx].enabled = true
                }
            }
            log.log("\(id) started", source: "WorkerManager")
        }
    }

    // MARK: - Private

    private func startDaemon(for watcher: WatcherDefinition, config: AppConfig) {
        guard !watcher.startCmd.isEmpty else {
            statuses[watcher.id] = .error("No startCmd")
            log.log("Skipped — no startCmd configured", source: watcher.label)
            return
        }

        let handle = DaemonHandle(id: watcher.id, label: watcher.label)
        daemons[watcher.id] = handle

        // Build MOLLY_* environment variables
        var mollyEnv: [String: String] = [
            "MOLLY_VAULT_PATH": config.vaultPath,
            "MOLLY_CLAUDE_BIN": config.claudeBin,
            "MOLLY_LLM_API_URL": config.llm.apiURL,
            "MOLLY_LLM_API_KEY": config.llm.apiKey,
            "MOLLY_LLM_MODEL": config.llm.model,
        ]
        // PageIndex specific
        if watcher.builtinPreset == .pageindex {
            mollyEnv["MOLLY_INDEX_DIR"] = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first!.appending(path: "Molly/index").path()
        }

        let watcherID = watcher.id
        handle.start(
            cmd: watcher.startCmd,
            cwd: watcher.startCwd,
            env: watcher.startEnv,
            mollyEnv: mollyEnv
        ) { [weak self] newStatus in
            DispatchQueue.main.async {
                self?.statuses[watcherID] = newStatus
            }
        }

    }
}
