import Foundation
import CoreServices

// FSEventStreamEventFlags is a typealias for UInt32
struct FSEvent: Sendable {
    let path: String
    let flags: UInt32
    var isFile: Bool { flags & UInt32(kFSEventStreamEventFlagItemIsFile) != 0 }
    var isCreated: Bool { flags & UInt32(kFSEventStreamEventFlagItemCreated) != 0 }
    var isModified: Bool { flags & UInt32(kFSEventStreamEventFlagItemModified) != 0 }
    var isRemoved: Bool { flags & UInt32(kFSEventStreamEventFlagItemRemoved) != 0 }
    var isRenamed: Bool { flags & UInt32(kFSEventStreamEventFlagItemRenamed) != 0 }
}

/// Wraps the CoreServices FSEventStream C API and yields file-level events as an AsyncStream.
final class FSEventStream: @unchecked Sendable {
    private var stream: FSEventStreamRef?
    private let queue = DispatchQueue(label: "com.molly.fsevents", qos: .utility)
    private var continuation: AsyncStream<[FSEvent]>.Continuation?
    private let paths: [String]
    private let latency: CFTimeInterval

    init(paths: [String], latency: CFTimeInterval = 1.0) {
        self.paths = paths
        self.latency = latency
    }

    func start() -> AsyncStream<[FSEvent]> {
        AsyncStream { [weak self] continuation in
            guard let self else { return }
            self.continuation = continuation
            self.startStream()
            continuation.onTermination = { [weak self] _ in
                self?.stopStream()
            }
        }
    }

    func stop() {
        continuation?.finish()
        continuation = nil
        stopStream()
    }

    private func startStream() {
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passRetained(self).toOpaque(),
            retain: nil,
            release: { ptr in
                guard let ptr else { return }
                Unmanaged<FSEventStream>.fromOpaque(ptr).release()
            },
            copyDescription: nil
        )

        let createFlags = UInt32(
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagNoDefer
        )

        stream = FSEventStreamCreate(
            nil,
            { _, info, numEvents, eventPaths, eventFlags, _ in
                guard let info else { return }
                let watcher = Unmanaged<FSEventStream>.fromOpaque(info).takeUnretainedValue()
                let pathsArray = unsafeBitCast(eventPaths, to: NSArray.self) as! [String]
                var events: [FSEvent] = []
                for i in 0..<numEvents {
                    events.append(FSEvent(path: pathsArray[i], flags: eventFlags[i]))
                }
                watcher.continuation?.yield(events)
            },
            &context,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            createFlags
        )

        if let stream {
            FSEventStreamSetDispatchQueue(stream, queue)
            FSEventStreamStart(stream)
        }
    }

    private func stopStream() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }
}
