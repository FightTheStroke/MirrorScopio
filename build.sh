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
# Unica fonte di verità per la versione: il file VERSION alla radice.
VERSION="$(tr -d ' \n' < VERSION)"
# Il numero di build è il conto dei commit: cresce da solo e non si scorda mai.
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 0)"
GIT_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo sconosciuto)"
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then GIT_DIRTY="si"; else GIT_DIRTY="no"; fi
BUILD_DATE="$(date '+%d/%m/%Y %H:%M')"

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
  <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
  <key>FTSGitCommit</key><string>$GIT_COMMIT</string>
  <key>FTSGitDirty</key><string>$GIT_DIRTY</string>
  <key>FTSBuildDate</key><string>$BUILD_DATE</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.education</string>
  <key>NSHumanReadableCopyright</key><string>© Fight The Stroke Foundation</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSMicrophoneUsageDescription</key>
  <string>Il microfono serve a sentire la lettura ad alta voce e capire da solo se la parola è giusta. L'audio resta su questo Mac.</string>

  <key>CFBundleIconFile</key><string>AppIcon</string>
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

# L'icona: un file solo, gia pronto. Si rigenera con `swift scripts/icona.swift`
# quando il segno cambia, non a ogni build.
if [ -f Resources/AppIcon.icns ]; then
  cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
else
  echo "Attenzione: manca Resources/AppIcon.icns — l'app userà l'icona di serie."
fi

if [ -d Resources/Fonts ]; then
  mkdir -p "$APP/Contents/Resources/Fonts"
  cp Resources/Fonts/*.otf Resources/Fonts/*.ttf "$APP/Contents/Resources/Fonts/" 2>/dev/null || true
fi

echo "MirrorScopio $VERSION (build $BUILD_NUMBER, commit $GIT_COMMIT$([ "$GIT_DIRTY" = si ] && echo ", con modifiche locali"))"
echo "Compilo…"
swiftc \
  -O \
  -target arm64-apple-macos26.0 \
  -framework SwiftUI -framework AppKit -framework AVFoundation \
  -framework Speech -framework FoundationModels -framework QuartzCore \
  -framework PDFKit -framework CoreAudio \
  -o "$BIN" \
  $(find Sources -name "*.swift")

if security find-identity -v -p codesigning | grep -q "93T3LG4NPG"; then
  echo "Signing as Fight The Stroke Foundation…"
  # La marca temporale va chiesta ad Apple e serve alla notarizzazione, ma
  # rallenta ogni build: si attiva solo quando si prepara un pacchetto.
  TS_FLAG="--timestamp=none"
  [[ "${TIMESTAMP:-0}" == "1" ]] && TS_FLAG="--timestamp"
  # Niente --deep: Apple lo sconsiglia e propagherebbe gli entitlements al
  # contenuto annidato. Qui dentro non c'è codice annidato, solo font.
  codesign --force --options runtime $TS_FLAG \
    --entitlements build/entitlements.plist \
    --sign "$TEAM_IDENTITY" "$APP"
else
  echo "Fight The Stroke identity not found — signing ad-hoc."
  # Stesso hardened runtime del ramo firmato: se una restrizione rompe
  # qualcosa, deve rompersi qui, non sul Mac di una famiglia.
  codesign --force --options runtime --entitlements build/entitlements.plist \
    --sign - --identifier "$BUNDLE_ID" "$APP"
fi

codesign --verify --verbose=1 "$APP" 2>&1 | tail -2

echo "Fatto: $APP  —  $VERSION ($BUILD_NUMBER)"
echo "Avvia con:  open $APP"
