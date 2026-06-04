# Notifications Hub (intern + extern)

Diese Spezifikation beschreibt den gemeinsamen Meldungs-Hub der App. Der Hub behandelt **alle** Meldungen unabhängig von der Quelle:

- **Extern**: geladene Pull Notifications
- **Intern**: von der App erzeugte Zustandsmeldungen (Sync, Login, Konflikte, Update)

Die Quelle ist fachlich wichtig, aber nicht die primäre Anzeigeachse. Für die Anzeige gelten gemeinsame Regeln für Priorität, Sichtbarkeit und Navigation.

## Ziel

Ein einheitlicher Meldungsfluss für die gesamte App:

- In **Settings** als gestapelter Hinweis (Top-Meldung + Anzahl)
- Bei Klick in einen **Meldungen-Screen** als vollständige Liste
- Auf anderen Seiten als **prominente Meldung**, wenn die Priorität hoch genug ist

## Fest entschiedene Regeln

- Prioritätsskala ist fix: `info`, `warn`, `urgent`.
- Externe Meldungen sind lokal **acknowledgebar**.
- Interne Meldungen sind **zustandsgetrieben** (kein manuelles Ack, solange der Zustand aktiv ist).
- „Bald gelöscht“-Hinweis erscheint ab **3 Tagen Restlaufzeit**.
- Für „bald gelöscht“ wird zusätzlich eine **tägliche lokale Push-Notification** gesendet, solange der Zustand aktiv ist.

## Begriffe

- **Meldung**: ein einheitlicher Eintrag im Notifications-Hub.
- **Quelle**:
  - `internal` (App erzeugt)
  - `external` (Pull-Feed)
- **Kanal**:
  - Settings-Stapel
  - Meldungen-Liste
  - Appweites Banner / Snackbar / Dialog

## Anforderungen

- **R1 — Einheitliches Modell:** Interne und externe Meldungen werden in ein gemeinsames Domainmodell gemappt.
- **R2 — Gemeinsame Sortierung:** Sortierung nach Priorität (`urgent`, `warn`, `info`) und danach Aktualität.
- **R3 — Einheitlicher Einstieg:** Settings zeigt einen gestapelten Hub-Hinweis; Klick öffnet die vollständige Liste.
- **R4 — Dringliche Sichtbarkeit:** `urgent`-Meldungen können appweit prominent erscheinen.
- **R5 — Ack-Regeln:** Nur externe Meldungen sind ackbar; interne Meldungen verschwinden automatisch, wenn der Zustand endet.
- **R6 — Trigger-Transparenz:** Für interne Meldungen sind Auslöser und Priorität eindeutig dokumentiert.
- **R7 — Dummy-frei:** Statische Platzhalterlisten und Dummy-Meldungen werden entfernt.
- **R8 — Offline-Fähigkeit:** Externe Meldungen bleiben über Cache verfügbar; interne Meldungen sind aus lokalem Zustand ableitbar.
- **R9 — Datenschutz:** Keine personenbezogenen Inhalte in Hub-Meldungen.

## Zielmodell (Domain)

Vorgeschlagenes Hub-Modell:

```json
{
  "id": "string",
  "source": "internal|external",
  "severity": "info|warn|urgent",
  "title": { "de": "string", "en": "string" },
  "body": { "de": "string", "en": "string" },
  "created_at": "ISO8601|null",
  "updated_at": "ISO8601|null",
  "is_ackable": "boolean",
  "is_active": "boolean",
  "dedupe_key": "string|null",
  "deep_link": "string|null",
  "external_link": "string|null",
  "platform": "android|ios|all|null"
}
```

Regeln:

- `is_ackable=true` nur für `source=external`.
- `is_active` bei internen Meldungen aus Zustand abgeleitet.
- `dedupe_key` verhindert doppelte Darstellung derselben Ursache über Kanäle.

## Externe Meldungen (Pull)

### Quelle und Laden

- Quelle bleibt eine JSON-Datei über URL aus `.env`.
- Cache-first mit gedrosseltem Remote-Check.

### Externe Felder

- `type` wird auf `severity` gemappt (`info|warn|urgent`).
- `platform`, `starts_at`, `ends_at` werden zentral vor Anzeige ausgewertet.

### Ack

- Externe Meldungen bleiben ackbar (lokale Persistenz in Hive).

## Vollständige Liste interner Meldungen

Die folgende Liste bildet den aktuellen internen Meldungsumfang ab, inkl. Priorität und Auslöser.

