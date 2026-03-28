import Foundation

struct AppConfig: Codable, Sendable, Equatable {
    var vaultPath: String = ""
    var claudeBin: String = ""
    var llm: LLMConfig = .init()
    var clips: ClipsConfig = .init()
    var ner: NERConfig = .init()
    var pageindex: PageIndexConfig = .init()
    var watchers: [WatcherDefinition] = []
    var configVersion: Int = 2

    struct LLMConfig: Codable, Sendable, Equatable {
        var apiURL: String = ""
        var apiKey: String = ""
        var model: String = ""
    }

    struct ClipsConfig: Codable, Sendable, Equatable {
        var enabled: Bool = false
        var clippingsSubdir: String = "Clippings"
        var claudeBin: String = ""
        var debounceSec: Double = 5.0
    }

    struct NERConfig: Codable, Sendable, Equatable {
        var enabled: Bool = false
        var entityTypes: [String] = ["PERSON", "ORG", "PRODUCT", "LOC", "METHOD", "WORK_OF_ART"]
        var skipNoteTypes: [String] = ["work-session", "task-view"]
        var debounceSec: Double = 3.0
    }

    struct PageIndexConfig: Codable, Sendable, Equatable {
        var enabled: Bool = false
        var topK: Int = 5
        var autoIndexOnStart: Bool = true
        var tgToken: String = ""
        var tgChatID: String = ""

        init(enabled: Bool = false, topK: Int = 5, autoIndexOnStart: Bool = true, tgToken: String = "", tgChatID: String = "") {
            self.enabled = enabled
            self.topK = topK
            self.autoIndexOnStart = autoIndexOnStart
            self.tgToken = tgToken
            self.tgChatID = tgChatID
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
            topK = try c.decodeIfPresent(Int.self, forKey: .topK) ?? 5
            autoIndexOnStart = try c.decodeIfPresent(Bool.self, forKey: .autoIndexOnStart) ?? true
            tgToken = try c.decodeIfPresent(String.self, forKey: .tgToken) ?? ""
            tgChatID = try c.decodeIfPresent(String.self, forKey: .tgChatID) ?? ""
        }
    }
}
