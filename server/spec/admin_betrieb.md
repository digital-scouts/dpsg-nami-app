# Admin-Übersicht Betrieb

`GET /admin/betrieb` ist eine schreibgeschützte Übersicht für den Betreiber. Sie nutzt denselben Zugang, dieselben Header (`Cache-Control: no-store`, `X-Robots-Tag: noindex`, Content-Security-Policy ohne Skripte) und dieselbe Begrenzung pro IP wie `/admin` (siehe `monatsreport.md`). Ohne Zugangsdaten gibt es die Route nicht (404). Gestaltung: `design/entscheidung/2026-10-10-admin-betrieb.md`.

## Inhalt

- **Prüfung:** Zusammenfassung und eine Zeile je Befund aus den Feeds der App, Fehler vor Warnungen.
  - `notifications.json`: Feed nicht abrufbar oder kein `{"items": [...]}`, fehlende oder doppelte `id`, unbekannter `type` oder `platform`, fehlender deutscher oder englischer Titel oder Text, ungültige Daten, `ends_at` nicht nach `starts_at`, abgelaufene Einträge, `external_link` ohne https, `deep_link` ohne führenden `/`.
  - `version.json`: Plattform fehlt, `latest` oder `min_supported` keine Version `x.y.z`, `latest` unter `min_supported`, `store_url` kein https-Link auf `play.google.com` bzw. `apps.apple.com`.
  - MongoDB nicht erreichbar.
- **Betrieb:** MongoDB erreichbar, letzter Snapshot-Eingang und Anzahl der letzten 7 Tage, letztes Backup, letztes Bundesaggregat, letzter Monatsreport, nächste Löschung, Zeitpunkt des Feed-Abrufs. Die Serverversion (`GIT_SHA`) steht nur im Kopf der Seite. Jede Kachel hat eine aufklappbare Erklärung (ohne Skript), was der Wert bedeutet und wie oft er sich ändert.
- **Nächste Löschung:** früheres Ablaufdatum von ältestem Rohsnapshot (Eingang plus 14 Monate) und frühester Installation (letzte erfolgreiche Sendung, sonst Anlage, plus 14 Monate), dazu beide Termine und die Zahl gespeicherter Installationen. Gelöscht wird über die TTL-Indizes, nicht durch diese Seite.
- **Pull-Notifications:** eine Karte je Eintrag mit Titel DE/EN, Status (aktiv, geplant, abgelaufen), ID, Typ, Plattform, Zeitraum und Link.
- **Versionen und Store-Check:** je Plattform `latest`, `min_supported` und Store-Adresse. Der Store selbst wird nicht abgefragt.

## Abruf der Feeds

Die Feeds liegen auf GitHub Pages, nicht auf dem Server. Der Server holt sie per HTTPS (5 s Timeout, keine Weiterleitungen) höchstens alle fünf Minuten und hält sie nur im Speicher. Ein Fehler beim Abruf erscheint als Befund, die Seite bleibt erreichbar.

| Env-Key | Bedeutung |
|---|---|
| `ADMIN_NOTIFICATIONS_URL` | Quelle von `notifications.json`, Standard `https://digital-scouts.github.io/dpsg-nami-app/notifications.json`, nur https |
| `ADMIN_VERSION_URL` | Quelle von `version.json`, Standard `https://digital-scouts.github.io/dpsg-nami-app/version.json`, nur https |
