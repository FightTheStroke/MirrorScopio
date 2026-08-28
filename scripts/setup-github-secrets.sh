#!/usr/bin/env bash
# Mette su GitHub le chiavi che servono a costruire il pacchetto in automatico.
# Chiede tutto passo passo. Nessun segreto viene scritto nel repository: vanno
# nella cassaforte di GitHub, che nemmeno GitHub sa rileggere.
set -euo pipefail
cd "$(dirname "$0")/.."

# Se qualcosa si rompe, si deve capire *dove*. Senza questa riga lo script
# poteva fermarsi a meta' senza stampare niente, e chi lo aveva lanciato
# restava a guardare uno schermo che sembrava dire «non e' successo nulla».
# Un programma che si arrende in silenzio fa credere alla persona di aver
# sbagliato lei.
mi_sono_fermato() {
  echo
  echo "✗ Mi sono fermato alla riga $1, e non e' colpa tua."
  echo "  E' un difetto di questo script: copia questo messaggio e le righe qui sopra."
}
trap 'mi_sono_fermato $LINENO' ERR

REPO="FightTheStroke/MirrorScopio"
TEAM_ID="93T3LG4NPG"
IDENTITY="Developer ID Application: Fight The Stroke Foundation ($TEAM_ID)"

echo
echo "════════════════════════════════════════════════════════"
echo "  Insegno a GitHub a costruire il pacchetto da solo"
echo "════════════════════════════════════════════════════════"
echo
echo "Servono tre cose. Il certificato lo prendo da solo: a te restano"
echo "l'Apple ID e la password per app."
echo

if ! command -v gh >/dev/null 2>&1; then
  echo "✗ Manca il comando «gh». Installalo con:  brew install gh"
  exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "✗ Non sei collegato a GitHub. Lancia prima:  gh auth login"
  exit 1
fi
if ! security find-identity -v -p codesigning | grep -q "$TEAM_ID"; then
  echo "✗ Su questo Mac non c'è il certificato «$IDENTITY»."
  echo "  Senza, non si può firmare nulla."
  exit 1
fi

# ── 1. Il certificato ───────────────────────────────────────────────────────
#
# Qui prima si chiedeva di esportare il certificato a mano da Accesso
# Portachiavi e poi di ridigitare la password inventata durante l'esportazione.
# Due passaggi che sbagliavano in silenzio, e un controllo che dava la colpa
# alla persona invece che a sé stesso: «openssl pkcs12» su un file esportato da
# macOS fallisce con «RC2-40-CBC unsupported», perché OpenSSL 3 ha tolto quegli
# algoritmi. L'errore vero finiva in /dev/null e a schermo compariva «il file e
# la password non vanno d'accordo». La password era giusta tutte le volte.
#
# Adesso il certificato lo tira fuori questo script, con una password che
# inventa lui e che nessuno deve ricordare.
echo "COSA 1 di 3 — il certificato di firma."
echo
echo "Lo prendo io dal portachiavi. Se macOS chiede il permesso, dai «Consenti»."
echo

# «-legacy» esiste solo su OpenSSL 3: la LibreSSL che macOS installa di serie
# quegli algoritmi li legge ancora, e l'opzione non la conosce.
LEGACY=()
if openssl version | grep -q "^OpenSSL 3"; then LEGACY=(-legacy); fi

TEMPDIR="$(mktemp -d)"
trap 'rm -rf "$TEMPDIR"' EXIT
P12_PATH="$TEMPDIR/firma.p12"
# Una password lunga e casuale: vive dentro questo script e dentro la cassaforte
# di GitHub, e nessun essere umano deve mai ridigitarla.
#
# Si genera con «openssl rand» e non con «tr < /dev/urandom | head -c 40».
# Quel modo, che e' il piu' diffuso su internet, qui uccideva lo script in
# silenzio: «head» chiude la pipe appena ha i suoi 40 caratteri, «tr» muore di
# SIGPIPE con codice 141, e «set -o pipefail» piu' «set -e» fanno uscire tutto
# senza stampare una riga. Dallo schermo sembrava che il comando non avesse
# fatto niente.
P12_PASSWORD="$(openssl rand -hex 20)"
export P12_PASSWORD

TUTTE="$TEMPDIR/tutte.p12"
PASS_TUTTE="$(openssl rand -hex 20)"
if ! security export -k login.keychain-db -t identities -f pkcs12 \
     -P "$PASS_TUTTE" -o "$TUTTE" >/dev/null 2>&1; then
  echo "✗ Il portachiavi non mi ha lasciato esportare i certificati."
  echo "  Sblocca il portachiavi «login» e riprova."
  exit 1
fi

# «security export» tira fuori *tutte* le identità del portachiavi — comprese
# quelle di sviluppo e le installer. A GitHub deve arrivare solo quella che
# serve a firmare: una chiave privata in più su un server è una chiave privata
# in più da perdere.
#
# «-legacy» non è un dettaglio: senza, OpenSSL 3 non sa nemmeno aprire il file
# che macOS ha appena scritto.
if ! openssl pkcs12 "${LEGACY[@]}" -in "$TUTTE" -passin "pass:$PASS_TUTTE" \
     -nodes -out "$TEMPDIR/tutte.pem" 2>/dev/null; then
  echo "✗ Non riesco a leggere quello che il portachiavi ha esportato."
  exit 1
fi

if ! ESITO="$(python3 scripts/estrai-identita.py "$TEMPDIR" "$IDENTITY")"; then
  echo "✗ $ESITO"
  exit 1
