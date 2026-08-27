#!/usr/bin/env bash
# Mette su GitHub le chiavi che servono a costruire il pacchetto in automatico.
# Chiede tutto passo passo. Nessun segreto viene scritto nel repository: vanno
# nella cassaforte di GitHub, che nemmeno GitHub sa rileggere.
set -euo pipefail
cd "$(dirname "$0")/.."

REPO="FightTheStroke/MirrorScopio"
TEAM_ID="93T3LG4NPG"
IDENTITY="Developer ID Application: Fight The Stroke Foundation ($TEAM_ID)"

echo
echo "════════════════════════════════════════════════════════"
echo "  Insegno a GitHub a costruire il pacchetto da solo"
echo "════════════════════════════════════════════════════════"
echo
echo "Servono quattro cose. Te le chiedo una alla volta."
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
echo "COSA 1 di 4 — il certificato di firma."
echo
echo "Va esportato a mano: macOS non lascia che un comando tiri fuori una"
echo "chiave privata senza il tuo consenso, ed è giusto così."
echo
echo "  a) Ti apro «Accesso Portachiavi»."
echo "  b) In alto a sinistra scegli «Accesso» → categoria «Certificati»."
echo "  c) Cerca:  Developer ID Application: Fight The Stroke Foundation"
echo "  d) Tasto destro sopra → «Esporta \"Developer ID Application…\"»"
echo "  e) Salvalo sulla Scrivania come  mirrorscopio.p12  (formato .p12)"
echo "  f) Ti chiederà una password NUOVA, inventata da te, per proteggere"
echo "     il file. Scrivitela: te la chiedo fra un momento."
echo
read -r -p "Premi Invio per aprire Accesso Portachiavi… " _
open -a "Keychain Access" || open -a "Accesso Portachiavi" || true

echo
DEFAULT_P12="$HOME/Desktop/mirrorscopio.p12"
read -r -p "Dov'è il file? [$DEFAULT_P12] " P12_PATH
P12_PATH="${P12_PATH:-$DEFAULT_P12}"
P12_PATH="${P12_PATH/#\~/$HOME}"
if [ ! -f "$P12_PATH" ]; then
  echo "✗ Non trovo «$P12_PATH». Rilancia quando il file c'è."
  exit 1
fi

echo
echo "COSA 2 di 4 — la password che hai appena inventato per quel file."
read -r -s -p "Password del file .p12: " P12_PASSWORD
echo
if [ -z "$P12_PASSWORD" ]; then
  echo "✗ Password vuota: senza, GitHub non riesce ad aprire il certificato."
  exit 1
fi
# Controllo subito che la coppia file+password funzioni: meglio scoprirlo qui
# che dentro un workflow che fallisce fra dieci minuti.
if ! openssl pkcs12 -in "$P12_PATH" -passin "pass:$P12_PASSWORD" -noout 2>/dev/null; then
  echo "✗ Il file e la password non vanno d'accordo. Riprova."
  exit 1
fi
echo "✓ Certificato leggibile."

# ── 3. Le credenziali Apple ─────────────────────────────────────────────────
echo
echo "COSA 3 di 4 — la tua Apple ID (la stessa usata per la notarizzazione)."
read -r -p "Apple ID (email): " APPLE_ID
[ -z "$APPLE_ID" ] && { echo "✗ Serve l'Apple ID."; exit 1; }

echo
echo "COSA 4 di 4 — la password per app, quella con i trattini."
echo "              È la stessa di ./scripts/setup-notarizzazione.sh."
read -r -s -p "Password per app: " APPLE_APP_PASSWORD
echo
APPLE_APP_PASSWORD="$(echo "$APPLE_APP_PASSWORD" | tr -d '[:space:]')"
if [[ ! "$APPLE_APP_PASSWORD" =~ ^[a-z]{4}-[a-z]{4}-[a-z]{4}-[a-z]{4}$ ]]; then
  echo "✗ Non ha la forma  abcd-efgh-ijkl-mnop . Riprova."
  exit 1
fi

echo
echo "→ Controllo che Apple accetti queste credenziali…"
if ! xcrun notarytool history --apple-id "$APPLE_ID" \
       --password "$APPLE_APP_PASSWORD" --team-id "$TEAM_ID" >/dev/null 2>&1; then
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
echo "Adesso cancella il file .p12 dalla Scrivania: contiene la chiave privata."
echo "    rm \"$P12_PATH\""
echo
echo "Da ora in poi, per pubblicare una versione basta:"
echo "    ./scripts/release.sh 0.3.0"
echo "e il pacchetto compare da solo nella pagina delle release."
