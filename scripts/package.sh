#!/usr/bin/env bash
# Prepara MirrorScopio per un altro Mac: DMG firmato e, se ci sono le
# credenziali, notarizzato e "stapled" — cioè con il timbro di Apple attaccato
# addosso, così si apre anche senza internet e senza tasto destro.
#
#   ./scripts/package.sh              → DMG firmato, non notarizzato
#   ./scripts/package.sh --notarize   → DMG notarizzato e stapled
#
# Per notarizzare serve una credenziale salvata una volta sola:
#   xcrun notarytool store-credentials mirrorscopio \
#     --apple-id <apple-id> --team-id 93T3LG4NPG --password <password-app>
# La password per app si crea su appleid.apple.com › Accesso e sicurezza.
set -euo pipefail

cd "$(dirname "$0")/.."

APP="build/MirrorScopio.app"
VERSION="$(cat VERSION)"
DMG="build/MirrorScopio-$VERSION.dmg"
PROFILE="${NOTARY_PROFILE:-mirrorscopio}"
NOTARIZE=0
[[ "${1:-}" == "--notarize" ]] && NOTARIZE=1

echo "→ Compilo (con marca temporale: serve alla notarizzazione)"
TIMESTAMP=1 ./build.sh >/dev/null

# Attenzione: `codesign | grep -q` sotto `pipefail` fallisce sempre, perché
# grep chiude la pipe e codesign muore di SIGPIPE. Si legge in una variabile.
SIGNATURE="$(codesign -dvv "$APP" 2>&1 || true)"
if [[ "$SIGNATURE" != *"Developer ID Application"* ]]; then
  echo "✗ L'app non è firmata Developer ID: su un altro Mac non si aprirebbe."
  echo "  Serve il certificato «Developer ID Application: Fight The Stroke Foundation»."
  exit 1
fi

echo "→ Preparo il DMG"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applicazioni"
rm -f "$DMG"
hdiutil create -volname "MirrorScopio $VERSION" -srcfolder "$STAGE" \
  -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

codesign --force --sign "Developer ID Application: Fight The Stroke Foundation (93T3LG4NPG)" \
  --timestamp "$DMG"

if [[ $NOTARIZE -eq 1 ]]; then
  echo "→ Mando ad Apple per la notarizzazione (qualche minuto)"
  if ! xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait; then
    echo "✗ Notarizzazione fallita. Credenziali mancanti? Vedi l'intestazione di questo file."
    exit 1
  fi
  echo "→ Attacco il timbro al DMG"
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
else
  echo "⚠︎ DMG non notarizzato: su un altro Mac Gatekeeper lo bloccherà."
  echo "  Rilancia con --notarize dopo aver salvato le credenziali."
fi

echo
echo "Fatto: $DMG"
ls -lh "$DMG" | awk '{print "  " $5}'
