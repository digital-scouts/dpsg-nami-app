# DPSG Nami Mobile App Constitution

## Core Principles

### I. Architektur: Clean Architecture & Repository Pattern

Klares Schichtenmodell (Presentation → Application → Domain → Data). Abhängigkeiten verlaufen nur nach innen. Repositories kapseln Datenquellen (Remote API, lokaler Cache via Hive). Keine UI-spezifische Logik in Domain. Domain-Ebene ist framework-agnostisch (reine Dart-Entitäten, UseCases). Data-Ebene implementiert Synchronisations- und Mappings. Skalierung bis ca. 1000 Mitglieder (typisch ~100). Pflichtfelder (Name, Mitgliedsnummer, Geburtsdatum) sind non-null; optionale Felder dürfen null sein und werden im UI adaptiv ausgeblendet.

Für Hitobito-basierte Mitgliedsdaten arbeitet die App fachlich immer in genau einem aktiven Arbeitskontext. Ein Arbeitskontext ist genau ein Layer. Hitobito-Rechte können den darin sichtbaren Personen- und Gruppenbestand verkleinern, ohne dass dadurch ein anderer Arbeitskontext entsteht. Als Arbeitskontexte angeboten werden aber nur die aus eigenen Rollen und arbeitskontextrelevanten Lese- oder Schreibrechten abgeleiteten relevanten Layer. Unterlayer gehören nicht automatisch dazu, sondern werden nur über einen bewussten Kontextwechsel geöffnet.

### II. State Management: BLoC / Cubit

Alle relevanten UI-Zustände und Seiteneffekte werden über BLoCs/Cubits gesteuert. Ereignis → Zustandsstrom. Strikte Trennung zwischen State und Side Effects (Navigation, Dialoge). Einheitliche Fehler-, Loading- und Empty-Zustände. BLoCs werden isoliert getestet (Unit). Keine Geschäftslogik direkt in Widgets. Rollen- und Rechteinformation wird nach Login geladen und im entsprechenden Auth/Permission-BLoC gehalten.

### III. Test-First (NON-NEGOTIABLE)

Neue UseCases, Repositories und kritische BLoCs erhalten zuerst Tests (Red-Green-Refactor). Minimale, klare Testfälle beschreiben Verhalten und Randfälle. Coverage-Fokus: Domain ~90%, Data >80%, Presentation kritisch (Event/State-Flows). Widgetbook dient zur visuellen Review & Dokumentation der Komponenten. PRs ohne Tests für neue Logik werden abgelehnt. Ein spezieller "Reinschnuppern"-Testmodus erzeugt synthetische Beispiel-Daten ohne Login (getrennte Datenpfade, keine Persistenz in produktiven Hive-Boxen).

### IV. Integration & Contract Testing

Repository-Integrations-Tests gegen simulierte API (Mock / Stub basierend auf Postman Collection). Contract-Tests validieren Mappings von API-JSON zu Domain-Modellen. Synchronisationspfad (lokal → ausstehende Änderungen → Remote) wird mit Szenarien getestet (Konflikt, Offline, Fehler-Retry, fachlicher Problemlösungsfall). Smoke-Tests für App-Start und kritische User-Flows (Login, Mitgliederliste, Mitglied anlegen/bearbeiten). Bearbeitungen starten weiterhin gegen den aktuellen Remote-Stand; bei retrybaren Übertragungsfehlern werden ausstehende Personenänderungen lokal vorgemerkt und später erneut gesendet. Echte Konflikte werden vor dem Upload auf Ebene der geänderten Felder und Kontaktobjekte bewertet, nicht nur über ein globales `updatedAt`.

### V. Observability & Simplicity

Fehler, Sync-Ereignisse und Performance-Metriken werden strukturiert geloggt (Level: debug/info/warn/error). Personenbezogene Daten werden nicht im Klartext geloggt; IDs werden anonymisiert/gehasht. Ausstehende lokale Personenänderungen werden nachvollziehbar über eine Change Queue geführt. Erwartbare Auth-Abläufe wie ein technisch abgefangener `401` werden fachlich als Retry- beziehungsweise Relogin-Ereignis geloggt, nicht als generischer Plattformfehler. YAGNI: Keine vorzeitige Optimierung; Feature-Scope klein halten. Versionierung nach MAJOR.MINOR.PATCH; Breaking Changes dokumentieren (Migration Guide). Lesedaten werden bevorzugt aus dem lokalen Cache angezeigt. Remote-Updates für Hitobito-Daten erfolgen nur, wenn das konfigurierte Refresh-Intervall abgelaufen ist. Ist der letzte erfolgreiche Datenstand älter als die konfigurierte Maximaldauer, werden die lokalen Hitobito-Daten gelöscht und die App meldet den Nutzer ab. Persistente Problemlösungsfälle für Personenänderungen werden fachlich getrennt von Auth- oder Netzwerkhinweisen geführt.

