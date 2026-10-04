import Cocoa
import Carbon

/// Registers a system-wide hot key using Carbon's RegisterEventHotKey.
/// Works even when the app is a background accessory and unfocused.
final class HotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let action: () -> Void
    private let id: UInt32

    private static var registry: [UInt32: HotKey] = [:]
    private static var nextID: UInt32 = 1
    private static var handlerInstalled = false

    /// - Parameters:
    ///   - keyCode: virtual key code (e.g. 17 for 'T').
    ///   - modifiers: Carbon modifier mask (e.g. cmdKey | shiftKey).
    init?(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        self.action = action
        self.id = HotKey.nextID
        HotKey.nextID += 1
        HotKey.registry[self.id] = self

        HotKey.installHandlerIfNeeded()

        let signature: OSType = 0x43455649 // 'CEVI'
        let hotKeyID = EventHotKeyID(signature: signature, id: self.id)
        let status = RegisterEventHotKey(keyCode,
                                         modifiers,
                                         hotKeyID,
                                         GetApplicationEventTarget(),
                                         0,
                                         &hotKeyRef)
        if status != noErr {
            HotKey.registry[self.id] = nil
            return nil
        }
    }

    deinit {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        HotKey.registry[id] = nil
    }

    private static func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: OSType(kEventHotKeyPressed))

        InstallEventHandler(GetApplicationEventTarget(),
                            { (_, event, _) -> OSStatus in
                                guard let event = event else { return OSStatus(eventNotHandledErr) }
                                var hkID = EventHotKeyID()
                                let err = GetEventParameter(event,
                                                            EventParamName(kEventParamDirectObject),
                                                            EventParamType(typeEventHotKeyID),
                                                            nil,
                                                            MemoryLayout<EventHotKeyID>.size,
                                                            nil,
                                                            &hkID)
                                if err == noErr, let hk = HotKey.registry[hkID.id] {
                                    DispatchQueue.main.async { hk.action() }
                                }
                                return noErr
                            },
                            1,
                            &eventType,
                            nil,
                            nil)
    }
}
