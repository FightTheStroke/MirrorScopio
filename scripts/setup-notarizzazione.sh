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
echo "         Accedi, vai su «Accesso e sicurezza» › «Password per app»,"
echo "         premi «+», chiamala  MirrorScopio  e copia la password che"
echo "         compare (quattro gruppi di lettere, tipo abcd-efgh-ijkl-mnop)."
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
if [[ -z "${APP_PASSWORD// }" ]]; then
  echo "✗ Password vuota. Rilancia quando ce l'hai."
  exit 1
fi

echo
echo "→ Verifico con Apple e salvo nel portachiavi…"
if xcrun notarytool store-credentials "$PROFILE" \
     --apple-id "$APPLE_ID" --team-id "$TEAM_ID" --password "$APP_PASSWORD" >/dev/null 2>&1; then
  echo "✓ Fatto. La credenziale è salvata come «$PROFILE» sul portachiavi."
  echo
  echo "Ora puoi creare il pacchetto da dare a chiunque:"
  echo "    ./scripts/package.sh --notarize"
else
  echo "✗ Apple non ha accettato queste credenziali."
  echo "  Le cause più comuni: password copiata a metà, oppure hai incollato"
  echo "  la password del tuo account invece di quella «per app»."
  echo "  Riprova pure: rilancia questo stesso comando."
  exit 1
fi
