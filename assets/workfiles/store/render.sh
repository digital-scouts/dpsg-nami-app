#!/usr/bin/env bash
# Exportiert alle Store-Grafiken in exakter Pixelgröße nach out/.
# Voraussetzung: Google Chrome; Rohscreens in raw/{iphone,ipad}/
# (tool/store_screenshots/run_store_screenshots.sh).
#
# Nutzung: assets/workfiles/store/render.sh [navy|hell|stufen]
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
STYLE="${1:-navy}"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
OUT="$DIR/out"
SLIDES=$(grep -c "^      scene: '" "$DIR/content.js")

shoot() { # url breite hoehe ziel
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --allow-file-access-from-files --virtual-time-budget=4000 \
    --window-size="$2,$3" --screenshot="$4" "$1" >/dev/null 2>&1
  local w h
  w=$(sips -g pixelWidth "$4" | awk '/pixelWidth/ {print $2}')
  h=$(sips -g pixelHeight "$4" | awk '/pixelHeight/ {print $2}')
  [[ "$w" == "$2" && "$h" == "$3" ]] || { echo "FEHLER: $4 ist ${w}x${h}, erwartet $2x$3" >&2; exit 1; }
  # App Store lehnt PNGs mit Alpha-Kanal ab.
  sips -g hasAlpha "$4" | grep -q "hasAlpha: no" || { echo "FEHLER: $4 hat Alpha-Kanal" >&2; exit 1; }
  printf '  %-34s %sx%s %s KB\n' "${4#"$OUT"/}" "$w" "$h" "$(( $(stat -f%z "$4") / 1024 ))"
}

rm -rf "$OUT"
mkdir -p "$OUT/play" "$OUT/iphone" "$OUT/ipad"
echo "Stil: $STYLE"
shoot "file://$DIR/feature-graphic.html?style=$STYLE" 1024 500 "$OUT/play/feature-graphic.png"
for ((i = 0; i < SLIDES; i++)); do
  n=$((i + 1))
  shoot "file://$DIR/screenshot.html?target=play&slide=$i&style=$STYLE" 1080 1920 "$OUT/play/$n.png"
  shoot "file://$DIR/screenshot.html?target=iphone&slide=$i&style=$STYLE" 1320 2868 "$OUT/iphone/$n.png"
  shoot "file://$DIR/screenshot.html?target=ipad&slide=$i&style=$STYLE" 2064 2752 "$OUT/ipad/$n.png"
done
