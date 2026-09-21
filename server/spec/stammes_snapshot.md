# Stammes-Snapshot

## API-Vertrag

- Endpunkt: `POST /snapshots/stamm`
- Erfolgsantwort: `204 No Content`
- Fehlerantwort bei ungültiger Anfrage: `400 Bad Request`
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
    "fields": ["dv_id"]
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

## Metadaten

- schema_version
- Stamm-ID (`stamm_id`, wird nach erfolgreicher Validierung serverseitig pseudonymisiert)
- Bezirk-ID (`bezirk_id`, optional)
- DV-ID (`dv_id`)
- ID der sendenden Person (`sender_id`, wird nach erfolgreicher Validierung serverseitig pseudonymisiert)
- Datum des Sendens (sent_at)
- Datum des Datenbestands (source_data_as_of)

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
  