fi

openssl pkcs12 -export "${LEGACY[@]}" -inkey "$TEMPDIR/solo.key" -in "$TEMPDIR/solo.crt" \
  -name "$IDENTITY" -passout env:P12_PASSWORD -out "$P12_PATH" 2>/dev/null

# La prova che conta non è che OpenSSL sappia aprire il file: è che macOS sappia
# importarlo e ci veda dentro un'identità buona per firmare. È esattamente
# quello che farà GitHub fra dieci minuti, quindi lo facciamo adesso, qui, dove
# si può ancora rimediare.
PORTACHIAVI="$TEMPDIR/prova.keychain-db"
security create-keychain -p prova "$PORTACHIAVI" >/dev/null 2>&1
security unlock-keychain -p prova "$PORTACHIAVI" >/dev/null 2>&1
security import "$P12_PATH" -k "$PORTACHIAVI" -P "$P12_PASSWORD" \
  -T /usr/bin/codesign >/dev/null 2>&1 || true
if ! security find-identity -v -p codesigning "$PORTACHIAVI" | grep -q "$TEAM_ID"; then
  echo "✗ Il certificato che ho preparato non si lascia importare."
  security delete-keychain "$PORTACHIAVI" >/dev/null 2>&1 || true
  exit 1
fi
security delete-keychain "$PORTACHIAVI" >/dev/null 2>&1 || true
echo "✓ Certificato pronto: $IDENTITY"

# ── 3. Le credenziali Apple ─────────────────────────────────────────────────
echo
echo "COSA 2 di 3 — la tua Apple ID (la stessa usata per la notarizzazione)."
read -r -p "Apple ID (email): " APPLE_ID
[ -z "$APPLE_ID" ] && { echo "✗ Serve l'Apple ID."; exit 1; }

echo
# Qui prima c'era solo «Password per app:» e un cursore che lampeggiava. Se non
# te la ricordavi, lo schermo non ti diceva ne' che non e' recuperabile, ne'
# dove se ne fa una nuova: restavi fermo a fissare un prompt muto. Se il
# programma sa una cosa, la dice.
echo "COSA 3 di 3 — la password per app, quella con i trattini (abcd-efgh-ijkl-mnop)."
echo
echo "  Non te la ricordi? Non e' un tuo problema di memoria: Apple la mostra"
echo "  una volta sola e poi non la sa piu' nemmeno lei. Non si recupera, se ne"
echo "  fa una nuova in un minuto — e quella vecchia si puo' buttare."
echo
echo "  Dove:  account.apple.com  →  Accesso e sicurezza  →  Password per app"
echo "         (con Safari a volte non va: usa Chrome o Edge)"
echo
read -r -p "  Vuoi che ti apra la pagina adesso? [invio = si', n = no] " APRI
if [ "${APRI:-}" != "n" ]; then
  open "https://account.apple.com/account/manage" >/dev/null 2>&1 || true
  echo "  Aperta. Quando ce l'hai, incollala qui sotto."
fi
echo
read -r -s -p "Password per app: " APPLE_APP_PASSWORD
echo
APPLE_APP_PASSWORD="$(echo "$APPLE_APP_PASSWORD" | tr -d '[:space:]')"
export APPLE_APP_PASSWORD
if [[ ! "$APPLE_APP_PASSWORD" =~ ^[a-z]{4}-[a-z]{4}-[a-z]{4}-[a-z]{4}$ ]]; then
  echo "✗ Quella che hai incollato non ha la forma  abcd-efgh-ijkl-mnop ."
  echo "  Sono quattro gruppi di quattro lettere minuscole con i trattini."
  echo "  Se hai incollato la password del tuo Apple ID: non e' quella, serve"
  echo "  proprio una \"password per app\" generata apposta."
  exit 1
fi

echo
echo "→ Controllo che Apple accetti queste credenziali…"
if ! xcrun notarytool history --apple-id "$APPLE_ID" \
       --password "@env:APPLE_APP_PASSWORD" --team-id "$TEAM_ID" >/dev/null 2>&1; then
  echo "✗ Apple le rifiuta. Controlla l'email e la password per app."
  exit 1
fi
echo "✓ Apple risponde."

# ── Consegna a GitHub ───────────────────────────────────────────────────────
echo
echo "→ Metto tutto nella cassaforte di $REPO…"
base64 -i "$P12_PATH" | gh secret set MACOS_CERT_P12 --repo "$REPO"
printf '%s' "$P12_PASSWORD"       | gh secret set MACOS_CERT_PASSWORD --repo "$REPO"
printf '%s' "$APPLE_ID"           | gh secret set APPLE_ID --repo "$REPO"
printf '%s' "$APPLE_APP_PASSWORD" | gh secret set APPLE_APP_PASSWORD --repo "$REPO"
printf '%s' "$TEAM_ID"            | gh secret set APPLE_TEAM_ID --repo "$REPO"

echo
echo "✓ Fatto. GitHub ora sa firmare e far timbrare l'app."
gh secret list --repo "$REPO"

echo
# Il consiglio stampato a schermo non viene seguito. Lo facciamo noi.
echo "Il certificato è passato da una cartella temporanea che si cancella da"
echo "sola: sulla Scrivania non resta niente da dimenticare."
echo
echo "Da ora in poi, per pubblicare una versione basta:"
echo "    ./scripts/release.sh 0.5.0"
echo "e il pacchetto compare da solo nella pagina delle release."
