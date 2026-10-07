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
  },
  "gruppen_je_stufe": {
    "woelflinge": {
      "gruppen_count": 61,
      "stamm_count": 44,
      "gruppen_pro_stamm": { "sum": 61, "stamm_count": 44, "median": 1 },
      "mitglieder": {
        "gesamt": { "sum": 830, "stamm_count": 44, "gruppen_count": 61, "median": 13 }
      },
      "leitende": {
        "gesamt": { "sum": 190, "stamm_count": 44, "gruppen_count": 61, "median": 3 }
      }
    }
  }
}
```

- `status` ist `ok` oder `insufficient_participation`. Bei `insufficient_participation` sind `metrics` und `gruppen_je_stufe` gleich `null`.
- `metrics` enthält die stammweiten Kennzahlen aus `metrics` im Stammes-Snapshot sowie die daraus abgeleiteten Stufenwerte `biber` … `rover` und `leitende_biber` … `leitende_rover` (Stufengröße je Stamm). Jede Kennzahl enthält:
  - `sum`: Summe über alle Stämme mit Wert
  - `stamm_count`: Anzahl der Stämme, die für diese Kennzahl einen Wert geliefert haben
  - `median`: Median über diese Stämme
- Kennzahlen, zu denen weniger als `min_stamm_count` Stämme Werte geliefert haben, werden mit `sum` und `median` gleich `null` ausgeliefert, damit einzelne Stämme nicht rückführbar sind.
- `gruppen_je_stufe` beschreibt die Gruppengröße je Stufe, also Meuten, Trupps, Runden usw. Grundlage sind alle effektiven Gruppen mit Wert:
  - `gruppen_count`: Anzahl Gruppen der Stufe, `stamm_count`: Anzahl Stämme, aus denen sie stammen
  - `gruppen_pro_stamm`: wie viele Gruppen dieser Stufe ein Stamm hat (über alle Stämme mit Gruppenstruktur, die mindestens eine Gruppe der Stufe haben)
  - `mitglieder` und `leitende` je Geschlechterfeld: `sum` über alle Gruppen, `median` über die Gruppen, dazu `gruppen_count` und `stamm_count`
  - Die Unterdrückung richtet sich nach der Anzahl **verschiedener Stämme**, nicht nach der Anzahl der Gruppen. Sonst wären etwa fünf Meuten eines einzigen Stammes rückführbar.

## Fachliche Regeln

- Grundlage ist pro Stamm genau ein effektiver Stand, zusammengeführt aus allen Snapshots der letzten zwei Monate (siehe `stammes_snapshot.md`, Abschnitt Effektiver Stand), unabhängig davon, welche Installation sie gesendet hat.
- `participating_stamm_count` zählt alle Stämme mit effektivem Stand, auch solche, die nur Gruppenwerte geliefert haben.
- Teilnahme gilt unabhängig von der Abdeckung: Auch wer nur Gruppenwerte sendet, darf lesen.
- Das Aggregat wird nach jedem neu gespeicherten Snapshot und beim Serverstart für die aktuelle ISO-Woche materialisiert. Die Read-API rechnet nicht live auf Rohsnapshots.
- Ein Widerruf in der App stoppt nur weitere Sendungen. Bereits gesendete Daten fallen nach zwei Monaten ohne neuen Snapshot aus dem Aggregat. Gelöscht werden sie nach Ablauf der Speicherfrist (14 Monate, siehe `stammes_snapshot.md`) oder vorher auf Anfrage per Mail mit der Installations-ID (`deploy/README.md`, Abschnitt Anfragen Betroffener).
