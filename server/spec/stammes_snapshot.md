# Stammes-Snapshot

## API-Vertrag

- Endpunkt: `POST /snapshots/stamm`
- Authentifizierung: `Authorization: Bearer <installation_secret>` (siehe Abschnitt Installations-Credentials)
- Erfolgsantwort: `204 No Content`
- Fehlerantwort bei ungültiger Anfrage: `400 Bad Request`
- Fehlerantwort bei fehlenden oder falschen Credentials: `401 Unauthorized`
- Fehlerantwort bei zu vielen Anfragen: `429 Too Many Requests`
- Ein erneut gesendeter Snapshot mit identischem Stamm, Sender, `source_data_as_of` und `schema_version` wird nicht erneut gespeichert und liefert trotzdem `204`.
- `source_data_as_of` darf höchstens 24 Stunden in der Zukunft liegen und höchstens acht Tage alt sein (sieben Tage plus 24 Stunden Toleranz für Geräteuhren), sonst `invalid_datetime`. Die App sendet nur Datenstände, die höchstens sieben Tage alt sind.
- Über Aktualität, Zwei-Monats-Fenster und Haltefrist entscheidet allein der Eingang beim Server (`received_at`), nie ein Zeitstempel des Clients. `source_data_as_of` dient nur der Dublettenerkennung.
- Unterstützte `schema_version`: `2026-10-08`. Ältere Versionen werden mit `unsupported_schema_version` abgelehnt. Bereits gespeicherte Snapshots älterer Versionen bleiben bis zum Ablauf der Speicherfrist liegen, zählen aber für den effektiven Stand nicht mehr und fallen nach zwei Monaten ohnehin aus dem Fenster.
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

Pro Stamm führt der Server alle Snapshots zusammen, die in den letzten zwei Monaten eingegangen sind (`received_at`). Ältere Snapshots spielen keine Rolle. „Neuer“ heißt: später eingegangen.

Ein Stamm besteht aus Teilen: der Gruppenstruktur samt DV und Bezirk, den stammweiten Kennzahlen, jeder Stufe und jeder einzelnen Gruppe. Für jeden Teil gilt dieselbe Vorrangregel:

- **Haltefrist:** Eine Installation ist für einen Teil aktiv, wenn ihr letzter Snapshot, der diesen Teil abdeckt, vor höchstens 14 Tagen eingegangen ist.
- Gibt es aktive Installationen, zählt die, die den Stamm am längsten kennt (`first_seen_at`, der erste Eingang dieser Installation für diesen Stamm), mit ihrem neuesten Snapshot.
- Ist keine Installation aktiv, zählt der neueste Snapshot.
- Snapshots, die so nicht zum Zug kommen, bleiben gespeichert und greifen, sobald die Haltefrist der Installation mit Vorrang abläuft.

Damit kann eine fremde Installation die Werte eines aktiv teilnehmenden Stammes nicht ersetzen und aus der Verschiebung des Aggregats zurückrechnen. Wer die App wochenlang nicht öffnet, blockiert dagegen nichts: Nach 14 Tagen übernimmt der neueste vorliegende Stand, auch mit geänderter Struktur. Kommt die Installation zurück, gilt wieder ihr Stand.

`first_seen_at` übernimmt der Server beim Eingang vom ältesten gespeicherten Snapshot desselben Senders für denselben Stamm; beim ersten Kontakt ist es `received_at`. So überdauert der Wert die Speicherfrist einzelner Snapshots.

1. **Gruppenstruktur:** Welche Gruppen und Stufen der Stamm hat, kommt aus dem Snapshot mit Vorrang, gleich welcher Abdeckung.
2. **Gruppenwerte:** Pro Gruppe der Struktur zählt der Snapshot mit Vorrang unter denen, die diese Gruppe abdecken.
3. **Stufenwerte** (`biber` … `rover`, `leitende_biber` … `leitende_rover`): Summe der Gruppenwerte dieser Stufe, je Feld. Die Summe stammt immer aus genau einem Snapshot, nämlich dem mit Vorrang unter denen, die alle Gruppen der Stufe abdecken. Sonst ließe sich eine unvollständige Stufe mit erfundenen Gruppen auffüllen und eine echte Gruppe aus der Summe herausrechnen. Deckt niemand alle Gruppen der Stufe ab, ist die ganze Stufe `null`; der Stamm zählt dann für diese Stufe nicht im Aggregat. Hat der Stamm keine aktive Gruppe einer Stufe, ist der Wert ebenfalls `null`, damit er nicht als liefernder Stamm zählt (Mindestgrößen siehe `bundesaggregat.md`).
4. **Stammweite Kennzahlen** kommen aus dem Snapshot mit Vorrang unter denen mit `abdeckung: "stamm"`. Gibt es keinen, sind sie `null`.

Beispiel ohne aktive Installation: P4 sendet den ganzen Stamm mit den Gruppen A, B, C und D (ältester Eingang). Danach senden P3 die Gruppe C, P2 die Gruppen A und B und zuletzt P1 die Gruppe A, alle vor mehr als 14 Tagen. Der effektive Stand besteht aus den stammweiten Werten und D von P4, C von P3, B von P2 und A von P1. Die Stufensumme der Wölflinge (A, B, C) kommt aus P4, weil nur P4 alle drei abdeckt.

Beispiel mit aktiven Installationen: Die Gruppenleitung G sendet seit März die Meute A, der Vorstand V seit Mai den ganzen Stamm, beide in den letzten 14 Tagen. Für Meute A zählt G, für alle anderen Teile V, auch für die Stufensumme der Wölflinge.

Die stammweiten Werte und Stufensummen können dadurch älter sein oder von anderen Gruppenwerten stammen als die einzelnen Gruppen. Kleine Abweichungen, etwa zwischen `leitende.gesamt` und der Summe der Leitenden je Stufe, sind gewollt in Kauf genommen.

Für Transparenz und Monatsreport merkt sich der effektive Stand außerdem:

- `data_as_of`: ältester und neuester Stand der verwendeten Teile
- `art`: `vollstaendig` (nur der Stamm-Snapshot), `nur_gruppen` (kein Stamm-Snapshot) oder `gemischt`
- Anzahl der Sender im Fenster sowie Anzahl der Gruppen, die mehr als ein Sender abgedeckt hat
