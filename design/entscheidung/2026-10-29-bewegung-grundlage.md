# Bewegung und Haptik: gemeinsame Grundlage

- **Datum:** 2026-10-29
- **Runden:** Vorführung auf iOS-Simulator und Android-Emulator, Bereich für Bereich mit Rückmeldung (`integration_test/vorfuehrung/`)
- **Anlass:** #278. Gemeinsame Kurven, Dauern und Haptik als Grundlage für #279, #281 und #283; „Bewegung reduzieren“ überall beachten.
- **Umsetzung:** Branch `feat/bewegung-haptik-278`; `app_bewegung.dart`, `app_haptik.dart`, `achievement_unlocked.dart`, `confetti_overlay.dart`, `welcome_dialog.dart`, `global_loading_top_bar.dart`, `settings_map_page.dart` sowie die Token-Umstellung in Kacheln, Filter-Chips, Steckbrief, Basis-Infokarte und NaMi-AI-Chat

## Entschieden

| Frage | Ergebnis | Kurz beschrieben |
|---|---|---|
| Plattform | iOS zuerst | Bewegung und Haptik iOS-typisch; Android je Punkt entscheiden. |
| Haptik unter Android 7–10 | ohne Ersatz | Erfolg und Fehler wirken unter Android erst ab API 30; darunter bleibt es still. |
| Erster Haptik-Einsatz | Erfolg ab Gold | Freischalt-Dialog ab Gold und bei Sondererfolgen; die Haptik kommt im Moment, in dem das Badge aufspringt. |
| Konfetti | bleibt | Feier-Stufen mit Dialog und großem Konfetti, darunter kleines Konfetti mit Snackbar; bei „Bewegung reduzieren“ keins. |
| Badge-Auftritt | verzögert, deutlich | Wartet 180 ms, bis der Dialog fast steht, federt dann aus 50 % auf (Bounce 0,45, etwa 106 %, 900 ms). Ein seltener Moment, darf verspielt sein. |
| Gruppenfilter | 120 ms | Kaum sichtbare Antwort, weil oft gefiltert wird. |
| Ladeleiste | blendet | Ein- und Ausblenden in 180 ms statt hart. |
| Kartensuche | eine Fläche | Der Such-Knopf ist die Fläche, die in 350 ms nach links wächst und wieder schrumpft; Ecken (Radius 14) bleiben in jedem Frame rund, nur der Inhalt wechselt (erst geht der alte, dann kommt der neue). |
| Kartensuche, Platz | neben Zurück | Zurück und Suche stehen in einer Zeile; die offene Suche überdeckt Zurück nicht. Knöpfe 44 pt hoch, Radius 14, Beschriftung wird gekürzt statt überzulaufen. |
| Kartensuche, Schrift | 14 pt | Eingabe und Hinweis in Fließtextgröße, damit der lange Hinweis passt. |
| Karte zentrieren | weicht nur Ergebnissen | Blendet erst aus, wenn Suchergebnisse erscheinen, und kommt zurück, wenn sie verschwinden; beide teilen sich den Platz unter der Suche. |

Zusätzliche Vorgaben aus den Rückmeldungen:

- Bewegungen in Zeitlupe prüfen; überlagerte Zustände und harte Kanten sind nicht gewollt.
- Übergänge zwischen zwei Zuständen derselben Fläche als eine Fläche bauen, nicht als zwei übereinander geblendete.

## Abgelehnt

| Frage | Variante | Grund |
|---|---|---|
| Badge-Auftritt | Feder ab 85 %, Bounce 0,25, gleichzeitig mit dem Dialog | Überschwingen praktisch unsichtbar, besonders auf dem iPhone |
| Kartensuche | Platzhalter mit 130 ms Pause beim Schließen | Verschwinden, Aufblinken, Springen |
| Kartensuche | zwei Flächen mit abgestimmten Überblendungen | Knopf über offenem Feld sichtbar, harte Kanten beim Aufdecken |
| Karte zentrieren | beim Öffnen der Suche ausblenden | Weicht schon, bevor es einen Konflikt gibt |

## Offen

- Haptik auf dem echten iPhone prüfen (Vorführung `NUR=erfolge` auf dem Gerät).
- Steckbrief-Aufklappen ließ sich mit Demo-Daten nicht zeigen: Kein Name ist auch mit 1,4-facher Schrift abgeschnitten.
- Katalog-Vorschau so groß wie die eingefügte Kachel: #208.
