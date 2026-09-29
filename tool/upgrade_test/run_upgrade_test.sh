#!/usr/bin/env bash
# Geraete-Upgrade-Test letzte Release-Version -> aktueller Stand.
#
# Quellversion ist LEGACY_REF (Default: neuester Tag vX.Y.Z unterhalb der
# pubspec-Version, z. B. v0.2.8). Pro Quellversion werden erwartet:
#   tool/legacy_fixture/vX_Y_Z/{legacy_seed.dart,main_seed.dart}
#   integration_test/upgrade_from_X_Y_Z_test.dart
#
# 1. Baut aus LEGACY_REF eine Seed-App (echter alter Code, Fake-Daten, geplante
#    Geburtstagsbenachrichtigungen) und installiert sie frisch.
# 2. Startet sie und wartet, bis der Seed fertig ist.
# 3. Installiert die aktuelle App darueber (Daten bleiben erhalten) und fuehrt
#    den passenden Integrationstest aus.
#
# Nutzung:
#   tool/upgrade_test/run_upgrade_test.sh --platform android --device emulator-5554
#   tool/upgrade_test/run_upgrade_test.sh --platform ios --device <simulator-udid>
#   LEGACY_REF=v0.2.8 tool/upgrade_test/run_upgrade_test.sh ...
set -euo pipefail

APP_ID="de.jlange.nami.app"
SEED_TIMEOUT_SECONDS=180
STATUS_FILE="legacy_seed_status.txt"

PLATFORM=""
DEVICE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform) PLATFORM="$2"; shift 2 ;;
    --device) DEVICE="$2"; shift 2 ;;
    *) echo "Unbekanntes Argument: $1" >&2; exit 2 ;;
  esac
done
if [[ "$PLATFORM" != "android" && "$PLATFORM" != "ios" ]] || [[ -z "$DEVICE" ]]; then
  echo "Nutzung: $0 --platform android|ios --device <id>" >&2
  exit 2
fi

if [[ "$PLATFORM" == "android" ]] && ! command -v adb >/dev/null 2>&1; then
  # adb liegt nach einer Android-Studio-Installation oft nicht im PATH.
  for sdk in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "$HOME/Library/Android/sdk"; do
    if [[ -n "$sdk" && -x "$sdk/platform-tools/adb" ]]; then
      export PATH="$sdk/platform-tools:$PATH"
      break
    fi
  done
  if ! command -v adb >/dev/null 2>&1; then
    echo "adb nicht gefunden. ANDROID_HOME setzen oder platform-tools in den PATH aufnehmen." >&2
    exit 2
  fi
fi

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

if [[ -z "${LEGACY_REF:-}" ]]; then
  CURRENT_VERSION="$(awk '/^version:/{print $2}' "$REPO_ROOT/pubspec.yaml")"
  CURRENT_VERSION="${CURRENT_VERSION%%+*}"
  LEGACY_REF="$(
    git -C "$REPO_ROOT" tag --list 'v[0-9]*.[0-9]*.[0-9]*' |
      awk -v current="$CURRENT_VERSION" '
        function key(v, parts) { sub(/^v/, "", v); split(v, parts, "."); return sprintf("%06d%06d%06d", parts[1], parts[2], parts[3]) }
        key($0) < key(current) && key($0) > best { best = key($0); ref = $0 }
        END { print ref }'
  )"
  if [[ -z "$LEGACY_REF" ]]; then
    echo "Kein Release-Tag unterhalb von $CURRENT_VERSION gefunden (git fetch --tags?)." >&2
    exit 2
  fi
fi
LEGACY_ID="${LEGACY_REF#v}"
LEGACY_ID="${LEGACY_ID//./_}"
SEED_DIR="$REPO_ROOT/tool/legacy_fixture/v${LEGACY_ID}"
UPGRADE_TEST="integration_test/upgrade_from_${LEGACY_ID}_test.dart"
SEED_TARGET="lib/main_seed_${LEGACY_ID}.dart"
if [[ ! -f "$SEED_DIR/legacy_seed.dart" || ! -f "$SEED_DIR/main_seed.dart" || ! -f "$REPO_ROOT/$UPGRADE_TEST" ]]; then
  echo "Fuer $LEGACY_REF fehlt der Upgrade-Test: erwartet ${SEED_DIR#"$REPO_ROOT"/}/{legacy_seed,main_seed}.dart" >&2
  echo "und $UPGRADE_TEST. Nach einem Release Seed und Test fuer die neue Quellversion anlegen." >&2
  exit 2
