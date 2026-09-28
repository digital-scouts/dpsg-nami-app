#!/usr/bin/env bash
# Macht einen git worktree von v0.2.8 baubar.
set -euo pipefail

WORKTREE="$1"

# 0.2.8 referenziert .gitlink (Symlink auf .git) als Asset. In einem worktree
# ist .git eine Datei, daher wird ein Platzhalter angelegt.
rm -rf "$WORKTREE/.gitlink"
mkdir -p "$WORKTREE/.gitlink/refs/heads"
echo "legacy-fixture" >"$WORKTREE/.gitlink/refs/heads/legacy-fixture"
echo "ref: refs/heads/legacy-fixture" >"$WORKTREE/.gitlink/HEAD"

# Die App liest .env als Asset; Werte werden fuer den Seed nicht benoetigt.
touch "$WORKTREE/.env"

# 0.2.8 baut mit -Xmx1536M; der Jetifier laeuft damit (z. B. in CI) in
# "Java heap space". Nur Build-Umgebung, der App-Code bleibt unveraendert.
GRADLE_PROPERTIES="$WORKTREE/android/gradle.properties"
if [[ -f "$GRADLE_PROPERTIES" ]]; then
  sed -i.bak 's/^org\.gradle\.jvmargs=.*/org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=1G/' "$GRADLE_PROPERTIES"
  rm -f "$GRADLE_PROPERTIES.bak"
fi