| ID | Meldung | Priorität | Auslöser (technisch) | Quelle | Kanal(e) | Status |
|---|---|---|---|---|---|---|
| `internal.hitobito.unreachable.cached` | Hitobito nicht erreichbar, lokale Daten werden angezeigt | `warn` | `AuthSessionModel.hasRemoteAccessIssue == true` und `requiresInteractiveLogin == false` | internal | Settings-Stapel, Members-Snackbar | implementiert |
| `internal.hitobito.unreachable.offline` | Gerät offline, Remote-Zugriff blockiert | `warn` | `NetworkAccessBlockedReason.offline` über `reportRemoteDataIssue`/`_reportNetworkAccessBlockedIssue` | internal | Settings-Stapel, Debug-Sync-Feedback | implementiert |
| `internal.hitobito.unreachable.server` | Hitobito aktuell nicht erreichbar (nicht offline, nicht relogin) | `warn` | Remote-Fehler ohne Offline-Reason und ohne Relogin-Zwang | internal | Settings-Stapel, Members-Snackbar | implementiert |
| `internal.hitobito.relogin_required` | Login abgelaufen, erneute Anmeldung erforderlich | `urgent` | `requiresInteractiveLogin == true` oder `AuthState.reloginRequired` | internal | Auth-Shell-Status, Settings-Stapel, Members-Snackbar | implementiert (Priorität im Hub anzupassen) |
| `internal.member.sync_conflict` | Offene Problemlösungsfälle bei Mitgliedsänderungen | `warn` | `MemberEditModel.openResolutionCount > 0` | internal | Settings-Stapel, Member-Detail-Banner | implementiert |
| `internal.member.sync_pending_retry` | Ausstehende Mitgliedsänderung ohne direkten Konflikt | `info` | `hasPending == true` und `needsResolution == false` im Detailkontext | internal | Member-Detail-Banner | implementiert |
| `internal.data.expiry_soon` | Hitobito nicht erreichbar, Daten werden bald gelöscht | `urgent` | `remainingUntilRelogin <= 3 Tage` | internal | Settings-Stapel, appweites Banner (optional), tägliche lokale Push | geplant |
| `internal.update.available` | Neuere App-Version verfügbar | `warn` | `AppUpdateService.checkForUpdate()` liefert `isRequired == false` | internal | Settings-Stapel, optional Dialog | implementiert |
| `internal.update.required` | Update erforderlich | `urgent` | `AppUpdateService.checkForUpdate()` liefert `isRequired == true` | internal | Settings-Stapel, Startup-Dialog | implementiert |
| `internal.sync.manual.result.success` | Manueller Sync erfolgreich | `info` | Debug-Trigger „Daten jetzt aktualisieren“ erfolgreich | internal | Debug-Snackbar | implementiert |
| `internal.sync.manual.result.partial` | Manueller Sync teilweise fehlgeschlagen | `warn` | Debug-Trigger mit Fehlerzustand | internal | Debug-Snackbar | implementiert |
| `internal.sync.manual.result.blocked` | Manueller Sync durch Netzregeln blockiert | `warn` | NetworkAccessPolicy blockiert | internal | Debug-Snackbar | implementiert |

Hinweise:

- Einige Meldungen existieren aktuell nur in bestimmten Kanälen (z. B. Detail-Banner, Debug-Snackbar) und sind noch nicht im zentralen Hub konsolidiert.
- Für `internal.hitobito.relogin_required` wird die endgültige Hub-Priorität auf `urgent` festgelegt.

## Sichtbarkeit und Prioritätsrouting

- **Settings-Stapel:** zeigt höchste aktive Meldung + Count über alle aktiven Meldungen.
- **Meldungen-Screen:** zeigt vollständige Liste (intern + extern), gefiltert nach aktiv/ackbar.
- **Andere Seiten:**
  - `urgent`: appweit prominent (Banner/Dialog, je nach Kontext)
  - `warn`: kontextabhängig (z. B. Members-Snackbar einmalig)
  - `info`: primär im Hub/Listenkontext

## „Bald gelöscht“-Regel (3 Tage + tägliche Push)

Fachregel:

- Wenn Restlaufzeit bis Relogin (`remainingUntilRelogin`) `<= 3 Tage` ist, wird `internal.data.expiry_soon` aktiv.
- Solange dieser Zustand aktiv ist, wird täglich eine lokale Push-Notification ausgelöst.
- Endet der Zustand (neuer Login/Sync), werden diese täglichen Erinnerungen beendet.

Technische Notiz:

- `flutter_local_notifications` ist als Paket vorhanden, aber bisher nicht angebunden.
- Die tägliche Push-Erinnerung ist daher als nächster technischer Ausbau vorgesehen.

## Architekturhinweise

- Bestehende Pull-Architektur bleibt erhalten, wird aber in den Hub integriert.
- Interne Builder werden zentralisiert (statt Verteilung über einzelne Screens).
- Dummy-Listen in der Meldungsansicht werden durch echten Hub-Feed ersetzt.

## Umsetzungsreihenfolge (technisch)

1. Gemeinsames Hub-Modell einführen (`AppMessage` o. ä.).
2. Interne Meldungsbuilder zentralisieren (Auth/Sync/Resolution/Update).
3. Externe Pull-Meldungen mappen und zentral filtern (`platform`, `starts_at`, `ends_at`).
4. Settings-Stapel und Meldungen-Screen auf denselben Hub-Feed stellen.
5. Dummy-Meldungen entfernen.
6. Prioritätsrouting für appweite Darstellung vereinheitlichen.
7. „Bald gelöscht“ + tägliche lokale Push ergänzen.

## Tests

- Unit-Tests für Mapping intern/extern auf Hub-Modell.
- Unit-Tests für Priorität, Sortierung, Dedupe.
- Unit-Tests für Zustandslogik „bald gelöscht“ (3-Tage-Schwelle).
- Tests für Ack-Policy (extern ackbar, intern nicht ackbar).
- Widget-Tests für Settings-Stapel und Meldungen-Liste aus gemeinsamer Quelle.

## Offene Punkte

- Endgültiger Kanal für `urgent` intern außerhalb Settings (globales Banner vs. Dialog) im Feindesign festlegen.
- Verhalten bei gleichzeitigen `urgent`-Meldungen (Queue/Rotation) definieren.
- Deep-Link-Verhalten für externe Meldungen abschließen.
