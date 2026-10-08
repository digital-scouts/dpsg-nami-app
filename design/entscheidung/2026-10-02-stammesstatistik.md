# Stammesstatistik

- **Datum:** 2026-10-02
- **Runden:** 5
- **Anlass:** Die Statistikseite wird neu aufgebaut, mit Themen, Kachelraster und Bearbeiten.
- **Umsetzung:**
  - PR #163
  - `lib/presentation/statistics/`
  - `statistics_page.dart`

## Entschieden

| Frage | Ergebnis | Kurz beschrieben |
|---|---|---|
| Layout | D · Themen mit C · Kachelraster | Tabs Überblick, Stufen, Entwicklung. Darunter ein Raster mit festen Größen 1×1, 2×1 und 2×2. Jede Kachel bietet nur Größen an, in denen ihr Inhalt trägt. |
| Kopf | K1 | Zeile 1 mit Gesamtzahl und Stufenband, Zeile 2 mit „‹Stammesname› \| Bundesweit“ (nach PR #162) |
| Anpassbar | nur Überblick | Stufen und Entwicklung sind fest zusammengestellt und lassen sich ausblenden. Ihre Kacheln stehen im Katalog für den Überblick bereit. |
| Stil | Balken und Zahlen, keine Punkte | Altersstruktur als Balken, „Alter in Zahlen“ als eigene Kachel, Bindung als Zahlen |
| Stufenwechsel | V2 · Balken, „heute“ grau | „nach dem Stichtag“ in Stufenfarbe, Text „… können zum … wechseln“, ohne „überfällig“ und ohne ▲ |
| Gruppen-Zielmarke | Z1 · Strich | große Zahl, langer Balken mit Zielstrich |
| Bearbeiten | wie Handy-Widgets | Knopf unten startet den Modus: Kacheln wackeln schwach, rotes − entfernt, Ecke ziehen ändert die Größe, Ziehen sortiert, ＋ öffnet den Katalog. Kein Wackeln bei „Bewegung reduzieren“. |
| Eigene Kacheln | wie alle anderen | Aufteilung nach Stufe als Torte in 1×1 mit Zahl oben links |
| Krumme Daten | dürfen seltsam aussehen, nicht brechen | geprüft mit „Stamm Querfeld“ |
| Größere Schrift | Kachelhöhe wächst mit, bis 140 % | Zahlen schrumpfen bei Platzmangel (FittedBox), Titel enden mit „…“ |

Farbregeln:

- Stufenfarben mit Textlabel, Leitung ohne eigene Farbe, eigene Palette für Geschlecht und Konfession.
- Biber immer ausgeschrieben, im Hellmodus Hellgrau mit Kontur. Jufi-Blau im Dunkelmodus aufgehellt.

Kachel-Details:

- Geschlecht und Konfession 1×1 nur mit Kürzel im Ring.
- 1×1-Kacheln nutzen die Höhe, z. B. Stufenwechsel mit Aufteilung.
- Kacheln sind in diesem Ausbau nicht antippbar.

## Abgelehnt

| Frage | Variante | Grund |
|---|---|---|
| Layout | A · Lagebericht, B · Pfad | nicht gewählt; die Stationskarten aus „Pfad“ leben als Gruppendetailseite weiter |
| Stil | Punkte | entfällt |
| Kopf | K2 · Kennzahl-Kacheln, K3 · Themen im Header | nicht gewählt |
| Stufenwechsel | V1 · Tabelle, V3 · Säulenpaare | nicht gewählt |
| Zielmarke | Z2 · „/Ziel“, Z3 · Zeile „Ziel höchstens“ | nicht gewählt |
| Bearbeiten | Stift neben den Tabs | nur über den Knopf unten |

## Offen

- Feinschliff einzelner Kacheln, siehe `specs/todos.md`
- Antippbare Kacheln („Hinter den Kacheln“) für einen späteren Ausbau
