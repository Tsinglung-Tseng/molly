import Foundation

enum ShellRunner {
    static func runClaude(bin: String, prompt: String, cwd: String) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(filePath: bin)
            process.arguments = ["--print", "--dangerously-skip-permissions", prompt]
            process.currentDirectoryURL = URL(filePath: cwd)
            process.standardInput = FileHandle.nullDevice
            process.terminationHandler = { p in
                if p.terminationStatus == 0 {
                    cont.resume()
                } else {
                    cont.resume(throwing: WorkerError.claudeFailed(Int(p.terminationStatus)))
                }
            }
            do { try process.run() } catch { cont.resume(throwing: error) }
        }
    }
}
