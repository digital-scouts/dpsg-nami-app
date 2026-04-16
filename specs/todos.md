# Todos

Liste an problemen, die noch behoben werden müssen.

## Fehler

Umsetzungsreihenfolge:

1. Fehler 9, 10 und 11
2. Fehler 5 und 6
3. Fehler 12 und 13
4. Fehler 7
5. Fehler 8

### Prüfen: 3 Konfliktdialog und Problemlösungsfall

Die nächste Ausbaustufe für Personenänderungen ersetzt den pauschalen Konflikt auf Basis von `updatedAt` durch einen feld- und objektbezogenen Problemlösungsfall pro Mitglied.

Ziel:

- Unabhängige Änderungen zwischen lokalem und aktuellem Serverstand automatisch zusammenführen.
- Nur echte Überschneidungen auf derselben Änderungseinheit oder fachliche Sync-Probleme eskalieren.
- Keine lokalen Änderungen still überschreiben oder verlieren.

Geplante Änderungseinheiten:

- Vorname
- Nachname
- Fahrtenname
- Geschlecht
- Geburtsdatum
- primäre E-Mail
- jede Telefonnummer über ihre `phoneNumberId`
- jede Zusatzmail über ihre `additionalEmailId`
- primäre Adresse als Block
- jede Zusatzadresse als Block über ihre `additionalAddressId`

Automatische Merge-Regeln:

1. Nur lokal geändert: lokale Änderung übernehmen.
2. Nur auf dem Server geändert: Serverstand übernehmen.
3. Beide gleich geändert: automatisch übernehmen.
4. Beide geändert, aber nicht dieselbe Änderungseinheit: automatisch zusammenführen.
5. Beide dieselbe Änderungseinheit unterschiedlich geändert: Problemlösungsfall.

UX-Regeln für den Problemlösungsfall:

- eigener Screen statt kleinem Dialog
- immer genau ein Mitglied gleichzeitig
- betroffene Änderungen untereinander statt lokal und Server dauerhaft nebeneinander
- klare visuelle Trennung für lokalen Stand, Serverstand und Konfliktstatus
- nur betroffene Änderungen anzeigen, nicht das gesamte Mitglied
- Entscheidungen pro Mitglied in einem Durchgang treffen und danach erneut senden

Direkt bearbeitbar im Problemlösungs-Screen:

- Name
- Geschlecht
- Geburtsdatum
- primäre E-Mail
- Zusatzmails
- Telefonnummern
- primäre Adresse
- Zusatzadressen

Verhalten je Einstieg:

- manueller Save: direkt zuordenbare Validierungsfehler bleiben im Bearbeiten-Screen; echte Konflikte öffnen den Problemlösungs-Screen direkt
- Hintergrund-Sync: einmalige Snackbar, danach persistenter Hinweis bis alle offenen Fälle gelöst sind

Geplante sichtbare Einstiege für offene Fälle:

- Einstellungen
- Mitglieddetails des betroffenen Mitglieds
- Warnsymbol in der Mitgliederliste

Abbruchverhalten:

- vollständig abgearbeitete Mitglieder werden direkt gesendet
- bei Abbruch bleibt der Fall offen
- Teilentscheidungen müssen nicht persistiert werden
- beim erneuten Öffnen beginnt dieses Mitglied wieder von vorn

Architekturgrenze:

- Repository und API-Client melden Datenstände, Validierungsfehler und Versionsabweichungen
- Merge-Erzeugung und Problemlösungsfall gehören in Model oder UseCase, nicht in den API-Client
- die ausführliche Projektbeschreibung liegt unter [docs/konfliktdialog.markdown](../docs/konfliktdialog.markdown)

### Done: 5 Änderung von bezeichnung im vergleich nicht sichtbar

Wird nur die Bezeichnung gehändert und steht in konflikt ist wird es nicht angezeigt. Stattdessen landen im vergleich die identischen E-Mail Adressen.

### Done 6: Löschen und Bearbeiten Konflikt

Wird auf dem Server ein zusatzfeld gelöscht und lokal bearbeitet, entsteht ein Konflikt. Entscheide ich mich für die lokale Änderung kommt es zu einem 404 Fehler. Die App muss das geänderte feld neu hinzufügen, damit die Änderung gespeichert werden kann.

### Offen 7: Adressvalidierung

