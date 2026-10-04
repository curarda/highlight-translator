import Cocoa

// Entry point. Runs as a menu-bar accessory app (no Dock icon).
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
