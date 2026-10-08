# Hilfe & Diagnose

- **Datum:** 2026-10-07
- **Runden:** 3
- **Anlass:** „Debug & Tools“ stand im Release unter „Entwicklung“ und enthielt Entwicklerfunktionen (A-94).
- **Umsetzung:**
  - `lib/presentation/screens/hilfe_diagnose_page.dart`
  - `lib/presentation/widgets/problem_melden_sheet.dart`

## Entschieden

| Frage | Ergebnis | Kurz beschrieben |
|---|---|---|
| Einstieg | E1 | Abschnitt „Hilfe“ in den Einstellungen mit der Zeile „Hilfe & Diagnose“, auch ohne Login erreichbar. |
| Offline-Karten im Release | ja | „Offline-Karten“ und „Stammessuche jetzt laden“ bleiben. |
| Seitenaufbau | G3 | Nur Zeilen wie auf der Einstellungsseite (Symbol, Titel, Kurztext), höchstens vier Gruppen. Löschende Aktionen zuletzt und rot. Entwicklerteile nur in Debug und Profile als Gruppe „Entwicklung“ ganz unten. |
| Problem melden | D2 | Kurzer Dialog vor der Mail: Art des Problems (Mehrfachauswahl) und drei freiwillige Fragen. Daraus eine vorbefüllte Mail mit App-Protokoll der letzten 24 Stunden, App-Version und Plattform. „Weiter zur Mail“ geht immer. |

## Abgelehnt

| Frage | Variante | Grund |
|---|---|---|
| Einstieg | E2, E3 | nicht gewählt |
| Seitenaufbau | S1, S2 (Runde 1) | wirkten unruhig, zu viele lose Knöpfe ohne Gliederung |
| Seitenaufbau | G1, G2 | nicht gewählt |
| Problem melden | D1 | nicht gewählt |

## Offen

- nichts
