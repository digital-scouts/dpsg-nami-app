# Responsive Lesebreite

- **Datum:** 2026-10-09
- **Runden:** 1
- **Anlass:** Auf iPad, iPad mini und dem aufgeklappten iPhone Duo laufen Listen und Karten über die volle Fensterbreite, Zeilen werden unlesbar lang. Etappe 1 von drei (danach seitliche Navigation, dann Liste und Detail nebeneinander).
- **Umsetzung:**
  - PR #<nr>
  - `lib/presentation/widgets/app_lesebreite.dart`
  - `AppPageHeader`, `SupporterBackdrop`
  - Mitgliederliste, Stufenwechsel, Einstellungen, Mitgliedsdetail

## Entschieden

| Frage | Ergebnis | Kurz beschrieben |
|---|---|---|
| Inhaltsbreite | B2 · 720 pt | Listen und Karten sind höchstens 720 pt breit (inklusive 16 pt Innenabstand) und stehen mittig. Auf dem iPad mini hoch (744) ist das fast die volle Breite, auf dem Duo bleiben etwa 75 pt Rand je Seite. |
| Kopf | H3 · Kopf als Block | Der Kopf der Hauptseiten samt Illustration ist genauso breit wie der Inhalt, steht mittig und ist unten abgerundet. Daneben sieht man die Hintergrundfarbe. Auf schmalen Fenstern bleibt der Kopf randlos wie bisher. |

Nachtrag nach Durchsicht auf dem Gerät (2026-10-09): Das aufgeklappte Duo soll neben der Seitenleiste noch die volle Breite nutzen. Die Lesebreite ist deshalb **800 pt**. Begrenzt wird erst, wenn je Seite mindestens 24 pt Rand bleiben (ab 848 pt), sonst bleiben Inhalt und Kopf randlos. Ohne Block reicht der Kopfhintergrund bis an beide Ränder, auch in den Systembereich rechts beim Duo.

Zusätzliche Vorgaben:

- Maßgeblich ist die Fensterbreite, nicht das Gerät. Das gilt auch für Split View und Stage Manager.
- Auf dem iPhone ändert sich nichts.
- Die Statistik behält ihr Kachelraster über die volle Breite, ihr Kopf bleibt ebenfalls volle Breite (Rückfrage nach der Runde).
- Unterseiten mit Titelleiste (Mitgliedsdetail, Einstellungsseiten): Die Leiste bleibt vollflächig, ihr Inhalt und die Tabs sind bündig mit der Inhaltsbreite.

## Abgelehnt

| Frage | Variante | Grund |
|---|---|---|
| Inhaltsbreite | Ist (volle Breite), B1 · 600 pt, B3 · 840 pt | nicht gewählt |
| Kopf | H1 · Suche bündig, Illustration randlos; H2 · Kopf volle Breite | nicht gewählt |

## Offen

- Seitliche Navigation (Etappe 2) sowie Liste und Detail nebeneinander (Etappe 3) folgen mit eigenen Runden.
