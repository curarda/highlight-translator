import Cocoa
import SwiftUI

/// Observable state shared between the popup controller and its SwiftUI view.
final class PopupState: ObservableObject {
    @Published var selectedText: String = ""

    // DeepL (fast, shown first)
    @Published var translation: String = ""
    @Published var isTranslating: Bool = false
    @Published var translationError: String? = nil

    // Gemini (on demand)
    @Published var geminiStarted: Bool = false
    @Published var answer: String = ""
    @Published var isAskingGemini: Bool = false
    @Published var geminiError: String? = nil

    @Published var followUp: String = ""
}

/// Owns the floating result panel, runs the DeepL translation immediately and
/// forwards to Gemini only when the user asks.
final class PopupController {
    let state = PopupState()
    private var panel: NSPanel!

    init() {
        buildPanel()
    }

    private func buildPanel() {
        let view = PopupView(
            state: state,
            onAskGemini: { [weak self] in self?.askGemini(followUp: nil) },
            onFollowUp: { [weak self] q in self?.askGemini(followUp: q) },
            onClose: { [weak self] in self?.hide() }
        )
        let hosting = NSHostingView(rootView: view)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 480),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Çeviri"
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentView = hosting
        panel.minSize = NSSize(width: 360, height: 320)
        self.panel = panel
    }

    /// Called after capturing a selection: shows the panel and starts DeepL.
    func show(selectedText: String) {
        state.selectedText = selectedText
        state.translation = ""
        state.translationError = nil
        state.geminiStarted = false
        state.answer = ""
        state.geminiError = nil
        state.followUp = ""

        positionNearCursor()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        runTranslation()
    }

    func hide() {
        panel.orderOut(nil)
    }

    // MARK: - DeepL

    private func runTranslation() {
        state.isTranslating = true
        state.translationError = nil
        DeepLClient.translate(text: state.selectedText) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.state.isTranslating = false
                switch result {
                case .success(let text):
                    self.state.translation = text
                    if self.isSingleWord(self.state.selectedText) {
                        TermStore.add(term: self.state.selectedText, translation: text)
                    }
                case .failure(let error):
                    self.state.translationError = error.localizedDescription
                    if self.isSingleWord(self.state.selectedText) {
                        TermStore.add(term: self.state.selectedText)
                    }
                }
            }
        }
    }

    // MARK: - Gemini (on demand)

    private func askGemini(followUp: String?) {
        let trimmed = followUp?.trimmingCharacters(in: .whitespacesAndNewlines)
        state.geminiStarted = true
        state.isAskingGemini = true
        state.geminiError = nil

        GeminiClient.ask(selectedText: state.selectedText, followUp: trimmed) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.state.isAskingGemini = false
                switch result {
                case .success(let text):
                    let (clean, terms) = self.extractTerms(from: text)
                    if let f = trimmed, !f.isEmpty {
                        self.state.answer += "\n\n---\n\n**\(f)**\n\n\(clean)"
                    } else {
                        self.state.answer = clean
                        // Save Gemini-identified hard terms (with translation + explanation).
                        for t in terms {
                            TermStore.add(term: t.term, translation: t.translation, explanation: t.explanation)
                        }
                    }
                case .failure(let error):
                    self.state.geminiError = error.localizedDescription
                }
            }
        }
    }

    private func isSingleWord(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return !t.isEmpty && !t.contains(where: { $0.isWhitespace })
    }

    struct Term {
        let term: String
        let translation: String?
        let explanation: String?
    }

    /// Splits a "#TERIMLER# term :: çeviri :: açıklama ;; …" marker off the answer.
    /// Returns the answer without that line, plus the parsed terms.
    private func extractTerms(from text: String) -> (clean: String, terms: [Term]) {
        guard let range = text.range(of: "#TERIMLER#") else { return (text, []) }
        let before = String(text[..<range.lowerBound])
        let rest = String(text[range.upperBound...])
        let firstLine = rest.split(separator: "\n", maxSplits: 1,
                                   omittingEmptySubsequences: false).first.map(String.init) ?? ""

        func nonEmpty(_ s: String) -> String? {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }

        var terms: [Term] = []
        for entry in firstLine.components(separatedBy: ";;") {
            let parts = entry.components(separatedBy: "::").map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard let term = parts.first, !term.isEmpty else { continue }
            let translation = parts.count > 1 ? nonEmpty(parts[1]) : nil
            let explanation = parts.count > 2 ? nonEmpty(parts[2]) : nil
            terms.append(Term(term: term, translation: translation, explanation: explanation))
        }
        return (before.trimmingCharacters(in: .whitespacesAndNewlines), terms)
    }

    private func positionNearCursor() {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else {
            panel.center()
            return
        }
        let size = panel.frame.size
        var origin = NSPoint(x: mouse.x + 16, y: mouse.y - size.height - 16)
        let visible = screen.visibleFrame
        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
        origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - size.height - 8)
        panel.setFrameOrigin(origin)
    }
}
