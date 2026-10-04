import Foundation

/// Persistent user settings, stored in UserDefaults.
final class Settings {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    var apiKey: String {
        get { defaults.string(forKey: "apiKey") ?? "" }
        set { defaults.set(newValue, forKey: "apiKey") }
    }

    var model: String {
        get { defaults.string(forKey: "model") ?? "gemini-3.5-flash-lite" }
        set { defaults.set(newValue, forKey: "model") }
    }

    var deepLKey: String {
        get { defaults.string(forKey: "deepLKey") ?? "" }
        set { defaults.set(newValue, forKey: "deepLKey") }
    }

    /// DeepL language code, e.g. TR, EN-US, DE, FR.
    var deepLTargetLang: String {
        get { defaults.string(forKey: "deepLTargetLang") ?? "TR" }
        set { defaults.set(newValue, forKey: "deepLTargetLang") }
    }

    var targetLanguage: String {
        get { defaults.string(forKey: "targetLanguage") ?? "Turkish" }
        set { defaults.set(newValue, forKey: "targetLanguage") }
    }

    var systemPrompt: String {
        get { defaults.string(forKey: "systemPrompt") ?? Settings.defaultPrompt }
        set { defaults.set(newValue, forKey: "systemPrompt") }
    }

    /// {LANG} is replaced with the target language at request time.
    static let defaultPrompt = """
    You are an expert assistant helping a reader understand English-language academic papers. \
    The reader is a native {LANG} speaker who may not know some English terms or jargon.

    When given a highlighted word, phrase, or sentence from a paper, respond in {LANG} and:
    1. Give a clear, natural {LANG} translation.
    2. If it is a technical or academic term, briefly explain what it means in this context.
    3. Be concise and readable — no unnecessary padding.

    If the reader asks a specific follow-up question, answer that question directly in {LANG}.
    Always respond in {LANG}.
    """

    /// Builds the final prompt sent to Gemini.
    func buildPrompt(selectedText: String, followUp: String?) -> String {
        let base = systemPrompt.replacingOccurrences(of: "{LANG}", with: targetLanguage)
        var prompt = base
        prompt += "\n\nHighlighted text from the paper:\n\"\"\"\n\(selectedText)\n\"\"\"\n"
        if let f = followUp, !f.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            prompt += "\nThe reader's follow-up question: \(f)\n"
        } else {
            // Extra task: at the very end, list the hard English terms so the app
            // can save them to the reader's personal glossary. This line is stripped
            // before display.
            prompt += """
            \n\n---
            EXTRA TASK: At the very END of your answer, add ONE line in EXACTLY this format:
            #TERIMLER# englishTerm :: \(targetLanguage) translation :: short \(targetLanguage) explanation ;; englishTerm2 :: ...
            Rules:
            - Use ' :: ' to separate the English term, its \(targetLanguage) translation, and a short one-line \(targetLanguage) explanation.
            - Use ' ;; ' to separate different terms.
            - Keep the term itself in ENGLISH; translation and explanation in \(targetLanguage).
            - List only genuinely difficult/technical English words or phrases from the highlighted text.
            - If a single word was highlighted, include that word.
            - If nothing is hard, write "#TERIMLER#" with nothing after it.
            """
        }
        return prompt
    }
}
