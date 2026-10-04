import Cocoa
import SwiftUI
import Carbon
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var chord: ModifierChord?
    private var popup: PopupController!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        popup = PopupController()
        setupStatusItem()
        setupHotKey()
        setupService()
        promptForAccessibilityIfNeeded()
    }

    // MARK: - Right-click Service

    private func setupService() {
        // Register this object as the provider for the "Ask Çeviri" service
        // declared under NSServices in Info.plist, then refresh the services cache.
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
    }

    /// Invoked by macOS when the user picks "Ask Çeviri" from the right-click /
    /// Services menu. The selected text is delivered via the pasteboard — no
    /// Accessibility permission or ⌘C simulation needed.
    @objc func askCeviri(_ pboard: NSPasteboard,
                         userData: String?,
                         error: AutoreleasingUnsafeMutablePointer<NSString>?) {
        let text = pboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { return }
        DispatchQueue.main.async { [weak self] in
            self?.popup.show(selectedText: text)
        }
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "character.book.closed",
                                   accessibilityDescription: "Çeviri")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Ask about selection  (fn + ⌃)",
                     action: #selector(triggerFromMenu),
                     keyEquivalent: "").target = self
        menu.addItem(withTitle: "Terimler dosyasını aç",
                     action: #selector(openTermsFile),
                     keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…",
                     action: #selector(openSettings),
                     keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Çeviri",
                     action: #selector(quit),
                     keyEquivalent: "q").target = self
        statusItem.menu = menu
    }

    // MARK: - Hot key

    private func setupHotKey() {
        // fn + control held together.
        chord = ModifierChord(required: [.function, .control]) { [weak self] in
            self?.trigger()
        }
    }

    @objc private func triggerFromMenu() { trigger() }

    @objc private func openTermsFile() {
        TermStore.ensureFileExists()
        NSWorkspace.shared.open(TermStore.fileURL)
    }

    private func trigger() {
        SelectionCapture.capture { [weak self] text in
            guard let self = self else { return }
            let cleaned = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !cleaned.isEmpty else {
                self.showNoSelectionHint()
                return
            }
            self.popup.show(selectedText: cleaned)
        }
    }

    private func showNoSelectionHint() {
        NSSound.beep()
    }

    // MARK: - Settings window

    @objc private func openSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "Çeviri Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Accessibility permission

    private func promptForAccessibilityIfNeeded() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            // The system prompt has been shown. Also show our own note so the
            // user understands why the permission is required.
            let alert = NSAlert()
            alert.messageText = "Accessibility permission needed"
            alert.informativeText = """
            Çeviri needs Accessibility permission to read the text you highlight \
            (it copies the selection with ⌘C behind the scenes).

            Open System Settings → Privacy & Security → Accessibility, and enable Çeviri. \
            Then quit and reopen the app.
            """
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")
            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
