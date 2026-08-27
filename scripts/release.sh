#!/bin/bash
# Rilascia una versione nuova: aggiorna VERSION, chiude la sezione del
# changelog, compila, verifica, marca il commit e crea la release su GitHub.
#
#   ./scripts/release.sh 0.2.0
#
# Non fa niente finché l'albero non è pulito: una release che non corrisponde
# a un commit è una release che nessuno potrà più riprodurre.
set -euo pipefail
cd "$(dirname "$0")/.."

NEW="${1:-}"
if [[ ! "$NEW" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Uso: ./scripts/release.sh MAGGIORE.MINORE.CORREZIONE   (es. 0.2.0)"
  echo "Versione attuale: $(cat VERSION)"
  exit 1
fi

OLD="$(tr -d ' \n' < VERSION)"
TODAY="$(date '+%Y-%m-%d')"

if [ -n "$(git status --porcelain)" ]; then
  echo "Ci sono modifiche non salvate. Fai commit prima di rilasciare."
  git status --short
  exit 1
fi

if git rev-parse "v$NEW" >/dev/null 2>&1; then
  echo "La versione v$NEW esiste già."
  exit 1
fi

if ! grep -q "## \[Non ancora rilasciato\]" CHANGELOG.md; then
  echo "Nel CHANGELOG manca la sezione [Non ancora rilasciato]."
  exit 1
fi

UNRELEASED="$(awk '/^## \[Non ancora rilasciato\]/{f=1;next} /^## \[/{f=0} f' CHANGELOG.md | tr -d '[:space:]')"
if [ -z "$UNRELEASED" ]; then
  echo "La sezione [Non ancora rilasciato] è vuota: scrivi che cosa cambia prima di rilasciare."
  exit 1
fi

echo "Rilascio $OLD → $NEW"

printf '%s\n' "$NEW" > VERSION

python3 - "$NEW" "$TODAY" <<'PY'
import sys, re
new, today = sys.argv[1], sys.argv[2]
p = "CHANGELOG.md"
s = open(p).read()
s = s.replace("## [Non ancora rilasciato]",
              f"## [Non ancora rilasciato]\n\n## [{new}] — {today}", 1)
base = "https://github.com/FightTheStroke/MirrorScopio"
s = re.sub(r"^\[Non ancora rilasciato\]:.*$",
           f"[Non ancora rilasciato]: {base}/compare/v{new}...HEAD",
           s, count=1, flags=re.M)
s = s.rstrip("\n") + f"\n[{new}]: {base}/releases/tag/v{new}\n"
open(p, "w").write(s)
PY

echo "Compilo per verificare che la versione stia in piedi…"
./build.sh >/dev/null
if [ -x ./test.sh ]; then ./test.sh; fi

git add VERSION CHANGELOG.md
git commit -q -m "Versione $NEW"
git tag -a "v$NEW" -m "MirrorScopio $NEW"
git push -q origin HEAD --follow-tags

NOTES="$(awk -v v="$NEW" '$0 ~ "^## \\["v"\\]"{f=1;next} /^## \[/{f=0} f' CHANGELOG.md)"

# Il pacchetto notarizzato viaggia insieme alla release: chi lo scarica deve
# poter fare doppio clic, non compilare.
DMG="build/MirrorScopio-$NEW.dmg"
if ./scripts/package.sh --notarize; then
  echo "Pacchetto pronto: $DMG"
else
  echo "⚠︎ Pacchetto non creato: la release avrà solo il codice sorgente."
  DMG=""
fi

if command -v gh >/dev/null 2>&1; then
  if [ -n "$DMG" ] && [ -f "$DMG" ]; then
    gh release create "v$NEW" --title "MirrorScopio $NEW" --notes "$NOTES" "$DMG"
  else
    gh release create "v$NEW" --title "MirrorScopio $NEW" --notes "$NOTES"
  fi || echo "Release GitHub non creata: crea il tag a mano se serve."
fi

echo "Fatto: v$NEW"
