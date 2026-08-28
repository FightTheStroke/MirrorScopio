#!/bin/sh
# Xcode Cloud esegue questo script subito dopo aver clonato il repository e
# prima di compilare. Serve a due cose che il clone da solo non porta.
#
# 1. Versione.xcconfig — da lì il progetto prende numero di versione e numero
#    di build. Non sta nel repository perché cambia a ogni commit (il numero di
#    build è il conto dei commit): committarlo vorrebbe dire una modifica falsa
#    in ogni confronto. Qui viene riscritto dai numeri veri.
#
# 2. Il progetto Xcode rigenerato da project.yml. Nel repository c'è già — deve
#    esserci, perché Xcode Cloud controlla che esista prima ancora di arrivare a
#    questo script — ma rigenerarlo garantisce che quello usato per compilare
#    corrisponda esattamente a project.yml, senza fidarsi di ciò che è stato
#    committato.
#
# Se questo script non parte, Xcode Cloud compila con versione e build vuote:
# meglio fermarsi.
set -eu

cd "$(dirname "$0")/.."

echo "Installo xcodegen"
brew install xcodegen

echo "Genero Versione.xcconfig e il progetto Xcode da project.yml"
./scripts/genera-progetto.sh
