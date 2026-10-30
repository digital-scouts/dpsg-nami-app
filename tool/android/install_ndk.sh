#!/usr/bin/env bash
# Installiert das Android-NDK, das Flutter fuer App-Projekte vorgibt, vor dem
# Gradle-Build. Gradle laedt ein fehlendes NDK sonst mitten im Build einmalig
# herunter; ein abgebrochener Download ("Archive is not a ZIP archive") laesst
# dann den ganzen Build scheitern. Hier wird der Download wiederholt.
#
# Nutzung (nach subosito/flutter-action, ANDROID_HOME gesetzt):
#   tool/android/install_ndk.sh            # Version aus dem Flutter-SDK
#   tool/android/install_ndk.sh 28.2.13676358
set -euo pipefail

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [[ -z "$SDK" || ! -d "$SDK" ]]; then
  echo "ANDROID_HOME ist nicht gesetzt." >&2
  exit 2
fi

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  FLUTTER_SDK="${FLUTTER_ROOT:-$(dirname "$(dirname "$(command -v flutter)")")}"
  EXTENSION="$FLUTTER_SDK/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt"
  VERSION="$(grep -oE 'val ndkVersion: String = "[0-9.]+"' "$EXTENSION" | grep -oE '[0-9]+(\.[0-9]+)+' || true)"
fi
if [[ -z "$VERSION" ]]; then
  echo "NDK-Version nicht ermittelbar; bitte als Argument angeben." >&2
  exit 2
fi

ZIEL="$SDK/ndk/$VERSION"
if [[ -f "$ZIEL/source.properties" ]]; then
  echo "NDK $VERSION ist bereits installiert."
  exit 0
fi

SDKMANAGER="$SDK/cmdline-tools/latest/bin/sdkmanager"
[[ -x "$SDKMANAGER" ]] || SDKMANAGER="$(command -v sdkmanager || true)"
if [[ -z "$SDKMANAGER" ]]; then
  echo "sdkmanager nicht gefunden." >&2
  exit 2
fi

# Lizenzen vorab bestaetigen. `yes` endet hier mit SIGPIPE, sobald
# sdkmanager fertig ist; mit pipefail darf das nicht als Fehler zaehlen.
yes 2>/dev/null | "$SDKMANAGER" --sdk_root="$SDK" --licenses >/dev/null || true

for versuch in 1 2 3; do
  echo "Installiere NDK $VERSION (Versuch $versuch) ..."
  # Massgeblich ist, ob das NDK danach vollstaendig da ist, nicht der
  # Exit-Code von sdkmanager.
  "$SDKMANAGER" --sdk_root="$SDK" --install "ndk;$VERSION" </dev/null >/dev/null || true
  if [[ -f "$ZIEL/source.properties" ]]; then
    echo "NDK $VERSION installiert."
    exit 0
  fi
  # Halbe Entpackungen raeumen, sonst haelt sdkmanager sie fuer installiert.
  rm -rf "$ZIEL"
  df -h "$SDK" || true
  sleep $((versuch * 15))
done

echo "NDK $VERSION liess sich nicht installieren." >&2
exit 1
