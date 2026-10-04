import Cocoa

/// Fires an action when a specific set of modifier keys becomes active
/// simultaneously (e.g. fn + control). Used instead of a Carbon hot key
/// because the `fn` (Globe) key is not a Carbon-registrable modifier.
///
/// Requires Accessibility permission (it uses a global event monitor).
final class ModifierChord {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let required: NSEvent.ModifierFlags
    private let action: () -> Void

    private var wasActive = false
    private var lastFire = Date.distantPast

    // Only these flags are considered when comparing (ignores caps-lock etc.).
    private let tracked: NSEvent.ModifierFlags = [.command, .shift, .option, .control, .function]

    init(required: NSEvent.ModifierFlags, action: @escaping () -> Void) {
        self.required = required
        self.action = action

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    deinit {
        if let g = globalMonitor { NSEvent.removeMonitor(g) }
        if let l = localMonitor { NSEvent.removeMonitor(l) }
    }

    private func handle(_ event: NSEvent) {
        let active = event.modifierFlags.intersection(tracked)
        // Trigger only when exactly the required modifiers are held.
        let isActive = (active == required)

        if isActive && !wasActive {
            let now = Date()
            if now.timeIntervalSince(lastFire) > 0.4 {   // debounce
                lastFire = now
                action()
            }
        }
        wasActive = isActive
    }
}
