#!/bin/bash
# Genera MirrorScopio.xcodeproj a partire da project.yml, dopo aver scritto il
# numero di versione in Versione.xcconfig.
#
# Perché esiste: il progetto Xcode chiedeva la versione a due segnaposto fissi
# ("0.0.0" e "0") scritti dentro project.yml, e nessuno li sostituiva mai. Chi
# costruiva da Xcode si ritrovava un'applicazione che diceva di essere la 0.0.0
# mentre il file VERSION diceva tutt'altro — un numero sbagliato che non
# protestava. Ora la versione la scrive questo script, sempre dalla stessa
# fonte: il file VERSION alla radice, esattamente come fa build.sh.
#
# Il file generato non sta nel repository: cambia a ogni commit (il numero di
# build è il conto dei commit) e sporcherebbe ogni confronto.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="$(tr -d ' \n' < VERSION)"
# Lo stesso conto che usa build.sh: cresce da solo e non si scorda mai.
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 0)"

cat > Versione.xcconfig <<CONF
// Generato da scripts/genera-progetto.sh — non modificare a mano:
// la fonte è il file VERSION alla radice. Ogni modifica qui viene riscritta.
MARKETING_VERSION = $VERSION
CURRENT_PROJECT_VERSION = $BUILD_NUMBER
CONF

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Manca xcodegen: installalo con  brew install xcodegen"
  exit 1
fi

xcodegen generate --quiet
# Toglie i numeri casuali che xcodegen assegna a cinque oggetti: senza questo
# passo il progetto risulta modificato appena lo si rigenera, e il controllo
# «progetto allineato a project.yml» che gira su GitHub non potrebbe esistere.
python3 "$(dirname "$0")/stabilizza-progetto.py" >/dev/null
echo "Progetto pronto: MirrorScopio.xcodeproj — versione $VERSION (build $BUILD_NUMBER)"
