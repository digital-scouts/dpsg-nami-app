# Pull Notifications

In der App sollen Mitteilungen angezeigt werden können, die alle Nutzer gleichermaßen betreffen. Es werden keine Push-Dienste (FCM/APNs) verwendet, die App holt die Nachrichten aktiv per Pull. Der Feed wird beim App-Start initialisiert; Remote-Checks werden über ein konfigurierbares Mindestintervall gedrosselt.

## Ziel

Pulled Notifications sind zeitlich relevante, öffentliche Mitteilungen (z. B. Hinweise, Wartungsfenster, Ankündigungen). Für das MVP ist die Quelle eine statische JSON-Datei auf GitHub (einfach zu pflegen, PR-basiert), konfigurierbar in der App.

## Annahmen

- Keine Push-Services (Firebase, APNs) oder Server-gestützte Push-Infrastruktur.
- Primäre Quelle für das MVP: statische JSON-Datei in einem Git-Repository (GitHub).
- Geladene Mitteilungen werden lokal in Hive gecached, damit sie auch offline angezeigt werden können.

## Anforderungen (angepasst)

- **R1 — Quelle & Default:** Default-Quelle für MVP ist eine GitHub-JSON-Datei. **Die URL zur JSON-Datei wird in der `.env`-Datei hinterlegt** und beim Start eingelesen. Ein optionaler Asset-Fallback ist nur für Entwicklungszwecke vorgesehen und aktuell noch offen.
- **R2 — Laden beim Start:** Beim App-Start wird der Notifications-Flow initialisiert. Es wird zuerst der Cache angezeigt; ein Remote-Pull erfolgt nur dann, wenn das konfigurierte Mindestintervall seit dem letzten erfolgreichen Fetch abgelaufen ist oder noch kein Cache vorhanden ist.
- **R3 — Mindestintervall statt Hintergrund-Timer:** Es gibt aktuell keinen periodischen Hintergrund-Pull. Stattdessen wird ein Mindestintervall für Remote-Checks verwendet, konfiguriert über `.env` (`PULL_NOTIFICATIONS_MIN_FETCH_INTERVAL_HOURS`), Default aktuell **1 Stunde**. Ein echter automatischer Intervall-Pull bleibt eine mögliche spätere Alternative.
- **R4 — Manuelles Aktualisieren:** Ein manueller Pull-Trigger ist in der Mitteilungsansicht vorhanden, die aktuell über Debug & Tools erreichbar ist.
- **R5 — Anzeige:** Mitteilungen werden in einer eigenen Komponente angezeigt; Pflicht: `title`, `body`. Optional: `type` (info/warn/urgent), `starts_at`, `ends_at`, `deep_link`, `external_link`, `platform`.
- **R6 — Priorisierung & Sichtbarkeit:** `urgent`-Mitteilungen werden appweit als hervorgehobenes Banner angezeigt, bis sie bestätigt werden. Andere Typen erscheinen als Vorschau der neuesten ungelesenen Mitteilung in den Einstellungen sowie vollständig in der Debug-Mitteilungsansicht.
- **R7 — Entität & Schema:** Das JSON-Schema unterstützt Mehrsprachigkeit (siehe Schema). Items sind idempotent über `id`.
- **R8 — Cache & Persistence:** Geladene Mitteilungen werden in Hive-Box `notifications_box` gespeichert. Zusätzliche Metadaten wie der letzte erfolgreiche Fetch-Zeitpunkt werden separat persistiert. Anzeige-Logik benutzt Cache zuerst; Remote-Checks werden per Mindestintervall gedrosselt.
- **R9 — Offline & Acknowledgement:** Bei Offline-Status wird der Cache angezeigt. Nutzer können Mitteilungen lokal bestätigen/ausblenden (Ack), dieser Zustand wird pro Gerät in Hive persistiert.
- **R10 — Duplikat-/Idempotenz:** Items werden anhand `id` dedupliziert; Änderungen werden angewendet wenn `updated_at` neuer ist.
- **R11 — Sicherheit & Datenschutz:** Mitteilungen enthalten keine personenbezogenen Daten. Logs enthalten keine Klartext-Personendaten.
- **R12 — Fehlerverhalten:** Es gibt aktuell keine eigene Retry-Strategie. Fehler beim Laden werden geloggt; Hintergrund-Refresh-Fehler werden in der App ignoriert und bei späterer normaler Nutzung wird erneut versucht.
- **R13 — Autorisierung & Pflege:** Für das MVP werden Mitteilungen via Git-Workflow gepflegt (Push auf Branch + PR → Merge). Das ist das vereinbarte Erstell-/Änderungsmodell.
- **R14 — Tests:** Unit-Tests für Parser/Mapper, Integrationstests für Repository gegen Mock-Endpoint, Widget-Tests für Anzeige, Contract-Tests für JSON-Schema.

