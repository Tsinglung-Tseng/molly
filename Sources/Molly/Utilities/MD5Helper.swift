import CryptoKit
import Foundation

enum MD5Helper {
    static func hash(of data: Data) -> String {
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func hash(ofFileAt url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return hash(of: data)
    }
}
