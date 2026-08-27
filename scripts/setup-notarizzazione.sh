#!/usr/bin/env bash
# Salva, una volta sola, la credenziale che serve per far timbrare l'app da
# Apple. Chiede tutto passo passo. La password non viene mai scritta su
# schermo né dentro il repository: finisce nel portachiavi di questo Mac.
set -euo pipefail

TEAM_ID="93T3LG4NPG"
PROFILE="mirrorscopio"

echo
echo "════════════════════════════════════════════════════════"
echo "  Preparo la firma di Apple per MirrorScopio"
echo "════════════════════════════════════════════════════════"
echo
echo "Serve una «password per app»: una password usa-e-getta che Apple"
echo "crea apposta, diversa da quella del tuo account."
echo
echo "PASSO 1. Ti apro la pagina giusta nel browser."
echo "         Accedi con il tuo Apple ID, poi cerca la sezione"
echo "         «Accesso e sicurezza» e dentro «Password specifiche per app»"
echo "         (in inglese: App-Specific Passwords)."
echo "         Premi «+» o «Genera password», chiamala  MirrorScopio ."
echo
echo "         Apple ti mostrerà una password fatta così:  abcd-efgh-ijkl-mnop"
echo "         Sedici lettere in quattro gruppi separati da trattini."
echo "         NON è la password del tuo account: se non ha i trattini,"
echo "         non è quella giusta."
echo
read -r -p "Premi Invio per aprire la pagina… " _
open "https://account.apple.com/account/manage" || true

echo
echo "PASSO 2. Quando hai la password sotto mano, torna qui."
echo
read -r -p "Qual è la tua Apple ID (l'email)? " APPLE_ID
if [[ -z "${APPLE_ID// }" ]]; then
  echo "✗ Senza Apple ID non posso andare avanti. Rilancia quando ce l'hai."
  exit 1
fi

echo
echo "PASSO 3. Incolla la password per app. Non si vedrà mentre la scrivi:"
echo "         è normale, sta funzionando lo stesso."
read -r -s -p "Password per app: " APP_PASSWORD
echo
# Gli spazi in coda arrivano spesso dal copia-incolla e fanno fallire tutto.
APP_PASSWORD="$(echo "$APP_PASSWORD" | tr -d '[:space:]')"
export APP_PASSWORD
if [[ -z "$APP_PASSWORD" ]]; then
  echo "✗ Password vuota. Rilancia quando ce l'hai."
  exit 1
fi
if [[ ! "$APP_PASSWORD" =~ ^[a-z]{4}-[a-z]{4}-[a-z]{4}-[a-z]{4}$ ]]; then
  echo
  echo "✗ Questa non sembra una password per app."
  echo "  Deve essere esattamente così:  abcd-efgh-ijkl-mnop"
  echo "  (sedici lettere minuscole, tre trattini, nient'altro)"
  echo "  Quella che hai incollato è lunga ${#APP_PASSWORD} caratteri."
  echo
  echo "  Se hai incollato la password del tuo account Apple, è quello"
  echo "  l'errore: ne serve una creata apposta nella pagina che ti ho aperto."
  echo "  Rilancia questo comando quando ce l'hai."
  exit 1
fi

echo
echo "→ Verifico con Apple e salvo nel portachiavi…"
xcrun notarytool store-credentials "$PROFILE" \
  --apple-id "$APPLE_ID" --team-id "$TEAM_ID" --password "@env:APP_PASSWORD" >/dev/null 2>&1 || true

# Salvare non basta: la volta scorsa la credenziale era salvata *e* sbagliata.
# Si chiede ad Apple una cosa vera prima di dire che ha funzionato.
if xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
  echo "✓ Fatto. Apple ha accettato la credenziale, salvata come «${PROFILE}»."
  echo
  echo "Ora puoi creare il pacchetto da dare a chiunque:"
  echo "    ./scripts/package.sh --notarize"
else
  echo "✗ Apple ha rifiutato queste credenziali."
  echo
  echo "  Che cosa controllare, in ordine:"
  echo "  1. L'email «$APPLE_ID» è davvero l'Apple ID con cui hai fatto"
  echo "     la password per app?"
  echo "  2. La password è stata copiata tutta intera, trattini compresi?"
  echo "  3. La password per app è ancora valida? Se l'hai revocata, creane"
  echo "     una nuova."
  echo
  echo "  Rilancia pure questo stesso comando: non si rompe niente."
  exit 1
fi
