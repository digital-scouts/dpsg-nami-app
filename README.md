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

- Mitglieder auflisten, sortieren und filtern
- Details von Mitgliedern ansehen. Adresse auf der Karte anzeigen. Über Buttons anrufen, E-Mails schreiben.
- Über Grafiken und Auflistung den Tätigkeitsverlauf eines Mitglieds ansehen.
- Mitgliedsdaten sind offline verfügbar und können nach belieben synchronisiert werden
- Statistiken geben einen Einblick die aktuelle Mitgliederanzahl, Altersstruktur und Stufenwechsel

## Geplante Funktionen

- Mitglieder bearbeiten und anlegen per Texterkennung
- Stufenwechsel durchführen
- Führungszeugniss Antragsunterlagen herrunterladen

## Versionen

### [0.0.4] - ??
- Add: Statistik Alterspyramide der Mitglieder hinzugefügt
- Add: Rechte des Nutzers werden geprüft / Funktionen entsprechend freigeschaltet
- Add: Mitgleider können per Formular bearbeitet und hinzugefügt werden
- Add: Stufenwechsel kann über den Tab Tätigkeiten eines Mitglieds durchgeführt werden
- Fix: Token wird aktuallisert, wenn dieser abgelaufen ist (Vorrausgesetzt, der Login wurde gespeichert)
- Fix: Der Nutzer abgemeldet, wenn er Token abgelaufen ist und Login nicht gespeichert wurde

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
  - Eine Karte wurde zu Mitgliedsdetails hinzugefügt
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

## Nami Rechte

Um die App und deren Funktion verwenden zu können sind bestimmte NaMi-Rechte Vorraussetzung.

### Vorraussetzung für die App
- 5: Personen - mitglied_READ, 
- 36: Organisation - gruppierung_READ, 
- 58: Personen - taetigkeitassignment_READ, 
- 118: Personen - mitglied_SHOW_TAB, 
- 139: Personen - taetigkeitassignment_SHOW_TAB, 
- 314: Mgl-Verwaltung - Rechte anzeigen, 

### Mitglied bearbeiten
- 4: Personen - mitglied_UPDATE,
- 57: Personen - taetigkeitassignment_UPDATE, 

### Stufenwechsel durchführen
- 57: Personen - taetigkeitassignment_UPDATE, 
- 59: Personen - taetigkeitassignment_CREATE, 

### Mitglied anlegen
-  6: Personen - mitglied_CREATE,
-  59: Personen - taetigkeitassignment_CREATE, 
-  313: Mgl-Verwaltung - Kontoverbindung anzeigen
-  316: Mgl-Verwaltung - Mgl. Beitragskonto

#### Mitglied verewaltung (Admin)
- 312: Mgl-Verwaltung - Mitgliedschaft beenden
- 315: Mgl-Verwaltung - Mgl. übernehmen
- 320: Mgl-Verwaltung - Mgl. Aktivieren
- 455: Mgl-Verwaltung - Gruppierung bearbeiten

### Führungszeugnis Unterlagen ansehen/herrunterladen
- 473: Mgl-Verwaltung - Eigene SGB VIII-Bescheinigungen ansehen, 
- 474: Mgl-Verwaltung - Eigene SGB VIII-Bescheinigungen herunterladen, 