Die Adressvalidierung im Offline- oder späteren Sync-Pfad ist noch nicht fachlich angeschlossen. Im Problemlösungsmodell werden nur Server-Validierungsfehler in ResolutionCases übersetzt in member_edit_model.dart:823; ein eigener Address-Validation-Trigger aus Retry oder Sync ist im Produktionspfad hier noch nicht sichtbar.

### Done 8: Umlaute

Teilweise fehlen Umlaute. Aktuell an mehreren Stellen ZB ae statt ä

### Done 9: Meldung beim offline speichern

Meldung bei offline Speichern ist Fehler und sollte Hinweis sein

### Prüfen 10: Meldung wenn Sitzung ungültig bearbeiten

Sitzung ungültig kommt bei jedem aufruf der Mitgliedsliste seite. Soll nur einnal, dann info in settings

- Nach Usetzung, meldung scheint nicht mehr zu kommen

### Done 11: Bearbeiten wenn sitzung ungültig

Wenn Sitzung nicht mehr gültig, soll trotzdem bearbeiten möglich sein - Ablauf wie offline Modus

### Done 12: Notifications werden zu oft geladen

Benachrichtigungen Fetch kommt zu oft

### Prüfen 13: Automatischer Background Sync

Auto-Sync läuft während aktiver App-Nutzung, sobald Senden wieder erlaubt ist. Das umfasst insbesondere verfügbare WLAN-Verbindung, die Freigabe mobiler Daten über die Einstellung und gedrosselte Retry-Versuche für bereits gequeue-te Änderungen.

## Änderungswünsche

- Länderflagen auch im MemberDetail an Telefonnummern
- GithubPages Wiki/Userguide
  - Konfliklösung
  - Regulatoren (Datenspeicherung, Löschung)
- Problemdialog: Mitglied bearbeiten kann aufgeklappt werden, bei Einstieg nicht sichtbar

## Weitere Funktionen

- Adresse Automatisch vervollständigen mit Geocoding API
  - Nutze bestehenden Dienst GEOAPIFY
  - Dazu müssen nicht mehr alle Felder zur Adresse angezeigt werden, die Eingabe und Auswahl kann in einem einzelnen Feld erfolgen. Bezeichnung und c/o sind weiterhin eigene Felder.
  - Feld Postfach kann entfallen.
  - Feld Land als Dropdown, nur Deutschland (default) und Nachbarländer.
  - Aktuelle Ansicht bleibt Fallback, wenn Bearbeitung offline oder Geocoding API nicht verfügbar ist.
- Adresse validieren (erst mit Konfliktdialog umsetzen)
  - Nur relevant bei Offline-Bearbeitung und späterem Sync.
  - Läuft über denselben Problemlösungsfall wie Konflikte oder andere fachliche Sync-Probleme.
  - Im normalen Online-Bearbeiten-Pfad bleibt die spätere automatische Adressvervollständigung der Hauptpfad.
  - Problemfall: Adresse nicht gefunden oder semantisch unplausibel, Eingaben prüfen oder lokale Änderung verwerfen.

## Manuelle Tests

- [ ] Fehlerhafte Telefonnummer im offline Modus: Ungültige Telefonnummer eingeben, Änderungen speichern, später synchronisieren, Validierungsfehler vom Server im Problemlösungsfall prüfen.
- [ ] Gültige Adresse offline bearbeiten: Adresse ändern, Änderungen speichern, später synchronisieren
- [ ] Ungültige Adresse offline bearbeiten: Ungültige Adresse eingeben, Änderungen speichern, später synchronisieren, Validierungsfehler von der App im Problemlösungsfall prüfen.
- [x] Konfliktlösung Online: Mitglied bearbeiten, gleichzeitig Serverstand ändern, Merge-Dialog öffnet automatisch, Konfliktlösung durchführen, Ergebnis prüfen.
- [ ] Konfliktlösung offline: Lokale Änderung an einem Mitglied vornehmen,  Serverstand ändern, später synchronisieren, Meldung erscheint, Merge-Dialog öffnen, Konfliktlösung durchführen, Ergebnis prüfen.
- [x] Automatische Zusammenführung: Lokale Änderung an einem Mitglied vornehmen, gleichzeitig Serverstand ändern, aber unterschiedliche Felder, später synchronisieren, automatisches Zusammenführen prüfen.
