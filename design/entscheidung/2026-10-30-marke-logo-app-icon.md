# Marke: Logo und App-Icon

- **Datum:** 2026-10-30
- **Runden:** 5
- **Anlass:** Die Startbühne (#279) soll das Halstuch im Icon knoten. Dabei zeigte sich, dass das Standard-Icon nicht mehr passt. Aus der Überarbeitung wurde ein Markenlogo, aus dem das App-Icon folgt (#285).
- **Umsetzung:** #285; Quellen in `design/marke/` (`lib/marke.mjs`, `generate.mjs`)

## Entschieden

| Frage | Ergebnis | Kurz beschrieben |
|---|---|---|
| Logo | R1 mit K1 | Drei Personen als Linienzeichnung: links Weinrot, rechts Ocker, vorn in der Mitte etwas größer in Blau. Die vordere Person verdeckt die hinteren ganz, auch zwischen Kopf und Körper. |
| App-Icon | R3 mit I1 | Eine Mitgliederliste mit drei versetzten Zeilen. Jede Zeile beginnt mit einer weißen, gefüllten Person im farbigen Kreis (Weinrot, Blau, Ocker), daneben zwei graue Balken. |
| Halstuch | T2 mit D3 | Breit und flach. Die Bänder kommen von links und rechts über die Schultern und laufen oben in einen Lederring mit zwei Rillen. Unten kommen zwei spitze Zipfel aus dem Ring. |
| Tuch auf der Schulter | S2 | Im Logo deckt das Tuch die Schulterlinie ab und schließt bündig mit ihrer Außenkante ab. Im Icon liegt es bündig auf dem gefüllten Körper. |
| Farben | F1 | Weinrot `#8e0f1b`, Blau `#114a84`, Ocker `#bd6508` wie bisher. Tuch grau, Ring lederbraun. Im Dunkelmodus sind die Farben aufgehellt. |
| Hintergrund des Icons | H3 | Sehr helles Blau mit leichtem Verlauf (`#f3f7fc` → `#d6e3f1`), dunkel `#1d2a40` → `#0d121c`. |

Zusätzliche Vorgaben aus den Kommentaren:

- Ziel ist ein Markenlogo, nicht nur ein App-Icon. Das Icon soll die Verwaltung aller Mitglieder zeigen, nicht die eigene Mitgliedschaft.
- Personen bleiben das Motiv.
- Die Lilie darf verwendet werden, auch das Original der DPSG. Die Nutzung ist laut CI der DPSG für diesen Zweck freigegeben (2026-10-30). Wölfi, Kobold und Biber kommen nicht in Logo oder Icon.
- Im Icon sind Tuch und Ring farbig, damit sie sich vom weißen Körper abheben.
- Reihenfolge der Arbeit: erst Logo und Icon, dann die Animation des Icons, dann die Startbühne (#279). Animiert werden das Tuch samt Zipfeln und der Knoten; dafür liefert `generate.mjs` die Ebenen `icon-*-grund`, `icon-*-tuch` und `icon-*-knoten`.

## Abgelehnt

| Frage | Variante | Grund |
|---|---|---|
| Motiv (Runde 1) | M1 Drei als Büste, M2 Vier Stufen | zu klobig, M2 merkwürdig |
| Motiv (Runde 1) | M3 Halstuch nah | allein unpassend, Tuch und Knoten lagen nicht richtig |
| Motiv (Runde 1) | M4 Runde, M6 nur das Halstuch | nicht gewünscht |
| Motiv (Runde 1) | M5 Mitgliedskarte | sauber, wirkt aber wie eine App für die eigene Mitgliedschaft |
| Farben | F2 Stufenfarben, F3 Marine mit rotem Tuch | nicht gewählt |
| Hintergrund | H1 Weiß, H2 Marineverlauf | nicht gewählt |
| Richtung | R2 Lilie aus Personen, R4 alle unter einem Tuch, R5 Monogramm N, R6 Ringe, R7 Original-Lilie über der Gruppe, R8 nur Original-Lilie | nicht gewählt; R1 gefiel als Logo, R3 als Icon |
| Logo | K2 weiter auseinander, K3 eng dahinter | nicht gewählt |
| App-Icon | I2 Personen als Linie, I3 gerade Zeilen | nicht gewählt |
| Halstuch | T1 schmal gerollt, T3 gerollt mit Rand | nicht gewählt |
| Knoten | D1 kleiner Knoten, D2 breiter Knoten mit geraden Zipfeln | nicht gewählt |
| Tuch auf der Schulter | S1 unter der Linie | nicht gewählt |

## Offen

- App-Name und Wortmarke: „NaMi“ ist nur Platzhalter (A-64).
- Icon-Composer-Ebenen für iOS 26 (Glas, getönte Darstellung) und das adaptive Android-Icon mit Monochrom-Ebene werden bei der Umsetzung abgeleitet und am Gerät geprüft.
- Ob die Supporter-Icons neben dem neuen Standard-Icon stimmig bleiben.
