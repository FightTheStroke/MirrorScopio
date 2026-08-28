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
# Per notarizzare serve una credenziale. Sul Mac di casa si salva una volta
# sola nel portachiavi:
#   xcrun notarytool store-credentials mirrorscopio \
#     --apple-id <apple-id> --team-id 93T3LG4NPG
# (senza `--password`: la chiede lui, e cosi' non resta scritta da nessuna
# parte. La password per app si crea su appleid.apple.com › Accesso e sicurezza.)
#
# Su GitHub la strada preferita e' la chiave API di App Store Connect, perche'
# e' un file e non un segreto scritto in una riga di comando:
#   NOTARY_KEY=/percorso/AuthKey_XXXXXX.p8  NOTARY_KEY_ID=XXXXXX  NOTARY_ISSUER=<uuid>
# In mancanza di quella si usa APPLE_ID + APPLE_APP_PASSWORD, che pero' qui
# viene consegnata sull'ingresso standard, mai fra gli argomenti: gli argomenti
# di un comando in esecuzione li legge chiunque, con `ps aux`.
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
  echo "→ Mando ad Apple per la notarizzazione (qualche minuto)"
  # Tre modi di autenticarsi, in ordine di preferenza. La differenza non e'
  # comodita': e' che nei primi due il segreto non compare mai fra gli
  # argomenti di un comando.
  #
  # 1. Chiave API di App Store Connect: e' un file, e un file non finisce in
  #    `ps`. E' la strada consigliata su GitHub.
  # 2. Apple ID con la password consegnata **sull'ingresso standard**.
  # 3. Profilo salvato nel portachiavi: e' quello che si usa sul Mac di casa.
  #
  # Quella che non c'e' piu' e' la quarta: `--password` scritto fra gli
  # argomenti. Su una macchina condivisa qualunque altro processo puo' leggere
  # gli argomenti di tutti i comandi in esecuzione — `ps aux` e basta — e una
  # password per app apre la notarizzazione a nome della fondazione.
  #
  # Prima ancora, qui c'era «--password "@env:APPLE_APP_PASSWORD"», con il
  # commento «@env: tiene la password fuori da ps aux». Il commento raccontava
  # una cosa che non esiste: notarytool quella sintassi non la conosce e prende
  # la stringa alla lettera. Ogni notarizzazione automatica e' sempre fallita
  # con «Invalid credentials», e il messaggio dava la colpa alla password. La
  # password era giusta tutte le volte. E' il motivo per cui qui sotto la
  # strada scelta viene **detta ad alta voce** prima di partire.
  DA_INGRESSO=""
  if [[ -n "${NOTARY_KEY:-}" && -n "${NOTARY_KEY_ID:-}" ]]; then
    echo "  autenticazione: chiave API di App Store Connect"
    NOTARY_ARGS=(--key "$NOTARY_KEY" --key-id "$NOTARY_KEY_ID")
    if [[ -n "${NOTARY_ISSUER:-}" ]]; then NOTARY_ARGS+=(--issuer "$NOTARY_ISSUER"); fi
  elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" ]]; then
    # Senza `--password`, notarytool chiede la password e la legge
    # dall'ingresso standard: gliela passiamo di li'. Provato: con la password
    # sbagliata risponde «401», cioe' l'ha davvero letta e usata.
    echo "  autenticazione: Apple ID, password consegnata sull'ingresso standard"
    NOTARY_ARGS=(--apple-id "$APPLE_ID" --team-id "${APPLE_TEAM_ID:-93T3LG4NPG}")
    DA_INGRESSO="$APPLE_APP_PASSWORD"
  else
    echo "  autenticazione: profilo «$PROFILE» salvato nel portachiavi"
    NOTARY_ARGS=(--keychain-profile "$PROFILE")
  fi

  if [[ -n "$DA_INGRESSO" ]]; then
    ESITO=0
    printf '%s\n' "$DA_INGRESSO" | xcrun notarytool submit "$DMG" "${NOTARY_ARGS[@]}" --wait || ESITO=$?
  else
    ESITO=0
    xcrun notarytool submit "$DMG" "${NOTARY_ARGS[@]}" --wait || ESITO=$?
  fi
  if [[ $ESITO -ne 0 ]]; then
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
