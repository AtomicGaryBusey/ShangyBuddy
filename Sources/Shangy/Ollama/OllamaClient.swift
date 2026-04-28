import Foundation

struct OllamaConfig {
    var endpoint: URL = URL(string: "http://127.0.0.1:11434")!
    var model: String = "llama3.2-vision"
    var timeout: TimeInterval = 120
}

enum OllamaError: Error {
    case notRunning
    case http(Int, String)
    case decode
}

final class OllamaClient {
    var config: OllamaConfig

    init(config: OllamaConfig = .init()) {
        self.config = config
    }

    func generate(systemPrompt: String, userPrompt: String, image: Data?) async throws -> String {
        let url = config.endpoint.appendingPathComponent("/api/chat")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = config.timeout
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

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw OllamaError.notRunning
        }

        guard let http = response as? HTTPURLResponse else { throw OllamaError.decode }
        guard (200..<300).contains(http.statusCode) else {
            throw OllamaError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OllamaError.decode
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
