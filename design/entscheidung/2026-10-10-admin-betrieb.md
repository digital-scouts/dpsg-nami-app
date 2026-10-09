# Admin-Übersicht Betrieb

- **Datum:** 2026-10-10
- **Runden:** 1
- **Anlass:** Der Betreiber braucht eine kleine, schreibgeschützte Übersicht über Pull-Notifications, `version.json` und den Serverbetrieb, mit demselben Login wie `/admin`.
- **Umsetzung:** noch kein PR; `server/src/modules/admin/` (`/admin/betrieb`)

## Entschieden

| Frage | Ergebnis | Kurz beschrieben |
|---|---|---|
| Aufbau | A1: Eine Seite, Prüfung zuerst | Kopf mit Stand und Serverversion, Umschalter Statistik/Betrieb. Danach die Feed-Prüfung als Zusammenfassung (Fehler, Warnungen) mit je einer farbigen Zeile pro Befund, dann Betrieb als Kacheln, dann Pull-Notifications, dann Versionen mit Store-Check je Plattform. |
| Pull-Notifications | M2: Karten | Eine Karte je Meldung: deutscher Titel, englischer Titel darunter (oder Hinweis „EN fehlt“), Status-Pille aktiv/geplant/abgelaufen, Metazeile mit ID, Typ, Plattform, Zeitraum und Link. |

Zusätzliche Vorgaben:

- Nur Lesen, keine Formulare, keine Skripte, Daten immer escaped.
- Store-Check prüft nur die Plausibilität der Store-Adresse (https, erwarteter Host), keinen Abgleich mit dem Store.

## Abgelehnt

| Frage | Variante | Grund |
|---|---|---|
| Aufbau | A2: Kacheln zuerst | nicht gewählt |
| Pull-Notifications | M1: Tabelle | nicht gewählt, mobil zu eng |

## Offen

- nichts
