import Foundation

/// A debouncer that cancels the previous pending task when a new trigger arrives.
/// Must be used from within a single actor (not thread-safe by itself).
final class DebounceTask: @unchecked Sendable {
    private var task: Task<Void, Never>?
    private let delay: Duration

    init(delay: Duration) {
        self.delay = delay
    }

    func trigger(action: @escaping @Sendable () async -> Void) {
        task?.cancel()
        task = Task {
            do {
                try await Task.sleep(for: delay)
                await action()
            } catch {
                // Cancelled — no-op
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
