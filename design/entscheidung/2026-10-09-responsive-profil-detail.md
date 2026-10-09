# Responsive: Profil, Qualifikationen-Kopf, Liste und Detail

- **Datum:** 2026-10-09
- **Runden:** 1 (mit zwei Rückfragen)
- **Anlass:** Durchsicht der Seitenleiste auf dem Gerät (#238). Offen waren Profil in der Leiste, ein Kopf für die Qualifikationen sowie Liste und Detail nebeneinander. Etappe 3 nach `2026-10-09-responsive-lesebreite.md` und `2026-10-09-responsive-navigation.md`.
- **Umsetzung:** PR #<nr>

## Entschieden

| Frage | Ergebnis | Kurz beschrieben |
|---|---|---|
| Profil in der Seitenleiste | P1 · Avatar | Oben in der Leiste der runde Avatar mit Initiale und dem eigenen Supporter-Badge. Tippen öffnet das Profil im Inhaltsbereich. In der breiten Leiste stehen Name und Stamm in zwei Zeilen daneben, je höchstens zwei Zeilen mit Auslassung. Ist das Profil gewählt, stehen beide vollständig da. |
| Breite der Seitenleiste | nach Rückfrage | Der Inhalt hat eine feste Breite (800 pt plus 24 pt Rand je Seite). Bleibt daneben mindestens 200 pt Platz, wird die Leiste breit und nimmt diesen Platz bis höchstens 320 pt. Sonst bleibt sie schmal (88 pt, nur Avatar), z. B. auf dem Duo und dem iPad 13" hoch. |
| Profilkopf in den Einstellungen | E2 · Profilkarte bleibt | Die Einstellungen zeigen ihre Profilkarte auch mit Seitenleiste. |
| Kopf der Qualifikationen | Q1 · Karte wie Stufenwechsel | Kopf mit Illustration wie die anderen Hauptbereiche. Obere Zeile: Personen mit Rolle und wie viele davon unvollständig sind (mindestens ein Nachweis fehlt). Untere Zeile: Arbeitskontext und Auswahl der Qualifikationen. Q3 (Filter-Chips) wurde zunächst gewählt, nach der Rückfrage zu den Filtern aber verworfen. |
| Qualifikationen-Kopf auf dem iPhone | O1 · überall gleich | Auch auf dem iPhone mit diesem Kopf, der Zurück-Pfeil sitzt in der oberen Zeile. |
| Mitglieder: Liste und Detail | L2 · Kopf über beiden Spalten | Suche und Filter über der ganzen Breite, darunter links die Liste, rechts das gewählte Mitglied mit eigener Kopfzeile und Tabs. |
| Ab welcher Breite nebeneinander | N1 · immer mit Seitenleiste | Sobald die Seitenleiste sichtbar ist (ab 840 pt). Auf dem Duo-Simulator prüfen; ist es dort zu eng, auf N2 (ab 1100 pt) wechseln. |
| Einstellungen nebeneinander | R1 · erste Seite gewählt | Einstellungen in derselben Aufteilung. Rechts ist zu Beginn das Profil gewählt (Kommentar), die Fläche ist nie leer. |

## Abgelehnt

| Frage | Variante | Grund |
|---|---|---|
| Profil | P2 · Profilkarte, P3 · Arbeitskontext | nicht gewählt |
| Profilkopf in den Einstellungen | E1 · nur Titel | nicht gewählt |
| Kopf der Qualifikationen | Q2 · Kennzahl je Art, Q3 · Titel und Filter | Q3 verworfen, weil es die Filter noch nicht gibt |
| Qualifikationen auf dem iPhone | O2 · nur mit Seitenleiste | nicht gewählt |
| Liste und Detail | L1 · Kopf nur über der Liste, L3 · Detail als Karte | nicht gewählt |
| Einstellungen rechts | R2 · Hinweis „Bereich auswählen“ | nicht gewählt |

Nachtrag nach Durchsicht auf dem Duo-Simulator (2026-10-09):

- N1 trägt auf dem Duo, es bleibt dabei.
- Auf Faltgeräten liegt die Teilung zwischen Liste und Detail auf dem Falz, bei den Mitgliedern wie in den Einstellungen. Halb aufgeklappt ergibt das zwei Buchseiten: links die Seitenleiste und die Liste, rechts das Detail und der Systemrand des Duo.
- iOS meldet die Lage des Falzes nicht. Die App erkennt die Innenfläche des Duo an einem quer liegenden iPhone-Fenster, das mindestens 600 pt hoch ist, und nimmt die Mitte. Auf Android gilt der gemeldete Falz bzw. das Scharnier, ein Spalt bleibt frei.
- Bleiben links oder rechts weniger als 280 pt, gelten die üblichen Listenbreiten (320 bzw. 360 pt).

## Offen

- Der Suchkopf der Mitglieder (L2) läuft über beide Seiten und damit über den Falz.
