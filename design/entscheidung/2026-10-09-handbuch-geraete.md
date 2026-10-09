# Handbuch Gerätesupport

- **Datum:** 2026-10-09
- **Runden:** 1
- **Anlass:** Mit Lesebreite und Seitenleiste (#237, #238) sieht die App auf iPad und aufgeklapptem iPhone Duo anders aus; das Handbuch hatte dazu keine Seite und kein Bildformat für breite Geräte.
- **Umsetzung:**
  - PR #<nr>
  - `docs/handbuch/geraetesupport.md`
  - `docs/_includes/geraete.html`, `.tablet` und `.duo` in `docs/_sass/custom/custom.scss`
  - Bilder unter `docs/assets/img/geraete/`, abgeleitet aus den Store-Rohscreens

## Entschieden

| Frage | Ergebnis | Kurz beschrieben |
|---|---|---|
| Seitenaufbau | A3 · Duo als Aufmacher | Großes Duo-Bild der Statistik direkt unter dem Einleitungssatz, darunter „Was sich auf breiten Fenstern ändert“ mit den Breitenstufen (schmal, ab 840 pt, ab 1200 pt, Lesebreite 800 pt), dann der Vergleich der Mitgliederliste auf iPhone, iPad und Duo und am Ende die Tabelle der unterstützten Geräte. |
| Bildrahmen | R1 ohne Falz | iPad und Duo bekommen denselben dunklen Rahmen wie die Handy-Bilder, ohne Falzlinie in der Mitte. |
| Duo-Screens | D1, D2, D3 | Mitglieder (Vergleichsreihe), Statistik (Aufmacher) und Karte (Schnellzugriff aus der Seitenleiste). |
| Titel und Ort | T2 · „Gerätesupport“ | Eigene Handbuchseite, in der Navigation vor der FAQ. |

Zusätzliche Vorgaben aus den Kommentaren:

- Keine Falzlinie im Duo-Rahmen.

## Abgelehnt

| Frage | Variante | Grund |
|---|---|---|
| Seitenaufbau | A1 · Tabelle, dann Vergleich; A2 · ein Abschnitt je Gerät | nicht gewählt |
| Bildrahmen | R2 · nur das Bild; R3 · aufgeklappt, angewinkelt | nicht gewählt |
| Duo-Screens | D4 Stufenwechsel, D5 Mitgliedsdetail, D6 Erscheinungsbild dunkel | nicht gewählt; das Mitgliedsdetail zeigt noch keine Seitenleiste |
| Titel und Ort | T1 · „Geräte“ nach Mitglieder; T3 · Abschnitt in Erste Schritte | nicht gewählt |

## Offen

- Liste und Detail nebeneinander (Etappe 3, `feat/responsive-liste-detail`): Seite und Duo-Bilder beim nächsten Doku-Abgleich nachziehen.