fi
echo "==> Upgrade-Test $LEGACY_REF -> aktueller Stand"

# Die App startet ohne Wiredash-Konfiguration nicht (main.dart wirft).
for key in WIREDASH_PROJECT_ID WIREDASH_SECRET; do
  if ! grep -Eq "^${key}=.+" "$REPO_ROOT/.env" 2>/dev/null; then
    echo "$key fehlt in .env (Dummy-Werte reichen fuer den Upgrade-Test)." >&2
    exit 2
  fi
done
WORKTREE="$(mktemp -d)/nami-legacy-${LEGACY_REF}"

cleanup() {
  git -C "$REPO_ROOT" worktree remove --force "$WORKTREE" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "==> Worktree $LEGACY_REF anlegen"
git -C "$REPO_ROOT" worktree add --detach "$WORKTREE" "$LEGACY_REF" >/dev/null
"$REPO_ROOT/tool/legacy_fixture/prepare_legacy_worktree.sh" "$WORKTREE"
cp "$SEED_DIR/legacy_seed.dart" "$WORKTREE/lib/legacy_seed.dart"
cp "$SEED_DIR/main_seed.dart" "$WORKTREE/$SEED_TARGET"

read_status_android() {
  adb -s "$DEVICE" shell run-as "$APP_ID" cat "app_flutter/$STATUS_FILE" 2>/dev/null || true
}

read_status_ios() {
  local container
  container="$(xcrun simctl get_app_container "$DEVICE" "$APP_ID" data 2>/dev/null || true)"
  [[ -n "$container" ]] && cat "$container/Documents/$STATUS_FILE" 2>/dev/null || true
}

echo "==> Seed-App ($LEGACY_REF) bauen und frisch installieren"
(
  cd "$WORKTREE"
  flutter pub get >/dev/null
  if [[ "$PLATFORM" == "android" ]]; then
    flutter build apk --debug -t "$SEED_TARGET"
  else
    flutter build ios --simulator --debug -t "$SEED_TARGET"
  fi
)

if [[ "$PLATFORM" == "android" ]]; then
  adb -s "$DEVICE" uninstall "$APP_ID" >/dev/null 2>&1 || true
  adb -s "$DEVICE" install "$WORKTREE/build/app/outputs/flutter-apk/app-debug.apk"
  adb -s "$DEVICE" shell pm grant "$APP_ID" android.permission.POST_NOTIFICATIONS >/dev/null 2>&1 || true
  adb -s "$DEVICE" shell monkey -p "$APP_ID" -c android.intent.category.LAUNCHER 1 >/dev/null
else
  xcrun simctl uninstall "$DEVICE" "$APP_ID" >/dev/null 2>&1 || true
  xcrun simctl install "$DEVICE" "$WORKTREE/build/ios/iphonesimulator/Runner.app"
  xcrun simctl launch "$DEVICE" "$APP_ID" >/dev/null
fi

echo "==> Auf Seed warten"
STATUS=""
for ((i = 0; i < SEED_TIMEOUT_SECONDS; i++)); do
  STATUS="$(read_status_"$PLATFORM")"
  [[ -n "$STATUS" ]] && break
  sleep 1
done
if [[ "$STATUS" != NAMI_LEGACY_SEED_DONE* ]]; then
  echo "Seed fehlgeschlagen oder Timeout: ${STATUS:-<kein Status>}" >&2
  exit 1
fi
echo "$STATUS"

if [[ "$PLATFORM" == "android" ]]; then
  adb -s "$DEVICE" shell run-as "$APP_ID" rm "app_flutter/$STATUS_FILE"
  adb -s "$DEVICE" shell am force-stop "$APP_ID"
else
  rm "$(xcrun simctl get_app_container "$DEVICE" "$APP_ID" data)/Documents/$STATUS_FILE"
  xcrun simctl terminate "$DEVICE" "$APP_ID" >/dev/null 2>&1 || true
fi

echo "==> Aktuelle App darueber installieren und Upgrade-Test ausfuehren"
cd "$REPO_ROOT"
flutter test "$UPGRADE_TEST" -d "$DEVICE"
