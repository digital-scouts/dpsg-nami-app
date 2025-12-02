# DPSG Nami Mobile App Constitution

## Core Principles

### I. Architektur: Clean Architecture & Repository Pattern

Klares Schichtenmodell (Presentation → Application → Domain → Data). Abhängigkeiten verlaufen nur nach innen. Repositories kapseln Datenquellen (Remote API, lokaler Cache via Hive). Keine UI-spezifische Logik in Domain. Domain-Ebene ist framework-agnostisch (reine Dart-Entitäten, UseCases). Data-Ebene implementiert Synchronisations- und Mappings. Skalierung bis ca. 1000 Mitglieder (typisch ~100). Pflichtfelder (Name, Mitgliedsnummer, Geburtsdatum) sind non-null; optionale Felder dürfen null sein und werden im UI adaptiv ausgeblendet.

### II. State Management: BLoC / Cubit

Alle relevanten UI-Zustände und Seiteneffekte werden über BLoCs/Cubits gesteuert. Ereignis → Zustandsstrom. Strikte Trennung zwischen State und Side Effects (Navigation, Dialoge). Einheitliche Fehler-, Loading- und Empty-Zustände. BLoCs werden isoliert getestet (Unit). Keine Geschäftslogik direkt in Widgets. Rollen- und Rechteinformation wird nach Login geladen und im entsprechenden Auth/Permission-BLoC gehalten.

### III. Test-First (NON-NEGOTIABLE)

Neue UseCases, Repositories und kritische BLoCs erhalten zuerst Tests (Red-Green-Refactor). Minimale, klare Testfälle beschreiben Verhalten und Randfälle. Coverage-Fokus: Domain ~90%, Data >80%, Presentation kritisch (Event/State-Flows). Widgetbook dient zur visuellen Review & Dokumentation der Komponenten. PRs ohne Tests für neue Logik werden abgelehnt. Ein spezieller "Reinschnuppern"-Testmodus erzeugt synthetische Beispiel-Daten ohne Login (getrennte Datenpfade, keine Persistenz in produktiven Hive-Boxen).

### IV. Integration & Contract Testing

Repository-Integrations-Tests gegen simulierte API (Mock / Stub basierend auf Postman Collection). Contract-Tests validieren Mappings von API-JSON zu Domain-Modellen. Synchronisationspfad (lokal → ausstehende Änderungen → Remote) wird mit Szenarien getestet (Konflikt, Offline, Fehler-Retry). Smoke-Tests für App-Start und kritische User-Flows (Login, Mitgliederliste, Mitglied anlegen/bearbeiten). Für den MVP sind Bearbeitungen nur online und nach vorherigem Refresh erlaubt; Offline-Edit wird für spätere Versionen vorbereitet (Architektur-Vorarbeit, Outbox abstrahiert, aber deaktiviert).

### V. Observability & Simplicity

Fehler, Sync-Ereignisse und Performance-Metriken werden strukturiert geloggt (Level: debug/info/warn/error). Personenbezogene Daten werden nicht im Klartext geloggt; IDs werden anonymisiert/gehasht. Lokale Änderungen (später) werden nachvollziehbar (Change Queue). YAGNI: Keine vorzeitige Optimierung; Feature-Scope klein halten. Versionierung nach MAJOR.MINOR.PATCH; Breaking Changes dokumentieren (Migration Guide). SWR-Ansatz: Anzeige aus Cache, paralleler Refresh, danach Merge/Update. Logout nach 30 Tagen Inaktivität, verpflichtender Sync spätestens alle 30 Tage.

## Zusätzliche Constraints & Anforderungen

