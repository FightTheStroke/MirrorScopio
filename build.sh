#!/bin/bash
# Costruisce build/MirrorScopio.app.
#
# Prima questo file compilava per conto suo: scriveva l'Info.plist a mano riga
# per riga e chiamava `swiftc` con l'elenco dei framework. Funzionava, ma erano
# due modi diversi di costruire la stessa app — questo e quello di Xcode — e non
# si somigliavano. La prova: acceso `DEAD_CODE_STRIPPING` in project.yml, l'app
# non e' cambiata di un byte, perche' questo file project.yml non lo apriva
# nemmeno. Ogni impostazione scritta li' valeva per meta' del mondo.
#
# Peggio: `swiftc -target arm64-apple-macos26.0` costruiva **solo** per Apple
# Silicon. Su un Mac Intel l'app non partiva, e nessuno lo aveva mai scritto.
#
# Adesso qui non si compila piu': si chiama `xcodebuild` sullo stesso progetto
# che usa Xcode, quindi c'e' un modo solo. L'app che ne esce e' universale
# (Apple Silicon e Intel) e pesa meno di prima.
#
# Serve: macOS 26+, Xcode 26, xcodegen (brew install xcodegen).
#
# La firma usa il Developer ID della Fight The Stroke Foundation quando c'e', e
# ripiega sulla firma alla buona: cosi' una copia appena scaricata compila su
# qualsiasi Mac, senza certificati.
set -euo pipefail

cd "$(dirname "$0")"

APP="build/MirrorScopio.app"
BUNDLE_ID="org.fightthestroke.mirrorscopio"
TEAM_IDENTITY="${MIRRORSCOPIO_IDENTITY:-Developer ID Application: Fight The Stroke Foundation (93T3LG4NPG)}"
# I risultati intermedi stanno fuori da build/, che viene svuotata a ogni giro:
# cosi' la seconda compilazione riusa il lavoro della prima invece di rifarlo.
DERIVED="$PWD/.build/xcode"

# Unica fonte di verità per la versione: il file VERSION alla radice.
VERSION="$(tr -d ' \n' < VERSION)"
# Il numero di build nasce dalla versione, non dal conto dei commit: vedi
# scripts/numero-build.sh per il perché (il conto dei commit può scendere).
BUILD_NUMBER="$(./scripts/numero-build.sh)"
GIT_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo sconosciuto)"
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then GIT_DIRTY="si"; else GIT_DIRTY="no"; fi
BUILD_DATE="$(date '+%d/%m/%Y %H:%M')"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Manca xcodegen: installalo con  brew install xcodegen"
  exit 1
fi

echo "MirrorScopio $VERSION (build $BUILD_NUMBER, commit $GIT_COMMIT$([ "$GIT_DIRTY" = si ] && echo ", con modifiche locali"))"

# Scrive Versione.xcconfig (da cui il progetto prende i due numeri) e rigenera
# il progetto da project.yml, cosi' si compila sempre l'ultima versione di
# quello che sta scritto li' dentro.
./scripts/genera-progetto.sh >/dev/null

rm -rf build
mkdir -p build

echo "Compilo…"
# La cartella dev'esserci prima, altrimenti il registro non si scrive e il
# controllo sulla concorrenza qui sotto guarderebbe un file vuoto: passerebbe
# sempre, e nessuno se ne accorgerebbe. E' successo.
mkdir -p "$DERIVED"
# Le tre chiavi FTS* non stanno in MirrorScopio.plist perche' cambiano a ogni
# commit: il plist le chiede come segnaposto e i valori arrivano da qui.
# CODE_SIGNING_ALLOWED=NO: la firma la mettiamo dopo, a mano, perche' dipende da
# quali certificati ha la macchina e perche' va messa **dopo** aver tolto i
# simboli (togliere qualcosa da un file firmato invaliderebbe la firma).
set +e
xcodebuild \
  -project MirrorScopio.xcodeproj \
  -scheme MirrorScopio \
  -destination "platform=macOS,arch=arm64" \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  FTS_GIT_COMMIT="$GIT_COMMIT" \
  FTS_GIT_DIRTY="$GIT_DIRTY" \
  FTS_BUILD_DATE="$BUILD_DATE" \
  build \
  | tee "$DERIVED/compilazione.log" \
  | grep -E "^\*\*|error:|warning: .*deprecated"
XCODEBUILD_STATUS="${PIPESTATUS[0]}"
set -e
if [ "$XCODEBUILD_STATUS" -ne 0 ]; then
  echo "xcodebuild si è fermato con codice $XCODEBUILD_STATUS."
  exit "$XCODEBUILD_STATUS"
fi

# Il registro completo resta accanto ai file di lavoro: a schermo si mostrano
# pochi avvisi di proposito, ma buttarli via vorrebbe dire non poterli piu'
# controllare. Sta fuori dall'app, che deve restare pulita.

