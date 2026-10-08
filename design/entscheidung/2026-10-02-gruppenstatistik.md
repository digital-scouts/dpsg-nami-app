# Gruppenstatistik, Teilsicht und Gruppen-Kachel

- **Datum:** 2026-10-02
- **Runden:** Gruppenstatistik 2, Gruppen-Kachel 2
- **Anlass:** Wer nur die eigene Gruppe lesen darf, braucht eine Gruppenstatistik. In großen Stämmen soll jede Gruppe erreichbar sein.
- **Umsetzung:**
  - `statistik_stamm_ansicht.dart`
  - `kacheln/inhalte_mitglieder.dart`
  - `kacheln/inhalte_alter.dart`
  - `gruppen_auswahl.dart`

## Entschieden

| Frage | Ergebnis | Kurz beschrieben |
|---|---|---|
| Detailseite einer Gruppe | A · Kacheln wie im Stamm | Dieselben Kacheln, nur für die Gruppe berechnet, feste Belegung ohne Bearbeiten. Karte als 2×2. |
| Stamm-Tab bei Teilsicht | bestehender Tab, nur „Überblick“ | Gleicher Header und gleiche Tabs, ohne Themenleiste. Bearbeiten wie bisher, nur „Stufen“ und „Entwicklung“ lassen sich nicht einblenden. |
| Mehrere Gruppen | keine Chips | Die Gruppen-Kachel führt zur Detailseite jeder Gruppe |
| Bund-Tab | wie Runde 1 | Bei Teilsicht Vergleich mit Gruppen derselben Stufe. Bei voller Sicht neu die Gruppengröße je Stufe. |
| Altersstruktur 2×1 | B · Alle Stufen in einer Zeile | Gemeinsame Altersachse, Säulen in Stufenfarbe, Altersgrenzen als Leiste unter der Achse |
| Überblick zurücksetzen | freigegeben | Eintrag im Bearbeiten-Modus unter dem Raster. Eigene Kacheln bleiben im Katalog, Zielwerte bleiben. |
| Gruppen-Kachel 2×1 | je Gruppe bis zwei, sonst „Stufen“ | Bei wenigen Gruppen eine Spalte je Gruppe, ein Tipp öffnet die Gruppe. Sonst eine Spalte je Stufe, die Stufe öffnet die Auswahl an dieser Stufe. |
| Gruppen-Kachel 2×2 | A, B und C nach Anzahl | Bis 6 Gruppen als Liste, 7–12 in zwei Spalten mit Name, Zahl und Balken, ab 13 Chips je Stufe. So bleiben alle Gruppen sichtbar. |
| Gruppenübersicht | als Blatt | Blatt mit allen Gruppen nach Stufe, erreichbar über den Kachel-Titel, eine Stufe und den Titel der Detailseite (Gruppenwechsel) |

## Abgelehnt

| Frage | Variante | Grund |
|---|---|---|
| Detailseite | B · volle Breite | nicht gewählt |
| Mehrere Gruppen | Chips mit oder ohne „Alle“ | Gruppen-Kachel reicht |
| Altersstruktur 2×1 | A · Zeile je Stufe gestaucht | laut Entwurf ab drei Stufen zu niedrig |
| Gruppen-Kachel 2×2 | „+N weitere“ ohne Ziel (Ausgangsstand) | Gruppen waren nicht erreichbar |

## Offen

- nichts
