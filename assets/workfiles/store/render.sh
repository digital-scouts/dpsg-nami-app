#!/usr/bin/env bash
# Exportiert alle Store-Grafiken in exakter Pixelgröße nach out/<sprache>/.
# Voraussetzung: Google Chrome; Rohscreens in raw/<sprache>/{iphone,duo,ipad}/
# (tool/store_screenshots/run_store_screenshots.sh --lang <sprache>).
#
# Nutzung: assets/workfiles/store/render.sh [navy|hell|stufen] [de|en|alle]
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
STYLE="${1:-navy}"
WAHL="${2:-alle}"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
OUT="$DIR/out"
# Szenen in Store-Reihenfolge; Dateinamen wie iphone-01-mitglieder.png.
SCENES=($(sed -n "s/^      scene: '\(.*\)',$/\1/p" "$DIR/content.js"))
SLIDES=${#SCENES[@]}

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
  printf '  %-40s %sx%s %s KB\n' "${4#"$OUT"/}" "$w" "$h" "$(( $(stat -f%z "$4") / 1024 ))"
}

case "$WAHL" in
  alle) LANGS=(de en) ;;
  de | en) LANGS=("$WAHL") ;;
  *) echo "Unbekannte Sprache: $WAHL (de, en oder alle)" >&2; exit 2 ;;
esac

rm -rf "$OUT"
echo "Stil: $STYLE"
for lang in "${LANGS[@]}"; do
  RAW="$DIR/raw/$lang"
  # Ohne iPhone- und iPad-Rohscreens fehlt die Grundlage fast aller Bilder.
  if ! compgen -G "$RAW/iphone/*.png" >/dev/null || ! compgen -G "$RAW/ipad/*.png" >/dev/null; then
    if [[ "$WAHL" == "alle" ]]; then
      echo "Hinweis: raw/$lang/iphone oder raw/$lang/ipad fehlt, Sprache $lang übersprungen."
      continue
    fi
    echo "FEHLER: raw/$lang/iphone oder raw/$lang/ipad fehlt." >&2
    exit 1
  fi
  # Duo-Rohscreens entstehen nur mit iOS-27.1-Simulator; ohne sie fehlt nur out/<lang>/duo/.
  DUO=0
  compgen -G "$RAW/duo/*.png" >/dev/null && DUO=1

  L="$OUT/$lang"
  mkdir -p "$L/play" "$L/playtablet" "$L/appstore" "$L/iphone" "$L/ipad"
  if ((DUO)); then mkdir -p "$L/duo"; fi
  echo "Sprache: $lang"
  q="style=$STYLE&lang=$lang"
  shoot "file://$DIR/feature-graphic.html?$q" 1024 500 "$L/play/feature-graphic.png"
  shoot "file://$DIR/appstore-header.html?$q" 3840 1646 "$L/appstore/header.png"
  shoot "file://$DIR/appstore-search.html?$q" 3840 2560 "$L/appstore/search.png"
  for ((i = 0; i < SLIDES; i++)); do
    n="$(printf '%02d' $((i + 1)))-${SCENES[i]}.png"
    shoot "file://$DIR/screenshot.html?target=play&slide=$i&$q" 1080 1920 "$L/play/play-$n"
    shoot "file://$DIR/screenshot.html?target=playtablet&slide=$i&$q" 1600 2560 "$L/playtablet/playtablet-$n"
    shoot "file://$DIR/screenshot.html?target=iphone&slide=$i&$q" 1206 2622 "$L/iphone/iphone-$n"
    if ((DUO)); then
      shoot "file://$DIR/screenshot.html?target=duo&slide=$i&$q" 2853 2007 "$L/duo/duo-$n"
    fi
    shoot "file://$DIR/screenshot.html?target=ipad&slide=$i&$q" 2064 2752 "$L/ipad/ipad-$n"
  done
  if ((!DUO)); then echo "Hinweis: raw/$lang/duo/ fehlt, iPhone-Duo-Screenshots übersprungen."; fi
done
