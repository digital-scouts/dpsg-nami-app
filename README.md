# NaMi


<a href="https://apps.apple.com/de/app/nami/id6468066816">
    <img src="./assets/workfiles/Download_on_the_App_Store_Badge_DE_RGB_blk_092917.svg" alt="Download für iOS" height="50">
</a>
<a href="https://play.google.com/store/apps/details?id=de.jlange.nami.app">
    <img src="./assets/workfiles/GetItOnGooglePlay_Badge_Web_color_German.png" alt="Download für Android" height="50" >
</a>

<br>

![wakatime](https://wakatime.com/badge/user/f75702c6-6ecd-478f-a765-9c0a07c62d50/project/c30b8bfa-fe60-4da1-9a32-9c86bad66605.svg)
[![Watch](https://img.shields.io/github/watchers/JanneckLange/dpsg-nami-app?label=Watch)](https://github.com/JanneckLange/dpsg-nami-app/subscription)

**Master**

[![Release](https://img.shields.io/github/v/release/janneckLange/dpsg-nami-app?display_name=tag&include_prereleases)](https://github.com/JanneckLange/dpsg-nami-app/releases)
[![Commit](https://shields.io/github/last-commit/JanneckLange/dpsg-nami-app/master)](https://github.com/JanneckLange/dpsg-nami-app/commits/master)

**Develop**

[![Test](https://github.com/JanneckLange/dpsg-nami-app/actions/workflows/flutter-test.yml/badge.svg)](https://github.com/JanneckLange/dpsg-nami-app/actions/workflows/flutter-test.yml)
[![Commit](https://shields.io/github/last-commit/JanneckLange/dpsg-nami-app/develop)](https://github.com/JanneckLange/dpsg-nami-app/commits/develop)

NaMi steht für die Namentliche Mitgliedermeldung der Deutschen Pfadfinderschaft Sankt Georg (DPSG). Diese App richtet sich speziell an Gruppenleiter:innen der DPSG und ermöglicht den mobilen, offline Zugriff auf Mitgliederdaten. Dank vielseitiger Sortier- und Filterfunktionen sowie grundlegender Bearbeitungsoptionen bietet die App eine unverzichtbare Unterstützung im Stammesalltag.

Diese App wird privat entwickelt und bereitgestellt. Sie steht in keinem Zusammenhang mit der DPSG und ist (wie alle privaten Projekte) weder von der DPSG autorisiert noch unterstützt. Alle Mitgliedsdaten werden auf eigene Verantwortung verwaltet und sind nicht Teil der offiziellen DPSG-Systeme.

Testversion der App laden: [Android](https://play.google.com/store/apps/details?id=de.jlange.nami.app) oder
[iOS](https://testflight.apple.com/join/YGeELMUq)

## Funktionsweise 

Die App verbindet sich direkt mit dem NaMi-Backend, sodass keine Mitgliedsdaten auf externen Servern gespeichert oder verarbeitet werden. 
Die Daten des ausgewählten Stammes werden lokal und verschlüsselt auf dem Gerät des Nutzers gespeichert. 

Die Daten werden tägliche automatisch im Hintergrund synchronisiert. Falls die Daten länger als 30 Tage nicht aktualisiert wurden, werden sie automatisch aus der App entfernt, um die Datensicherheit zu gewährleisten.

Hat ein Nutzer die Rechte mehrere Stämme zu sehen (zum Beispiel, weil er auch Aktiv in einem Diözesanarbeitskreis ist), dann muss **ein** Stamm ausgewählt werden. Es werden die Mitgliedes dieses Stammes angezeigt. 

## Aktuelle Funktionen

- Mitglieder und deren Details auflisten, sortieren und filtern
  - Adresse und Entfernung zum Stammesheim auf der Karte anzeigen.
  - Über Grafiken und Auflistung den Tätigkeitsverlauf eines Mitglieds ansehen.
  - Wie in den Kontakten E-Mails schreiben und einen Anruf starten
- Mitglieder und Tätigkeiten bearbeiten, erstellen und löschen/Mitgliedschaft beenden
- Mitgliedsdaten sind offline verfügbar und können nach belieben synchronisiert werden
- Statistiken geben einen Einblick in die aktuelle Mitgliederanzahl und Altersstruktur
- Empfehlung für den nächsten Stufenwechsel eines Mitglieds.
  - Die gewünschte Altersgrenzen der Stufen können angepasst werden.
  - Stufenwechsel durchführen
- Führungszeugniss Antragsunterlagen und Bescheinigungen herrunterladen
- Jeder Nutzer sieht auch nur die Funktionen, die er aufgrund seiner Rechte ausführen kann. Die Recht sind im eigenen Profil aufgelistet.
- Jeder Nutzer hat die Möglichkeit das Bearbeiten von Daten zu deaktiven und braucht so keine Angst haben 'Etwas kaput zu machen'

## Geplante Funktionen

- Mitglieder anlegen per Texterkennung / Foto vom Anmeldebogen
- Export von Zuschusslisten
- Erinnerungen und Kalenderintegration für
  - Geburtstage 
  - Ablaufende Ausbildungen (Präventionsschulung)
- Statistik historische Entwicklung im Stamm
  - Wann verlassen Mitglieder den Stamm, wann kommen sie
- Stammeskarte

## Externe Apis

- [Geoapify](https://www.geoapify.com): Autovervollständigung von Adressen beim anlegen eines Nutzers (Free Limit 3000 Requests / day)
- [openplzapi](https://www.openplzapi.org/de/): Fallback für Geoapify (Unlimited)
- [openiban](https://openiban.com): Validierung der IBAN beim anlegen eines Nutzers (Unlimited)

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

- 6: Personen - mitglied_CREATE,
- 59: Personen - taetigkeitassignment_CREATE,
- 313: Mgl-Verwaltung - Kontoverbindung anzeigen
- 316: Mgl-Verwaltung - Mgl. Beitragskonto

### Mitglied verewaltung (Admin)

- 312: Mgl-Verwaltung - Mitgliedschaft beenden
- 315: Mgl-Verwaltung - Mgl. übernehmen
- 320: Mgl-Verwaltung - Mgl. Aktivieren
- 455: Mgl-Verwaltung - Gruppierung bearbeiten

### Gruppierung verwalten (Admin)

- 578: Eingangsrechnungen Gruppierung
- 376: Rechnung lesen
- 378: Rechnung download
- 433: Rechnung download
- 591: Gruppierungsverwaltung
- 36: Gruppierung lesen

### Führungszeugnis Unterlagen ansehen/herrunterladen

- 473: Mgl-Verwaltung - Eigene SGB VIII-Bescheinigungen ansehen
- 474: Mgl-Verwaltung - Eigene SGB VIII-Bescheinigungen herunterladen
- Ein Recht die Antragsunterlagen zu erstellen ist nicht definiert (Möglicherweise nut für Beitragspflichtige Mitgliedschaften)
