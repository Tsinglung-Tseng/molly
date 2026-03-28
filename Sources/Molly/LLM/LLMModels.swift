import Foundation

struct LLMMessage: Codable, Sendable {
    let role: String
    let content: String
}

struct LLMRequest: Codable, Sendable {
    let model: String
    let messages: [LLMMessage]
    let temperature: Double
    let maxTokens: Int
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, stream
        case maxTokens = "max_tokens"
    }
}

struct LLMResponse: Codable, Sendable {
    struct Choice: Codable, Sendable {
        struct Message: Codable, Sendable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]

    var text: String { choices.first?.message.content ?? "" }
}

struct LLMStreamChunk: Codable, Sendable {
    struct Choice: Codable, Sendable {
        struct Delta: Codable, Sendable {
            let content: String?
        }
        let delta: Delta
        let finishReason: String?
        enum CodingKeys: String, CodingKey {
            case delta
            case finishReason = "finish_reason"
        }
    }
    let choices: [Choice]
}
