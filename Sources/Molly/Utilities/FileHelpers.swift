import Foundation

enum FileHelpers {
    static func markdownFiles(in directory: URL, recursive: Bool) -> [URL] {
        let fm = FileManager.default
        if recursive {
            guard let enumerator = fm.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { return [] }
            return enumerator.compactMap { $0 as? URL }.filter {
                $0.pathExtension.lowercased() == "md"
            }
        } else {
            return (try? fm.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            ))?.filter { $0.pathExtension.lowercased() == "md" } ?? []
        }
    }

    static func readText(_ url: URL) -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }

    static func writeText(_ text: String, to url: URL) throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Returns the vault-relative path without extension.
    static func relativeName(of url: URL, vaultURL: URL) -> String {
        var path = url.path
        let base = vaultURL.path
        if path.hasPrefix(base) {
            path = String(path.dropFirst(base.count))
        }
        if path.hasPrefix("/") { path = String(path.dropFirst()) }
        if path.hasSuffix(".md") { path = String(path.dropLast(3)) }
        return path
    }
}
