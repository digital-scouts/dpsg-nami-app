# Responsive Navigation

- **Datum:** 2026-10-09
- **Runden:** 2
- **Anlass:** Auf breiten Fenstern kostet die untere Leiste vor allem im Querformat (Duo aufgeklappt, iPad quer) Höhe. Etappe 2 von drei nach der Lesebreite (`2026-10-09-responsive-lesebreite.md`).
- **Umsetzung:**
  - PR #<nr>
  - `lib/presentation/widgets/app_seitenleiste.dart`
  - `navigation_home.page.dart`, `settings_page.dart`

## Entschieden

| Frage | Ergebnis | Kurz beschrieben |
|---|---|---|
| Ab welcher Breite | A2 · ab 840 pt | Seitenleiste auf Duo aufgeklappt, iPad quer und iPad 13" hoch. iPad mini hoch, iPad 11" hoch und Split View behalten die untere Leiste. Maßgeblich ist die Fensterbreite. |
| Form | S3 · schmal, ab 1200 pt breit | Bis 1200 pt schmal (umgesetzt 88 pt, damit „Qualifikationen“ ohne Verkleinerung passt) mit Symbol und Beschriftung darunter, Auswahl als Pille. Ab 1200 pt (iPad 13" quer) breit mit Symbol und Text nebeneinander und App-Namen oben. |
| Fläche | F2 · auf dem Hintergrund | Keine eigene Fläche und keine Trennlinie, die Leiste liegt direkt auf dem Seitenhintergrund. |
| Statistik iPad mini | K2 · 2 Spalten | Die Schwelle des Kachelrasters bleibt bei 700 pt. Weil das iPad mini hoch die untere Leiste behält, ändert sich dort nichts. |
| Schnellzugriff: Einträge | E1 · nur nutzbare | Unter den vier Hauptbereichen, mit Abstand abgesetzt: Karte, Qualifikationen (mit Schloss, solange gesperrt) und NaMi AI (nur wenn sichtbar). Platzhalter ohne Funktion (Rechnungen, Veranstaltungen, Abos) bleiben weg. In der breiten Form steht „Schnellzugriff“ darüber. |
| Schnellzugriff: Öffnen | O1 · neben der Leiste | Die Seite öffnet sich rechts neben der Leiste wie ein Hauptbereich, der Eintrag ist markiert, kein Zurück-Pfeil. |
| Schnellzugriff in den Einstellungen | D1 · entfällt dort | Solange die Seitenleiste sichtbar ist, zeigen die Einstellungen keinen Schnellzugriff. Auf schmalen Fenstern bleibt er wie bisher. |

Zusätzliche Vorgaben aus den Kommentaren:

- Was bisher in den Einstellungen unter „Schnellzugriff“ stand, kommt mit in die Seitenleiste (Anlass für Runde 2).

## Abgelehnt

| Frage | Variante | Grund |
|---|---|---|
| Ab welcher Breite | Ist (immer unten), A1 · ab 600 pt | nicht gewählt |
| Form | S1 · immer schmal, S2 · immer breit | nicht gewählt |
| Fläche | F1 · eigene Fläche | nicht gewählt |
| Statistik iPad mini | K1 · 4 Spalten ab 620 pt | nicht gewählt |
| Schnellzugriff: Einträge | E2 · alle inklusive Platzhalter | nicht gewählt; passt auf dem Duo nicht in die Höhe |
| Schnellzugriff: Öffnen | O2 · als eigene Seite | nicht gewählt |
| Schnellzugriff in den Einstellungen | D2 · bleibt zusätzlich | nicht gewählt |

## Offen

- Liste und Detail nebeneinander folgen in Etappe 3.
