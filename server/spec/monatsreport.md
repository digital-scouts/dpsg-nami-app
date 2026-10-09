# Monatsreport

Der Server hält monatlich fest, wie groß der Kreis der Teilnehmenden ist, damit sich abschätzen lässt, ab wann regionale Vergleiche (Diözese, Bezirk) tragfähig sind. Der Bericht enthält nur Zählwerte und die bei den Snapshots gespeicherten DV- und Bezirks-IDs, keine Stammes- oder Personendaten.

## Auslieferung

- **Web-Ansicht** `GET /admin`, geschützt mit HTTP Basic Auth (ein einziger Zugang aus `ADMIN_USER` und `ADMIN_PASSWORD_HASH`, keine Accountverwaltung). Sie zeigt den laufenden Monat live bis zum aktuellen Zeitpunkt, die Regionen und den Verlauf aller gespeicherten Monate. Antworten tragen `Cache-Control: no-store`, `X-Robots-Tag: noindex` und eine Content-Security-Policy ohne Skripte. Die Route ist pro IP begrenzt. Ohne Zugangsdaten gibt es die Route nicht (404). Mit demselben Zugang zeigt `GET /admin/betrieb` Betrieb und Feeds der App (`admin_betrieb.md`).
- **Telegram:** Nach Monatsende eine kurze Nachricht mit den Kernzahlen und dem Link auf `/admin`, sofern `REPORT_TELEGRAM_BOT_TOKEN` und `REPORT_TELEGRAM_CHAT_ID` gesetzt sind.

## Zeitpunkt

- Ein Scheduler im Serverprozess prüft beim Start und danach alle sechs Stunden, ob der Bericht des Vormonats (UTC) schon gespeichert ist (Collection `monthly_reports`, ein Dokument je Monat). Fehlt er, wird er berechnet und gespeichert. Fehlen ältere Monate, werden bis zu zwölf Monate rückwirkend aus den Rohdaten berechnet; leere Monate vor den ersten Daten werden übersprungen.
- Die Telegram-Nachricht geht nur für den Vormonat raus, genau einmal (`notified_at`). Schlägt sie fehl, versucht es der nächste Durchlauf erneut.
- Die Mock-Instanz legt keine Berichte an.
- `npm run report -- --month YYYY-MM` gibt den Bericht als Text aus (im Container, siehe `deploy/README.md`; lokal `npm run report:dev`). Ohne `--month` gilt der Vormonat.

## Inhalt

Stichtag ist das Monatsende, beim laufenden Monat der aktuelle Zeitpunkt. Der effektive Stand wird dafür so berechnet, als wäre der Stichtag „jetzt“ (Zwei-Monats-Fenster bis zum Stichtag). Zu jeder Zahl steht der Wert des Vormonats daneben.

- **Installationen**
  - aktive Installationen: Sender mit mindestens einem neu gespeicherten Snapshot im Monat
  - neue Installationen: im Monat erstmals registrierte Sender
  - Installationen gesamt (Sender innerhalb der Speicherfrist von 14 Monaten)
- **Stämme**
  - teilnehmende Stämme (effektiver Stand am Stichtag)
  - davon `vollstaendig`, `nur_gruppen`, `gemischt`
  - Stämme mit mehreren Sendern im Fenster
  - Stämme ohne verwertbare Werte (nur Teilnahmen ohne Werte oder nur inaktive Gruppen); sie zählen nicht als teilnehmend
- **Gruppen**
  - aktive Gruppen mit Wert (mehr als 2 Mitglieder), gesamt und je Stufe
  - Gruppen, die mehr als ein Sender abgedeckt hat; dabei nicht verwendete Gruppenwerte anderer Sender
  - Stufen, die keine Installation vollständig abgedeckt hat (Anzahl Stamm-Stufen-Paare)
- **Regionen**
  - Stämme je DV und je Bezirk (IDs wie gespeichert, ohne ID als „unbekannt“)
  - Markierung, welche DVs und Bezirke schon `MIN_STAMM_COUNT_FOR_READ` Stämme erreichen

## Konfiguration

| Env-Key | Bedeutung |
|---|---|
| `ADMIN_USER` | Benutzername für `/admin` |
| `ADMIN_PASSWORD_HASH` | scrypt-Hash des Passworts, erzeugt mit `npm run admin:hash` (Format `scrypt:<salt>:<hash>`) |
| `REPORT_TELEGRAM_BOT_TOKEN` | Token des Telegram-Bots |
| `REPORT_TELEGRAM_CHAT_ID` | Chat, in den der Bot schreibt |
| `PUBLIC_BASE_URL` | Basis-URL für den Link in der Nachricht, z. B. `https://namiapp.scout-link.de` |

`ADMIN_USER` und `ADMIN_PASSWORD_HASH` bzw. Token und Chat-ID müssen jeweils gemeinsam gesetzt sein, sonst startet der Server nicht.
