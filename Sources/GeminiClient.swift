import Foundation

/// Minimal client for the Google Gemini `generateContent` REST endpoint.
enum GeminiClient {
    enum GeminiError: LocalizedError {
        case noAPIKey
        case http(Int, String)
        case emptyResponse
        case blocked(String)
        case network(String)

        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "No Gemini API key set. Open Settings (menu-bar icon → Settings) and paste your key."
            case .http(let code, let msg):
                return "Gemini API error (HTTP \(code)): \(msg)"
            case .emptyResponse:
                return "Gemini returned an empty response."
            case .blocked(let reason):
                return "The request was blocked by Gemini (\(reason))."
            case .network(let msg):
                return "Network error: \(msg)"
            }
        }
    }

    static func ask(selectedText: String,
                    followUp: String?,
                    completion: @escaping (Result<String, Error>) -> Void) {
        let settings = Settings.shared
        let key = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            completion(.failure(GeminiError.noAPIKey))
            return
        }

        let model = settings.model.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
        guard let url = URL(string: urlString) else {
            completion(.failure(GeminiError.network("Invalid model name.")))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        request.timeoutInterval = 60

        let prompt = settings.buildPrompt(selectedText: selectedText, followUp: followUp)
        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            // Kısa/hızlı yanıt: çıktı uzunluğunu sınırla (tüm modellerde geçerli alan).
            "generationConfig": [
                "maxOutputTokens": 800,
                "temperature": 0.3
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(GeminiError.network(error.localizedDescription)))
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(GeminiError.network(error.localizedDescription)))
                return
            }
            guard let http = response as? HTTPURLResponse, let data = data else {
                completion(.failure(GeminiError.emptyResponse))
                return
            }

            guard (200..<300).contains(http.statusCode) else {
                let msg = Self.extractAPIErrorMessage(from: data) ?? String(data: data, encoding: .utf8) ?? "Unknown error"
                completion(.failure(GeminiError.http(http.statusCode, msg)))
                return
            }

            switch Self.parseText(from: data) {
            case .success(let text): completion(.success(text))
            case .failure(let err): completion(.failure(err))
            }
        }
        task.resume()
    }

    // MARK: - Parsing

    private static func parseText(from data: Data) -> Result<String, Error> {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .failure(GeminiError.emptyResponse)
        }

        // Prompt-level block (e.g. safety).
        if let feedback = json["promptFeedback"] as? [String: Any],
           let reason = feedback["blockReason"] as? String {
            return .failure(GeminiError.blocked(reason))
        }

        guard let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first else {
            return .failure(GeminiError.emptyResponse)
        }

        if let finish = first["finishReason"] as? String,
           finish == "SAFETY" || finish == "PROHIBITED_CONTENT" {
            return .failure(GeminiError.blocked(finish))
        }

        guard let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            return .failure(GeminiError.emptyResponse)
        }

        let text = parts.compactMap { $0["text"] as? String }.joined()
        if text.isEmpty {
            return .failure(GeminiError.emptyResponse)
        }
        return .success(text)
    }

    private static func extractAPIErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String else {
            return nil
        }
        return message
    }
}
