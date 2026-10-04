import Cocoa

/// Captures the currently selected text in whatever app is frontmost by
/// simulating ⌘C, reading the pasteboard, then restoring the previous contents.
/// This works universally — browsers, PDF viewers, native apps — because it
/// relies on the standard Copy command rather than any per-app integration.
enum SelectionCapture {

    static func capture(completion: @escaping (String?) -> Void) {
        let pasteboard = NSPasteboard.general
        let previousString = pasteboard.string(forType: .string)
        let startChangeCount = pasteboard.changeCount

        simulateCopy()

        // Poll for the pasteboard to change (copy is asynchronous).
        poll(pasteboard: pasteboard,
             startChangeCount: startChangeCount,
             previousString: previousString,
             attempt: 0,
             completion: completion)
    }

    private static func poll(pasteboard: NSPasteboard,
                             startChangeCount: Int,
                             previousString: String?,
                             attempt: Int,
                             completion: @escaping (String?) -> Void) {
        let maxAttempts = 15   // ~15 * 25ms = ~375ms max wait

        if pasteboard.changeCount != startChangeCount {
            let copied = pasteboard.string(forType: .string)
            // Restore the user's previous clipboard so we don't clobber it.
            restore(previousString, on: pasteboard)
            completion(copied)
            return
        }

        if attempt >= maxAttempts {
            // Nothing got copied (likely no selection).
            completion(nil)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) {
            poll(pasteboard: pasteboard,
                 startChangeCount: startChangeCount,
                 previousString: previousString,
                 attempt: attempt + 1,
                 completion: completion)
        }
    }

    private static func restore(_ previousString: String?, on pasteboard: NSPasteboard) {
        // Delay restore slightly so we don't race the app that just copied.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            pasteboard.clearContents()
            if let previousString = previousString {
                pasteboard.setString(previousString, forType: .string)
            }
        }
    }

    private static func simulateCopy() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let cKeyCode: CGKeyCode = 8 // 'c'

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: cKeyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: cKeyCode, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
