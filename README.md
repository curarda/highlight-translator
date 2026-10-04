# Çeviri

A tiny macOS menu-bar app that explains and translates highlighted text using the
**Gemini API**. Built for reading English academic papers: highlight a term or
sentence you don't understand in any app — Chrome, Safari, Preview/Skim PDFs,
anything — press a shortcut, and get a clear explanation in your language.

## How it works

1. You highlight text in **any** app.
2. You press **⌘⇧T** (or use the menu-bar icon → *Ask about selection*).
3. Çeviri copies the selection behind the scenes (simulated ⌘C), sends it to
   Gemini with instructions to translate + explain academic terms, and shows the
   answer in a floating popup.
4. You can type a **follow-up question** in the popup to dig deeper.

Because it uses the standard Copy command, it works everywhere — no browser
extension required, and PDFs work too.

## Setup (one time)

### 1. Build

```bash
./build.sh
```

This produces `Çeviri.app` (no Xcode needed — it uses `swiftc` from the Command
Line Tools).

### 2. Run

```bash
open "Çeviri.app"
```

A book icon appears in the menu bar. There is no Dock icon.

### 3. Grant Accessibility permission

The app needs Accessibility permission to read your highlighted text (it presses
⌘C for you). On first launch it will prompt you. Otherwise:

**System Settings → Privacy & Security → Accessibility → enable Çeviri**, then
quit and reopen the app.

### 4. Add your Gemini API key

- Get a free key at <https://aistudio.google.com/apikey>
- Menu-bar icon → **Settings…** → paste the key.

## Settings

- **API key** — your Gemini key (stored locally in your macOS user defaults).
- **Model** — `gemini-2.5-flash` (default), `gemini-2.5-pro`, or `gemini-2.0-flash`.
- **Answer language** — defaults to **Turkish**. Change to any language.
- **Instructions to Gemini** — the prompt template. Use `{LANG}` where the answer
  language should be inserted.

## Shortcut

Default is **⌘⇧T**. It's currently fixed in code — to change it, edit
`setupHotKey()` in `Sources/AppDelegate.swift` (the `keyCode` / `modifiers`) and
rebuild.

## Notes

- The app restores your previous clipboard contents after reading the selection.
- Your API key and selected text are sent only to Google's Gemini endpoint.
- Rebuilding may reset the Accessibility permission; re-enable it if the shortcut
  stops capturing text.

## Project layout

```
Sources/
  main.swift            – entry point (menu-bar accessory app)
  AppDelegate.swift     – menu bar, hotkey wiring, permissions
  HotKey.swift          – global ⌘⇧T via Carbon RegisterEventHotKey
  SelectionCapture.swift– ⌘C simulation + clipboard read/restore
  GeminiClient.swift    – Gemini REST call + response parsing
  Settings.swift        – persisted settings + prompt builder
  PopupController.swift  – floating result panel + query flow
  PopupView.swift       – SwiftUI popup UI
  SettingsView.swift    – SwiftUI settings UI
Resources/Info.plist    – bundle metadata (LSUIElement = menu-bar app)
build.sh                – compiles + assembles Çeviri.app
```
