# NaMi

[![Watch](https://img.shields.io/github/watchers/JanneckLange/dpsg-nami-app?label=Watch)](https://github.com/JanneckLange/dpsg-nami-app/subscription)
[![wakatime](https://wakatime.com/badge/user/f75702c6-6ecd-478f-a765-9c0a07c62d50/project/c30b8bfa-fe60-4da1-9a32-9c86bad66605.svg)](https://wakatime.com/badge/user/f75702c6-6ecd-478f-a765-9c0a07c62d50/project/c30b8bfa-fe60-4da1-9a32-9c86bad66605)

**Master**
[![Release](https://img.shields.io/github/v/release/janneckLange/dpsg-nami-app?display_name=tag&include_prereleases)](https://github.com/JanneckLange/dpsg-nami-app/releases)
[![Commit](https://shields.io/github/last-commit/JanneckLange/dpsg-nami-app/master)](https://github.com/JanneckLange/dpsg-nami-app/commits/master)

**Develop**
[![Test](https://github.com/JanneckLange/dpsg-nami-app/actions/workflows/flutter-test.yml/badge.svg)](https://github.com/JanneckLange/dpsg-nami-app/actions/workflows/flutter-test.yml)
[![Commit](https://shields.io/github/last-commit/JanneckLange/dpsg-nami-app/develop)](https://github.com/JanneckLange/dpsg-nami-app/commits/develop)

Die NaMi ist die Namentliche Mitgliedermeldung des Pfadfinderverbandes DPSG (Deutsche Pfadfinderschaft Sankt Georg).

Dies ist ein Flutter Projekt um die NaMi als App für Android und iOS anzubieten.

## Lizenz

[![Lizenz](https://licensebuttons.net/l/by-nc-sa/4.0/88x31.png)](https://licensebuttons.net/l/by-nc-sa/4.0/88x31.png)

Dieses Werk ist lizenziert unter einer [Creative Commons Namensnennung - Nicht-kommerziell - Weitergabe unter gleichen Bedingungen 4.0 International Lizenz.](http://creativecommons.org/licenses/by-nc-sa/4.0/)

## Aktuelle Funktionen

- Mitglieder auflisten, sortien und filtern
- Deteils von Mitgliedern ansehen. Über Buttons anrufen, E-Mails schreiben und die Adresse auf der Karte anzeigen.
- Über Grafiken und auflistung den Tätigkeitsverlauf eines Mitglieds ansehen.
- Mitgliedsdaten sind offline verfügbar und können nach belieben syncronisiert werden
- Statistiken geben einen einblick die aktuelle Mitgliederanzahl

## Geplante Funktionen

- Mitglieder bearbeiten, 'löschen' und anlegen per Texterkennung
- Stufenwechsel durchführen
- Führungszeugniss Antragsunterlagen herrunterladen
- Umfangreiche Statistiken (mit historischen Daten)

## Versionen

### [0.0.3] - 06.10.2023 [![Test](https://img.shields.io/badge/release-v0.0.3-orange)](https://github.com/JanneckLange/dpsg-nami-app/releases/tag/v0.0.3)

- Add: Seite Stistiken hinzugefügt
  - Anzahl Mitgliedern/Leitende pro Stufe
  - Wer kann die Stufe wechseln
- Add: Seite Profil und Dashboard hinzugefügt
- Add Seite Einstellungen
  - Möglichkeit Daten zu syncronisieren
  - Möglichkeit Datum für Stufenwechsel zu ändern
- Add: Authentifizierung mit bio-metrischen Daten hinzugefügt
- Change: Als Server wird nun ein mockServer angesprochen
- Change: Mitgliedsliste hat einen neuen Filter bekommen
- Change: Mitglieddetails hat einen neuen Anstrich bekommen
  - Eine Karte wurde zu Mitgliedsdetails hinzugefügts
  - Statistiken zur Mitgliedschaft wurden hinzugefügt
  - Informationen zum Stufenwechsel wurden hinzugefügt
  - Tätigkeiten befinden sich nun auf einem eigenen Tab
- Fix: NaMi Login wird nur noch angefragt, wenn wirklich notwendig

### [0.0.2] - 09.12.2021 [![Test](https://img.shields.io/badge/release-v0.0.2-orange)](https://github.com/JanneckLange/dpsg-nami-app/releases/tag/v0.0.2)

- Changed: Offline Mode to Sync-Button
- Add: Update only new Versions of Members
- Add: Delete all data when logout
- Add: Member Details

### [0.0.1] - 07.12.2021

- Add: Login
- Add: Member List
- Add: Offline Mode