- Plattformen: Android & iOS (Flutter stable channel), breite Geräteunterstützung (min SDK Versionen so niedrig wie praktikabel – noch festzulegen).
- Offline-Fähigkeit MVP: Nur Lesen aus Hive Cache (kein Offline-Edit). Später: Outbox für Schreiboperationen (vorbereitet, deaktiviert).
- Sync-Strategie aktuell: SWR für Lesedaten (Cache sofort → Refresh). Änderungen nur online und nur auf frischen Daten (Refresh vor Bearbeitung zwingend). Trigger: App-Start, manuell, täglich einmal falls online.
- Datensatz-Versionierung vorhanden (Mitgliederversion) → Vor Bearbeitung wird Version abgeglichen, sonst Refresh.
- Sicherheitsaspekte: Auth via Username/Passwort → apiSessionToken (Gültigkeit ~1h). Silent Refresh kurz vor Ablauf (im Auth-Repository Zeitüberwachung). Optionaler Biometrie-Login (Keychain/Keystore Speicherung des Tokens oder Refresh-Creds). Rechte werden nach Login geladen und lokal (verschlüsselt) persistiert.
- Verschlüsselung: Alle personenbezogenen Daten in Hive verschlüsselt (Key-Management noch zu definieren; SecureStorage + ableitbarer Schlüssel). Hive Purge bei Logout oder Auto-Abmeldung.
- Performance: Erstes Laden Mitgliederliste <2s (warm start), Sortieren/Filtern client-seitig performant bis 1000 Einträge.
- Internationalisierung: Initial nur Deutsch; Architektur erlaubt Erweiterung (ARB-Dateien) für Englisch.
- Accessibility: Dynamische Schriftgrößen (OS Einstellungen), VoiceOver/TalkBack Labels, ausreichende Kontraste (gemäß Corporate Design Leitfaden: [Corporate Design PDF](https://dpsg.de/sites/default/files/2021-04/dpsg_corporate_design_leitfaden.pdf) + WCAG Mindestanforderungen).
- API-Spezifikation: Postman Collection manuell gepflegt → Ableitung eines internen Schemas (später automatisierter Export zu OpenAPI geplant).
- Fehlerstrategie: Netzwerkfehler → Retry mit exponentiellem Backoff; Auth 401 → Re-Login Flow. Bei Versionskonflikt: erzwungener Refresh.
- Datenvalidierung: Domain Entities garantieren Pflichtfelder; optionale Felder bleiben null und werden im UI ausgeblendet.
- Package Policy: Externe Pakete nur bei aktivem Wartungsstatus & kompatibler Lizenz (MIT/Apache2 bevorzugt). Minimaler Zusatzumfang.
- Rollen & Rechte: Nutzer mit fehlender Leseberechtigung auf Mitglieder können App nicht nutzen → Freundliche Fehlermeldung + Logout.
- Push Notifications: Geburtstags-Erinnerungen (lokal berechnet), Warnung bei baldiger Auto-Abmeldung (≥25 Tage Inaktivität), Deep Link zur Mitglieder-Detailseite (`app://member/<id>`).
- Logging: Ausführlich aber anonymisiert (IDs können gehasht werden – konkrete Hash-Strategie beliebig). Kein Klartext von Personenfeldern. Manuelles Exportieren der Logs per Mail. Reaktion auf Login-Fehler wegen zu vieler falscher Eingaben mit spezifischer Meldung.

## Entwicklungs-Workflow & Quality Gates

1. Issue/Story → Definition von Akzeptanzkriterien + Domain-Auswirkungen.
2. Test-Spezifikation (Unit + ggf. Integration) → Review (Selbst-Review bei Einzelmaintainer, später formalisieren).
3. Implementierung minimal bis Tests grün (Red-Green-Refactor).
4. Widgetbook-Komponenten aktualisieren (Story hinzufügen oder ändern).
5. Code Review (Solo): Checkliste (Architektur-Konformität, Logging-Anonymität, Pflichtfelder, Rechteprüfung, Tests).
6. CI (GitHub Actions):****
   - Format & Lint (dart format, dart analyze)
   - Unit Tests
   - (Später) Integration/Contract Tests mit Mock/Stubs
   - Build Artefakte (Android .apk / iOS TestFlight build)
   - Optional: Security Scan (Dependency Audit)
7. Release: Manuell nach erfolgreichem Build. Semver Tagging, Changelog aktualisieren.
8. Monitoring & Feedback: Wiredash für Feedback/Analyse, Crash Reporting (Tool Auswahl offen, Kandidaten: Sentry/Crashlytics).

Quality Gates Mindestanforderungen (MVP angepasster Umfang):

- Keine offenen TODOs ohne Issue-Verlinkung.
- Test Coverage Ziel MVP: Domain ≥80% (Steigerung auf 90% nach Stabilisierung), Data ≥70% (später ≥80%).
- Keine zyklischen Abhängigkeiten zwischen Layers.
- Lints: 0 Errors, nur dokumentierte Ausnahmen.
- Logging prüft Anonymität (Utility Funktion testbar).

## Governance

Diese Constitution übersteuert individuelle Präferenzen. Änderungen erfordern:

1. Vorschlag inkl. Begründung & Auswirkungen (ADR falls substantiell).
2. (Aktuell Solo) Selbst-Review + Dokumentation; bei Erweiterung des Teams: ≥2 Approvals Pflicht.
3. Migrationsplan für bestehende Module (Pflicht bei Breaking Changes).
4. Aktualisierung dieser Datei mit Versionserhöhung (MINOR bei nicht-break, MAJOR bei breaking). Patch bei Klarstellungen ohne Code-Auswirkung.

Einhaltung wird bei jedem Commit/PR mittels Checkliste geprüft (später automatisierbar). Komplexität muss begründet werden (Architektur-Diagramm oder kurze ADR). Runtime-Guidance: Separate `ARCHITECTURE.md` plus eventuell `SECURITY.md` für Schlüssel- und Auth-Flows. Hive-Purge bei Logout oder automatischer Abmeldung nach 30 Tagen ist verpflichtend.

**Version**: 0.2.0 | **Ratified**: 2025-10-30 | **Last Amended**: 2025-10-30

### Technische Namespaces & Storage

Hive Boxen: `members_box`, `auth_box`, `settings_box` (erweiterbar). Deep Link Schema: `app://member/<id>`. Hard Delete Politik: Entfernte Mitglieder werden lokal sofort gelöscht. Geburtstagsbenachrichtigungen vollständig lokal berechnet.

### Migration & Backend-Wechsel

Beim späteren neuen Backend werden nur DTOs und Remote Datasources ersetzt. Repository-Interfaces und Domain-Modelle bleiben stabil. Mapper-Adapter per API-Version möglich. Lokales Datenmodell verhindert aufwendige Migration.

### Linting & Code-Standards Zusatz

Lint/Format: Paket `very_good_analysis`. BLoCs/Cubits mit Suffix `Bloc`/`Cubit`, UseCases Verb + `UseCase`. Weitere Namenskonventionen bewusst minimal.
