#!/bin/sh

echo "Stage: PRE-Xcode Build is activated .... "

# Überprüfen, ob die Umgebungsvariablen gesetzt sind
if [ -z "$WIREDASH_SECRET" ]; then
    echo "Fehler: WIREDASH_SECRET ist nicht gesetzt."
    exit 1
fi
if [ -z "$WIREDASH_PROJECT_ID" ]; then
    echo "Fehler: WIREDASH_PROJECT_ID ist nicht gesetzt."
    exit 1
fi
# Überprüfen, ob die .env-Datei existiert
cd $CI_PRIMARY_REPOSITORY_PATH || exit 1
if [ ! -f .env ]; then
   exit 1
fi

# Schreiben der Umgebungsvariablen in die .env-Datei
echo "WIREDASH_SECRET=$WIREDASH_SECRET" > .env
echo "WIREDASH_PROJECT_ID=$WIREDASH_PROJECT_ID" >> .env
echo "WIREDASH_SECRET=$WIREDASH_SECRET | WIREDASH_PROJECT_ID=$WIREDASH_PROJECT_ID"

echo "Die Umgebungsvariablen wurden erfolgreich in die .env-Datei geschrieben."

echo "Stage: PRE-Xcode Build is DONE .... "

