#!/bin/bash
set -euo pipefail

# Build Çeviri.app with swiftc (no Xcode project required).
cd "$(dirname "$0")"

APP="Çeviri.app"
BIN_NAME="Ceviri"
MACOS_DIR="$APP/Contents/MacOS"
RES_DIR="$APP/Contents/Resources"

# Stable self-signed identity → Accessibility permission survives rebuilds.
# Falls back to ad-hoc ("-") if the certificate isn't installed.
IDENTITY="Ceviri Self Signed"
if ! security find-identity 2>/dev/null | grep -q "$IDENTITY"; then
    echo "⚠️  '$IDENTITY' certificate not found — falling back to ad-hoc signing."
    IDENTITY="-"
fi

echo "Cleaning previous build…"
rm -rf "$APP"
mkdir -p "$MACOS_DIR" "$RES_DIR"

echo "Copying Info.plist…"
cp Resources/Info.plist "$APP/Contents/Info.plist"

echo "Compiling Swift sources…"
swiftc \
    -swift-version 5 \
    -O \
    -framework Cocoa \
    -framework SwiftUI \
    -framework Carbon \
    -framework ApplicationServices \
    Sources/*.swift \
    -o "$MACOS_DIR/$BIN_NAME"

echo "Code signing ($IDENTITY)…"
codesign --force --deep --sign "$IDENTITY" "$APP" >/dev/null 2>&1 || \
    echo "  (codesign skipped)"

# Install into /Applications so the right-click Service is reliably indexed.
# (macOS only surfaces Services from apps in /Applications or ~/Applications.)
INSTALL_DIR="/Applications"
if [ ! -w "$INSTALL_DIR" ]; then
    INSTALL_DIR="$HOME/Applications"
    mkdir -p "$INSTALL_DIR"
fi
INSTALLED="$INSTALL_DIR/$APP"

echo "Installing to $INSTALLED …"
# Quit the running app so we can replace it.
pkill -x "$BIN_NAME" 2>/dev/null || true
sleep 1
rm -rf "$INSTALLED"
cp -R "$APP" "$INSTALLED"
codesign --force --deep --sign "$IDENTITY" "$INSTALLED" >/dev/null 2>&1 || true

echo "Registering the right-click Service…"
LSREG="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
"$LSREG" -f "$INSTALLED" 2>/dev/null || true
/System/Library/CoreServices/pbs -flush 2>/dev/null || true
/System/Library/CoreServices/pbs -update 2>/dev/null || true

echo ""
echo "✅ Built and installed at: $INSTALLED"
echo "   Launch it with:  open \"$INSTALLED\""
echo "   NOTE: after a rebuild, fully quit & reopen your browser/PDF app so it"
echo "         Re-grant Accessibility permission (the shortcut needs it)."
