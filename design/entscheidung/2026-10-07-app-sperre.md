# App-Sperre und Sichtschutz

- **Datum:** 2026-10-07
- **Runden:** 3
- **Anlass:** Die Sperre dunkelte nur zu 70 % ab, Name und Adresse blieben lesbar (A-16). Im App-Umschalter war der letzte Bildschirm zu sehen (A-17).
- **Umsetzung:** `lib/presentation/widgets/app_sperre_flaeche.dart`

## Entschieden

| Frage | Ergebnis | Kurz beschrieben |
|---|---|---|
| Sperrbildschirm | B | Deckend, Grafik und Text mittig, „Jetzt entsperren“ unten. |
| Vorschau im App-Umschalter | 1 | Dieselbe Fläche ohne Text und Knopf, als Standbild. |
| Grafik | B3 | Vollbild: ohne Supporter-Paket ein Verlauf in der Primärfarbe, mit Paket der animierte Hintergrund. Text auf einer Glasfläche. |
| Szenenhöhe | S | Die Szene füllt etwa 55 % der Höhe (310 pt auf dem iPhone) und wächst anteilig mit dem Gerät. Darüber geht sie in ihre Himmelfarbe über. |

Zusätzliche Vorgaben:

- Keine Lilie und keine DPSG-Zeichen (A-64), nur App-Icon und eigene Szenen.
- Bei „Bewegung reduzieren“ steht der Hintergrund still. Im Umschalter steht immer ein Standbild.

## Abgelehnt

| Frage | Variante | Grund |
|---|---|---|
| Sperrbildschirm | A | nicht gewählt |
| Grafik | B1 App-Icon groß | nicht gewählt |
| Grafik | B2 Icon mit Horizont-Band | nicht gewählt |
| Grafik | B4 Kopfzeile wie in der App | nicht gewählt |
| Szenenhöhe | M (65 %), L (75 %) | gewünscht war eine kleinere Szene als in B3 |

## Offen

- nichts
