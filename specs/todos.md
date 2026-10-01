# Todos

Diese Liste führt nur offene Aufgaben. Umgesetzte Arbeitskontext-, Stufen-, Beitragsart-, Statistik- und Sync-Pakete bleiben im Code, in Tests und im Arbeitskontext-Konzept nachvollziehbar, werden hier aber nicht mehr als aktive Aufgaben geführt.

## Priorität 1: Feldtests und Doku-Abgleich

Ziel: Die bereits implementierten Stammstatistik-, Stufen-, Beitragsart- und Sync-Anpassungen mit echten Daten prüfen und die Projektdokumentation auf den aktuellen Stand bringen.

Nächste Aufgaben:

- Feldtests mit echten Layerdaten durchführen, insbesondere sehr große Stämme, unvollständige Adressen und reale Biber-/Wö-/Jufi-/Pfadi-/Rover-Gruppen.
- Statistiktexte und Lokalisierung für neue oder seltene Statusfälle prüfen und bei Bedarf nachschärfen.
- [specs/hitobito-arbeitskontext-konzept.md](hitobito-arbeitskontext-konzept.md) mit dem umgesetzten Stand zu Stufen, Beitragsarten, Rollenladen und Sync-Status abgleichen.
- Prüfen, ob zusätzliche Begriffs- oder Gruppentyp-Dokumentation nötig ist; aktuell existiert dafür keine eigene `dpsg-org-hierarchie`-Spec.

## Priorität 2: Offline-Sync und Problemlösungsfälle fertig prüfen

Ziel: Der bestehende Problemlösungsfall soll für spätere Sync- und Retry-Situationen belastbar sein.

Nächste Aufgaben:

- Offline-Konflikt manuell testen: Mitglied lokal ändern, Serverstand ändern, später synchronisieren, Problemlösungsfall öffnen und lösen.
- Fehlerhafte Telefonnummer offline speichern und später synchronisieren: Server-Validierungsfehler muss als Problemlösungsfall sichtbar werden.
- Automatischen Sync während aktiver App-Nutzung mit Queue-Einträgen prüfen: WLAN, erlaubte mobile Daten, gedrosselte Retry-Versuche.
- Verhalten bei ungültiger Sitzung erneut prüfen: Hinweis nur einmal anzeigen, Bearbeiten weiterhin wie im Offline-Modus möglich.

Die manuelle Prüfung verlief ohne Befund. Die Fälle sollen künftig automatisiert abgesichert werden.

**Stufe A, gemockt:**

- Auto-Sync-Steuerung aus `lib/main.dart` herauslösen. Betroffen sind `_startConnectivityListener`, `_startPendingRetryTimer`, `_handleForegroundSyncOpportunity`, `_runForegroundSync`, `_retryPendingPersonUpdatesIfPossible` und der Reset beim Resume.
- Daraus eine testbare Klasse machen, die `Connectivity`, Timer und Uhr injiziert bekommt. `fake_async` ist vorhanden, `MemberEditModel` hat bereits einen `nowProvider`.
- Durchgehende Tests über die ganze Kette:
  - `HitobitoPeopleService` mit `MockClient`
  - `HitobitoMemberWriteRepository`
  - `MemberEditModel`
  - Pending-Repository
- Szenarien:
  - Offline-Konflikt bis zum Problemfall
  - Antwort 422 bei `phone_numbers` bis zum Problemfall
  - Auto-Sync mit WLAN und mobilen Daten samt Backoff
  - ungültige Sitzung mit einmaligem Hinweis
- Heute testet jede Schicht nur mit eigenen privaten Fakes. Durchgehend am Stück ist die Kette nicht abgesichert.
- JSON:API-Fixtures und gemeinsame Fakes nach `test/support/` legen.

**Stufe B, Spike mit lokalem Hitobito-Stack (Docker, DPSG-Wagon):**

- Hürden:
  - Port 3000 ist durch den Statistikserver belegt.
  - Cleartext-HTTP braucht eine Dev-Ausnahme (ATS bzw. `networkSecurityConfig`).
  - Der Login läuft interaktiv über `flutter_web_auth_2`.
- Empfehlung: Contract-Tests auf Service-Ebene mit Service-Token (`X-TOKEN`) statt Geräte-Integrationstests.
- `HITOBITO_BASE_URL` wird nur aus `.env` gelesen. Schema und Port bleiben beim Ableiten der API-URLs erhalten.

## Priorität 3: Adressvalidierung anschließen

Ziel: Adressprobleme aus Offline-Bearbeitung und späterem Sync sollen denselben Problemlösungsfall nutzen wie Konflikte und andere fachliche Sync-Probleme.

Nächste Aufgaben:

