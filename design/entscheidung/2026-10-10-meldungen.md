# Meldungen

- **Datum:** 2026-10-10
- **Runden:** 1
- **Anlass:** Die Meldungsansicht der App (Karte, Urgent-Banner, Liste) soll überarbeitet werden; #210 klärt dazu den Urgent-Kanal.
- **Umsetzung:** noch kein PR; `notification_card.dart`, `notifications_page.dart`, Urgent-Banner in `navigation_home.page.dart`

## Entschieden

| Frage | Ergebnis | Kurz beschrieben |
|---|---|---|
| Meldungskarte | K2: Weiß mit Streifen | Neutrale Karte, links ein farbiger Streifen je Priorität, Prioritäts-Label in Kapitälchen über dem Titel, Datum unten, Aktionen als Pillen (Mehr erfahren, Bestätigen). |
| Urgent-Banner | B3: Seitenzähler | Das Banner über den Tabs zeigt eine Urgent-Meldung mit der Zeile „1 von 3 · Alle ansehen“. Nach dem Bestätigen erscheint die nächste. |
| Meldungsliste | L2: Gruppen mit Überschrift | Abschnitte „Dringend“, „Hinweise“, „Information“ mit Zähler und kleinem Abstand statt Trennlinie. Aktualisieren per Wischen, „Gelesene zurücksetzen“ im Menü (⋯). |
| Leerzustand | E2: Symbol und Hinweis | Haken-Symbol, „Alles gelesen“, Zeitpunkt der letzten Prüfung. |

Zusätzliche Vorgaben:

- Jede Meldung ist bestätigbar und danach weg. Ausnahme ist die Sperre durch ein erforderliches Update.
- Die Meldungsseite ist nur über den Hinweis in den Einstellungen erreichbar, solange Meldungen vorliegen. Der Leerzustand erscheint deshalb nur direkt nach dem Bestätigen der letzten Meldung. Dort steht „Gelesene wieder anzeigen“ als Rückgängig-Aktion, ohne dauerhaften Einstieg bei leerem Stand.

## Abgelehnt

| Frage | Variante | Grund |
|---|---|---|
| Meldungskarte | K0, K1, K3 | nicht gewählt |
| Urgent-Banner | B1, B2 | nicht gewählt |
| Meldungsliste | L1 | nicht gewählt |
| Leerzustand | E1 | nicht gewählt, E2 wird auf den erreichbaren Fall verschlankt |

## Offen

- nichts
