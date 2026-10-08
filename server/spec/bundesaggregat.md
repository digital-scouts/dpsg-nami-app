# Bundesaggregat

## API-Vertrag

- Endpunkt: `GET /aggregates/bund/latest`
- Header:
  - `X-Sender-Id: <installation_id>`: dieselbe ID, die beim Senden als `sender_id` verwendet wird
  - `Authorization: Bearer <installation_secret>`
- Erfolgsantwort: `200 OK`
- Fehlerantworten:
  - `401` mit `missing_sender_credentials` oder `invalid_sender_credentials`
  - `403` mit `not_participating`, wenn die Installation noch nie oder seit mehr als 30 Tagen keinen Snapshot erfolgreich gesendet hat. Eine Teilnahme ohne Werte zählt dabei als Snapshot.
  - `429` mit `rate_limited`

## Antwort

```json
{
  "status": "ok",
  "aggregation_type": "bund",
  "aggregation_week": "2026-W40",
  "generated_at": "2026-09-28T03:00:00.000Z",
  "teilnehmende_staemme_mindestens": 40,
  "min_stamm_count": 5,
  "data_as_of": {
    "oldest": "2026-08-01T00:00:00.000Z",
    "newest": "2026-09-27T00:00:00.000Z"
  },
  "notice": "Annäherung aus freiwillig geteilten Stammesdaten teilnehmender App-Nutzer. Keine amtliche und keine repräsentative Statistik.",
  "metrics": {
    "biber": {
      "gesamt": { "durchschnitt": 7.8, "median": 7 },
      "weiblich": { "durchschnitt": 3.6, "median": 4, "anteil": 46 },
      "divers": { "durchschnitt": null, "median": null, "anteil": null }
    },
    "alle_stufen": {
      "gesamt": { "durchschnitt": 61.4, "median": 58 },
      "maennlich": { "durchschnitt": 30.1, "median": 29, "anteil": 49 }
    },
    "kuraten": { "durchschnitt": 0.6, "median": 1 }
  },
  "gruppen_je_stufe": {
    "woelflinge": {
      "gruppen_pro_stamm": { "durchschnitt": 1.4, "median": 1 },
      "mitglieder": {
        "gesamt": { "durchschnitt": 13.6, "median": 13 },
        "weiblich": { "durchschnitt": 6.1, "median": 6, "anteil": 45 }
      },
      "leitende": {
        "gesamt": { "durchschnitt": 3.1, "median": 3 }
      }
    }
  }
}
```

- `status` ist `ok` oder `insufficient_participation`. Bei `insufficient_participation` sind `metrics`, `gruppen_je_stufe` und `teilnehmende_staemme_mindestens` gleich `null`; die App zeigt dann „unter `min_stamm_count` Stämme“.
- `teilnehmende_staemme_mindestens` nennt die Zahl der teilnehmenden Stämme nur als Untergrenze: unter 50 auf Vielfache von 5, ab 50 auf Vielfache von 10 abgerundet, nie unter `min_stamm_count`.
- `data_as_of` nennt den ältesten und neuesten Eingang der verwendeten Teile, nur tagesgenau.
- **Keine Zählwerte:** Ausgeliefert werden nur gerundete Ergebnisse, keine Summen und keine Zahl der Stämme oder Gruppen je Kennzahl. Exakte Zählwerte machten die Differenz zweier Abrufe zum exakten Beitrag einzelner Stämme.
- `metrics` enthält die stammweiten Kennzahlen aus `metrics` im Stammes-Snapshot sowie die daraus abgeleiteten Stufenwerte `biber` … `rover` und `leitende_biber` … `leitende_rover` (Stufengröße je Stamm) und `alle_stufen` (Mitglieder aller Stufen je Stamm nach Geschlecht). Jede Kennzahl enthält:
  - `durchschnitt`: Durchschnitt je Stamm mit Wert, eine Nachkommastelle
  - `median`: Median über diese Stämme, ganze Zahl
  - `anteil`: nur bei Feldern neben einem `gesamt` (Geschlecht, Leitende nach Alter, Beitragsarten): Anteil an `gesamt` in ganzen Prozent, berechnet aus den Summen über alle Stämme
