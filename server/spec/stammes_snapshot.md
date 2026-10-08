# Stammes-Snapshot

## API-Vertrag

- Endpunkt: `POST /snapshots/stamm`
- Authentifizierung: `Authorization: Bearer <installation_secret>` (siehe Abschnitt Installations-Credentials)
- Erfolgsantwort: `204 No Content`
- Fehlerantwort bei ungültiger Anfrage: `400 Bad Request`
- Fehlerantwort bei fehlenden oder falschen Credentials: `401 Unauthorized`
- Fehlerantwort bei zu vielen Anfragen: `429 Too Many Requests`
- Ein erneut gesendeter Snapshot mit identischem Stamm, Sender, `source_data_as_of` und `schema_version` wird nicht erneut gespeichert und liefert trotzdem `204`.
- `sent_at` und `source_data_as_of` dürfen höchstens 24 Stunden in der Zukunft liegen, sonst `invalid_datetime`.
- Unterstützte `schema_version`: `2026-10-01`. Ältere Versionen werden mit `unsupported_schema_version` abgelehnt. Bereits gespeicherte Snapshots älterer Versionen bleiben bis zum Ablauf der Speicherfrist liegen, zählen aber für den effektiven Stand nicht mehr und fallen nach zwei Monaten ohnehin aus dem Fenster.
- Speicherfrist: Rohsnapshots werden 14 Monate nach Eingang (`received_at`) gelöscht, Sender 14 Monate nach ihrer letzten erfolgreichen Sendung (ohne Sendung nach der Anlage). Umgesetzt über TTL-Indizes auf dem internen Feld `expires_at`; die Frist deckt den Backfill der Monatsberichte ab. Vorher löscht der Betreiber auf Anfrage (`npm run installation -- loeschen`).
- Unbekannte Felder werden auf allen Ebenen serverseitig verworfen.
- Fehlende bekannte Kennzahlenfelder werden serverseitig wie `null` behandelt.
- IDs werden roh gesendet und im Server direkt nach erfolgreicher Validierung serverseitig pseudonymisiert.
- Plausibilisierung: Mindestens eine abgedeckte Gruppe muss bei `mitglieder.gesamt` einen Wert größer `0` haben. Ausgenommen ist die Teilnahme ohne Werte (siehe Abschnitt Abdeckung).

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
- `invalid_coverage` (Abdeckung und Gruppenliste passen nicht zusammen, siehe Abschnitt Abdeckung)
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

Metadaten liegen flach auf Top-Level. Abdeckung und Gruppen liegen ebenfalls auf Top-Level, stammweite Kennzahlen unter `metrics`.

## Abdeckung

Nicht jede sendende Person sieht den ganzen Stamm. Wer nur Leserechte auf die eigene Gruppe hat (z. B. `group_read` als Leitung einer Meute), sendet nur die Werte dieser Gruppe. Welche Gruppen abgedeckt sind, bestimmt die App aus den Hitobito-Rechten der Person; der Server prüft das nicht gegen Hitobito und kennt keine Personen.

- `abdeckung`: `"stamm"` oder `"gruppen"`
  - `stamm`: Die Person darf den ganzen Stamm lesen. Alle Gruppen sind abgedeckt, `metrics` enthält die stammweiten Kennzahlen.
  - `gruppen`: Die Person sieht nur einzelne Gruppen. `metrics` wird serverseitig vollständig verworfen, weil stammweite Werte aus einer Teilsicht falsch wären.
- `gruppen`: Liste **aller** Stufengruppen des Stammes, die die App kennt (höchstens 50). Hitobito liefert angemeldeten Personen die Gruppenstruktur unabhängig von den Personenrechten; daher kennt auch eine Teilsicht alle Gruppen.

```json
{
  "gruppe_id": "4711",
  "stufe": "woelflinge",
  "abgedeckt": true,
  "mitglieder": { "gesamt": 14, "maennlich": 7, "weiblich": 6, "divers": 0, "geschlecht_unbekannt": 1 },
  "leitende": { "gesamt": 3, "maennlich": 1, "weiblich": 2, "divers": 0, "geschlecht_unbekannt": 0 }
}
```