- Produktionspfad für Adressvalidierung definieren: wann wird geprüft, wann wird nur gespeichert, wann entsteht ein Problemlösungsfall.
- Geoapify-basierte Prüfung für spätere Retry-/Sync-Fälle anbinden, ohne den normalen Offline-Speicherpfad zu blockieren.
- Ungültige Adresse offline speichern und später synchronisieren: Adresse nicht gefunden oder semantisch unplausibel muss als Problemlösungsfall erscheinen.
- Gültige Adresse offline bearbeiten und später synchronisieren: Änderung muss ohne unnötigen Problemlösungsfall gesendet werden.

## Priorität 4: Adressbearbeitung vereinfachen

Ziel: Die spätere automatische Adressvervollständigung soll den Online-Bearbeiten-Pfad vereinfachen, ohne den Offline-Fallback zu verlieren.

Nächste Aufgaben:

- Adresssuche über den bestehenden Geoapify-Dienst als primären Online-Pfad konzipieren.
- Adresseingabe auf ein Such- und Auswahlfeld reduzieren; Bezeichnung und c/o bleiben eigene Felder.
- Land als Dropdown vorbereiten: Deutschland als Default plus Nachbarländer.
- Aktuelle strukturierte Adresseingabe als Fallback erhalten, wenn offline oder Geoapify nicht verfügbar ist.
- Prüfen, ob das Postfach-Feld im neuen Online-Pfad entfallen kann und wie bestehende Daten weiter angezeigt werden.

## Priorität 5: Stammstatistik nachschärfen

Ziel: Die neue Kachel-Statistik nach den ersten Rückmeldungen abrunden.

Nächste Aufgaben:

- Größere Schrift feinschleifen: Bei hoher Textskalierung wirkt die Schrift in einigen Kacheln eher kleiner und der Leerraum wächst (siehe Entwürfe Runde 5 unter `design/statistik/`).
- „Hinter den Kacheln“ aus Runde 2 (§6) als eigene Ausbaustufe konzipieren: Detailseiten beim Antippen der Kacheln.
- Konfession aus echten Daten statt der bisherigen Beispielquelle anzeigen, sobald Hitobito sie liefert.

## Priorität 6: App-Wartung und nützliche Ergänzungen

- GitHub-Pages-Wiki/Userguide für Konfliktlösung, Datenspeicherung und Löschung schreiben.
- Problemlösungs-Screen prüfen: Bereich "Mitglied bearbeiten" bleibt beim Einstieg eingeklappt, kann aber gut sichtbar aufgeklappt werden.
- Erstes Laden: Skeleton oder gleichwertige Fortschrittsanzeige prüfen.
- Erststart nach Update von Versionen vor 1.0.0: alten Datenstand vollständig entfernen und App neu initialisieren, wenn die alte Datenstruktur nicht kompatibel ist.

## Spätere Ausbaustufen

Gesammelt am 2026-10-01, jeweils mit Kurzbefund. Jede Stufe wird vor der Umsetzung eigens geplant.

**Statistik klickbar („Hinter den Kacheln“)**

- Erster Schritt: Ein Tipp auf eine Kachel öffnet die gefilterte Mitgliederliste.
  - Heute ist das Antippen nur für eigene Kacheln verdrahtet, in `lib/presentation/statistics/kachel_raster.dart`.
- Danach Detailseiten nach `design/statistik/entwurf-runde-2.html` §6.

**Qualifikationen und Erinnerungen**

- Umfang:
  - `/api/qualifications` und `qualification_kinds` anbinden
  - Übersicht „läuft bald ab“
  - Erinnerung über `internal.data.expiry_soon` (`specs/pull-notifications.md`)
- Vorbild ist der EFZ-Code: `lib/domain/qualifikation/qualifikationsart.dart` und `lib/services/hitobito_efz_service.dart`.
- Die DPSG-API erlaubt auch POST auf `qualifications`.

**Events und Kurse aus Sicht der Teilnehmenden**

- Ziel: Events und Kurse über mehrere Layer und Gruppen hinweg suchen und filtern, sich anmelden und angemeldete Termine in den Kalender übernehmen.
- Befunde zur API (`specs/hitobito_dpsg_openapi.yaml`):
  - `events`, `event_kinds` und `event_participations` sind nur lesbar.
  - Eine Anmeldung per API gibt es nicht. Möglich wären ein Deep-Link auf die Eventseite, `external_application_link` oder ein Upstream-PR für `POST event_participations`.
  - Zum Filtern gibt es `filter[group_id]` als Liste, dazu Art, Kategorie, Typ, `after_or_on` und `before_or_on`.
  - Einen Filter über Layer oder rekursiv gibt es nicht.
  - Bei Kursen lassen sich freie Plätze aus `maximum_participants - participant_count` berechnen.
  - „Meine Anmeldungen“ geht über `event_participations` mit `filter[participant_id]`, das gibt es nur in der DPSG-Spec.
  - Die API bietet keinen iCal-Feed. Die App müsste Einträge selbst im Gerätekalender anlegen.
