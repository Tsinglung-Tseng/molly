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
            config = loaded
        } else {
            config = AppConfig()
        }
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
