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
        builtinPreset = try c.decodeIfPresent(BuiltinPreset.self, forKey: .builtinPreset)
        startCmd = try c.decodeIfPresent(String.self, forKey: .startCmd) ?? ""
        startCwd = try c.decodeIfPresent(String.self, forKey: .startCwd) ?? ""
        startEnv = try c.decodeIfPresent([String: String].self, forKey: .startEnv) ?? [:]
    }
}

// MARK: - BuiltinPreset

enum BuiltinPreset: String, Codable, Sendable {
    case clips
    case ner
    case pageindex
}