- Kennzahlen, zu denen weniger als `min_stamm_count` Stämme Werte geliefert haben, werden mit allen Werten gleich `null` ausgeliefert, damit einzelne Stämme nicht rückführbar sind.
- Für `alle_stufen` trägt ein Stamm ohne Gruppe einer Stufe dort 0 bei. Stämme, bei denen eine Stufe unvollständig ist, fehlen.
- `gruppen_je_stufe` beschreibt die Gruppengröße je Stufe, also Meuten, Trupps, Runden usw. Grundlage sind alle aktiven effektiven Gruppen mit Wert:
  - `gruppen_pro_stamm`: wie viele aktive Gruppen dieser Stufe ein Stamm hat (über alle Stämme, die mindestens eine haben)
  - `mitglieder` und `leitende` je Geschlechterfeld: `durchschnitt` und `median` je Gruppe, `anteil` wie oben
  - Die Unterdrückung richtet sich nach der Anzahl **verschiedener Stämme**, nicht nach der Anzahl der Gruppen. Sonst wären etwa fünf Meuten eines einzigen Stammes rückführbar.

## Fachliche Regeln

- Grundlage ist pro Stamm genau ein effektiver Stand, zusammengeführt aus allen Snapshots, die in den letzten zwei Monaten eingegangen sind (siehe `stammes_snapshot.md`, Abschnitt Effektiver Stand mit Haltefrist).
- Teilnehmend ist ein Stamm, der mindestens eine aktive Gruppe mit Wert oder stammweite Kennzahlen beiträgt, auch wenn er nur Gruppenwerte geliefert hat.
- **Mindestgrößen:** Gruppen mit höchstens 2 Mitgliedern (`mitglieder.gesamt`, ohne Leitende) gelten als nicht aktiv und zählen nirgends, auch nicht für Stufensummen und `gruppen_pro_stamm`. Eine Stufe ohne aktive Gruppe zählt für diese Stufe nicht als liefernder Stamm. Ein Stamm mit weniger als 5 Mitgliedern (`aktive_mitglieder.gesamt`, ohne Gesamtbericht die Summe seiner aktiven Gruppen) liefert keine stammweiten Kennzahlen und keine Stufenwerte, sondern nur seine aktiven Gruppen.
- Teilnahme gilt unabhängig von der Abdeckung: Auch wer nur Gruppenwerte sendet, darf lesen.
- Das Aggregat wird nicht nach jedem Snapshot neu berechnet, sonst ergäbe die Differenz zweier Abrufe den Beitrag eines einzelnen Stammes. Stattdessen gibt es zwei feste Läufe:
  - **Wochenlauf** (Montag 03:00 UTC): Alle Stämme werden aus den Rohsnapshots neu zusammengeführt. Ihre Stände werden bis zum nächsten Wochenlauf eingefroren (`effective_states`).
  - **Nachtlauf** (täglich 03:00 UTC): Nur Stämme, die noch nicht veröffentlicht sind, kommen dazu. Bestehende Stämme bleiben auf dem Stand des Wochenlaufs, auch beim Zwei-Monats-Fenster. Ohne neue Stämme ändert sich nichts.
  - Der Server prüft stündlich und beim Start, ob ein Lauf fällig ist, und holt verpasste Läufe nach. Ein Neustart ohne fälligen Lauf rechnet nicht neu. Eine Löschung auf Anfrage veröffentlicht sofort neu, damit die Daten nicht bis zum Wochenlauf sichtbar bleiben.
  - Hinweis: Kommt in einer Nacht genau ein neuer Stamm dazu, zeigt die Differenz seine vergröberten Werte. Zuordnen kann sie nur, wer weiß, welcher Stamm neu ist. Dieses Restrisiko ist bewusst akzeptiert.
- Die Read-API rechnet nicht live auf Rohsnapshots, sondern liefert das zuletzt veröffentlichte Aggregat.
- Ein Widerruf in der App stoppt nur weitere Sendungen. Bereits gesendete Daten fallen nach zwei Monaten ohne neuen Snapshot aus dem Aggregat. Gelöscht werden sie nach Ablauf der Speicherfrist (14 Monate, siehe `stammes_snapshot.md`) oder vorher auf Anfrage per Mail mit der Installations-ID (`deploy/README.md`, Abschnitt Anfragen Betroffener).
