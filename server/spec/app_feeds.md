# Meldungen und Versionen für die App

Der Server hält die Meldungen (Pull-Notifications) und die Versionsangaben der App in MongoDB. Die App lädt sie über eine öffentliche Schnittstelle, der Betreiber pflegt sie im Admin per Formular. Vorher lagen sie als `docs/notifications.json` und `docs/version.json` auf GitHub Pages. Gestaltung: `design/entscheidung/2026-10-10-admin-pflege.md`.

## Schnittstelle für die App

Beide Endpunkte sind ohne Login erreichbar und liefern dasselbe Format wie die früheren Dateien, damit der Parser der App unverändert bleibt.

| Endpunkt | Antwort |
|---|---|
| `GET /app/notifications` | `{"items": [...]}`, neueste zuerst. Je Meldung `id`, `type`, `platform`, `title{de,en}`, `body{de,en}`, `created_at`, `updated_at`, optional `starts_at`, `ends_at`, `external_link`, `deep_link`. Ohne Meldungen `{"items": []}`. |
| `GET /app/version` | je Plattform `android` und `ios` die Felder `latest`, `min_supported`, `store_url`, optional `security{min_version, betrifft, betrifft_en, daten_loeschen}`. Fehlt eine Plattform, fehlt ihr Eintrag; fehlen beide, antwortet der Endpunkt mit 404 und die App behält ihren letzten Stand. |

- Abgelaufene Meldungen bleiben in der Antwort, bis sie gelöscht werden. Die App filtert selbst nach Zeitraum und Plattform.
- `ETag` aus dem Inhalt, `Cache-Control: no-cache`. Mit passendem `If-None-Match` antwortet der Server mit 304.
- Rate-Limit: 600 Anfragen je Zeitfenster und IP, weil sich viele Apps eine IP teilen können.
- Das Request-Log enthält wie überall keine IP.

## Speicher

- `app_notifications`: ein Dokument je Meldung, `_id` ist die Meldungs-ID.
- `app_versions`: ein Dokument je Plattform, `_id` ist `android` oder `ios`.
- Die Daten sind nicht personenbezogen und haben keine Speicherfrist. Sie stecken im täglichen Backup.
- Gespeichert wird nur, wenn der Stand noch der gelesene ist (`updated_at`). Sonst zeigt das Formular „Inzwischen von anderer Stelle geändert“.

## Pflege im Admin

Gleicher Zugang, gleiche Header und gleiche Begrenzung wie `/admin`. Ohne Zugangsdaten gibt es die Routen nicht (404). Es gibt keine Skripte, nur Formulare.

- `GET /admin/meldungen`: Liste mit Status (aktiv, geplant, abgelaufen) und „+ Neue Meldung“.
- `GET /admin/meldungen/neu`, `GET /admin/meldungen/:id`: Formular mit Typ, Plattform, Titel und Text je Deutsch und Englisch, Zeitraum in deutscher Zeit, Ziel in der App oder externer Link.
- Die ID einer neuen Meldung entsteht aus dem deutschen Titel, wenn das Feld leer bleibt (bei Kollision mit `-2`, `-3` …). Danach ist sie fest, weil die App bestätigte Meldungen über die ID merkt. `neu` ist reserviert.
- `GET /admin/meldungen/:id/loeschen`: Rückfrage, `POST` löscht.
- `GET /admin/versionen`: beide Plattformen nebeneinander, das Sicherheitsupdate als aufklappbarer Bereich.
- Ablauf jeder Änderung: Formular → `POST …/vorschau` → Vorschau → `POST …` mit `aktion=speichern` oder `aktion=zurueck` → Redirect 303.
  - Mit Fehlern zeigt die Vorschau das Formular mit den Eingaben und den Fehlern am Feld (422).
  - Die Vorschau zeigt die Wirkung in Klartext, bei Meldungen dazu die Karte, wie die App sie zeigt, auf Deutsch und Englisch.

## Prüfregeln

Fehler verhindern das Speichern, Warnungen nicht.

- **Meldung, Fehler:** ID nicht `[a-z0-9-]`, höchstens 64 Zeichen, oder schon vergeben; Typ nicht `info`, `warn` oder `urgent`; Plattform nicht `all`, `android` oder `ios`; Titel Deutsch oder Englisch fehlt oder ist länger als 120 Zeichen; Text länger als 1000 Zeichen; Zeitpunkt ungültig (auch eine Zeit, die es wegen der Zeitumstellung nicht gibt); „Bis“ nicht nach „Ab“; externer Link nicht https; Ziel in der App nicht in der Liste der Ziele, die die App öffnet (`erlaubteMeldungsZiele`).
- **Meldung, Warnung:** Text nur in einer Sprache; abgelaufen; Ziel in der App und externer Link zugleich (die App öffnet dann nur das Ziel).
- **Version, Fehler:** `latest` oder `min_supported` keine Version `x.y.z`; `min_supported` über `latest`; Store-Adresse kein https-Link auf `play.google.com` bzw. `apps.apple.com`; bei aktivem Sicherheitsupdate erste behobene Version keine Version `x.y.z` oder „Betrifft“ auf Deutsch fehlt.
- **Version, Warnung:** „Betrifft“ auf Englisch fehlt; erste behobene Version über `latest`; Sicherheitsupdate neu oder mit neuer Version (Frage, ob die Version schon im Store ist).

## Schutz der Formulare

Der Browser schickt Basic Auth bei jeder Anfrage an die Seite mit, auch wenn eine fremde Seite das Formular abschickt. Deshalb gilt für jeden `POST`:

- Das Feld `csrf` muss den Wert enthalten, den nur angemeldete Seiten ausliefern (HMAC aus dem Passwort-Hash).
- Schickt der Browser `Sec-Fetch-Site`, muss es `same-origin` sein.
- Schickt er einen `Origin` (nicht `null`), muss dessen Host dem `Host` der Anfrage entsprechen. Hinter Caddy mit `Referrer-Policy: no-referrer` ist `Origin` bei Formularen meist `null`.
- Sonst 403. Die Content-Security-Policy erlaubt Formulare nur an die eigene Adresse (`form-action 'self'`).

## Telegram

Nach jedem Speichern oder Löschen schickt der Server eine Nachricht mit Überschrift („NaMi-App: Meldung angelegt“, „… geändert“, „… gelöscht“, „NaMi-App: Versionen iOS geändert“), den Zeilen der Wirkung und einem Link auf die Pflegeseite (`PUBLIC_BASE_URL`). Es gelten dieselben Env-Keys wie für den Monatsreport (`REPORT_TELEGRAM_BOT_TOKEN`, `REPORT_TELEGRAM_CHAT_ID`); ohne sie gibt es keine Nachricht. Die Nachricht läuft im Hintergrund, ein Fehler dort macht die Änderung nicht rückgängig und wird geloggt.
