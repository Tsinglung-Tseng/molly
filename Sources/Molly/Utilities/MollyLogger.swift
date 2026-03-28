import Foundation

// MARK: - LogEntry

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: String
    let source: String
    let message: String

    var formatted: String { "[\(timestamp)] [\(source)] \(message)" }
}

// MARK: - MollyLogger

final class MollyLogger: ObservableObject, @unchecked Sendable {
    static let shared = MollyLogger()
    @Published private(set) var entries: [LogEntry] = []
    var clearAll: (() -> Void)?
    private let maxLines = 500

    private init() {}

    func log(_ message: String, source: String = "System") {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let entry = LogEntry(timestamp: ts, source: source, message: message)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.entries.append(entry)
            if self.entries.count > self.maxLines {
                self.entries.removeFirst(self.entries.count - self.maxLines)
            }
        }
    }

    /// Available log sources for filtering.
    @MainActor
    var sources: [String] {
        Array(Set(entries.map(\.source))).sorted()
    }

    @MainActor
    func clear() { entries.removeAll() }
}
