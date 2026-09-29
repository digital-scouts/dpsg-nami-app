#!/usr/bin/env bash
# Erzeugt Rohscreens der Storybook-Szenen "Store/..." im iOS-Simulator und
# kopiert sie nach assets/workfiles/store/raw/<name>/.
#
# Nutzung:
#   tool/store_screenshots/run_store_screenshots.sh --device <simulator-udid> --name iphone
#   tool/store_screenshots/run_store_screenshots.sh --device <simulator-udid> --name ipad
#
# Empfohlene Simulatoren: iPhone Pro Max (6,9", 1320x2868) und
# iPad Pro 13-inch (2064x2752). Die App wird dabei auf dem Simulator
# installiert und danach von `flutter test` wieder entfernt; die PNGs schreibt
# der Test direkt in den Zielordner (nur im Simulator moeglich).
set -euo pipefail

DEVICE=""
NAME=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --device) DEVICE="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    *) echo "Unbekanntes Argument: $1" >&2; exit 2 ;;
  esac
done
if [[ -z "$DEVICE" || -z "$NAME" ]]; then
  echo "Nutzung: $0 --device <simulator-udid> --name <zielordner>" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT_DIR="$ROOT/assets/workfiles/store/raw/$NAME"

cd "$ROOT"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl ui "$DEVICE" appearance light

mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR"/*.png
flutter test integration_test/store_screenshots_test.dart -d "$DEVICE" \
  --dart-define=STORE_SCREENSHOT_DIR="$OUT_DIR"
echo "Rohscreens in $OUT_DIR:"
for f in "$OUT_DIR"/*.png; do
  echo "  $(basename "$f") $(sips -g pixelWidth -g pixelHeight "$f" | awk '/pixel/ {printf "%s ", $2}')"
done
