import Foundation

/// Actor that watches one or more vault paths and filters events.
actor VaultWatcher {
    private var streamObj: FSEventStream?

    /// Watch `path` and yield only `.md` file create/modify events.
    /// - Parameter recursive: if false, filters to only direct children of `path`.
    func watch(path: String, recursive: Bool, latency: CFTimeInterval = 1.0) -> AsyncStream<FSEvent> {
        let streamRef = FSEventStream(paths: [path], latency: latency)
        self.streamObj = streamRef
        let rawStream = streamRef.start()
        let pathURL = URL(filePath: path)

        return AsyncStream { continuation in
            let task = Task {
                for await batch in rawStream {
                    for event in batch {
                        guard event.isFile,
                              event.path.hasSuffix(".md"),
                              event.isCreated || event.isModified || event.isRenamed
                        else { continue }

                        if !recursive {
                            let eventURL = URL(filePath: event.path)
                            guard eventURL.deletingLastPathComponent().standardized == pathURL.standardized
                            else { continue }
                        }
                        continuation.yield(event)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func stop() {
        streamObj?.stop()
        streamObj = nil
    }
}
