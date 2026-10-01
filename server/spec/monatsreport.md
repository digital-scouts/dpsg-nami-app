# Monatsreport

Der Server schickt einmal im Monat eine Mail an den Betreiber. Sie beschreibt den Kreis der Teilnehmenden, damit sich abschätzen lässt, ab wann regionale Vergleiche (Diözese, Bezirk) tragfähig sind. Der Report enthält nur Zählwerte und die bei den Snapshots gespeicherten DV- und Bezirks-IDs, keine Stammes- oder Personendaten.

## Zeitpunkt

- Berichtet wird jeweils der abgeschlossene Vormonat (UTC).
- Ein Scheduler im Serverprozess prüft beim Start und danach alle sechs Stunden, ob der Report des Vormonats schon verschickt wurde. Der Merker liegt in `ops_status` unter `_id: "monthly_report"` (`last_reported_month`, `sent_at`). So geht nach Neustarts oder Ausfällen kein Monat verloren und keiner wird doppelt verschickt.
- Ohne vollständige Mail-Konfiguration ist der Report aus (z. B. auf der Mock-Instanz).
- `npm run report -- --month YYYY-MM [--dry-run]` erzeugt den Report von Hand. Mit `--dry-run` wird er nur ausgegeben und nicht verschickt; der Merker bleibt unverändert.

## Inhalt

Stichtag ist das Monatsende. Der effektive Stand wird dafür so berechnet, als wäre der Stichtag „jetzt“ (Zwei-Monats-Fenster bis zum Stichtag). Zu jeder Zahl steht der Wert des Vormonats daneben.

- **Installationen**
  - aktive Installationen: Sender mit mindestens einem neu gespeicherten Snapshot im Monat
  - neue Installationen: im Monat erstmals registrierte Sender
  - Installationen gesamt
- **Stämme**
  - teilnehmende Stämme (effektiver Stand am Stichtag)
  - davon `vollstaendig`, `nur_gruppen`, `gemischt`
  - Stämme mit mehreren Sendern im Fenster
- **Gruppen**
  - Gruppen mit Wert, gesamt und je Stufe
  - Gruppen, die mehr als ein Sender abgedeckt hat; dabei verworfene ältere Gruppenwerte
  - Stufen, die wegen fehlender Gruppenwerte `null` sind (Anzahl Stamm-Stufen-Paare)
- **Regionen**
  - Stämme je DV und je Bezirk (IDs wie gespeichert, ohne ID als „unbekannt“)
  - Markierung, welche DVs und Bezirke schon `MIN_STAMM_COUNT_FOR_READ` Stämme erreichen

## Konfiguration

| Env-Key | Bedeutung |
|---|---|
| `REPORT_SMTP_HOST` | SMTP-Server; ohne Wert ist der Report aus |
| `REPORT_SMTP_PORT` | Port, Standard `587` (STARTTLS); bei `465` wird TLS direkt verwendet |
| `REPORT_SMTP_USER`, `REPORT_SMTP_PASS` | Zugangsdaten, optional |
| `REPORT_MAIL_FROM` | Absender |
| `REPORT_MAIL_TO` | Empfänger, mehrere durch Komma getrennt |

Ist `REPORT_SMTP_HOST` gesetzt, müssen auch `REPORT_MAIL_FROM` und `REPORT_MAIL_TO` gesetzt sein, sonst startet der Server nicht.
