import Foundation

/// Manages MCP server registration in Claude Code settings.
/// Writes to both global (~/.claude/settings.json) and vault-local (.mcp.json).
/// Safely degrades: if files/directories don't exist, does nothing.
enum ClaudeCodeMCP {

    private static let globalSettingsURL: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".claude/settings.json")
    }()

    /// Register (or update) a pageindex MCP server entry.
    /// Writes to global settings and vault root .mcp.json.
    @discardableResult
    static func registerPageIndex(
        pythonPath: String,
        scriptPath: String,
        env: [String: String],
        vaultPath: String
    ) -> Bool {
        let desired: [String: Any] = [
            "type": "stdio",
            "command": pythonPath,
            "args": [scriptPath],
            "env": env
        ]

        var wrote = false

        // Global: ~/.claude/settings.json (for interactive sessions)
        wrote = upsertMCPEntry("pageindex", desired, in: globalSettingsURL, key: "mcpServers") || wrote

        // Vault root: .mcp.json (for --print mode / non-interactive sessions)
        let vaultMCPURL = URL(filePath: vaultPath).appending(path: ".mcp.json")
        wrote = upsertOrCreateMCPFile("pageindex", desired, at: vaultMCPURL) || wrote

        return wrote
    }

    /// Remove the pageindex MCP server entry from all known locations.
    static func unregisterPageIndex(vaultPath: String) {
        removeMCPEntry("pageindex", from: globalSettingsURL, key: "mcpServers")
        let vaultMCPURL = URL(filePath: vaultPath).appending(path: ".mcp.json")
        removeMCPEntry("pageindex", from: vaultMCPURL, key: "mcpServers")
    }

    // MARK: - Private helpers

    /// Insert or update a server entry in an existing JSON file.
    private static func upsertMCPEntry(
        _ name: String,
        _ desired: [String: Any],
        in fileURL: URL,
        key: String
    ) -> Bool {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else {
            MollyLogger.shared.log("\(fileURL.path()) not found, skipping", source: "MCP")
            return false
        }

        do {
            let data = try Data(contentsOf: fileURL)
            var root = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            var servers = (root[key] as? [String: Any]) ?? [:]

            if let existing = servers[name] as? [String: Any],
               NSDictionary(dictionary: existing).isEqual(to: desired) {
                MollyLogger.shared.log("\(name) already up-to-date in \(fileURL.lastPathComponent)", source: "MCP")
                return true
            }

            servers[name] = desired
            root[key] = servers

            let output = try JSONSerialization.data(
                withJSONObject: root,
                options: [.prettyPrinted, .sortedKeys]
            )
            try output.write(to: fileURL, options: .atomic)
            MollyLogger.shared.log("\(name) registered in \(fileURL.lastPathComponent)", source: "MCP")
            return true
        } catch {
            MollyLogger.shared.log("Failed to update \(fileURL.lastPathComponent): \(error.localizedDescription)", source: "MCP")
            return false
        }
    }

    /// Insert or update in .mcp.json, creating the file if it doesn't exist.
    private static func upsertOrCreateMCPFile(
        _ name: String,
        _ desired: [String: Any],
        at fileURL: URL
    ) -> Bool {
        do {
            var root: [String: Any]
            if FileManager.default.fileExists(atPath: fileURL.path()) {
                let data = try Data(contentsOf: fileURL)
                root = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            } else {
                root = [:]
            }

            var servers = (root["mcpServers"] as? [String: Any]) ?? [:]

            if let existing = servers[name] as? [String: Any],
               NSDictionary(dictionary: existing).isEqual(to: desired) {
                MollyLogger.shared.log("\(name) already up-to-date in \(fileURL.lastPathComponent)", source: "MCP")
                return true
            }

            servers[name] = desired
            root["mcpServers"] = servers

            let output = try JSONSerialization.data(
                withJSONObject: root,
                options: [.prettyPrinted, .sortedKeys]
            )
            try output.write(to: fileURL, options: .atomic)
            MollyLogger.shared.log("\(name) registered in \(fileURL.lastPathComponent)", source: "MCP")
            return true
        } catch {
            MollyLogger.shared.log("Failed to update \(fileURL.lastPathComponent): \(error.localizedDescription)", source: "MCP")
            return false
        }
    }

    /// Remove a server entry from a JSON file.
    private static func removeMCPEntry(
        _ name: String,
        from fileURL: URL,
        key: String
    ) {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else { return }

        do {
            let data = try Data(contentsOf: fileURL)
            guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  var servers = root[key] as? [String: Any],
                  servers[name] != nil else { return }

            servers.removeValue(forKey: name)
            root[key] = servers

            let output = try JSONSerialization.data(
                withJSONObject: root,
                options: [.prettyPrinted, .sortedKeys]
            )
            try output.write(to: fileURL, options: .atomic)
            MollyLogger.shared.log("\(name) removed from \(fileURL.lastPathComponent)", source: "MCP")
        } catch {
            MollyLogger.shared.log("Failed to remove \(name) from \(fileURL.lastPathComponent): \(error.localizedDescription)", source: "MCP")
        }
    }
}
