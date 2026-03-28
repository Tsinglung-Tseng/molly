import Foundation

// MARK: - WatcherID

typealias WatcherID = String

// MARK: - WatcherDefinition

struct WatcherDefinition: Codable, Sendable, Equatable, Identifiable {
    var id: WatcherID
    var label: String
    var enabled: Bool
    var watchPath: String
    var recursive: Bool
    var debounceSec: Double
    var fileFilter: String
    var action: WatcherAction
    var builtinPreset: BuiltinPreset?
    var startCmd: String
    var startCwd: String
    var startEnv: [String: String]

    init(
        id: WatcherID = UUID().uuidString,
        label: String,
        enabled: Bool = false,
        watchPath: String = "",
        recursive: Bool = false,
        debounceSec: Double = 3.0,
        fileFilter: String = "*.md",
        action: WatcherAction = .shellCommand(""),
        builtinPreset: BuiltinPreset? = nil,
        startCmd: String = "",
        startCwd: String = "",
        startEnv: [String: String] = [:]
    ) {
        self.id = id
        self.label = label
        self.enabled = enabled
        self.watchPath = watchPath
        self.recursive = recursive
        self.debounceSec = debounceSec
        self.fileFilter = fileFilter
        self.action = action
        self.builtinPreset = builtinPreset
        self.startCmd = startCmd
        self.startCwd = startCwd
        self.startEnv = startEnv
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        label = try c.decode(String.self, forKey: .label)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        watchPath = try c.decodeIfPresent(String.self, forKey: .watchPath) ?? ""
        recursive = try c.decodeIfPresent(Bool.self, forKey: .recursive) ?? false
        debounceSec = try c.decodeIfPresent(Double.self, forKey: .debounceSec) ?? 3.0
        fileFilter = try c.decodeIfPresent(String.self, forKey: .fileFilter) ?? "*.md"
        action = try c.decodeIfPresent(WatcherAction.self, forKey: .action) ?? .shellCommand("")
        builtinPreset = try c.decodeIfPresent(BuiltinPreset.self, forKey: .builtinPreset)
        startCmd = try c.decodeIfPresent(String.self, forKey: .startCmd) ?? ""
        startCwd = try c.decodeIfPresent(String.self, forKey: .startCwd) ?? ""
        startEnv = try c.decodeIfPresent([String: String].self, forKey: .startEnv) ?? [:]
    }
}

// MARK: - WatcherAction

enum WatcherAction: Codable, Sendable, Equatable {
    case shellCommand(String)
    case claudeSkill(String)
    case llmPrompt(String)

    private enum CodingKeys: String, CodingKey {
        case type, value
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        let value = try c.decode(String.self, forKey: .value)
        switch type {
        case "shellCommand": self = .shellCommand(value)
        case "claudeSkill":  self = .claudeSkill(value)
        case "llmPrompt":    self = .llmPrompt(value)
        default:             self = .shellCommand(value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .shellCommand(let v):
            try c.encode("shellCommand", forKey: .type)
            try c.encode(v, forKey: .value)
        case .claudeSkill(let v):
            try c.encode("claudeSkill", forKey: .type)
            try c.encode(v, forKey: .value)
        case .llmPrompt(let v):
            try c.encode("llmPrompt", forKey: .type)
            try c.encode(v, forKey: .value)
        }
    }
}

// MARK: - BuiltinPreset

enum BuiltinPreset: String, Codable, Sendable {
    case clips
    case ner
    case pageindex
}
