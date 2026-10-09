#!/usr/bin/env bash
# Erzeugt Rohscreens der Storybook-Szenen im iOS-Simulator.
#
# Nutzung:
#   tool/store_screenshots/run_store_screenshots.sh --device <simulator-udid> --name iphone
#   tool/store_screenshots/run_store_screenshots.sh --device <simulator-udid> --name duo
#   tool/store_screenshots/run_store_screenshots.sh --device <simulator-udid> --name ipad
#   tool/store_screenshots/run_store_screenshots.sh --set docs --device <simulator-udid>
#   tool/store_screenshots/run_store_screenshots.sh --set review --device <simulator-udid>
#
# --set store (Standard): Szenen "Store/..." nach assets/workfiles/store/raw/<name>/.
# --set docs: Szenen "Store/..." und "Docs/..." fuer das Nutzerhandbuch, auf
# 600 px Breite verkleinert als JPEG nach docs/assets/img/screens/.
# --set review: Szenen "Review/..." (Kaufseite und Paket-Sheets auf Englisch)
# fuer die Pruefinformationen der In-App-Kaeufe nach
# assets/workfiles/store/review/.
#
# Empfohlene Simulatoren: iPhone 17 Pro (6,3", 1206x2622), iPhone Duo
# aufgeklappt (iOS 27.1, 2853x2007; mit iOS-27.1-SDK bauen, sonst
# Kompatibilitaetsmodus mit 2613x2007) und iPad Pro 13-inch
# (2064x2752); fuer docs immer ein iPhone. Die App wird dabei
# auf dem Simulator installiert und danach von `flutter test` wieder entfernt;
# die PNGs schreibt der Test direkt in den Zielordner (nur im Simulator
# moeglich).
set -euo pipefail

DEVICE=""
NAME=""
SET="store"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --device) DEVICE="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    --set) SET="$2"; shift 2 ;;
    *) echo "Unbekanntes Argument: $1" >&2; exit 2 ;;
  esac
done
if [[ -z "$DEVICE" || ( "$SET" == "store" && -z "$NAME" ) || ( "$SET" != "store" && "$SET" != "docs" && "$SET" != "review" ) ]]; then
  echo "Nutzung: $0 [--set store|docs|review] --device <simulator-udid> [--name <zielordner>]" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ "$SET" == "docs" ]]; then
  OUT_DIR="$ROOT/build/docs_screenshots"
elif [[ "$SET" == "review" ]]; then
  OUT_DIR="$ROOT/assets/workfiles/store/review"
else
  OUT_DIR="$ROOT/assets/workfiles/store/raw/$NAME"
fi

cd "$ROOT"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl ui "$DEVICE" appearance light

mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR"/*.png
flutter test integration_test/store_screenshots_test.dart -d "$DEVICE" \
  --dart-define=STORE_SCREENSHOT_DIR="$OUT_DIR" \
  --dart-define=STORE_SCREENSHOT_SET="$SET"

if [[ "$SET" == "docs" ]]; then
  DOCS_DIR="$ROOT/docs/assets/img/screens"
  mkdir -p "$DOCS_DIR"
  rm -f "$DOCS_DIR"/*.jpg
  for f in "$OUT_DIR"/*.png; do
    sips -s format jpeg -s formatOptions 82 --resampleWidth 600 "$f" \
      --out "$DOCS_DIR/$(basename "$f" .png).jpg" >/dev/null
  done
  echo "Handbuch-Screens in $DOCS_DIR:"
  for f in "$DOCS_DIR"/*.jpg; do
    echo "  $(basename "$f") $(( $(stat -f%z "$f") / 1024 )) KB"
  done
  exit 0
fi

echo "Rohscreens in $OUT_DIR:"
for f in "$OUT_DIR"/*.png; do
  echo "  $(basename "$f") $(sips -g pixelWidth -g pixelHeight "$f" | awk '/pixel/ {printf "%s ", $2}')"
done
