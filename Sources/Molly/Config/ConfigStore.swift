import Foundation

actor ConfigStore {
    static let shared = ConfigStore()

    private(set) var config: AppConfig
    private let fileURL: URL
    private var continuations: [UUID: AsyncStream<AppConfig>.Continuation] = [:]

    private init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let dir = appSupport.appending(path: "Molly", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appending(path: "config.json")

        if let data = try? Data(contentsOf: fileURL),
           let loaded = try? JSONDecoder().decode(AppConfig.self, from: data) {
            config = ConfigStore.migrate(loaded)
        } else {
            config = AppConfig()
        }
    }

    // MARK: - Migration
    static func migrate(_ old: AppConfig) -> AppConfig {
        var cfg = old
        if cfg.configVersion < 2 {
            cfg = migrateV1toV2(cfg)
        }
        return cfg
    }

    private static func migrateV1toV2(_ cfg: AppConfig) -> AppConfig {
        var updated = cfg
        updated.configVersion = 2

        // 提升 claudeBin
        if updated.claudeBin.isEmpty && !cfg.clips.claudeBin.isEmpty {
            updated.claudeBin = cfg.clips.claudeBin
        }

        let existingIDs = Set(cfg.watchers.map(\.id))

        if !existingIDs.contains("builtin.clips") {
            updated.watchers.insert(
                WatcherDefinition(
                    id: "builtin.clips",
                    label: "Clip Processor",
                    enabled: cfg.clips.enabled,
                    watchPath: cfg.clips.clippingsSubdir,
                    recursive: false,
                    debounceSec: cfg.clips.debounceSec,
                    builtinPreset: .clips
                ),
                at: 0
            )
        }

        if !existingIDs.contains("builtin.ner") {
            updated.watchers.append(
                WatcherDefinition(
                    id: "builtin.ner",
                    label: "NER Tagger",
                    enabled: cfg.ner.enabled,
                    watchPath: "",
                    recursive: false,
                    debounceSec: cfg.ner.debounceSec,
                    builtinPreset: .ner
                )
            )
        }

        if !existingIDs.contains("builtin.pageindex") {
            updated.watchers.append(
                WatcherDefinition(
                    id: "builtin.pageindex",
                    label: "Note Indexer",
                    enabled: cfg.pageindex.enabled,
                    watchPath: "",
                    recursive: true,
                    debounceSec: 3.0,
                    builtinPreset: .pageindex
                )
            )
        }

        return updated
    }

    func update(_ transform: @Sendable (inout AppConfig) -> Void) async throws {
        transform(&config)
        try save()
        broadcast()
    }

    func reload() throws {
        let data = try Data(contentsOf: fileURL)
        config = try JSONDecoder().decode(AppConfig.self, from: data)
        broadcast()
    }

    private func save() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: fileURL, options: .atomic)
    }

    private func broadcast() {
        for continuation in continuations.values {
            continuation.yield(config)
        }
    }

    var configStream: AsyncStream<AppConfig> {
        AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation
            continuation.yield(config)
            continuation.onTermination = { [id] _ in
                Task { await self.removeContinuation(id: id) }
            }
        }
    }

    private func removeContinuation(id: UUID) {
        continuations.removeValue(forKey: id)
    }

    var configFileURL: URL { fileURL }

    var indexDirectory: URL {
        fileURL.deletingLastPathComponent().appending(path: "index", directoryHint: .isDirectory)
    }
}
