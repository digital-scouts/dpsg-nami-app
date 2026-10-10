# Admin-Pflege: Meldungen und Versionen

- **Datum:** 2026-10-10
- **Runden:** 1
- **Anlass:** Meldungen und Versionen kommen nicht mehr als Dateien von GitHub Pages, sondern aus der Server-Datenbank. Der Betreiber pflegt sie im Admin per Formular, nicht als JSON-Text.
- **Umsetzung:** PR #270, `server/src/modules/admin/pflegePage.ts`, `pflegeRoute.ts` (`/admin/meldungen`, `/admin/versionen`)

## Entschieden

| Frage | Ergebnis | Kurz beschrieben |
|---|---|---|
| Wo wird gepflegt? | E2: Eigene Menüpunkte | Navigation Statistik · Betrieb · Meldungen · Versionen. Betrieb behält Prüfung und Kacheln und fasst Meldungen und Versionen in einer Karte mit Links zusammen. Meldungen ist eine Liste von Karten mit „+ Neue Meldung“ und „Bearbeiten“ je Karte. |
| Meldungsformular | F1: Sprachen nebeneinander | Karten „Einstellungen“ (ID, Typ und Plattform als Knopfreihe), „Text“ (Deutsch links, Englisch rechts, mobil untereinander), „Zeitraum“ (Ab/Bis in deutscher Zeit), „Link“ (Ziel in der App oder externer https-Link). Unten „Weiter zur Vorschau“, „Abbrechen“ und rechts „Löschen“. Fehler stehen rot am Feld und als Zusammenfassung oben. |
| Vorschau | V1: Wirkung + App-Ansicht | Oben die Wirkung in Klartext (kritische Zeilen rot mit Ausrufezeichen), darunter die Meldung so, wie sie in der App erscheint, auf Deutsch und Englisch, dann die Prüfbefunde, dann „Speichern“ und „Zurück zum Formular“ mit dem Hinweis auf die Telegram-Nachricht. |
| Versionen | P1: Beide Plattformen auf einer Seite | Zwei Karten Android und iOS nebeneinander, mobil untereinander, jede mit eigenem Formular und eigener Vorschau. `latest`, `min_supported` und Store-Adresse mit Hilfetext zur Wirkung. Das Sicherheitsupdate ist ein einklappbarer Bereich mit Haken „aktiv“; aktiv ist er geöffnet, rot umrandet und mit Pille „aktiv“ markiert. |

Zusätzliche Vorgaben aus den Kommentaren:

- Die Hilfetexte zu `min_supported` stellen klar, dass eine App darunter keine Sperre bekommt: einmal je Start der Dialog „Update erforderlich“ und dauerhaft eine dringende, nicht wegklickbare Meldung mit Store-Link. Gesperrt wird nur über das Sicherheitsupdate.

Festgelegt vor der Runde:

- Keine Skripte (CSP), nur Formulare, Links und `<details>`. Stil der bestehenden Admin-Seiten, nur hell.
- Jede Änderung läuft über die Vorschau und erzeugt eine Telegram-Nachricht.
- Die Meldungs-ID wird beim Anlegen aus dem Titel vorgeschlagen und ist danach fest.
- Löschen hat eine eigene Rückfrageseite, die erklärt, dass eine wiederverwendete ID für Apps mit Bestätigung als gelesen gilt.

## Abgelehnt

| Frage | Variante | Grund |
|---|---|---|
| Wo wird gepflegt? | E1: Direkt auf Betrieb | nicht gewählt |
| Meldungsformular | F2: Eine Spalte, Abschnitte | nicht gewählt |
| Vorschau | V2: Wirkung + Änderungsliste | nicht gewählt |
| Versionen | P2: Eine Plattform je Seite | nicht gewählt |

## Offen

- nichts
