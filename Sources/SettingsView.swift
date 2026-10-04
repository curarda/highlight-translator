import SwiftUI

/// Simple settings form. Values are written straight to `Settings.shared`.
struct SettingsView: View {
    @State private var apiKey: String = Settings.shared.apiKey
    @State private var model: String = Settings.shared.model
    @State private var targetLanguage: String = Settings.shared.targetLanguage
    @State private var systemPrompt: String = Settings.shared.systemPrompt
    @State private var deepLKey: String = Settings.shared.deepLKey
    @State private var deepLTargetLang: String = Settings.shared.deepLTargetLang

    private let models = ["gemini-3.5-flash-lite", "gemini-3.6-flash", "gemini-2.5-flash", "gemini-2.5-pro"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Çeviri Settings")
                    .font(.title2).bold()

                Group {
                    label("DeepL API key (hızlı çeviri)")
                    SecureField("xxxxxxxx-xxxx-…:fx", text: $deepLKey)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: deepLKey) { Settings.shared.deepLKey = deepLKey }
                    Text("Ücretsiz anahtar: deepl.com/pro-api → Free plan. (Free anahtar \":fx\" ile biter.)")
                        .font(.caption).foregroundColor(.secondary)
                    HStack {
                        Text("Hedef dil kodu")
                        TextField("TR", text: $deepLTargetLang)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 90)
                            .onChange(of: deepLTargetLang) { Settings.shared.deepLTargetLang = deepLTargetLang }
                    }
                }

                Divider()

                Group {
                    label("Gemini API key (detaylı açıklama)")
                    SecureField("AIza…", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: apiKey) { Settings.shared.apiKey = apiKey }
                    Text("Ücretsiz anahtar: aistudio.google.com/apikey")
                        .font(.caption).foregroundColor(.secondary)
                }

                Group {
                    label("Model")
                    Picker("", selection: $model) {
                        ForEach(models, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .onChange(of: model) { Settings.shared.model = model }
                }

                Group {
                    label("Answer language")
                    TextField("Turkish", text: $targetLanguage)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: targetLanguage) { Settings.shared.targetLanguage = targetLanguage }
                }

                Group {
                    label("Instructions to Gemini")
                    Text("Use {LANG} where the answer language should go.")
                        .font(.caption).foregroundColor(.secondary)
                    TextEditor(text: $systemPrompt)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 160)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                        .onChange(of: systemPrompt) { Settings.shared.systemPrompt = systemPrompt }
                    Button("Reset to default") {
                        systemPrompt = Settings.defaultPrompt
                        Settings.shared.systemPrompt = systemPrompt
                    }
                    .buttonStyle(.link)
                }

                Divider()
                Text("Kısayol: fn + control — bir metni seç, sonra ikisine birlikte bas. Önce DeepL çevirir, istersen Gemini açıklar.")
                    .font(.caption).foregroundColor(.secondary)
            }
            .padding(20)
        }
        .frame(width: 460, height: 560)
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.headline)
    }
}
