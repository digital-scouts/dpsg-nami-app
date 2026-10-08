# Supporter-Designs: Hintergründe, Paletten, Icons und Badges

- **Datum:** 2026-09-29
- **Runden:** Hintergründe 5, Paletten, Icons und Badges über die Übersicht `design/supporter/preview.html`
- **Anlass:** Animierte Hintergründe der Mitgliederliste, Farbpaletten, App-Icons und Supporter-Badges für die Supporter-Pakete.
- **Umsetzung:**
  - Generatoren in `design/supporter/` (Szenen in `lib/szenen.mjs`)
  - App-Nachbau in `lib/presentation/widgets/supporter_background_painter.dart`
  - Paletten in `lib/presentation/theme/theme.dart`

Namen seit 2026-10-08: Waldsee, Lagerfeuer, Nachthimmel (siehe `2026-10-08-supporter-waldsee-icons.md`).

## Entschieden

| Frage | Ergebnis | Kurz beschrieben |
|---|---|---|
| Lagerfeuer, Nacht | B · Feuerstelle mit Sitzkreis | Größeres Feuer mit Steinring und zwei Sitzbalken, Funken |
| Lagerfeuer, Tag | Sitzkreis, Feuer ausgebrannt | Wie B, aber verkohlte Scheite, schwache Glut und ruhig aufsteigender Rauch |
| Nachthimmel, Tag | Sonne und Lager | Tiefe Sonne mit langsam drehenden Strahlen, Wolken, Vögel, kleines Lager aus drei Kohten auf fernem Hügel (B und C kombiniert) |
| Nachthimmel, Nacht | Milchstraße mit Lager | Milchstraße und Sternschnuppen, dasselbe Lager mit einer leuchtenden Kohte |
| Waldsee, Tag | Waldsee mit Plätschern | Libellen, Schilf, einzelne Wasserkreise etwa alle vier Sekunden |
| Waldsee, Nacht | Mondlicht am See | Weiches Mondlicht ab dem Mond, Sterne, Mondspiegelung, seltene Wasserkreise, wenige Glühwürmchen |
| Paletten | Standard, Waldsee, Lagerfeuer, Nachthimmel, Hochkontrast | Gleiche Tokens wie `DPSGColors` |
| Badges | Kompass in sechs Farben, Förderer-Badge Polarstern | |

Gestaltungsregel: nur eigene Motive, keine Lilie, keine Stufenlogos und keine DPSG-Designs. Stufenfarben nur als Farbwerte.

## Abgelehnt

| Frage | Variante | Grund |
|---|---|---|
| Lagerfeuer, Nacht | A · kleines Feuer unten, C · Feuer an der Kohte, D · Feuer in der Ferne | nicht gewählt |
| Lagerfeuer, Tag | Zeltlager am Morgen | nicht gewählt |
| Nachthimmel, Nacht | Mondnacht ohne Milchstraße | nicht gewählt |
| Waldsee, Tag | Blätter im Wind | nicht gewählt |
| Waldsee, Nacht | Kohte im Wald | nicht gewählt; die Kohte kam 2026-10-08 an den See |
| Icons | Hajk-Motiv | entfällt mit dem Paketmodell (#212) |

## Offen

- nichts
