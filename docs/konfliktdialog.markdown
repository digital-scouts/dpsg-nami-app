---
layout: page
title: Konfliktdialog und Problemlösungsfall
permalink: /konfliktdialog/
---

## Überblick

Diese Seite beschreibt das aktuelle Verhalten der App beim Bearbeiten und späteren Synchronisieren von Personenänderungen im Hitobito-Schreibpfad.

Ein Problemlösungsfall entsteht nur dann, wenn die App eine Änderung nicht sicher automatisch übernehmen kann.

## Was die App heute macht

Die App vergleicht beim Senden einer Personenänderung immer drei Stände:

- den Basisstand, mit dem die Bearbeitung begonnen wurde
- den lokalen Bearbeitungsstand
- den aktuellen Serverstand aus Hitobito

Unabhängige Änderungen werden automatisch zusammengeführt. Ein Problemlösungsfall entsteht nur dann, wenn dieselbe Änderungseinheit lokal und auf dem Server unterschiedlich geändert wurde oder wenn ein späterer Retry einen nicht direkt im Formular lösbaren Validierungsfehler meldet.

Wenn keine Meldung erscheint, wurde die Änderung konfliktfrei gesendet oder automatisch zusammengeführt.

## Änderungseinheiten

Die App behandelt einen Versionsunterschied nicht pauschal als globalen Konflikt, sondern pro Änderungseinheit.

Aktuell werden folgende Änderungseinheiten verglichen:

- Vorname
- Nachname
- Fahrtenname
- Geschlecht
- Geburtsdatum
- primäre E-Mail
- jede Telefonnummer über ihre `phoneNumberId`
- jede Zusatzmail über ihre `additionalEmailId`
- die primäre Adresse als ein zusammenhängender Block
- jede Zusatzadresse als ein zusammenhängender Block über ihre `additionalAddressId`

## Automatisches Zusammenführen

Für jede Änderungseinheit gilt:

1. Wenn nur lokal geändert wurde, wird die lokale Änderung übernommen.
2. Wenn nur auf dem Server geändert wurde, wird der Serverstand übernommen.
3. Wenn beide Seiten dieselbe Änderung vorgenommen haben, wird sie automatisch übernommen.
4. Wenn beide Seiten unterschiedliche Änderungseinheiten geändert haben, wird automatisch zusammengeführt.
5. Nur wenn dieselbe Änderungseinheit unterschiedlich geändert wurde, entsteht ein Problemlösungsfall.

Beispiel:

- Auf dem Server wurde eine Telefonnummer geändert.
- Lokal wurde nur die primäre E-Mail geändert.

Das ist kein Konflikt, obwohl sich `updatedAt` geändert hat. Beide Änderungen werden automatisch zusammengeführt.

## Wann ein Problemlösungsfall entsteht

Ein Problemlösungsfall wird pro Mitglied gespeichert.

Aktuell sind zwei Arten von Fällen angeschlossen:

- dieselbe Änderungseinheit wurde lokal und auf dem Server unterschiedlich geändert
- ein späterer Retry meldet einen Validierungsfehler, der nicht mehr direkt im normalen Bearbeiten-Screen aufgelöst wird

Direkt zuordenbare Validierungsfehler bei einem manuellen Online-Speichern, zum Beispiel eine ungültige Telefonnummer, bleiben weiterhin im normalen Bearbeiten-Screen.

Die separate Adressvalidierung für den Offline- oder späteren Sync-Pfad ist fachlich vorgesehen, aber noch nicht an diesen Ablauf angeschlossen.

## Wo offene Fälle sichtbar sind

Offene Problemlösungsfälle bleiben sichtbar, bis sie erfolgreich gesendet wurden.

Aktuelle Einstiege sind:

- Einstellungen mit einer Hinweis-Karte für den ersten offenen Fall
- Mitglieddetails des betroffenen Mitglieds
- Mitgliederliste über Warnsymbol und globale Snackbar für offene Fälle

Jeder Einstieg öffnet immer genau einen Fall für genau ein Mitglied.

## Wie der Screen aussieht

Der Problemlösungs-Screen verwendet denselben Bearbeiten-Screen wie die normale Personenbearbeitung, startet aber mit einem eigenen Fokus auf das Speichern des betroffenen Mitglieds.

Im Kopf des Screens zeigt die App einen Titel mit Bezug auf das Mitglied und eine kurze Handlungsaufforderung.