## Zusätzliche Constraints & Anforderungen

- Plattformen: Android & iOS (Flutter stable channel), breite Geräteunterstützung (min SDK Versionen so niedrig wie praktikabel – noch festzulegen).
- Offline-Fähigkeit MVP: Lesedaten kommen bevorzugt aus dem verschlüsselten lokalen Cache. Für Hitobito ist in der ersten Ausbaustufe genau ein aktiver Arbeitskontext lokal verfügbar; ein Kontextwechsel ersetzt den lokalen Bestand. Schreiboperationen werden nicht als vollwertiger Offline-Erfassungsmodus angeboten, aber retrybare Sendefehler werden über eine lokale Change Queue gepuffert.
- Sync-Strategie aktuell: Cache zuerst für Lesedaten. Remote-Updates für Hitobito-Daten werden nur bei fälligem Intervall (`HITOBITO_REFRESH_INTERVAL_HOURS`) versucht. Schlägt ein Update fehl, bleibt der vorhandene Cache lesbar und ein fachlicher Hinweis wird angezeigt. Änderungen starten gegen frische Remote-Daten; retrybare Sendefehler werden lokal vorgemerkt und können später erneut gesendet werden.
- Sync-Strategie nächste Ausbaustufe: Personenänderungen werden als Change-Set gegenüber dem Basisstand betrachtet. Unabhängige Änderungen zwischen lokalem und aktuellem Serverstand werden automatisch zusammengeführt. Nur Überschneidungen auf derselben Änderungseinheit oder fachliche Sync-Probleme führen zu einem Problemlösungsfall pro Mitglied.
- Arbeitskontext-Regel: Suche, Listen, Statistiken und persönliche Dashboards arbeiten nur innerhalb des aktiven Arbeitskontexts. Im MVP ist Hitobito die Quelle der Wahrheit für die sichtbare Teilmenge innerhalb dieses Kontexts. Gruppen, Tags und spätere persönliche Auswahlen sind Teilmengen dieses Kontexts und keine eigenständigen Hauptkontexte.
- Startkontext-Regel: Der initiale Arbeitskontext wird aus dem Primary Layer der Person abgeleitet, sofern dieser zu den relevanten Layern gehört. Falls dies ausnahmsweise nicht brauchbar bestimmbar ist, wird der erste relevante Layer aus einer stabil sortierten Liste verwendet.
- Gruppenregel MVP: In-App-Stufen werden global im Code über zentrale Regeln zu Hitobito-Gruppentypen hergeleitet. Personen werden Gruppen über Rollen zugeordnet. Leere Gruppen ohne Personen werden im Lesemodus nicht angezeigt.
- RelevantLayer-Regel: `layer_read`, `layer_full`, `layer_and_below_read` und `layer_and_below_full` bestimmen die angebotenen Layer direkt. Gruppenrechte wie `group_read`, `group_and_below_read` und `group_and_below_full` machen den zugehörigen Layer relevant, schränken aber primär die sichtbare Teilmenge innerhalb dieses Layers ein. Rechte wie `contact_data`, Finanz- oder Antragsrechte erweitern die angebotene Layerliste nicht. Leere Layer bleiben zulässige Arbeitskontexte.
- Datensatz-Versionierung vorhanden (Mitgliederversion) → Vor Bearbeitung wird Version abgeglichen, sonst Refresh.
- Sicherheitsaspekte: Auth via Username/Passwort → apiSessionToken (Gültigkeit ~1h). Silent Refresh kurz vor Ablauf (im Auth-Repository Zeitüberwachung). Optionaler Biometrie-Login (Keychain/Keystore Speicherung des Tokens oder Refresh-Creds). Rechte werden nach Login geladen und lokal (verschlüsselt) persistiert.
- Verschlüsselung: Alle personenbezogenen Daten in Hive verschlüsselt (Key-Management noch zu definieren; SecureStorage + ableitbarer Schlüssel). Hive Purge bei Logout oder Auto-Abmeldung.
- Performance: Erstes Laden Mitgliederliste <2s (warm start), Sortieren/Filtern client-seitig performant bis 1000 Einträge.
- Internationalisierung: Initial nur Deutsch; Architektur erlaubt Erweiterung (ARB-Dateien) für Englisch.
- Accessibility: Dynamische Schriftgrößen (OS Einstellungen), VoiceOver/TalkBack Labels, ausreichende Kontraste (gemäß Corporate Design Leitfaden: [Corporate Design PDF](https://dpsg.de/sites/default/files/2021-04/dpsg_corporate_design_leitfaden.pdf) + WCAG Mindestanforderungen).
- API-Spezifikation: Postman Collection manuell gepflegt → Ableitung eines internen Schemas (später automatisierter Export zu OpenAPI geplant).
- Fehlerstrategie: Netzwerkfehler bei Hitobito-Updates blockieren die App nicht sofort, solange ein gültiger lokaler Datenstand vorhanden ist; stattdessen wird nach Ablauf des konfigurierten Refresh-Intervalls erneut versucht. Läuft eine Sitzung in einen technisch erwartbaren `401`, versucht die App zuerst Refresh und Relogin, ohne den lokalen Arbeitskontext vorzeitig zu verwerfen. Auth- oder OAuth-Fehler werden für Nutzer fachlich übersetzt. Ist kein gültiger lokaler Datenstand vorhanden oder läuft er ab, ist ein erneuter Login erforderlich. Versionsabweichungen bei Personenänderungen führen nicht pauschal zu einem erzwungenen Refresh, sondern zunächst zu einer feld- und objektbezogenen Konfliktprüfung. Nur echte Überschneidungen oder fachliche Sync-Probleme erzeugen einen sichtbaren Problemlösungsfall.
- Datenvalidierung: Domain Entities garantieren Pflichtfelder; optionale Felder bleiben null und werden im UI ausgeblendet.
- Package Policy: Externe Pakete nur bei aktivem Wartungsstatus & kompatibler Lizenz (MIT/Apache2 bevorzugt). Minimaler Zusatzumfang.
- Rollen & Rechte: Nutzer ohne arbeitskontextrelevantes Layer- oder Gruppen-Lese- beziehungsweise Schreibrecht können die App fachlich nicht nutzen → explizite Nicht-berechtigt-Meldung + Logout.
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
   - Versionskonsistenz zwischen pubspec und Changelog
   - Android AAB für den internen Play-Track bei Pushes auf `develop` sowie nach gemergten Pull Requests auf `master`
   - GitHub Release mit Release-Notizen aus dem Changelog nach gemergten Pull Requests auf `master`
   - Optional: Security Scan (Dependency Audit)
7. Release: Version in `pubspec.yaml` pflegen, Changelog aktualisieren, Merge via Pull Request nach `master`; GitHub Release und Android-Deploy laufen danach automatisiert. Direkte Pushes nach `master` gelten als Hotfixes und lösen diese Release-Automation nicht aus. iOS-Distribution bleibt außerhalb von GitHub Actions.
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

**Version**: 0.2.1 | **Ratified**: 2025-10-30 | **Last Amended**: 2026-04-14

### Technische Namespaces & Storage

Hive Boxen: `members_box`, `auth_box`, `settings_box` (erweiterbar). Deep Link Schema: `app://member/<id>`. Hard Delete Politik: Entfernte Mitglieder werden lokal sofort gelöscht. Geburtstagsbenachrichtigungen vollständig lokal berechnet.

### Migration & Backend-Wechsel

Beim späteren neuen Backend werden nur DTOs und Remote Datasources ersetzt. Repository-Interfaces und Domain-Modelle bleiben stabil. Mapper-Adapter per API-Version möglich. Lokales Datenmodell verhindert aufwendige Migration.

### Linting & Code-Standards Zusatz

Lint/Format: Paket `very_good_analysis`. BLoCs/Cubits mit Suffix `Bloc`/`Cubit`, UseCases Verb + `UseCase`. Weitere Namenskonventionen bewusst minimal.
