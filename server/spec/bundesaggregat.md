# Bundesaggregat

## API-Vertrag

- Endpunkt: `GET /aggregates/bund/latest`
- Header:
  - `X-Sender-Id: <installation_id>`: dieselbe ID, die beim Senden als `sender_id` verwendet wird
  - `Authorization: Bearer <installation_secret>`
- Erfolgsantwort: `200 OK`
- Fehlerantworten:
  - `401` mit `missing_sender_credentials` oder `invalid_sender_credentials`
  - `403` mit `not_participating`, wenn die Installation noch nie oder seit mehr als 14 Tagen keinen Snapshot erfolgreich gesendet hat
  - `429` mit `rate_limited`

## Antwort

```json
{
  "status": "ok",
  "aggregation_type": "bund",
  "aggregation_week": "2026-W40",
  "generated_at": "2026-09-29T08:00:00.000Z",
  "participating_stamm_count": 42,
  "min_stamm_count": 5,
  "data_as_of": {
    "oldest": "2026-08-01T10:00:00.000Z",
    "newest": "2026-09-29T07:59:00.000Z"
  },
  "notice": "Annäherung aus freiwillig geteilten Stammesdaten teilnehmender App-Nutzer. Keine amtliche und keine repräsentative Statistik.",
  "metrics": {
    "biber": {
      "gesamt": { "sum": 310, "stamm_count": 40, "median": 7 },
      "divers": { "sum": null, "stamm_count": 3, "median": null }
    }
  }
}
```

- `status` ist `ok` oder `insufficient_participation`. Bei `insufficient_participation` ist `metrics` gleich `null`.
- `metrics` hat dieselbe Struktur wie `metrics` im Stammes-Snapshot. Jede Kennzahl enthält:
  - `sum`: Summe über alle Stämme mit Wert
  - `stamm_count`: Anzahl der Stämme, die für diese Kennzahl einen Wert geliefert haben
  - `median`: Median über diese Stämme
- Kennzahlen, zu denen weniger als `min_stamm_count` Stämme Werte geliefert haben, werden mit `sum` und `median` gleich `null` ausgeliefert, damit einzelne Stämme nicht rückführbar sind.

## Fachliche Regeln

- Grundlage ist pro Stamm genau ein effektiver Stand: der Snapshot mit dem neuesten `source_data_as_of`, bei Gleichstand der mit dem neuesten `sent_at`, unabhängig davon, welche Installation ihn gesendet hat.
- Ein Stamm zählt nur, wenn sein effektiver Stand höchstens zwei Monate alt ist (bezogen auf `source_data_as_of`).
- Das Aggregat wird nach jedem neu gespeicherten Snapshot und beim Serverstart für die aktuelle ISO-Woche materialisiert. Die Read-API rechnet nicht live auf Rohsnapshots.
- Ein Widerruf in der App stoppt nur weitere Sendungen. Bereits gesendete Daten bleiben im MVP erhalten und fallen nach zwei Monaten ohne neuen Snapshot aus dem Aggregat.