Im Abschnitt Speicherprobleme zeigt die App pro betroffenem Eintrag:

- die betroffene Änderungseinheit
- die Problembeschreibung
- bei Konflikten einen Vergleich Lokal und Server nebeneinander
- bei Retry-Validierungen einen Vergleich Aktuell und Vorheriger Stand nebeneinander

Telefonnummern und Zusatzmails werden dabei mit Bezeichnung und Wert angezeigt.

Adressen werden nicht als ein einziger String gezeigt, sondern mit ihren einzelnen Feldern untereinander, zum Beispiel Bezeichnung, c/o, Straße, Hausnummer, PLZ, Ort und Land.

Der normale Bearbeiten-Bereich bleibt im selben Screen verfügbar, ist beim Einstieg in den Problemlösungsfall aber zunächst eingeklappt.

Wenn der Nutzer bei einem Problemfeld Bearbeiten wählt, klappt die App den Bearbeiten-Bereich auf und setzt den Fokus auf das passende Eingabefeld. Für Adressprobleme gilt dabei eine Standardregel und der Fokus landet auf dem Straßenfeld der betroffenen Adresse.

Direkt bearbeitbar sind heute:

- Name
- Geschlecht
- Geburtsdatum
- primäre E-Mail
- Zusatzmails
- Telefonnummern
- primäre Adresse
- Zusatzadressen

Adressen werden dabei als Blöcke behandelt.

## Entscheidungen im Problemlösungsfall

Je nach Problemtyp stehen unterschiedliche Aktionen zur Verfügung.

Bei echten Konflikten:

- lokalen Stand behalten
- Serverstand übernehmen

Bei späteren Validierungsproblemen:

- lokalen Wert bearbeiten
- lokale Änderung verwerfen

Anschließend sendet die App den verbleibenden Stand für dieses Mitglied erneut.

## Verhalten bei manuellem Speichern und späterem Retry

Beim manuellen Speichern:

- direkt zuordenbare Validierungsfehler bleiben im Bearbeiten-Screen
- echte Konflikte öffnen den Problemlösungs-Screen direkt

Beim späteren Retry aus der lokalen Queue, egal ob manuell oder automatisch während aktiver App-Nutzung:

- wird bei Erfolg der Queue-Eintrag entfernt
- bleibt ein technischer Fehler bestehen, bleibt der Queue-Eintrag erhalten
- wird ein Konflikt oder Retry-Validierungsfehler erkannt, wechselt der Eintrag in den Problemlösungsfall

Die Mitgliederliste zeigt zusätzlich eine einmalige Snackbar, wenn offene Problemlösungsfälle vorhanden sind.

## Abbruch und erneutes Öffnen

- Wird der Screen geschlossen, bleibt der Fall offen.
- Bereits getroffene Teilentscheidungen werden nicht separat gespeichert.
- Beim späteren erneuten Öffnen startet die Bearbeitung dieses Mitglieds erneut auf Basis des aktuell gespeicherten Falls.

## Tracking und Logs

Wenn Analytics aktiviert sind, erfasst die App zusätzlich Wiredash-Ereignisse für:

- das Entstehen eines Problemlösungsfalls
- das Öffnen aus Liste, Details oder Einstellungen
- Entscheidungen innerhalb des Screens
- den erneuten Sendeversuch und dessen Ergebnis

Die vollständige Eventliste steht unter [Wiredash und Tracking](../wiredash/).

## Aktuelle Grenzen

- Der Screen zeigt zusätzlich zum Abschnitt Offene Probleme weiterhin auch die normalen Bearbeitungsbereiche.
- Neue lokale Kontaktobjekte ohne Server-ID werden nicht als eigener Problemtyp ausgewiesen.
- Die separate Adressvalidierung für Offline- und spätere Sync-Fälle ist noch nicht angebunden.

## Fachliche Zuständigkeit im Code

Die App trennt technisch zwischen Übertragung, Merge und Nutzerentscheidung:

- Der API-Client meldet Daten, Validierungsfehler und Versionsabweichungen.
- Repository und Model bauen daraus automatische Merges oder Problemlösungsfälle.
- Der Screen arbeitet mit dem gespeicherten Fall pro Mitglied und sendet danach erneut.

Dadurch bleiben unabhängig geänderte Daten erhalten, während nicht sicher auflösbare Änderungen sichtbar und nachvollziehbar bleiben.
