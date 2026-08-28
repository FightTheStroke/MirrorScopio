#!/bin/bash
# Esegue gli harness di verifica. Non sono XCTest: sono binari veri che
# stampano quello che succede, perché due dei tre parlano con il microfono e
# con il modello di sistema, e lì l'output va letto, non solo contato.
#
#   ./test.sh            gli harness veloci (staircase)
#   ./test.sh --all      tutti, anche quelli che usano voce e modello
set -euo pipefail
cd "$(dirname "$0")"

ALL=0
[ "${1:-}" = "--all" ] && ALL=1

OUT="build/tests"
mkdir -p "$OUT" build/schermate

# I file di Sources che servono agli harness: tutto il Core, più i dati.
# Le viste no: tirerebbero dentro SwiftUI senza alcun bisogno.
CORE=$(find Sources/Core Sources/Data Sources/Design -name "*.swift")
# Il banco delle schermate disegna l'interfaccia vera: a lui servono anche le viste.
VISTE=$(find Sources/Views -name "*.swift")

FRAMEWORKS="-framework AppKit -framework SwiftUI -framework AVFoundation \
  -framework Speech -framework FoundationModels -framework QuartzCore \
  -framework CoreAudio"

FAILED=0

run_harness() {
  local name="$1" file="$2" slow="$3"
  if [ "$slow" = "slow" ] && [ "$ALL" -eq 0 ]; then
    echo "· $name — saltato (serve --all: usa microfono o modello)"
    return
  fi

  echo ""
  echo "── $name ──"
  # Si mostrano solo gli errori: il rumore dei warning nasconderebbe il resto.
  # L'esito vero è l'esistenza del binario, controllata subito sotto.
  rm -f "$OUT/$name"
  local sorgenti="$CORE"
  [ "$name" = "schermate" ] && sorgenti="$CORE $VISTE"
  swiftc -O -target arm64-apple-macos26.0 -parse-as-library \
    $FRAMEWORKS -o "$OUT/$name" $sorgenti "$file" 2>&1 | grep -E "error:" || true
  if [ ! -x "$OUT/$name" ]; then
    echo "✗ $name non compila"
    FAILED=1
    return
  fi
  # Gli harness che parlano col microfono e col modello vocale devono girare
  # dentro un'applicazione firmata, come l'app vera.
  #
  # Un binario nudo non ha un identificatore stabile, e il sistema si rifiuta
  # di dargli in uso il modello vocale italiano: il risultato era che le tre
  # verifiche più importanti fallivano dicendo «manca il modello» su un Mac
  # dove il modello c'era. Una verifica che fallisce sempre smette di essere
  # letta, e allora tanto vale non averla.
  local eseguibile="$OUT/$name"
  if [ "$slow" = "slow" ]; then
    local bundle="$OUT/$name.app"
    rm -rf "$bundle"
    mkdir -p "$bundle/Contents/MacOS"
    cp "$OUT/$name" "$bundle/Contents/MacOS/$name"
    cat > "$bundle/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$name</string>
  <key>CFBundleExecutable</key><string>$name</string>
  <key>CFBundleIdentifier</key><string>org.fightthestroke.mirrorscopio.verifica.$name</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>LSBackgroundOnly</key><true/>
  <key>NSMicrophoneUsageDescription</key>
  <string>Serve a verificare che il riconoscimento vocale funzioni. L'audio resta su questo Mac.</string>
</dict>
</plist>
PLIST
    cat > "$OUT/entitlements.plist" <<ENT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.device.audio-input</key><true/>
</dict>
</plist>
ENT
    local identita="${MIRRORSCOPIO_IDENTITY:-Developer ID Application: Fight The Stroke Foundation (93T3LG4NPG)}"
    if security find-identity -v -p codesigning 2>/dev/null | grep -q "93T3LG4NPG"; then
      codesign --force --options runtime --entitlements "$OUT/entitlements.plist" \
        --sign "$identita" "$bundle" >/dev/null 2>&1
    else
      codesign --force --entitlements "$OUT/entitlements.plist" -s - "$bundle" >/dev/null 2>&1
    fi
    eseguibile="$bundle/Contents/MacOS/$name"
  fi

  if "$eseguibile"; then
    echo "✓ $name"
  else
    echo "✗ $name"
    FAILED=1
  fi
}

# Le prove scritte con swift-testing (Verifiche/) e quelle che aprono l'app vera
# senza mouse (ProveDaTastiera/). Girano con Xcode, non con SwiftPM.
#
# Perche' non piu' `swift test`: le stesse prove vivevano in due sistemi che
# chiamavano il modulo con due nomi diversi, e si sono scollate. Due sistemi che
# si scollano sono peggio di uno solo, perche' il verde di uno copre il rosso
# dell'altro. Ora la casa e' una: il progetto Xcode, generato da project.yml.
#
# I banchi qui sotto restano perche' hanno bisogno di un .app firmato
# (microfono, modello vocale), che le prove unitarie non costruiscono.
echo "── prove swift ──"
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "✗ manca xcodegen (brew install xcodegen)"
  FAILED=1
elif xcodegen generate >/dev/null && xcodebuild test \
    -project MirrorScopio.xcodeproj -scheme MirrorScopio \
    -destination 'platform=macOS' 2>&1 \
    | grep -E "Test run with|Executed [0-9]+ test|skipped -|error:|\*\* TEST"; then
  echo "✓ prove Xcode"
else
  echo "✗ prove Xcode"
  FAILED=1
fi

run_harness staircase   Tests/StaircaseHarness.swift    fast
run_harness suoni       Tests/SuoniHarness.swift         fast
run_harness schermate   Tests/SchermateHarness.swift     fast
run_harness microfono   Tests/MicHarness.swift          slow
run_harness punteggio   Tests/ScoringHarness.swift      slow
run_harness intelligenza Tests/IntelligenceHarness.swift slow

echo ""
if [ "$FAILED" -eq 0 ]; then
  echo "Tutto a posto."
else
  echo "Qualcosa non va: vedi sopra."
  exit 1
fi
