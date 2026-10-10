# Admin-Übersicht Betrieb

`GET /admin/betrieb` ist eine Übersicht für den Betreiber. Sie nutzt denselben Zugang, dieselben Header (`Cache-Control: no-store`, `X-Robots-Tag: noindex`, Content-Security-Policy ohne Skripte) und dieselbe Begrenzung pro IP wie `/admin` (siehe `monatsreport.md`). Ohne Zugangsdaten gibt es die Route nicht (404). Gestaltung: `design/entscheidung/2026-10-10-admin-betrieb.md` und `design/entscheidung/2026-10-10-admin-pflege.md`.

## Inhalt

- **Prüfung:** Zusammenfassung und eine Zeile je Befund, Fehler vor Warnungen.
  - Meldungen und Versionen nach den Regeln aus `app_feeds.md`, dazu: Versionen einer Plattform fehlen.
  - MongoDB nicht erreichbar.
- **Betrieb:** MongoDB erreichbar, letzter Snapshot-Eingang und Anzahl der letzten 7 Tage, letztes Backup, letztes Bundesaggregat, letzter Monatsreport, nächste Löschung. Die Serverversion (`GIT_SHA`) steht nur im Kopf der Seite. Jede Kachel hat eine aufklappbare Erklärung (ohne Skript), was der Wert bedeutet und wie oft er sich ändert.
- **Nächste Löschung:** früheres Ablaufdatum von ältestem Rohsnapshot (Eingang plus 14 Monate) und frühester Installation (letzte erfolgreiche Sendung, sonst Anlage, plus 14 Monate), dazu beide Termine und die Zahl gespeicherter Installationen. Gelöscht wird über die TTL-Indizes, nicht durch diese Seite.
- **Inhalte für die App:** eine Karte mit der Zahl der Meldungen je Status, `latest` je Plattform mit Hinweis auf ein aktives Sicherheitsupdate, Zeitpunkt der letzten Änderung und Links auf `/admin/meldungen` und `/admin/versionen`.

Die Navigation aller Admin-Seiten: Statistik · Betrieb · Meldungen · Versionen.
