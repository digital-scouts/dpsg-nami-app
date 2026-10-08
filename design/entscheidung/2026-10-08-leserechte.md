# Fehlende Daten bei reinen Leserechten

- **Datum:** 2026-10-08
- **Runden:** 2
- **Anlass:** Mit `group_read` liefert Hitobito keine Rollen, Qualifikationen und EFZ anderer Personen. Die App zeigte dann Nullen und „Keines hinterlegt“ (#187).
- **Umsetzung:**
  - PR #225
  - `lib/presentation/widgets/leserechte_hinweis.dart`
  - `_NutzenKarte` in `settings_qualifikationen_page.dart`

## Entschieden

| Frage | Ergebnis | Kurz beschrieben |
|---|---|---|
| Hinweis auf fehlende Daten | A · Dezente Zeile | Eine Zeile in der Hinweisfarbe mit Info-Symbol, ohne Fläche. Verwendet in Mitgliederliste, Rollen- und Qualifikationen-Tab, Übersicht, Statistik und Stufenwechsel. EFZ und Qualifikationen zeigen ein Schloss mit „Keine Berechtigung“. |
| Gesperrte Qualifikationen-Seite: Nutzen | A · Getönte Karte | Farbige Karte mit Zeichen, Titel und Satz. Grün „Hilft dir“ bei Leserecht auf den Stamm, gelb „Hilft dir teilweise“ bei `group_full` auf einzelne Gruppen, orange „Hilft dir nicht“ bei nur `group_read`. |
| Zustand „teilweise“ | behalten | |

Zusätzliche Vorgaben:

- Gruppenchips gibt es nur noch für Gruppen mit lesbaren Rollen.
- Die Hinweise verschwinden von selbst, sobald Hitobito die Daten liefert.

## Abgelehnt

| Frage | Variante | Grund |
|---|---|---|
| Hinweis auf fehlende Daten | B · Info-Karte mit „Mehr erfahren“, gemischt | nicht gewählt |
| Nutzen | B · Farbige Zeile | nicht gewählt |

## Offen

- Hitobito-Vorschlag #4555/#4556, damit Leitende mit `group_read` Rollen sehen.
