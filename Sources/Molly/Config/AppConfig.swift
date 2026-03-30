import Foundation

struct AppConfig: Codable, Sendable, Equatable {
    var vaultPath: String = ""
    var claudeBin: String = ""
    var llm: LLMConfig = .init()
    var watchers: [WatcherDefinition] = []

    struct LLMConfig: Codable, Sendable, Equatable {
        var apiURL: String = ""
        var apiKey: String = ""
        var model: String = ""
    }
}
