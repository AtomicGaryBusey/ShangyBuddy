import Foundation

struct OllamaConfig {
    var endpoint: URL = URL(string: "http://127.0.0.1:11434")!
    var model: String = "llama3.2-vision"
    var timeout: TimeInterval = 120
}

enum OllamaError: Error {
    case notRunning
    case http(Int)
    case decode
    case notLoopback
}

final class OllamaClient {
    var config: OllamaConfig

    /// Loopback-only egress. Screenshots stay on this machine; refuse to send
    /// to any host that isn't the local loopback even if the endpoint is
    /// later mutated.
    private static let loopbackHosts: Set<String> = ["127.0.0.1", "::1", "localhost"]

    /// Ephemeral session: no on-disk URL cache, no cookie storage, no
    /// credential storage. The request body (which contains a base64-encoded
    /// screenshot) is never persisted to a Foundation cache.
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.httpCookieStorage = nil
        config.urlCredentialStorage = nil
        return URLSession(configuration: config)
    }()

    init(config: OllamaConfig = .init()) {
        self.config = config
    }

    func generate(systemPrompt: String, userPrompt: String, image: Data?) async throws -> String {
        try ensureLoopback()

        let url = config.endpoint.appendingPathComponent("/api/chat")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = config.timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var userMessage: [String: Any] = [
            "role": "user",
            "content": userPrompt
        ]
        if let image {
            userMessage["images"] = [image.base64EncodedString()]
        }

        let body: [String: Any] = [
            "model": config.model,
            "stream": false,
            "options": [
                "temperature": 1.05,
                "top_p": 0.92,
                "num_predict": 80
            ],
            "messages": [
                ["role": "system", "content": systemPrompt],
                userMessage
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            // Drop the request body reference before propagating so the
            // base64-encoded screenshot is freed promptly.
            request.httpBody = nil
            throw OllamaError.notRunning
        }
        // Body sent — release the upload buffer immediately.
        request.httpBody = nil

        guard let http = response as? HTTPURLResponse else { throw OllamaError.decode }
        guard (200..<300).contains(http.statusCode) else {
            // Do not include the response body in the thrown error: the model
            // could echo prompt/screenshot-derived material that would then
            // surface in any future logging of `error`.
            throw OllamaError.http(http.statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OllamaError.decode
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func ensureLoopback() throws {
        guard let host = config.endpoint.host?.lowercased(),
              OllamaClient.loopbackHosts.contains(host) else {
            throw OllamaError.notLoopback
        }
    }
}