- `gruppe_id` wird wie `stamm_id` serverseitig pseudonymisiert. Jede ID darf nur einmal vorkommen.
- `stufe` ist einer der Werte `biber`, `woelflinge`, `jungpfadfinder`, `pfadfinder`, `rover`. Die Zuordnung leitet die App aus dem Hitobito-Gruppentyp ab. Gruppen ohne Stufe werden nicht gesendet.
- Bei `abgedeckt: false` setzt der Server `mitglieder` und `leitende` auf `null`, auch wenn Werte gesendet wurden.
- Bei `abdeckung: "stamm"` müssen alle Gruppen `abgedeckt: true` sein, sonst `invalid_coverage`.
- Bei `abdeckung: "gruppen"` darf auch keine einzige Gruppe abgedeckt sein. Das ist eine **Teilnahme ohne Werte**: Die Person will teilen, sieht aber keine Zahlen, etwa als Leitung mit `group_read`, für deren Gruppe Hitobito keine Rollen liefert. Der Snapshot liefert nur die Gruppenstruktur und berechtigt zum Lesen des Aggregats. Ein Stamm, für den nur solche Snapshots vorliegen, zählt nicht als teilnehmend.
- Eine Person kann in mehreren Gruppen derselben Stufe sein und zählt dann in jeder Gruppe.

## Kennzahlen

`metrics` enthält nur noch stammweite Kennzahlen. Stufen- und Leitendenzahlen je Stufe bildet der Server aus den Gruppen (siehe Abschnitt Effektiver Stand).

In Kennzahlen sind Doppelnennungen möglich. Eine Person kann Vorstand und Leitung in mehreren Stufen sein.

- `aktive_mitglieder`
  - `gesamt`
  - `normaler_beitrag`
  - `familienermaessigter_beitrag`
  - `sozialermaessigter_beitrag`
- `passive_mitglieder`
- `leitende` (alle Leitenden des Stammes, jede Person einmal)
  - `gesamt`
  - `unter_21`, `von_21_bis_30`, `von_31_bis_40`, `von_41_bis_50`, `von_51_bis_60`, `ueber_60`
- `nicht_leitende_erwachsene` (sonstige Mitglieder)
- `stammesvorstand`
- `kuraten`

Je Gruppe (unter `gruppen`):

- `mitglieder` und `leitende`, jeweils mit `gesamt`, `maennlich`, `weiblich`, `divers`, `geschlecht_unbekannt`

## Effektiver Stand

Pro Stamm führt der Server alle Snapshots zusammen, deren `source_data_as_of` höchstens zwei Monate alt ist. Ältere Snapshots spielen keine Rolle. „Neuer“ heißt: späteres `source_data_as_of`, bei Gleichstand späteres `sent_at`.

1. **Gruppenstruktur:** Welche Gruppen und Stufen der Stamm hat, kommt aus dem neuesten Snapshot, gleich welcher Abdeckung.
2. **Gruppenwerte:** Pro Gruppe der Struktur zählt der neueste Snapshot, der diese Gruppe abdeckt.
3. **Stufenwerte** (`biber` … `rover`, `leitende_biber` … `leitende_rover`): Summe der Gruppenwerte dieser Stufe, je Feld. Fehlt für eine Gruppe der Stufe ein Wert, ist die ganze Stufe `null`; der Stamm zählt dann für diese Stufe nicht im Aggregat. Hat der Stamm keine Gruppe einer Stufe, ist der Wert `0`.
4. **Stammweite Kennzahlen** kommen aus dem neuesten Snapshot mit `abdeckung: "stamm"`. Gibt es keinen, sind sie `null`.

Beispiel: P4 sendet den ganzen Stamm mit den Gruppen A, B, C und D (ältester Stand). Danach senden P3 die Gruppe C, P2 die Gruppen A und B und zuletzt P1 die Gruppe A. Der effektive Stand besteht aus den stammweiten Werten und D von P4, C von P3, B von P2 und A von P1.

Die stammweiten Werte können dadurch älter sein als die Gruppenwerte. Kleine Abweichungen, etwa zwischen `leitende.gesamt` und der Summe der Leitenden je Stufe, sind gewollt in Kauf genommen.

Für Transparenz und Monatsreport merkt sich der effektive Stand außerdem:

- `data_as_of`: ältester und neuester Stand der verwendeten Teile
- `art`: `vollstaendig` (nur der Stamm-Snapshot), `nur_gruppen` (kein Stamm-Snapshot) oder `gemischt`
- Anzahl der Sender im Fenster sowie Anzahl der Gruppen, die mehr als ein Sender abgedeckt hat
