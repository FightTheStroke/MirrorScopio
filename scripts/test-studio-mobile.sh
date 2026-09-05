#!/bin/bash
# Le prove del percorso Studio, sul simulatore scelto da chi le lancia.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "$#" -ne 1 ]; then
  echo "Uso: bash scripts/test-studio-mobile.sh ID_SIMULATORE_IPHONE"
  echo "Gli identificatori si leggono con: xcrun simctl list devices available"
  exit 2
fi

./scripts/genera-progetto.sh
xcodebuild test \
  -project MirrorScopio.xcodeproj \
  -scheme MirrorScopioMobile \
  -destination "platform=iOS Simulator,id=$1" \
  -derivedDataPath .build/studio-mobile \
  -parallel-testing-enabled NO \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_ALLOWED=YES
