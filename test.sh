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
# Le prove da tastiera aprono l'app vera e devono portarla in primo piano. Se
# ne e' rimasta aperta una di un giro precedente — anche compilata altrove — il
# sistema rifiuta di attivarne una seconda e cinque prove falliscono con
# «Failed to activate application». Non c'entra niente con il codice, ma chi
# legge l'errore ci perde mezz'ora. Quindi si chiude prima, e lo si dice.
RIMASTE="$(pgrep -f 'MirrorScopio.app/Contents/MacOS/MirrorScopio' || true)"
if [ -n "$RIMASTE" ]; then
  echo "  chiudo un'istanza di MirrorScopio rimasta aperta (pid $(echo "$RIMASTE" | tr '\n' ' '))"
  # shellcheck disable=SC2086
  kill $RIMASTE 2>/dev/null || true
  sleep 2
fi
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "✗ manca xcodegen (brew install xcodegen)"
  FAILED=1
elif ./scripts/genera-progetto.sh >/dev/null && xcodebuild test \
    -project MirrorScopio.xcodeproj -scheme MirrorScopio \
    -destination 'platform=macOS' 2>&1 \
    | grep -E "Test run with|Executed [0-9]+ test|skipped -|error:|\*\* TEST"; then
  echo "✓ prove Xcode"
else
  echo "✗ prove Xcode"
  FAILED=1
fi

# Il progetto Xcode deve dire la stessa versione del file VERSION. Prima diceva
# sempre "0.0.0" e nessuno se ne accorgeva, perche' l'unico controllo guardava
# l'applicazione costruita da build.sh. Un numero sbagliato che non protesta e'
# il difetto peggiore: finisce in un pacchetto e ci resta.
ATTESA="$(tr -d ' \n' < VERSION)"
DETTA="$(xcodebuild -project MirrorScopio.xcodeproj -target MirrorScopio \
  -configuration Release -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ MARKETING_VERSION = /{print $2; exit}')"
if [ "$ATTESA" = "$DETTA" ]; then
  echo "✓ versione del progetto Xcode ($DETTA)"
else
  echo "✗ versione: VERSION dice $ATTESA, il progetto Xcode dice ${DETTA:-niente}"
  FAILED=1
fi

# La scala adattiva e i suoni stanno in Verifiche/, sotto xcodebuild, dove
# girano anche in CI: qui c'erano due copie delle stesse prove e potevano
# dire cose diverse. «schermate» adesso disegna e basta, non boccia piu'
# niente: contrasto e scorrimento sono in Verifiche/Contrasto.swift.
run_harness schermate   scripts/disegna-schermate.swift  fast
# Vuole build/MirrorScopio.app: se non c'è, la costruisce. È il banco che prova
# l'aggiornamento dall'app su un pacchetto vero, non su un'idea di pacchetto:
# firma, timbro di Apple e scambio della cartella si possono verificare solo
# su un'applicazione che esiste davvero.
[ -d build/MirrorScopio.app ] || ./build.sh >/dev/null
run_harness aggiornamento Tests/AggiornamentoHarness.swift fast
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
