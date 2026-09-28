#!/usr/bin/env bash
# Installiert ein Release-AAB so, wie Google Play es ausliefert (bundletool,
# Debug-Keystore), startet die App und prueft, dass sie nicht abstuerzt.
# Faengt Fehler ab, die nur im Release-Build auftreten (R8/minify, Packaging).
#
# Nutzung:
#   BUNDLETOOL_JAR=/pfad/bundletool.jar \
#     tool/android/smoke_start_release.sh --aab app-release.aab --device emulator-5554
set -euo pipefail

APP_ID="de.jlange.nami.app"
STARTUP_SECONDS=20

AAB=""
DEVICE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --aab) AAB="$2"; shift 2 ;;
    --device) DEVICE="$2"; shift 2 ;;
    *) echo "Unbekanntes Argument: $1" >&2; exit 2 ;;
  esac
done
if [[ -z "$AAB" || ! -f "$AAB" || -z "$DEVICE" || ! -f "${BUNDLETOOL_JAR:-}" ]]; then
  echo "Nutzung: BUNDLETOOL_JAR=<jar> $0 --aab <app.aab> --device <id>" >&2
  exit 2
fi

KEYSTORE="$HOME/.android/debug.keystore"
if [[ ! -f "$KEYSTORE" ]]; then
  mkdir -p "$(dirname "$KEYSTORE")"
  keytool -genkeypair -keystore "$KEYSTORE" -storepass android -keypass android \
    -alias androiddebugkey -dname "CN=Android Debug,O=Android,C=US" \
    -keyalg RSA -keysize 2048 -validity 10000 >/dev/null
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
ADB="$(command -v adb)"

echo "==> Geraete-APKs aus $AAB erzeugen"
java -jar "$BUNDLETOOL_JAR" build-apks \
  --bundle "$AAB" --output "$WORKDIR/app.apks" \
  --connected-device --device-id "$DEVICE" --adb "$ADB" \
  --ks "$KEYSTORE" --ks-pass pass:android \
  --ks-key-alias androiddebugkey --key-pass pass:android

echo "==> Frisch installieren und starten"
adb -s "$DEVICE" uninstall "$APP_ID" >/dev/null 2>&1 || true
java -jar "$BUNDLETOOL_JAR" install-apks --apks "$WORKDIR/app.apks" \
  --device-id "$DEVICE" --adb "$ADB"
adb -s "$DEVICE" logcat -c
adb -s "$DEVICE" shell monkey -p "$APP_ID" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep "$STARTUP_SECONDS"

PID="$(adb -s "$DEVICE" shell pidof "$APP_ID" | tr -d '\r' || true)"
CRASH="$(adb -s "$DEVICE" logcat -d -b crash 2>/dev/null || true)"
if [[ -z "$PID" || "$CRASH" == *"$APP_ID"* ]]; then
  echo "Release-Build laeuft nach ${STARTUP_SECONDS}s nicht mehr." >&2
  echo "$CRASH" >&2
  adb -s "$DEVICE" logcat -d -s flutter AndroidRuntime | tail -50 >&2
  exit 1
fi
echo "Release-Build laeuft (pid $PID)."
