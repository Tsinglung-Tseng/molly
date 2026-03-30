import Foundation

struct AppConfig: Codable, Sendable, Equatable {
    var vaultPath: String = ""
    var claudeBin: String = ""
    var watchers: [WatcherDefinition] = []
}
