import Foundation

actor LLMClient {
    static let shared = LLMClient()
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        session = URLSession(configuration: config)
    }

    func complete(
        systemPrompt: String? = nil,
        userMessage: String,
        llmConfig: AppConfig.LLMConfig,
        temperature: Double = 0.1,
        maxTokens: Int = 2000
    ) async throws -> String {
        guard !llmConfig.apiKey.isEmpty else { throw LLMError.missingAPIKey }

        var messages: [LLMMessage] = []
        if let sys = systemPrompt {
            messages.append(LLMMessage(role: "system", content: sys))
        }
        messages.append(LLMMessage(role: "user", content: userMessage))

        let request = LLMRequest(
            model: llmConfig.model,
            messages: messages,
            temperature: temperature,
            maxTokens: maxTokens,
            stream: false
        )

        let urlRequest = try buildRequest(request: request, config: llmConfig)
        let (data, response) = try await session.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse else { throw LLMError.emptyResponse }
        guard (200..<300).contains(http.statusCode) else { throw LLMError.httpError(http.statusCode) }

        let decoded = try JSONDecoder().decode(LLMResponse.self, from: data)
        let text = decoded.text
        guard !text.isEmpty else { throw LLMError.emptyResponse }
        return text
    }

    func completeStreaming(
        systemPrompt: String? = nil,
        userMessage: String,
        llmConfig: AppConfig.LLMConfig,
        temperature: Double = 0.1,
        maxTokens: Int = 2000
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard !llmConfig.apiKey.isEmpty else { throw LLMError.missingAPIKey }

                    var messages: [LLMMessage] = []
                    if let sys = systemPrompt {
                        messages.append(LLMMessage(role: "system", content: sys))
                    }
                    messages.append(LLMMessage(role: "user", content: userMessage))

                    let request = LLMRequest(
                        model: llmConfig.model,
                        messages: messages,
                        temperature: temperature,
                        maxTokens: maxTokens,
                        stream: true
                    )

                    let urlRequest = try buildRequest(request: request, config: llmConfig)
                    let (bytes, response) = try await session.bytes(for: urlRequest)

                    guard let http = response as? HTTPURLResponse,
                          (200..<300).contains(http.statusCode)
                    else { throw LLMError.httpError(0) }

                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let json = String(line.dropFirst(6))
                            if json == "[DONE]" { break }
                            if let data = json.data(using: .utf8),
                               let chunk = try? JSONDecoder().decode(LLMStreamChunk.self, from: data),
                               let content = chunk.choices.first?.delta.content {
                                continuation.yield(content)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func buildRequest(request: LLMRequest, config: AppConfig.LLMConfig) throws -> URLRequest {
        let baseURL = config.apiURL.hasSuffix("/") ? config.apiURL : config.apiURL + "/"
        guard let url = URL(string: baseURL + "chat/completions") else {
            throw LLMError.networkError(URLError(.badURL))
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        return urlRequest
    }
}
