#!/bin/bash
# Stampa il numero di build da mettere nell'app. Unico posto dove si calcola:
# lo chiamano sia build.sh sia scripts/genera-progetto.sh, così i due non
# possono dire due numeri diversi.
#
# Perché non è più il conto dei commit. Lo era, e il 28/08 si è rotto: la copia
# installata sul Mac di Roberto diceva 103, mentre il ramo principale ne
# produceva 94. Non era un errore di conto — unire una serie di modifiche
# schiacciandole in un unico salvataggio *toglie* salvataggi alla storia, e il
# conto scende. macOS però pretende che questo numero salga sempre: un Mac
# fermo a un numero più alto non vedrebbe mai arrivare le versioni successive,
# e nessuno se ne accorgerebbe finché non serve.
#
# Adesso il numero nasce dal file VERSION, che è già l'unica fonte di verità
# per la versione e che sale per costruzione: 0.6.0 → 600, 0.6.1 → 601,
# 0.7.0 → 700, 1.0.0 → 10000. Vale finché le cifre di mezzo restano sotto 100,
# ed è il motivo per cui questo script si rifiuta di lavorare se non lo sono.
set -euo pipefail

cd "$(dirname "$0")/.."

# Normalmente legge VERSION alla radice. VERSION_FILE serve solo alle prove,
# che devono poter chiedere «e con la versione 1.100.0 che cosa fai?» senza
# toccare il file vero.
VERSIONE="$(tr -d ' \n' < "${VERSION_FILE:-VERSION}")"

if ! [[ "$VERSIONE" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "VERSION contiene «${VERSIONE}», che non è nella forma numero.numero.numero." >&2
  exit 1
fi

MAGGIORE="${BASH_REMATCH[1]}"
MEDIO="${BASH_REMATCH[2]}"
MINORE="${BASH_REMATCH[3]}"

if [ "$MEDIO" -ge 100 ] || [ "$MINORE" -ge 100 ]; then
  echo "La versione $VERSIONE ha una cifra da 100 o più: il numero di build calcolato" >&2
  echo "smetterebbe di salire sempre. Va cambiato il calcolo qui dentro prima di" >&2
  echo "pubblicare questa versione." >&2
  exit 1
fi

echo $(( MAGGIORE * 10000 + MEDIO * 100 + MINORE ))
