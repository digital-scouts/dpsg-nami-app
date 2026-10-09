#!/usr/bin/env bash
# Gleicht die Handbuch-Bilder unter docs/assets/img/screens/ und
# docs/assets/img/geraete/ mit ihren Verwendungen in docs/ ab:
# shots.html (name:Text), geraete.html (art:ordner/name:Text) und direkte Pfade.
# Meldet fehlende Dateien (Exit 1) und verwaiste Bilder (nur Hinweis).
#
# Nutzung: .claude/skills/doku-abgleich/bilder_pruefen.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT/docs"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

QUELLEN=(--include='*.md' --include='*.markdown' --include='*.html' --exclude-dir=_site --exclude=shots.html --exclude=geraete.html)

{
  # Includes: zwei Felder -> screens/<name>, drei Felder -> <ordner>/<name>
  { grep -rhoE 'items="[^"]+"' "${QUELLEN[@]}" . || true; } \
    | sed -E 's/^items="//; s/"$//' | tr '|' '\n' \
    | awk -F: '{ gsub(/ /, ""); if (NF >= 3) print $2; else if (NF == 2) print "screens/" $1 }'
  { grep -rhoE 'img/(screens|geraete)/[a-z0-9_]+' "${QUELLEN[@]}" . || true; } | sed 's#img/##'
  # docs/index.html: {%- assign screens = '/assets/img/screens/' -%} … {{ screens }}name.jpg
  { grep -rhoE '\{\{ *screens *\}\}[a-z0-9_]+' "${QUELLEN[@]}" . || true; } | sed -E 's/^\{\{ *screens *\}\}/screens\//'
} | grep -v '^$' | sort -u > "$TMP/verwendet"

for ordner in screens geraete; do
  [[ -d "assets/img/$ordner" ]] && ls "assets/img/$ordner" | sed -E "s/\.jpg$//; s#^#$ordner/#"
done | sort -u > "$TMP/vorhanden"

FEHLEND="$(comm -23 "$TMP/verwendet" "$TMP/vorhanden")"
VERWAIST="$(comm -13 "$TMP/verwendet" "$TMP/vorhanden")"

if [[ -n "$VERWAIST" ]]; then
  echo "Verwaiste Bilder (nirgends verwendet):"
  echo "$VERWAIST" | sed 's/^/  /'
fi
if [[ -n "$FEHLEND" ]]; then
  echo "Fehlende Bilder (verwendet, aber keine Datei):"
  echo "$FEHLEND" | sed 's/^/  /'
  exit 1
fi
echo "Alle verwendeten Handbuch-Bilder vorhanden ($(wc -l < "$TMP/verwendet" | tr -d ' ') Verweise)."
