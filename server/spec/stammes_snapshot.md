# Stammes-Snapshot

## API-Vertrag

- Endpunkt: `POST /snapshots/stamm`
- Authentifizierung: `Authorization: Bearer <installation_secret>` (siehe Abschnitt Installations-Credentials)
- Erfolgsantwort: `204 No Content`
- Fehlerantwort bei ungültiger Anfrage: `400 Bad Request`
- Fehlerantwort bei fehlenden oder falschen Credentials: `401 Unauthorized`
- Fehlerantwort bei zu vielen Anfragen: `429 Too Many Requests`
- Ein erneut gesendeter Snapshot mit identischem Stamm, Sender und `source_data_as_of` wird nicht erneut gespeichert und liefert trotzdem `204`.
- `sent_at` und `source_data_as_of` dürfen höchstens 24 Stunden in der Zukunft liegen, sonst `invalid_datetime`.
- Unterstützte `schema_version`: `2026-04-01`
- Unbekannte Felder werden auf allen Ebenen serverseitig verworfen.
- Fehlende bekannte Kennzahlenfelder werden serverseitig wie `null` behandelt.
- IDs werden roh gesendet und im Server direkt nach erfolgreicher Validierung serverseitig pseudonymisiert.
- Für die Stammes-Plausibilisierung muss mindestens eine der Kernstufen `biber`, `woelflinge`, `jungpfadfinder`, `pfadfinder` oder `rover` einen numerischen Gesamtwert größer `0` haben.

## Fehlerformat

Ungültige Anfragen liefern eine strukturierte Fehlerantwort:

```json
{
  "error": {
    "code": "missing_required_field",
    "message": "Snapshot payload is invalid",
    "fields": ["stamm_id"]
  }
}
```

- `code` ist ein mittelgranularer Fehlercode für die primäre Fehlerklasse.
- `message` bleibt aktuell konstant auf `Snapshot payload is invalid`.
- `fields` enthält die fachlich relevanten Feldpfade der Beanstandung.

Aktuell verwendete Fehlercodes:

- `unsupported_schema_version`
- `missing_required_field`
- `invalid_datetime`
- `invalid_metric_value`
- `invalid_stamm_plausibility`
- `invalid_snapshot_payload`
- `missing_sender_credentials` (401)
- `invalid_sender_credentials` (401)
- `rate_limited` (429)
- `payload_too_large` (413), `unsupported_media_type` (415), `invalid_request` (400, z. B. ungültiges JSON)

## Installations-Credentials

- Die App erzeugt pro Installation eine zufällige Installations-ID und ein zufälliges Secret (mindestens 32 Zeichen).
- Die Installations-ID wird als `sender_id` im Payload gesendet, das Secret als Bearer-Token.
- Beim ersten erfolgreichen Senden hinterlegt der Server einen gepfefferten Hash des Secrets (Trust on First Use). Jede weitere Anfrage mit dieser `sender_id` muss dasselbe Secret verwenden.
- Die Credentials belegen keine Stammeszugehörigkeit, sondern nur die Wiedererkennung derselben Installation. Sie sind die Grundlage für die Teilnahmeprüfung der Read-API (siehe `bundesaggregat.md`).

## Metadaten

- schema_version
- Stamm-ID (`stamm_id`, wird nach erfolgreicher Validierung serverseitig pseudonymisiert)
- Bezirk-ID (`bezirk_id`, optional)
- DV-ID (`dv_id`, optional, weil die Diözese nicht in jedem Hitobito-Zugriff sicher ableitbar ist)
- Installations-ID der sendenden App (`sender_id`, wird nach erfolgreicher Validierung serverseitig pseudonymisiert)
- Datum des Sendens (sent_at)
- Datum des Datenbestands (source_data_as_of)

Zeitstempel werden im ISO-8601-Format mit `Z` oder Offset gesendet und serverseitig als UTC-Datum gespeichert.

Metadaten liegen flach auf Top-Level. Kennzahlen liegen unter `metrics`.

## Kennzahlen

In Kennzahlen sind doppelnennungen möglich. Eine Person kann Vorstand und Leitung in mehreren Stufen sein.
Die Anzahl der Leitenden ist also nicht gleich die Summe aller Leitenden in den Stufen.

- Anzahl Aktive Mitglieder
  - Anzahl normaler Beitrag
  - Anzahl familienermäßigter Beitrag
  - Anzahl sozialermäßigter Beitrag
- Anzahl Passive Mitglieder
- Anzahl Biber
  - Anzahl männliche Biber
  - Anzahl weibliche Biber
  - Anzahl diverse Biber
  - Anzahl unbekannte Geschlecht Biber
- Anzahl Wölflinge
  - Anzahl männliche Wölflinge
  - Anzahl weibliche Wölflinge
  - Anzahl diverse Wölflinge
  - Anzahl unbekannte Geschlecht Wölflinge
- Anzahl Jungpfadfinder
  - Anzahl männliche Jungpfadfinder
  - Anzahl weibliche Jungpfadfinder
  - Anzahl diverse Jungpfadfinder
  - Anzahl unbekannte Geschlecht Jungpfadfinder
- Anzahl Pfadfinder
  - Anzahl männliche Pfadfinder
  - Anzahl weibliche Pfadfinder
  - Anzahl diverse Pfadfinder
  - Anzahl unbekannte Geschlecht Pfadfinder
- Anzahl Rover
  - Anzahl männliche Rover
  - Anzahl weibliche Rover
  - Anzahl diverse Rover
  - Anzahl unbekannte Geschlecht Rover
- Anzahl Leitende
  - Anzahl Leitende unter 21 Jahren
  - Anzahl Leitende 21-30 Jahren
  - Anzahl Leitende 31-40 Jahren
  - Anzahl Leitende 41-50 Jahren
  - Anzahl Leitende 51-60 Jahren
  - Anzahl Leitende über 60 Jahren
- Anzahl Leitende Biber
  - Anzahl männliche Leitende
  - Anzahl weibliche Leitende
  - Anzahl diverse Leitende
  - Anzahl unbekannte Geschlecht Leitende
- Anzahl Leitende Wölflinge
  - Anzahl männliche Leitende
  - Anzahl weibliche Leitende
  - Anzahl diverse Leitende
  - Anzahl unbekannte Geschlecht Leitende
- Anzahl Leitende Jungpfadfinder
  - Anzahl männliche Leitende
  - Anzahl weibliche Leitende
  - Anzahl diverse Leitende
  - Anzahl unbekannte Geschlecht Leitende
- Anzahl Leitende Pfadfinder
  - Anzahl männliche Leitende
  - Anzahl weibliche Leitende
  - Anzahl diverse Leitende
  - Anzahl unbekannte Geschlecht Leitende
- Anzahl Leitende Rover
  - Anzahl männliche Leitende
  - Anzahl weibliche Leitende
  - Anzahl diverse Leitende
  - Anzahl unbekannte Geschlecht Leitende
- Anzahl nicht Leitende Erwachsene (sonstige Mitglieder)
- Anzahl Stammesvorstand
- Anzahl Kuraten
  