## JSON-Schema

Minimalobjekt (Titel/Body unterstützen Mehrsprachigkeit; einfache String-Felder werden als Legacy-Shortcut noch akzeptiert):

```json
{
    "id": "string",
    "title": { "de": "string", "en": "string" },
    "body": { "de": "string", "en": "string" },
    "type": "info|warn|urgent",
    "created_at": "ISO8601|null",
    "updated_at": "ISO8601|null",
    "starts_at": "ISO8601|null",
    "ends_at": "ISO8601|null",
    "deep_link": "string|null",
    "external_link": "string|null",
    "platform": "android|ios|all|null"
}
```

API-Wrapper:

```json
{
    "items": [ ... ]
}
```

Hinweis: Die App wählt die passende Sprache anhand der Device-Locale (Fallback: `de`, dann erstes verfügbares).

## Anzeige & UX

- **Urgent:** `urgent`-Items → appweites Banner bis zur Bestätigung; aktuelles Verhalten ist gewünscht, hat aber noch offene Probleme in der Ausgestaltung.
- **Weitere Items:** In den Einstellungen wird die neueste ungelesene Mitteilung angezeigt; die vollständige Liste ist aktuell über Debug & Tools erreichbar. Dort können Mitteilungen bestätigt/ausgeblendet werden (lokaler Ack).
- **Filter & Sortierung:** Anzeige filtern nach Plattform-Relevanz; wenn `platform` fehlt oder `null`, gilt `all`. Sortierung: Typ (urgent,warn,info) und nach Reihenfolge im Feed.
- **Details:** Tap → Detail-View bzw. `deep_link`/`external_link` ist vorgesehen, aber noch nicht umgesetzt.

## Betriebsanforderungen

- **B1 — Quelle erreichbar:** Für MVP ist GitHub ausreichend (statische Datei + PR-Workflow). Ein optionaler Asset-Fallback ist nur für Entwicklungszwecke als spätere Ergänzung vorgesehen.
- **B2 — Performance:** Pull darf App-Start nicht blockieren — Cache zuerst, Pull asynchron.

## Konkrete Entscheidungen (aus Antworten übernommen)

- Default-Quelle: GitHub (JSON-Datei, Pflege via branch+PR).
- Mindestintervall für Remote-Checks: 1 Stunde via `.env`.
- Plattform-spezifische Items: supported (optional, `platform`-Feld).
- Umgang mit `urgent`: appweites Banner bis Bestätigung.
- Erstellen/Ändern: PR-basiert im GitHub-Repo.
- Acknowledgement: ja, lokal in Hive speichern per Gerät.
- Mehrsprachigkeit: ja, `de`/`en` unterstützt.
- Sichtbarkeit: neueste ungelesene Mitteilung in Einstellungen, vollständige Liste in Debug & Tools.

## Implementierungshinweise

- Architektur: `PullNotificationsRepository`, `RemotePullNotificationsDataSource`, `HiveNotificationsDataSource`.
- State-Management: `PullNotificationsCubit` / `PullNotificationsBloc` (States: `initial`, `loading`, `loaded`, `empty`, `error`).
- Persistenz: Hive-Box `notifications_box`, ACK-Box `notifications_ack_box`, Meta-Box für letzten Fetch-Zeitpunkt.
- Tests: Mock-HTTP + Contract-Tests gegen das JSON-Schema.

## Offene TODOs

- Plattform-Filterung über `platform` zentral vor der Anzeige anwenden.
- Zeitfenster über `starts_at` und `ends_at` auswerten.
- Tap auf Mitteilungen für Detailansicht, `deep_link` oder `external_link` umsetzen.
- Optionalen Asset-Fallback für Entwicklungszwecke ergänzen.

## Beispiel API-Response (mit Mehrsprachigkeit)

```json
{
    "items": [
        {
            "id": "2025-12-15-001",
            "title": { "de": "Wartung am 18.12.", "en": "Maintenance on 18 Dec" },
            "body": { "de": "Am 18.12. findet eine Serverwartung statt...", "en": "Maintenance will occur on 18 Dec..." },
            "type": "info",
            "created_at": "2025-12-15T08:00:00Z",
            "updated_at": "2025-12-15T08:00:00Z",
            "starts_at": "2025-12-18T06:00:00Z",
            "ends_at": "2025-12-18T08:00:00Z",
            "deep_link": null,
            "external_link": null,
            "platform": "all"
        }
    ]
}
```
