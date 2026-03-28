import Foundation

enum LLMError: Error, LocalizedError {
    case missingAPIKey
    case httpError(Int)
    case decodingError(String)
    case emptyResponse
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "LLM API key is not configured."
        case .httpError(let code): return "LLM HTTP error: \(code)"
        case .decodingError(let msg): return "LLM response decode failed: \(msg)"
        case .emptyResponse: return "LLM returned an empty response."
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        }
    }
}
