#!/bin/bash
# Builds MirrorScopio.app without an Xcode project.
# Requirements: macOS 26+, Xcode 26 command line tools.
#
# Signing: uses the Fight The Stroke Foundation Developer ID when available,
# falls back to ad-hoc so a fresh clone still builds on any machine.
set -euo pipefail

cd "$(dirname "$0")"

APP="build/MirrorScopio.app"
BIN="$APP/Contents/MacOS/MirrorScopio"
BUNDLE_ID="org.fightthestroke.mirrorscopio"
TEAM_IDENTITY="${MIRRORSCOPIO_IDENTITY:-Developer ID Application: Fight The Stroke Foundation (93T3LG4NPG)}"
VERSION="1.0"

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>MirrorScopio</string>
  <key>CFBundleDisplayName</key><string>MirrorScopio</string>
  <key>CFBundleExecutable</key><string>MirrorScopio</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.education</string>
  <key>NSHumanReadableCopyright</key><string>© Fight The Stroke Foundation</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSMicrophoneUsageDescription</key>
  <string>Il microfono serve a sentire la lettura ad alta voce e capire da solo se la parola è giusta. L'audio resta su questo Mac.</string>
  <key>NSSpeechRecognitionUsageDescription</key>
  <string>Il riconoscimento vocale avviene interamente su questo Mac e serve a confrontare quello che leggi con la parola mostrata.</string>
  <key>ATSApplicationFontsPath</key><string>Fonts</string>
</dict>
</plist>
PLIST

cat > build/entitlements.plist <<ENT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.device.audio-input</key><true/>
  <key>com.apple.security.files.user-selected.read-write</key><true/>
</dict>
</plist>
ENT

if [ -d Resources/Fonts ]; then
  mkdir -p "$APP/Contents/Resources/Fonts"
  cp Resources/Fonts/*.otf Resources/Fonts/*.ttf "$APP/Contents/Resources/Fonts/" 2>/dev/null || true
fi

echo "Compiling…"
swiftc \
  -O \
  -target arm64-apple-macos26.0 \
  -framework SwiftUI -framework AppKit -framework AVFoundation \
  -framework Speech -framework FoundationModels -framework QuartzCore \
  -framework PDFKit -framework Charts \
  -o "$BIN" \
  $(find Sources -name "*.swift")

if security find-identity -v -p codesigning | grep -q "93T3LG4NPG"; then
  echo "Signing as Fight The Stroke Foundation…"
  codesign --force --deep --options runtime --timestamp=none \
    --entitlements build/entitlements.plist \
    --sign "$TEAM_IDENTITY" "$APP"
else
  echo "Fight The Stroke identity not found — signing ad-hoc."
  codesign --force --entitlements build/entitlements.plist \
    --sign - --identifier "$BUNDLE_ID" "$APP"
fi

codesign --verify --verbose=1 "$APP" 2>&1 | tail -2

echo "Done: $APP"
echo "Run with:  open $APP"
