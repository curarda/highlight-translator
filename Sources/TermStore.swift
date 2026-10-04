import Foundation

/// Appends looked-up words/terms to a personal glossary file in ~/Documents,
/// skipping duplicates. Format: "- **term** — translation  _(date)_".
enum TermStore {
    private static let queue = DispatchQueue(label: "ceviri.termstore")

    static var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return docs.appendingPathComponent("Çeviri-Bilinmeyen-Terimler.md")
    }

    static func add(term: String, translation: String? = nil, explanation: String? = nil) {
        let cleaned = term
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?\"'()[]"))
        guard !cleaned.isEmpty, cleaned.count <= 200 else { return }

        queue.async {
            var content = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
            if content.isEmpty {
                content = "# Bilinmeyen Terimler / Kelimeler\n\n"
            }

            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            var line = "- **\(cleaned)**"
            if let tr = translation?.trimmingCharacters(in: .whitespacesAndNewlines), !tr.isEmpty {
                line += " — \(tr)"
            }
            if let ex = explanation?.trimmingCharacters(in: .whitespacesAndNewlines), !ex.isEmpty {
                line += " · \(ex)"
            }
            line += "  _(\(df.string(from: Date())))_"

            var lines = content.components(separatedBy: "\n")
            let needle = "**\(cleaned.lowercased())**"
            if let idx = lines.firstIndex(where: { $0.lowercased().contains(needle) }) {
                // Already present — replace only if the new entry is richer (longer).
                if line.count > lines[idx].count {
                    lines[idx] = line
                    try? lines.joined(separator: "\n").write(to: fileURL, atomically: true, encoding: .utf8)
                }
                return
            }

            // New term — append.
            if !content.hasSuffix("\n") { content += "\n" }
            content += line + "\n"
            try? content.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    /// Ensures the file exists (used before opening it from the menu).
    static func ensureFileExists() {
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try? "# Bilinmeyen Terimler / Kelimeler\n\n".write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }
}
