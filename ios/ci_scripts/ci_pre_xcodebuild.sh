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
require_env "HITOBITO_BASE_URL"
require_env "HITOBITO_OAUTH_CLIENT_ID"
require_env "HITOBITO_OAUTH_CLIENT_SECRET"
require_env "HITOBITO_OAUTH_REDIRECT_URI"

cd "$CI_PRIMARY_REPOSITORY_PATH" || exit 1

: > .env

awk -F= '/^[A-Z][A-Z0-9_]*=/{print $1}' .env.example | while read -r key; do
    write_env "$key"
done

echo "Die .env-Datei wurde fuer Xcode Cloud aktualisiert."
echo "Geschriebene Keys entsprechen .env.example."
echo "Stage: PRE-Xcode Build is DONE .... "

