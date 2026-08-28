#!/usr/bin/env bash
# Prepara MirrorScopio per un altro Mac: DMG firmato e, se ci sono le
# credenziali, notarizzato e "stapled" — cioè con il timbro di Apple attaccato
# addosso, così si apre anche senza internet e senza tasto destro.
#
#   ./scripts/package.sh              → DMG firmato, non notarizzato
#   ./scripts/package.sh --notarize   → DMG notarizzato e "stapled"
#
# Escono due file dallo stesso binario: il DMG, per chi installa la prima volta
# e trascina l'icona nelle Applicazioni, e uno zip, che serve a MirrorScopio
# stesso quando si aggiorna da solo.
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
ZIP="build/MirrorScopio-$VERSION.zip"
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

IDENTITY="${SIGN_IDENTITY:-Developer ID Application: Fight The Stroke Foundation (93T3LG4NPG)}"
codesign --force --sign "$IDENTITY" --timestamp "$DMG"

if [[ $NOTARIZE -eq 1 ]]; then
  echo "→ Mando ad Apple per la notarizzazione (qualche minuto)"  # Sul Mac di casa le credenziali stanno nel portachiavi; su GitHub arrivano
  # dalle variabili segrete. Stessa strada, due modi di autenticarsi.
  if [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" ]]; then
    # Qui c'era «--password "@env:APPLE_APP_PASSWORD"», con il commento
    # «@env: tiene la password fuori da ps aux». Il commento raccontava una
    # cosa che non esiste: notarytool quella sintassi non la conosce e prende
    # la stringa alla lettera. Risultato, ogni notarizzazione automatica e'
    # sempre fallita con «Invalid credentials», e il messaggio dava la colpa
    # alla password. La password era giusta tutte le volte.
    NOTARY_ARGS=(--apple-id "$APPLE_ID" --password "$APPLE_APP_PASSWORD"
                 --team-id "${APPLE_TEAM_ID:-93T3LG4NPG}")
  else
    NOTARY_ARGS=(--keychain-profile "$PROFILE")
  fi
  if ! xcrun notarytool submit "$DMG" "${NOTARY_ARGS[@]}" --wait; then
    echo "✗ Notarizzazione fallita. Credenziali mancanti? Vedi l'intestazione di questo file."
    exit 1
  fi
  echo "→ Attacco il timbro al DMG"
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
  # E anche all'app: il timbro attaccato addosso è quello che l'aggiornatore
  # dentro MirrorScopio controlla prima di sostituire la versione vecchia.
  # Senza, l'app nuova sarebbe pur sempre notarizzata, ma dimostrarlo
  # richiederebbe internet proprio nel momento in cui non lo si ha.
  echo "→ Attacco il timbro all'app"
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
else
  echo "⚠︎ DMG non notarizzato: su un altro Mac Gatekeeper lo bloccherà."
  echo "  Rilancia con --notarize dopo aver salvato le credenziali."
fi

# Lo zip accanto al DMG. Il DMG serve a chi installa la prima volta e trascina
# l'icona; lo zip serve a MirrorScopio stesso, che sa aggiornarsi da solo e per
# farlo deve poter aprire il pacchetto senza montare un disco.
#
# `ditto` e non `zip`: la firma di un'app vive anche nei permessi e nei
# collegamenti interni, e `zip` li perde. Un pacchetto così arriverebbe a
# destinazione con la firma rotta, e l'aggiornatore — giustamente — lo
# rifiuterebbe.
echo "→ Preparo lo zip per l'aggiornamento dall'app"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo
echo "Fatto: $DMG"
ls -lh "$DMG" | awk '{print "  " $5}'
echo "Fatto: $ZIP"
ls -lh "$ZIP" | awk '{print "  " $5}'