# Gli avvisi di concorrenza sono l'unica famiglia che qui diventa un errore.
# Dicono che due parti del programma toccano la stessa cosa da fili diversi, e
# in un'app che ascolta un microfono mentre disegna sullo schermo e conta i
# fotogrammi quella e' la classe di difetti che si manifesta una volta su cento
# e non si riesce a rifare. Il caso vero trovato il 29 agosto: la finestra
# «dove lo salvo» del referto veniva aperta da un filo qualsiasi. Funzionava
# perche' la premeva sempre un dito su un bottone, non perche' fosse giusto.
#
# Gli avvisi che vengono dai framework di Apple non li contiamo: non possiamo
# correggerli e non dicono niente sul nostro codice.
NOSTRI="$(grep -E "warning: .*(main actor-isolated|nonisolated deinit|non-Sendable)" \
  "$DERIVED/compilazione.log" 2>/dev/null | grep -v "AttributeScopes" || true)"
if [ -n "$NOSTRI" ]; then
  echo ""
  echo "$NOSTRI"
  echo ""
  echo "Concorrenza: qui sopra c'e' del codice che tocca la stessa cosa da due"
  echo "fili diversi. Non e' un dettaglio di stile: e' la famiglia di difetti"
  echo "che compare una volta su cento e non si riesce a rifare. Va sistemata"
  echo "adesso, non quando si passera' a Swift 6."
  exit 1
fi

COSTRUITA="$DERIVED/Build/Products/Release/MirrorScopio.app"
if [ ! -d "$COSTRUITA" ]; then
  echo "xcodebuild non ha prodotto l'applicazione: $COSTRUITA"
  exit 1
fi
cp -R "$COSTRUITA" "$APP"

# Toglie i nomi interni delle funzioni, che servono solo a chi ha il debugger
# attaccato. Xcode li lascia dentro, e sono due terzi del peso: 6,9 MB di
# programma diventano 2,3. Sono megabyte che ogni famiglia deve scaricare.
# I nomi restano comunque nel file .dSYM accanto, quindi un rapporto di errore
# si sa ancora leggere.
strip -rSTx "$APP/Contents/MacOS/MirrorScopio" 2>/dev/null

# I permessi si leggono dall'unico file che li contiene. Prima erano scritti
# due volte — qui e in `MirrorScopio.entitlements` — e due copie della stessa
# verita' si allontanano in silenzio: bastava aggiungere un permesso in un posto
# solo per firmare l'app con permessi diversi da quelli dichiarati nel progetto.
cp MirrorScopio.entitlements build/entitlements.plist

if security find-identity -v -p codesigning | grep -q "93T3LG4NPG"; then
  echo "Firmo come Fight The Stroke Foundation…"
  # La marca temporale va chiesta ad Apple e serve alla notarizzazione, ma
  # rallenta ogni build: si attiva solo quando si prepara un pacchetto.
  TS_FLAG="--timestamp=none"
  [[ "${TIMESTAMP:-0}" == "1" ]] && TS_FLAG="--timestamp"
  # Niente --deep: Apple lo sconsiglia e propagherebbe gli entitlements al
  # contenuto annidato. Qui dentro non c'è codice annidato, solo font.
  codesign --force --options runtime $TS_FLAG \
    --entitlements build/entitlements.plist \
    --sign "$TEAM_IDENTITY" "$APP"
else
  FIRMA_ALLA_BUONA=1
  echo "Certificato della fondazione non trovato — firmo alla buona."
  # Stesso hardened runtime del ramo firmato: se una restrizione rompe
  # qualcosa, deve rompersi qui, non sul Mac di una famiglia.
  codesign --force --options runtime --entitlements build/entitlements.plist \
    --sign - --identifier "$BUNDLE_ID" "$APP"
fi

codesign --verify --verbose=1 "$APP" 2>&1 | tail -2

echo "Fatto: $APP  —  $VERSION ($BUILD_NUMBER)"
echo "Avvia con:  open $APP"

# Una firma alla buona cambia a ogni costruzione, e macOS considera «un'altra
# app» ogni copia. Il permesso del microfono concesso ieri smette di valere, e
# a schermo sembra un pulsante «Consenti» che non fa niente: è già successo, ci
# sono volute ore per capirlo. Se capita, va detto qui, come ultima riga, dove
# si guarda — non a metà di duecento righe di compilazione.
if [[ "${FIRMA_ALLA_BUONA:-0}" == "1" ]]; then
  echo
  echo "  ATTENZIONE: questa copia è firmata alla buona, non con il certificato"
  echo "  della fondazione. macOS la tratterà come un'app diversa da quella di"
  echo "  ieri: il permesso del microfono andrà concesso di nuovo, e se non"
  echo "  compare nessuna richiesta serve  tccutil reset Microphone $BUNDLE_ID"
fi
