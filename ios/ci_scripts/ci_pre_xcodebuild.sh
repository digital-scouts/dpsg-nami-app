#!/bin/sh

set -eu

echo "Stage: PRE-Xcode Build is activated .... "

require_env() {
    key="$1"
    value="$(printenv "$key" || true)"
    if [ -z "$value" ]; then
        echo "Fehler: $key ist nicht gesetzt."
        exit 1
    fi
}

write_env() {
    key="$1"
    value="$(printenv "$key" || true)"
    printf '%s=%s\n' "$key" "$value" >> .env
}

require_env "CI_PRIMARY_REPOSITORY_PATH"
require_env "WIREDASH_SECRET"
require_env "WIREDASH_PROJECT_ID"
require_env "GEOAPIFY_KEY"

cd "$CI_PRIMARY_REPOSITORY_PATH" || exit 1

: > .env

write_env "WIREDASH_SECRET"
write_env "WIREDASH_PROJECT_ID"
write_env "GEOAPIFY_KEY"
write_env "PULL_NOTIFICATIONS_URL"
write_env "PULL_NOTIFICATIONS_MIN_FETCH_INTERVAL_HOURS"
write_env "APP_UPDATE_URL"
write_env "APP_UPDATE_MIN_FETCH_INTERVAL_HOURS"
write_env "APP_UPDATE_FETCH_TIMEOUT_SECONDS"
write_env "OPEN_AI_KEY"
write_env "APPSTORE_ID"

echo "Die .env-Datei wurde fuer Xcode Cloud aktualisiert."
echo "Geschriebene Keys: WIREDASH_SECRET, WIREDASH_PROJECT_ID, GEOAPIFY_KEY, PULL_NOTIFICATIONS_URL, PULL_NOTIFICATIONS_MIN_FETCH_INTERVAL_HOURS, APP_UPDATE_URL, APP_UPDATE_MIN_FETCH_INTERVAL_HOURS, APP_UPDATE_FETCH_TIMEOUT_SECONDS, OPEN_AI_KEY, APPSTORE_ID"
echo "Stage: PRE-Xcode Build is DONE .... "

