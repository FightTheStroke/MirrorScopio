#!/bin/bash
# Esegue gli harness di verifica. Non sono XCTest: sono binari veri che
# stampano quello che succede, perché due dei tre parlano con il microfono e
# con il modello di sistema, e lì l'output va letto, non solo contato.
#
#   ./test.sh            gli harness veloci (staircase)
#   ./test.sh --all      tutti, anche quelli che usano voce e modello
set -euo pipefail
cd "$(dirname "$0")"

ALL=0
[ "${1:-}" = "--all" ] && ALL=1

OUT="build/tests"
mkdir -p "$OUT"

# I file di Sources che servono agli harness: tutto il Core, più i dati.
# Le viste no: tirerebbero dentro SwiftUI senza alcun bisogno.
CORE=$(find Sources/Core Sources/Data Sources/Design -name "*.swift")

FRAMEWORKS="-framework AppKit -framework SwiftUI -framework AVFoundation \
  -framework Speech -framework FoundationModels -framework QuartzCore"

FAILED=0

run_harness() {
  local name="$1" file="$2" slow="$3"
  if [ "$slow" = "slow" ] && [ "$ALL" -eq 0 ]; then
    echo "· $name — saltato (serve --all: usa microfono o modello)"
    return
  fi

  echo ""
  echo "── $name ──"
  if ! swiftc -O -target arm64-apple-macos26.0 -parse-as-library \
      $FRAMEWORKS -o "$OUT/$name" $CORE "$file" 2>&1 | grep -E "error:" ; then
    :
  fi
  if [ ! -x "$OUT/$name" ]; then
    echo "✗ $name non compila"
    FAILED=1
    return
  fi
  if "$OUT/$name"; then
    echo "✓ $name"
  else
    echo "✗ $name"
    FAILED=1
  fi
}

run_harness staircase   Tests/StaircaseHarness.swift    fast
run_harness punteggio   Tests/ScoringHarness.swift      slow
run_harness intelligenza Tests/IntelligenceHarness.swift slow

echo ""
if [ "$FAILED" -eq 0 ]; then
  echo "Tutto a posto."
else
  echo "Qualcosa non va: vedi sopra."
  exit 1
fi
