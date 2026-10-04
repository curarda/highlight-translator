import SwiftUI

struct PopupView: View {
    @ObservedObject var state: PopupState
    let onAskGemini: () -> Void
    let onFollowUp: (String) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Highlighted source text.
            section(title: "Seçilen metin") {
                ScrollView {
                    Text(state.selectedText)
                        .font(.callout)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 70)
            }

            // DeepL translation (fast).
            section(title: "Çeviri · DeepL") {
                if state.isTranslating {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("DeepL ile çevriliyor…").foregroundColor(.secondary)
                    }
                } else if let err = state.translationError {
                    Text(err).foregroundColor(.orange).font(.callout)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if !state.translation.isEmpty {
                    Text(state.translation)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // Gemini section — only after the user asks.
            if state.geminiStarted {
                Divider()
                section(title: "Açıklama · Gemini") {
                    if state.isAskingGemini && state.answer.isEmpty {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Gemini düşünüyor…").foregroundColor(.secondary)
                        }
                    }
                    if let err = state.geminiError {
                        Text(err).foregroundColor(.red)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !state.answer.isEmpty {
                        ScrollView {
                            Text(markdown(state.answer))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
            Divider()

            // Ask-Gemini button + follow-up box.
            if !state.geminiStarted {
                Button(action: onAskGemini) {
                    Label("Gemini ile açıkla", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
            }

            HStack(spacing: 8) {
                TextField("Gemini'a takip sorusu sor…", text: $state.followUp)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { submit() }
                Button("Sor") { submit() }
                    .disabled(state.followUp.trimmingCharacters(in: .whitespaces).isEmpty || state.isAskingGemini)
            }
        }
        .padding(14)
        .frame(minWidth: 360, minHeight: 320)
    }

    private func submit() {
        let q = state.followUp
        state.followUp = ""
        onFollowUp(q)
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundColor(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func markdown(_ string: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        if let attributed = try? AttributedString(markdown: string, options: options) {
            return attributed
        }
        return AttributedString(string)
    }
}
