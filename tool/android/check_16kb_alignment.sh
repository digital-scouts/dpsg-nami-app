#!/usr/bin/env bash
# Prueft, ob alle 64-Bit-Native-Libraries eines AAB/APK fuer 16-KB-Seiten
# ausgerichtet sind (Google-Play-Anforderung ab Android 15).
#
# Nutzung:
#   tool/android/check_16kb_alignment.sh build/app/outputs/bundle/release/app-release.aab
set -euo pipefail

ARCHIVE="${1:-}"
if [[ -z "$ARCHIVE" || ! -f "$ARCHIVE" ]]; then
  echo "Nutzung: $0 <app.aab|app.apk>" >&2
  exit 2
fi

OBJDUMP=""
for sdk in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "$HOME/Library/Android/sdk"; do
  [[ -n "$sdk" && -d "$sdk/ndk" ]] || continue
  candidate="$(ls "$sdk"/ndk/*/toolchains/llvm/prebuilt/*/bin/llvm-objdump 2>/dev/null | sort -V | tail -1 || true)"
  if [[ -n "$candidate" ]]; then
    OBJDUMP="$candidate"
    break
  fi
done
if [[ -z "$OBJDUMP" ]]; then
  OBJDUMP="$(command -v llvm-objdump || command -v objdump || true)"
fi
if [[ -z "$OBJDUMP" ]]; then
  echo "Weder llvm-objdump (NDK) noch objdump gefunden." >&2
  exit 2
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
# 16 KB betrifft nur 64-Bit-ABIs; armeabi-v7a/x86 werden ignoriert.
unzip -q -o "$ARCHIVE" '*lib/arm64-v8a/*.so' '*lib/x86_64/*.so' -d "$WORKDIR" 2>/dev/null || true

FAILED=0
CHECKED=0
while IFS= read -r so; do
  CHECKED=$((CHECKED + 1))
  # Kleinste Ausrichtung aller LOAD-Segmente, z. B. "2**14" -> 14.
  min_exp="$("$OBJDUMP" -p "$so" | awk '/LOAD/ { sub(/^2\*\*/, "", $NF); print $NF }' | sort -n | head -1)"
  name="${so#"$WORKDIR"/}"
  if [[ -z "$min_exp" || "$min_exp" -lt 14 ]]; then
    echo "FEHLER  $name: LOAD-Alignment 2**${min_exp:-?} (< 16 KB)"
    FAILED=1
  else
    echo "ok      $name: 2**$min_exp"
  fi
done < <(find "$WORKDIR" -name '*.so' | sort)

if [[ "$CHECKED" -eq 0 ]]; then
  echo "Keine 64-Bit-Native-Libraries in $ARCHIVE gefunden." >&2
  exit 1
fi
if [[ "$FAILED" -ne 0 ]]; then
  echo "Mindestens eine Library unterstuetzt keine 16-KB-Seiten." >&2
  exit 1
fi
echo "Alle $CHECKED 64-Bit-Libraries sind 16-KB-kompatibel."
