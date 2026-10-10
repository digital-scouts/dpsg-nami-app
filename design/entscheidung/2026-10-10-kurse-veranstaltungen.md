# Kurse & Veranstaltungen

- **Datum:** 2026-10-10
- **Runden:** 1
- **Anlass:** Erster Durchgang von #211: Kurse und Veranstaltungen aus Hitobito suchen, filtern, ansehen, in den Kalender übernehmen und im Web öffnen. Eine Anmeldung in der App ist nicht enthalten.
- **Umsetzung:**
  - PR #<nr>
  - `lib/presentation/screens/veranstaltungen/`
  - `lib/presentation/widgets/veranstaltungen/`

## Entschieden

| Frage | Ergebnis | Kurz beschrieben |
|---|---|---|
| Name und Einstieg | N2 · Kurse & Veranstaltungen | Ein Eintrag im Schnellzugriff der Einstellungen, der den Platzhalter „Events“ ersetzt. Ab 840 pt steht er zusätzlich in der Seitenleiste unter dem Schnellzugriff, in der schmalen Leiste zweizeilig. Kein fünfter Tab. |
| Suchliste | L3 · Nach Monat gruppiert | Abschnittsüberschrift je Monat. Darunter eine Karte mit kompakten Zeilen, getrennt durch Abstand: links Tag und Wochentag, daneben ein Punkt für die Art (Kurs lila, Veranstaltung blau), Titel, veranstaltende Gruppe und eine Statuszeile als farbiger Text. Grün „Anmeldung offen bis …“, orange „Anmeldung ab …“, grau „Anmeldeschluss vorbei“. Bei Kursen kommen „x frei“ bzw. rot „ausgebucht“ dazu. Sortiert nach dem ersten Termin. |
| Suche und Filter | F1 · Chip-Leiste | Suchleiste (Name, Ort, Gruppe) und darunter waagerecht scrollbare Chips: Alle / Kurse / Veranstaltungen, Anmeldung offen, Ebene ▾, Zeitraum ▾. Ebene, Zeitraum und Kursart-Kategorie liegen in einem Filterfenster. |
| Detailansicht | D2 · Kopf mit Statusbanner | Art in Kapitälchen (z. B. „Kurs · GLK“), großer Titel, Gruppe und Zeitraum. Darunter ein farbiges Banner mit Anmeldestatus und Plätzen, dann die Aktionen als Pillen („Im Web öffnen“ bzw. „Zur Anmeldung“ bei externer Anmeldung, „In Kalender“). Es folgen die Abschnitte Termine (Zeitstrahl), Ort und Kosten, Beschreibung, Kursart (Kategorie, Mindestalter, Infos, Voraussetzungen), Ansprechpersonen (Kontakt, Leitung) und Veranstaltet von. Leere Angaben werden ausgeblendet oder als „kein … angegeben“ gezeigt. |

Zusätzliche Vorgaben aus den Kommentaren:

- F1: Die Chips stehen wie bei den Mitgliedern mit in der Kopfzeile, also auf der Illustration unter der Suchleiste und nicht darunter auf dem Seitenhintergrund.

Ohne eigene Frage übernommen, so wie in den Folgescreens gezeigt:

- Das Filterfenster ist ein Bottom Sheet mit diesen Abschnitten:
  - Kursart-Kategorie (Chips)
  - Ebene: Mein Stamm / Mein Stamm und darüber / Alle sichtbaren
  - Zeitraum: 4 Wochen / 3 Monate / Alle kommenden / Eigener
  - darunter „Zurücksetzen“ und „x anzeigen“
- „In Kalender“ öffnet den Systemdialog. Bei mehreren Terminen wird vorher in einem Bottom Sheet gefragt, welcher Termin eingetragen werden soll.
- Zustände mit Symbol, Titel und Hinweis:
  - offline: „Keine Verbindung“, mit „Erneut versuchen“
  - keine Treffer: „Nichts gefunden“, mit „Filter zurücksetzen“
  - Fehler: „Laden fehlgeschlagen“, mit „Erneut versuchen“
  - keine aktive Rolle: „Keine Veranstaltungen sichtbar“
- iPad quer (ab 840 pt): Seitenleiste, links Suche, Chips und Liste, rechts das gewählte Event wie bei den Mitgliedern.

## Abgelehnt

| Frage | Variante | Grund |
|---|---|---|
| Name und Einstieg | N1 · Veranstaltungen, N3 · Termine | nicht gewählt |
| Suchliste | L1 · Karten wie Mitglieder, L2 · Datumsblock | nicht gewählt |
| Suche und Filter | F2 · Filtersymbol wie Mitglieder, F3 · Umschalter Art | nicht gewählt |
| Detailansicht | D1 · Wie Mitgliedsdetail mit Aktionsleiste | nicht gewählt |

## Offen

- Anmeldung und Abmeldung in der App, sobald die Hitobito-API sie anbietet (Upstream)
- „Meine Termine“ und Erinnerungen als Folgeschritt
- Vergebene Qualifikationen eines Kurses, sobald die API sie liefert