- Der Scope `api` sollte reichen. Prüfen gegen `dpsg.puzzle.ch`.
- Erster Schritt: ein Spike, wie viele Events mit echten Daten gepflegt sind und in welcher Qualität.
- Trägt das Feature, kommt es ins Supporter-Paket, ohne neue Preisstufe.

**Monetarisierung**

- Ein einziges Supporter-Paket mit Paletten, Icons und Badge. Später kommen gegebenenfalls Events und NaMi AI hinzu.
- Eine Store-Anbindung (`in_app_purchase` oder RevenueCat) ersetzt `UnlockedSupportAccess`.
- Den Erfolg „Unterstützung“ einblenden.
- Vorher den rechtlichen Rahmen klären.

**NaMi AI**

- Zuerst die Eval auf einem echten Gerät abschließen (`chat_ai/eval/manual-test-todo.md`) und BM25 gegen Hybrid entscheiden.
- Danach Android ermöglichen. Heute liegt die gesamte KI-Logik in Swift (`ios/NamiAiKit`), und das Gate in Dart schließt Android aus (`nami_ai_access_service.dart`).
- Empfehlung:
  - Die modellunabhängige Logik nach Dart portieren: BM25 mit Stemming, Grounding-Gate, Schreibabsicht-Filter, Sliding Window, Self-Correction-Policy, Prompts.
  - Je Plattform nur einen schmalen nativen Modell-Adapter vorsehen, auf Android z. B. Gemini Nano.
  - Das Retrieval vor dem Modellaufruf ausführen statt als Tool.

**Mitglied anlegen und Beitrittsanfragen**

- Die DPSG-API bietet POST für `people` und `groups/{id}/self_registrations`.
- Offen sind die Schreibrechte bei Teilsicht, die Offline-Queue und `require_person_add_requests`.

**Spätere Versionen oder ganz streichen**

- Abos/Mailinglisten, Rechnungen und die Events-Verwaltungssicht.
- Die Platzhalter für Abos und Rechnungen in `lib/presentation/screens/settings_page.dart` entfernen.

**Vor dem Livegang (Q1/2027, Version bleibt 1.0.0)**

- `feature/member-edit-felder` mergen, sobald der Hitobito-PR mit den Label-IDs durch ist.
- Den 1.0.0-Eintrag in `assets/changelog.json` auf den tatsächlichen Umfang bringen.
- `README.md` korrigieren: „Mitglieder erstellen“ beschreibt den Altstand.
- Crash-Reporting entscheiden.

## Später prüfen: Arbeitskontext-Ausbau

Diese Punkte sind für den aktuellen MVP nicht blockierend, bleiben aber als spätere Produktentscheidungen relevant.

- Schreib- und Bearbeitungslogik für teilweise sichtbare Layer klären, sobald Gruppenwechsel, Rollenwechsel, Verschieben oder Neuanlage von Personen geplant werden.
- Offene API-Felder prüfen, wenn sie fachlich gebraucht werden: insbesondere Person-`created_at` und mögliche Tags. Rollen-`created_at`, `start_on` und `end_on` sind bereits im Roles-Modell berücksichtigt.
- Mehrere offline verfügbare Arbeitskontexte nur dann konzipieren, wenn ein konkreter Bedarf für parallele Offline-Layer entsteht.
- Rekursive Sichten über Unterlayer nur als eigenen Produktentscheid behandeln; sie gehören weiterhin nicht automatisch zum aktiven Arbeitskontext.
- Persönliche Teilmengen, Tags und "Meine Gruppe" erst nach Stabilisierung der bestehenden Gruppen- und Stufenfilter konkretisieren.

## Manuelle Prüfliste

- [ ] Neue Testdaten enthalten Biber, Wö, Jufi, Pfadi und Rover mit bestätigten Gruppentypen.
- [ ] Stufenfilter zeigt mit neuen Testdaten alle erwarteten Stufen korrekt an.
- [ ] Biber wird über die zentrale Stufenableitung erkannt und bei fehlendem Biber im aktiven Stamm standardmäßig ausgeblendet.
- [ ] Jufi und Pfadi werden fachlich korrekt getrennt.
- [ ] Mitglieder ohne Stufenzuordnung landen weiterhin in Rest beziehungsweise Alle anderen.
- [ ] Konfliktlösung offline getestet.
- [ ] Fehlerhafte Telefonnummer offline gespeichert und später als Problemlösungsfall geprüft.
- [ ] Gültige Adresse offline gespeichert und später erfolgreich synchronisiert.
- [ ] Ungültige Adresse offline gespeichert und später als Problemlösungsfall geprüft.
- [ ] Automatischer Sync mit vorhandenen Queue-Einträgen geprüft.
