import Foundation

/// Minimal client for the DeepL translation REST API.
/// Free keys end with ":fx" and use api-free.deepl.com; Pro keys use api.deepl.com.
enum DeepLClient {
    enum DeepLError: LocalizedError {
        case noAPIKey
        case http(Int, String)
        case empty
        case network(String)

        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "DeepL API anahtarı girilmedi. Ayarlar'dan ekleyebilirsin."
            case .http(let code, let msg):
                return "DeepL hatası (HTTP \(code)): \(msg)"
            case .empty:
                return "DeepL boş yanıt döndürdü."
            case .network(let msg):
                return "Ağ hatası: \(msg)"
            }
        }
    }

    static func translate(text: String,
                          completion: @escaping (Result<String, Error>) -> Void) {
        let settings = Settings.shared
        let key = settings.deepLKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            completion(.failure(DeepLError.noAPIKey))
            return
        }

        let isFree = key.hasSuffix(":fx")
        let host = isFree ? "https://api-free.deepl.com" : "https://api.deepl.com"
        guard let url = URL(string: "\(host)/v2/translate") else {
            completion(.failure(DeepLError.network("Geçersiz URL.")))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("DeepL-Auth-Key \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20

        // Satır sonlarını ve fazla boşlukları tek boşluğa indirge ki DeepL
        // metni tek bir bütün olarak görsün ve bağlam (context) kaybolmasın.
        let cleaned = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let body: [String: Any] = [
            "text": [cleaned],
            "target_lang": settings.deepLTargetLang
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(DeepLError.network(error.localizedDescription)))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(DeepLError.network(error.localizedDescription)))
                return
            }
            guard let http = response as? HTTPURLResponse, let data = data else {
                completion(.failure(DeepLError.empty))
                return
            }
            guard (200..<300).contains(http.statusCode) else {
                let msg = String(data: data, encoding: .utf8) ?? "Bilinmeyen hata"
                completion(.failure(DeepLError.http(http.statusCode, msg)))
                return
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let translations = json["translations"] as? [[String: Any]],
                  let first = translations.first,
                  let translated = first["text"] as? String,
                  !translated.isEmpty else {
                completion(.failure(DeepLError.empty))
                return
            }
            completion(.success(translated))
        }.resume()
    }
}
