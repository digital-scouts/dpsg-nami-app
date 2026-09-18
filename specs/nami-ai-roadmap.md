# NaMi AI Roadmap

Status: Entwurf für ersten Test und MVP
Datum: 2026-06-08
Kontext: NaMi App, Apple FoundationModels-Framework (bestätigt, iOS 26+), Siri und App Intents (spätere Phase)
Update 2026-09-18: Plattform ist öffentlich. Framework-Name und Mindestversion bestätigt (Abschnitt 2.3/2.6), Abschnitt 3 um einen technischen Umsetzungsplan für den ersten Vertical Slice (T1/T2) ergänzt.

## 1) Ziel und Scope

### Zielbild
- NaMi AI bietet in der App und per Siri einen schnellen, sicheren und nachvollziehbaren Zugang zu Wissen und Funktionen rund um DPSG-Kontext, App-Bedienung, Mitgliedsdaten und Statistik.
- Die erste Ausbaustufe fokussiert auf hohe Nutzbarkeit bei klar begrenztem Risiko.

### Produktziele
- Weniger Zeit für wiederkehrende Fragen und einfache Datenabfragen.
- Bessere Selbsthilfe für Leitende und Vorstände.
- Sichere, protokollierte Ausführung von Aktionen mit Rollen- und Rechteprüfung.

### Scope in dieser Spec
- Technischer Zuschnitt für einen ersten Test.
- Roadmap bis MVP.
- MVP-Funktionskatalog mit Priorisierung Muss, Soll, Kann, Später.
- Gate-Regeln für kontrollierte Aktivierung.

### Out of Scope
- Vollständige Automatisierung aller Verwaltungsprozesse.
- Freie, unkontrollierte Tool-Ausführung ohne Benutzerkontext.
- Plattformübergreifende Implementierung außerhalb iOS in dieser Phase.

## 2) Systembereiche

### Überblick
Die Lösung wird in acht Systembereiche getrennt, um Verantwortlichkeiten sauber zu halten.

### 2.1 Chat UI
- In-App Chat mit Konversationsverlauf, Quellenhinweisen und klaren Handlungsbuttons.
- Sichtbare Zustände: arbeitet, Rückfrage nötig, Ergebnis, nicht zulässig.
- Antwortformatierung für kurze Entscheidungen und klare nächste Schritte.

### 2.2 Siri und App Intents
- Intent-Einstieg für häufige Aufgaben und Fragen.
- Übergabe von Nutzerkontext, Rollenhinweis und aktiver Organisationseinheit.
- Definierte Intent-Antworttypen: Info, Aktion bestätigt, Aktion blockiert.

### 2.3 Apple Foundation Schnittstelle
- Bestätigtes Framework: `FoundationModels` (`import FoundationModels`), verfügbar seit iOS 26. Kernbausteine: `SystemLanguageModel`, `LanguageModelSession`, `Tool`-Protokoll für Funktionsaufrufe, `@Generable`/`@Guide` für strukturierte, validierte Ausgaben.
- Nutzung von FoundationModels für Sprachverstehen, Zusammenfassung und Textgenerierung.
- Strikte Trennung zwischen Inhaltsgenerierung und fachlicher Ausführung.
- Wichtig: FoundationModels kann Inhalte generieren, Dateierstellung und Export muss die App implementieren.
- Klarstellung: Die App-seitige Session-API ist rein on-device. Es gibt keine automatische Server-Weiterleitung wie bei Apples eigener Private-Cloud-Compute für Systemfunktionen. Ein Server-Call ist möglich und nicht ausgeschlossen, aber nur als bewusst selbst gebautes zusätzliches Tool, nie als eingebautes Framework-Verhalten.

### 2.4 Document Pipeline
- Ingestion und Aufbereitung von DPSG-Dokumenten, Ordnung, Satzung, Hilfetexten.
- Versionierung und Gültigkeitsmarken für Quellen.
- Retrieval mit Zitierpflicht für normative Aussagen.
- Ist-Zustand: Rohquellen (5 PDFs: Satzung Stamm/Bezirk/Diözese/Bund, Ordnung) liegen in `chat_ai/files/`. Nur Satzung Stamm ist bisher gechunkt (`assets/ai_kontext/satzung_stamm_2024.json`, 69 Chunks, ungenutzt), Chunking ohne Metadaten. Vorhandene OpenAI-Embeddings (`satzung_stamm_2024_embeddings.json`) sind für On-Device-Retrieval nicht nutzbar und werden im Zuge der Umsetzung entfernt (siehe Abschnitt 3.4).
- Verbindliches Chunk-Metadatenschema für Zitierfähigkeit: `doc_id`, `ebene`, `doc_title`, `doc_stand`, `section_number`, `section_title`, `page_start`/`page_end`, `text`, `source_file`.

### 2.5 Orchestrator und Tools
- Orchestrator steuert Dialogfluss, Tool-Auswahl und Reihenfolge.
- Tools kapseln App-Funktionen und Server-Endpunkte mit festen Verträgen.
- Rückfragen bei Mehrdeutigkeit vor schreibenden Aktionen.

### 2.6 Gates
- Plattform-Gate: nur iOS aktiv.
- Geräte-Gate: Laufzeitprüfung via `SystemLanguageModel.default.availability` (Gerät ungeeignet / Apple Intelligence nicht aktiviert / Modell lädt noch), nicht über eine Geräte-Identifier-Whitelist — Whitelists sind wartungsintensiv und faktisch unzuverlässig.
- Versions-Gate: Mindestversion iOS 26 (reale Mindestversion von FoundationModels, unabhängig von der jeweils aktuellsten iOS-Version).
- Env-Gate: Feature-Flag NAMI_AI_ENABLED standardmäßig false.
- Rollout-Gate: schrittweise Freigabe pro Nutzergruppe oder Verband.
- Monetarisierungs-Gate: optionale Paywall für Premium-Funktionen.

### 2.7 Safety und Audit
- Rollen- und Rechteprüfung vor jedem Datenzugriff und jeder Änderung.
- Policy-Prüfung für sensible Anfragen und potenziell unzulässige Auskünfte.
- Audit-Log für Prompt, Tool-Aufrufe, Ergebnisstatus und Begründungen.
- Nachvollziehbare Fehlermeldungen ohne Offenlegung sensibler Details.

### 2.8 Qualität und Betrieb
- Qualitätsmetriken: Antwortqualität, Erfolgsquote, Fehlerrate, Abbruchrate.
- Betrieb: Telemetrie, Alarmierung, Fallback-Verhalten bei Tool-Fehlern.
- Teststrategie: Intent-Tests, Integrations-Tests, Sicherheits- und Rollen-Tests.

## 3) Technischer Umsetzungsplan: Vertical Slice T1/T2

Konkretisierung von Meilenstein T1/T2: Wissensfragen zu Satzung/Ordnung, on-device via FoundationModels, mit Quellenpflicht, ohne Schreibzugriff. Stand: 2026-09-18.

### 3.1 Machbarkeits-Einschätzung
Scope-Hinweis: Diese Einschätzung ist bewusst enger gefasst als der Rest von Abschnitt 3. Sie prüft ausschließlich einen Piloten zum Thema **Stammesversammlung** auf Basis der **Satzung Stamm (Mai 2024)** — keine anderen Ebenen (Bezirk, Diözese, Bund), keine Ordnung, keine anderen Themen der Satzung Stamm selbst. 3.2–3.11 beschreiben weiterhin den breiteren Zuschnitt über alle 5 Dokumente; bei Umsetzung ist zu klären, ob dieser enge Piloten-Rahmen die Ziel-Konfiguration für T1/T2 wird oder nur ein Zwischenschritt ist.

Der Grundgedanke ist heute vollständig umsetzbar, nichts Grundsätzlich fehlt. `SystemLanguageModel`, `LanguageModelSession`, das `Tool`-Protokoll und `@Generable`/`@Guide` sind stabiler Teil von FoundationModels seit iOS 26.

Konkrete Korpus-Analyse (Ist-Zustand `assets/ai_kontext/satzung_stamm_2024.json`, 69 Chunks nach dem Muster ein Chunk pro nummerierter Ziffer, `chat_ai/pdf_phrase_extraction.py`):

- 26 von 69 Chunks (Ziffer 18–67, verstreut über gut zwei Drittel des Dokuments) enthalten den Begriff „Stammesversammlung" wörtlich — das ist der direkt per Keyword-Filter fassbare Kern des Themas.
- Mindestens 5 weitere Chunks gehören inhaltlich zum selben Regelungskomplex, ohne den Begriff wörtlich zu wiederholen, weil sie eine vorangehende Ziffer nur fortsetzen: Ziffer 48 (Mehrheitsregel für „Organe und Gremien"), Ziffer 49 (Wahlmodus), Ziffer 54 (Formvorschrift für Anträge, Fortsetzung von Ziffer 53), Ziffer 57 (Fristverlängerung, Fortsetzung von Ziffer 55/56), Ziffer 63 (Vertraulichkeit, Fortsetzung vor Ziffer 64 zum Ausschluss der Öffentlichkeit in der Stammesversammlung). Ein reiner Wortfilter auf „Stammesversammlung" würde diese Chunks verlieren, obwohl sie zur vollständigen Beantwortung typischer Fragen (z. B. „Wie wird gewählt?", „Wie werden Anträge gestellt?") gehören.
- Token-Budget ist unkritisch: Die 26 Kern-Chunks sind zusammen rund 13.900 Zeichen (~3.500 Tokens grob geschätzt), der gesamte Korpus rund 32.000 Zeichen (~8.000 Tokens) — zu groß für einen Prompt in Rohform, aber irrelevant sobald Retrieval nur die Top-k passenden Chunks pro Anfrage liefert (typischerweise 3–5 Chunks, ~1.500–2.700 Zeichen, ~400–700 Tokens) — komfortabel innerhalb des kleinen Kontextfensters.

Reale, nicht-blockierende Restrisiken für diesen engen Zuschnitt:

- **Themenabgrenzung ist ein Retrieval-Problem, kein Dokumentgrenzen-Problem.** Da bisher nur Satzung Stamm gechunkt ist, sind andere Ebenen und die Ordnung schon heute technisch gar nicht im Korpus vorhanden — „keine anderen Ebenen/Ordnung" ist also praktisch bereits erfüllt. Innerhalb der Satzung Stamm behandeln aber 43 der 69 Chunks andere Themen (Mitgliedschaft, Ausschluss, Siedlungen, Auflösung u. a.) im selben unstrukturierten Asset ohne Themen-Metadatum. „Keine anderen Themen" erfordert daher einen expliziten Vorfilter auf einen definierten Chunk-Subset, nicht nur eine Prompt-Anweisung — Prompt-only-Restriktion ist laut dem bereits bekannten Risiko „`@Generable` erzwingt nur Struktur, nicht Wahrheit" nicht zuverlässig genug, um Themen-Leaks zuverlässig zu verhindern. **Umgesetzt:** `chat_ai/pilot_stammesversammlung/build_subset.py` erzeugt den verifizierten Subset als `stammesversammlung_pilot_chunks.json` (32 Ziffern, je mit `reason`: `direct_match`/`continuation`/`hyphenation_elision`) — bewusst als eigenständiges Piloten-Artefakt unter `chat_ai/`, nicht als App-Asset unter `assets/ai_kontext/`, da noch nicht an eine native Retrieval-Tool-Implementierung (3.6) angebunden.
- **Grobkörniges Chunking ohne Metadaten verliert thematisch zugehörige Fortsetzungs-Ziffern.** Bei der manuellen Verifikation kamen zwei Arten von Lücken zutage: 5 Fortsetzungs-Ziffern ohne woertliche Wiederholung (48, 49, 54, 57, 63) und ein Fall von Bindestrich-Kurzform, Ziffer 60 „Stammes- und Bezirksversammlung", den ein reiner Substring-Filter auf „Stammesversammlung" ebenfalls verloren hätte. Für den engen Piloten reichte eine einmalige manuelle Nachschärfung der Chunk-Liste (kein automatisiertes Pipeline-Problem); ob dieses Muster bei den übrigen 4 Dokumenten (3.4) systematisch genug ist, um einen Heuristik-Check statt reiner Handarbeit zu rechtfertigen, ist offen.
- **Die geplante `unclear`-Antwortkategorie (3.6) unterscheidet aktuell nicht zwischen „keine Quelle gefunden" und „Quelle vorhanden, aber außerhalb des engen Themenrahmens" (andere Ebene, Ordnung, anderes Satzungs-Stamm-Thema).** Für sauberes Scoping wäre eine dritte Kategorie oder ein vorgelagerter Themen-Gate nötig — Detailausarbeitung gehört inhaltlich in 3.6/3.7, wird hier nur als Erkenntnis aus der engeren Betrachtung festgehalten.
- Deutschsprachige Antwortqualität bei Verbandsjargon ist unbekannt und muss früh per Spike geprüft werden (3.3) — für diesen engen Piloten genügt ein kleineres, gezielteres Fragenset (10–15 Fragen ausschließlich zur Stammesversammlung statt breit gestreut über 5 Dokumente).
- Guardrails sind pauschal, nicht DPSG-spezifisch; harmlose Fragen können vereinzelt blockiert werden — nur UX-seitig auffangbar. Unverändert gegenüber dem breiteren Zuschnitt.
- CI prüft aktuell nichts aktiv: `#if canImport(...)` kompiliert bei fehlendem Modul lautlos in den Fallback-Zweig — genau das ist mit `AppleIntelligence` statt `FoundationModels` bereits einmal passiert (siehe 3.9). Unverändert gegenüber dem breiteren Zuschnitt.

Fazit: Der enge Zuschnitt auf Stammesversammlung/Satzung Stamm reduziert Korpusgröße (32 statt 69 Chunks) und Guardrail-Prüffläche spürbar und macht das Kontextfenster-Risiko praktisch irrelevant. Er verschiebt den Schwerpunkt aber von „reicht das Kontextfenster" zu „wird der enge Themenrahmen zuverlässig eingehalten". Der verifizierte Chunk-Subset ist jetzt vorhanden (`chat_ai/pilot_stammesversammlung/`); offen bleibt weiterhin die Antwortkategorie für „richtiges Dokument, falsches Thema" — das ist ein Schema-/Prompt-Thema und gehört inhaltlich in 3.6/3.7, nicht in diesen Feasibility-Piloten.

Klarstellung Ist-Zustand: Der eigentliche Frage-Kontext-Antwort-Workflow existiert im Code noch nicht. `nami_ai_chat_page.dart` und `nami_ai_service.dart` senden eine Frage bereits vollständig per MethodChannel an die native Seite (Schritt 1 ist fertig). `SceneDelegate.swift` fängt das zwar ab, aber `generateReply` ist dort weiterhin der alte Platzhalter hinter `#if canImport(AppleIntelligence)` (der bekannte Bug aus 3.9) und gibt einen hartcodierten String zurück — kein `FoundationModels`-Import, kein `LanguageModelSession`, keine Kontextübergabe. Schritt 2 (Kontext übergeben) und Schritt 3 (KI antwortet) fehlen komplett; der in diesem Abschnitt gebaute Chunk-Subset (`chat_ai/pilot_stammesversammlung/`) wird von keiner Codestelle gelesen.

Plan: minimaler 3-Schritte-Workflow für den Stammesversammlung-Piloten (noch nicht umgesetzt, nur geplant):

1. **Kontext als App-Asset verfügbar machen.** `stammesversammlung_pilot_chunks.json` nach `assets/ai_kontext/` kopieren (oder von dort per Skript generieren) und in `pubspec.yaml` als Asset eintragen, damit Swift per `FlutterDartProject.lookupKeyForAsset(...)` → `Bundle.main.path(forResource:)` darauf zugreifen kann — Architekturentscheidung ist in 3.2 bereits getroffen. Aufwand: klein.
2. **Bug fixen + echtes Verfügbarkeits-Gate in `SceneDelegate.swift`.** `#if canImport(AppleIntelligence)` → `#if canImport(FoundationModels)`, `import FoundationModels`, dazu `@available(iOS 26.0, *)`-Guard und `SystemLanguageModel.default.availability`-Prüfung (Pseudocode bereits in 3.5 notiert) statt des `iOS 17`-Placeholders. Aufwand: klein.
3. **Kontext laden und übergeben (bewusst ohne echtes Retrieval für den ersten Spike).** Bei nur 32 Chunks (~3.500 Tokens roh, siehe Korpus-Analyse oben) reicht für einen ersten funktionierenden Durchstich, alle 32 Chunks als feste Session-Instructions zu laden statt vorab eine Suche zu bauen — das testet direkt „kann das Modell aus echtem Satzungstext korrekt antworten", ohne Retrieval-Qualität als zusätzliche Variable. Echtes Retrieval (Tool-Protokoll, Score-Schwelle) bleibt 3.6-Scope für den breiteren Fall mit mehr Dokumenten.
4. **`LanguageModelSession` aufrufen und Platzhalter ersetzen.** System-Prompt fest auf „beantworte ausschließlich Fragen zur Stammesversammlung laut Satzung Stamm, alles andere ablehnen" plus die geladenen Chunks; `session.respond(to:)` aufrufen, Klartext-Antwort zurückgeben. Bewusste Vereinfachung gegenüber 3.6: kein `@Generable`/`NamiAiAnswer`-Schema, keine belegten Quellenangaben, kein natives Grounding-Gate in diesem ersten Spike — das Modell kann also halluzinieren, ohne dass eine technische Kontrolle das abfängt. Für einen internen Testscreen ohne Rollout akzeptabel, für jede Freigabe über den eigenen Kreis hinaus nicht.
5. **Manuell auf echtem Gerät oder Apple-Intelligence-fähigem Simulator testen.** Voraussetzung: entweder ein reales iPhone mit iOS 26+, geeigneter Hardware und aktivierter Apple Intelligence, oder ein Simulator auf einem Mac, der selbst Apple Intelligence unterstützt (Apple Silicon M1 Pro/Max oder neuer, passende macOS-Version, Toggle aktiviert) — ein gewöhnlicher Simulator auf nicht unterstützter Hardware liefert kein Modell. Automatisiert/CI ist das nicht prüfbar (siehe 3.11). Fragenset: die Stammesversammlung-Themen aus dem Chunk-Subset, z. B. „Wie oft muss die Stammesversammlung stattfinden?", „Wer darf teilnehmen?", „Wie werden Anträge gestellt?".

Aufwand grob gesamt für 1–4: Größenordnung halber bis ganzer Tag für jemanden mit Vorkenntnis der Codebasis; Schritt 5 (Testen) kommt als separate, nicht automatisierbare Zeit obendrauf und braucht dein Gerät/deinen Mac.

### 3.2 Architekturentscheidung
Retrieval läuft zwingend nativ in Swift als `Tool`, nicht in Dart — `Tool.call(arguments:)` wird innerhalb der `LanguageModelSession`-Laufzeit ausgeführt, ein Rückkanal zu Dart pro Tool-Aufruf wäre unnötige Latenz. Die Chunk-Daten bleiben ein einziges Flutter-Asset (`assets/ai_kontext/`), von Swift über `FlutterDartProject.lookupKeyForAsset(...)` → `Bundle.main.path(forResource:)` gelesen, statt einer zweiten Kopie als Xcode-Bundle-Resource (vermeidet Drift bei Corpus-Updates). Der Korpus bleibt mit geschätzt 200–500 Chunks über alle 5 Dokumente klein genug für Brute-Force-Suche ohne Datenbank/Vektorindex.

### 3.3 Phase 0 – Spike: deutsche Antwortqualität & Guardrail-Verhalten (manuell, 0,5–1 Tag)
Minimale `LanguageModelSession` auf echtem Testgerät (oder Simulator mit Apple-Intelligence-Unterstützung), 10–15 handverlesene Satzungsfragen, roher Chunk-Text im Prompt ohne Tooling. Beobachten: Sprachqualität bei Verbandsjargon, Guardrail-Fehlrate. Deliverable: Kurznotiz mit Go/No-Go-Einschätzung, steuert den Umfang von Prompt-Tuning in 3.8. Muss auf echtem Gerät erfolgen, nicht automatisierbar.

**Ergebnis (echtes Gerät, Stand 2026-09-18):** Ausgangspunkt war ein konkreter Bug im 3.1-Testlog: Auf "Was sind die Aufgaben des Stavo in der SV?" kam die Antwort zu den Aufgaben der SV selbst. Als erste Maßnahme wurde ein statisches DPSG-Verbandsjargon-Glossar (SV, Stavo, StaLei, LR, Wö, Jufi, Pfadi, Rover, Biber, Kurat*in, BDKJ, rdp, StuKo, DV, DL) in `NamiAiResponder.swift` ergänzt, dazu der System-Prompt von einer hartcodierten "nur Stammesversammlung"-Themenzeile auf eine allgemeine, rein grounding-basierte DPSG-Beschreibung umgestellt (Ablehnung hängt jetzt ausschließlich daran, ob die Auszüge die Frage abdecken, nicht an einer festen Themen-Zeile) — realistischer für das spätere Produkt, in dem es keine hartcodierte Themenbeschränkung mehr geben wird.

- **Jargon-Auflösung funktioniert gut:** Reine Abkürzungsfragen (Stavo-Zusammensetzung, StaLei vs. LR, Wö/Jufi-Vertretung in der SV, SV vs. StuKo) wurden nach Glossar-Einführung korrekt aufgelöst.
- **Der ursprüngliche Stavo/SV-Bug ist weiterhin reproduzierbar — trotz Glossar.** Das legt eine falsche Ursachenzuschreibung offen: Es war nie ein Vokabular-Problem. Der Korpus enthält keinen Chunk, der explizit "Aufgaben des Stammesvorstands" auflistet (Stavo-Zuständigkeiten stehen verstreut in Ziffer 23, 29, 55/56); Ziffer 24 ist der einzige Chunk mit einer klaren "hat folgende Aufgaben"-Struktur, und das Modell greift strukturell danach, unabhängig vom gefragten Organ. Das ist ein Retrieval-/Synthese-Problem, kein Prompt-Tuning-Fall — gehört fachlich in 3.6 (natives Grounding-Gate, Tool-basierte Suche über mehrere Chunks), nicht in weiteres Glossar-Tuning in 3.8.
- **Zwei weiche Guardrail-Grenzfälle:** Bei einer Frequenzfrage zu einem im Korpus nicht geregelten Gremium wich das Modell auf eine thematisch verwandte, aber nicht zutreffende Aussage aus statt korrekt abzulehnen. Bei einer Ausschlussfrage lehnte es den Kern korrekt ab ("nicht explizit beschrieben"), hängte aber lose verwandte Zusatzinfos an, statt sauber zu stoppen. Kein Halluzinieren harter Fakten, aber auch kein sauberes binäres Antworten-oder-Ablehnen.
- **Der grounding-only System-Prompt (ohne hartcodierte Themen-Zeile) hat sich bewährt:** Eine komplett fachfremde Frage wurde korrekt und ausschließlich mit Verweis auf die fehlende Quellenabdeckung abgelehnt — bestätigt, dass die Ablehnung nicht an der alten "nur SV"-Formulierung hing.
- **UI-Fund (kein Modellproblem):** Das Modell liefert von sich aus Markdown-Formatierung (Fett, Listen), die aktuelle Chat-UI rendert `message.text` aber als reinen `Text`-Widget ohne Markdown-Unterstützung (`nami_ai_chat_page.dart:234`) — Rohsternchen sichtbar. Siehe TODO in 3.7.

**Go/No-Go:** Go für die Fortsetzung mit 3.4–3.7. Die Sprachqualität und Guardrail-Grundfunktion sind tragfähig; der verbleibende Schwachpunkt (Multi-Chunk-Synthese für Organe ohne eigene "Aufgaben"-Liste) ist kein Blocker für den nächsten Schritt, muss aber explizit im Grounding-Gate/Retrieval-Design von 3.6 berücksichtigt werden, nicht durch weiteres Prompt-Tuning in 3.8 "wegoptimiert" werden.

### 3.4 Phase 1 – Dokumenten-Pipeline (2–3 Tage)
Ein konfigurationsgetriebenes Skript statt vier Kopien, zweigleisige Chunking-Strategie:
- Satzungen (Stamm/Bezirk/Diözese/Bund): nummerierte Absätze als natürliche Chunk-Grenze, TOC-Erkennung per Heuristik statt hartcodierter Seitenzahl, Section-Header-Vererbung als Metadatum.
- Ordnung: andere Struktur (Kapitel/Stufen statt einheitlicher Nummerierung) → Heading-Erkennung über Schriftattribute mit Fallback auf Seiten-Chunking; für T2 bewusst gröbere Granularität akzeptieren, iterativ verfeinern.
- Ziel-Chunk-Größe 150–400 Tokens, ~15 % Overlap bei langen Absätzen.

Dateien: neu `chat_ai/build_chunks.py` (ersetzt `pdf_phrase_extraction.py`), `chat_ai/README.md` (Pflegeprozess), `assets/ai_kontext/nami_ai_corpus_v1.json`. Entfernen: `assets/ai_kontext/satzung_stamm_2024.json`, `assets/ai_kontext/satzung_stamm_2024_embeddings.json`, `chat_ai/phrases_to_embedding_vector.py` (ungenutzter Cloud-Embedding-Pfad, siehe 3.6).

Pflegeprozess: Satzungen/Ordnung ändern sich selten (Bundesversammlungs-Rhythmus). Kein Server-Sync nötig — neue PDF-Version → Skript neu laufen lassen → Diff sichten → `corpus_version` bumpen → normales App-Release.

Zwischenergebnis: Skript läuft lokal über alle 5 PDFs, JSON validiert (keine leeren Chunks, Pflichtfelder gesetzt), Stichprobe manuell geprüft.

### 3.5 Phase 2 – Natives Grundgerüst + echtes Verfügbarkeits-Gate (2–3 Tage)

**Umgesetzt:** Der Bugfix `#if canImport(AppleIntelligence)` → `#if canImport(FoundationModels)` sowie die Auslagerung in dedizierte Dateien war bereits vor diesem Schritt erledigt: `SceneDelegate.swift` registriert nur noch `NamiAiFlutterBridge`, die eigentliche Verfügbarkeitslogik liegt in `NamiAiKit` (`NamiAiAvailability.swift`, `NamiAiAssistant.swift`, `NamiAiError.swift`) und bildet bereits alle vier `SystemLanguageModel.Availability`-Fälle ab, unit-getestet in `NamiAiAvailabilityTests.swift`.

In diesem Schritt ergänzt: `NamiAiAssistant.checkAvailability() -> NamiAiError?` als eigenständige, von `respond` wiederverwendete Prüfung, dazu die neue MethodChannel-Methode `checkAvailability` in `NamiAiFlutterBridge.swift` (liefert `{"available": true}` bzw. `{"available": false, "reason": <flutterErrorCode>}`). Jede Codestelle braucht weiterhin beide Guards zusammen: `#if canImport(FoundationModels)` (Compile-Zeit) und `@available(iOS 26, *)` (Laufzeit).

In `nami_ai_access_service.dart`/`nami_ai_env.dart`: Geräte-Identifier-Whitelist (`NAMI_AI_DEVICE_GATE_MODE`, `_WHITELIST`, `_APPLE_INTELLIGENCE_WHITELIST`) vollständig entfernt statt nur stillgelegt; `checkAvailability` (über die neue `NamiAiAvailabilityService`-Wrapperklasse) ist jetzt alleinige Quelle der Wahrheit für das Geräte-Gate. Die dadurch ungenutzte `NamiAiDeviceService`-Klasse und die `device_info_plus`-Abhängigkeit wurden ebenfalls entfernt. Die Mindestversion war zuvor über `NAMI_AI_MIN_IOS_MAJOR` per Env-Flag konfigurierbar (Fallback bereits in Commit `173a7bd` auf 26 korrigiert, siehe auch Abschnitt 7); da es sich um ein reales API-Faktum von FoundationModels handelt und nicht um einen Rollout-Hebel wie `NAMI_AI_ENABLED`, wurde der Env-Key entfernt und `26` stattdessen als Konstante `NamiAiAccessService._minIosMajorVersion` fest codiert.

CI-seitige Absicherung (Xcode-Version pinnen, aktiver Check ob das FoundationModels-SDK auf dem Runner vorhanden ist) ist bewusst nicht Teil dieses Schritts, sondern bleibt Aufgabe von Abschnitt 3.9.

Zwischenergebnis: `checkAvailability`-Mapping unit-getestet mit gemocktem Dart-`MethodChannel` (`test/nami_ai_service_test.dart`) für Erfolgs- und Fehlerfall; `NamiAiAccessService.evaluate()` erstmals vollständig getestet für alle `NamiAiBlockReason`-Fälle (`test/nami_ai_access_service_test.dart`). Manueller Test auf echtem iOS-26(+)-Gerät (Toggle testweise aus/an) steht noch aus.

### 3.6 Phase 3 – Retrieval-Tool + Quellenpflicht technisch erzwingen (2 Tage)

```swift
@Generable
struct NamiAiSourceRef {
    @Guide(description: "Kurztitel, z. B. 'Satzung Stamm'") var docTitle: String
    @Guide(description: "Abschnitts-/Paragraphennummer") var sectionNumber: String
    @Guide(description: "Stand des Dokuments, z. B. 'Mai 2024'") var docStand: String
}

@Generable
struct NamiAiAnswer {
    @Guide(description: "Antwort ausschließlich basierend auf gefundenen Quellen") var answer: String
    @Guide(description: "Belegte Quellen; leer, wenn keine passende Quelle gefunden wurde") var sources: [NamiAiSourceRef]
    @Guide(description: "true, wenn keine passende Quelle gefunden wurde oder Frage außerhalb Satzung/Ordnung liegt") var unclear: Bool
}

struct NamiAiSearchTool: Tool {
    let name = "search_regelwerk"
    let description = "Durchsucht Satzung und Ordnung der DPSG."
    @Generable struct Arguments { @Guide(description: "Suchbegriffe/Frage") var query: String }
    func call(arguments: Arguments) async throws -> ToolOutput { /* Suche gegen NamiAiCorpus */ }
}
```

Retrieval-Varianten geprüft:

| Variante | Bewertung |
|---|---|
| (A) Rein lexikalisch (BM25-artig) — empfohlen | Kein Zusatzrisiko, deterministisch, über 200–500 Chunks Sub-Millisekunde, ohne Gerät/Modell automatisiert testbar. Schwäche: Umformulierungen/Komposita. |
| (B) On-Device-Embeddings (`NLContextualEmbedding`) | Bessere Paraphrasen-Erkennung, aber eigene Asset-Verfügbarkeitsprüfung und Nicht-Determinismus über OS-Versionen — verdoppelt die Fehlerfläche des ersten Slice. |
| (C) OpenAI-Embeddings weiter nutzen | Macht die Kernfunktion Cloud-abhängig für Inhalte ohne Datenschutzvorteil; neuer Drittanbieter müsste in `docs/app-privacy-policy.md` ergänzt werden. Verworfen für diesen Zweck. |
| (D) Hybrid | Lohnt sich erst bei deutlich größerem Korpus als hier vorhanden. |

A jetzt umsetzen, B/D als datengetriebene Option nach 3.8 (Eval zeigt, ob Recall-Grenzen real ein Problem sind).

**TODO:** `NamiAiGlossaryTool` — das in 3.3 als statischer, immer mitgeschickter String eingeführte Verbandsjargon-Glossar (`NamiAiResponder.glossary`) als eigenes `Tool` neben `NamiAiSearchTool` umsetzen, das das Modell nur bei Bedarf aufruft, statt die Liste in jedem Prompt mitzuschleppen. Lohnt sich erst, sobald hier ohnehin ein Tool-Grundgerüst entsteht — bei aktuell 15 Einträgen ist der Umbau kein eigenständiger Aufwand.

Wichtiger Befund: `@Generable`/`@Guide` erzwingen nur die Struktur, nicht die Wahrheit — deshalb natives Grounding-Gate nach jedem `respond`-Aufruf: jede zurückgegebene `source` gegen die tatsächlich im letzten Tool-Aufruf gelieferten Chunk-IDs abgleichen, nicht verifizierbare Quellen herausfiltern bzw. Antwort als `unclear` behandeln. Zusätzlich Mindest-Score-Schwelle im Tool.

Zwischenergebnis: `NamiAiRetrievalTests.swift` mit ersten 10–15 Eval-Fragen, grün in CI — reiner Algorithmus, kein Gerät/Modell nötig.

### 3.7 Phase 4 – Flutter-Integration: Chat-UI, Persistenz, Streaming, Folgefragen (3–4 Tage)
Anfrage verstehen: keine vorgeschaltete ML-Intent-Klassifikation nötig für den engen T1/T2-Scope. Zweistufig: (1) deterministischer Vorfilter in Swift ohne LLM für explizite Schreibverben → sofortige feste Antwort; (2) alles andere ans Modell, Pflichtfeld `unclear` zwingt es, Off-Topic-Fragen zu markieren statt zu halluzinieren. Ein voller Intent-Router lohnt sich erst ab T3.

Folgefragen: eine `LanguageModelSession` pro Chat-Session nativ am Leben halten, nicht bei jedem Turn neu aufbauen. Bei Kontextüberlauf: Sliding-Window-Truncation (letzte 1–2 Turns behalten, neue Session mit gleichem Systemprompt) statt LLM-Zusammenfassung — deterministisch, kein zusätzliches Halluzinationsrisiko. Nach App-Neustart: nativer Session-Zustand ist zwangsläufig weg → bewusst neues Gespräch beginnen.

Persistenz: neues `NamiAiChatHistoryLocalRepository` nach dem Muster von `lib/data/arbeitskontext/secure_arbeitskontext_local_repository.dart` (verschlüsselte Hive_ce-Box). Streaming: `session.streamResponse` → neuer `EventChannel` (`com.namiapp/nami_ai_stream`) statt reinem MethodChannel.

**TODO:** Markdown-Rendering für Chat-Bubbles. Fund aus dem 3.3-Spike: Das Modell liefert von sich aus Markdown (Fett, Listen), `nami_ai_chat_page.dart:234` rendert `message.text` aber aktuell als reinen `Text`-Widget ohne Markdown-Unterstützung — Rohsternchen/Listenzeichen sichtbar. Umstellung auf ein Markdown-Widget (z. B. `flutter_markdown`, noch keine Dependency in `pubspec.yaml`) statt dem Modell Markdown per Prompt zu verbieten, da die Struktur (Listen bei Aufgabenkatalogen etc.) die Antworten inhaltlich klarer macht.

Zwischenergebnis: Widget-Tests für alle UI-Zustände inkl. Quellenanzeige; manueller End-to-End-Test auf Gerät mit sichtbaren §-Referenzen.

### 3.8 Phase 5 – Eval-Set & Prompt-/Antwortoptimierung (läuft parallel zu 3.6/3.7)
`chat_ai/eval/eval_questions.json`: 30–50 kuratierte Fragen mit erwarteten Dokument-/Abschnittsreferenzen. Retrieval-only-Prüfung automatisiert/CI-fähig (Teil von `NamiAiRetrievalTests.swift`). End-to-End-Qualität (Antworttext, Zitate, Halluzination) nicht automatisierbar (Simulator/CI hat kein geladenes Modell) → Human-in-the-loop-Runbook in `chat_ai/eval/README.md`, manuell auf echtem Gerät. Guardrail-Handling: `GenerationError`-Fälle auf ein kleines `NamiAiError`-Enum mappen, nie Rohfehlertext an die UI durchreichen.

Zwischenergebnis: dokumentierte Eval-Runde → Entscheidungsgrundlage, ob Retrieval-Upgrade (Variante B/D) nötig wird.

### 3.9 Phase 6 – CI-Absicherung (1 Tag)
Schließt die Lücke, die die `AppleIntelligence`/`FoundationModels`-Verwechslung überhaupt erst unbemerkt ließ: Xcode-Version im `validate-ios`-Job explizit pinnen statt unbestimmtem `macos-latest` (konkrete Runner-Version zum Umsetzungszeitpunkt neu verifizieren, CI-Infrastruktur ändert sich schnell); neuer Schritt, der das FoundationModels-Modul aktiv prüft statt sich auf impliziten Build-Erfolg zu verlassen; `xcodebuild test` für das bestehende `RunnerTests`-Target ergänzen (aktuell läuft nur `build`).

### 3.10 Risikoübersicht

| Risiko | Auswirkung | Gegenmaßnahme |
|---|---|---|
| CI prüft SDK-Vorhandensein nicht aktiv | Fallback-Zweig bleibt unbemerkt aktiv (bereits einmal passiert) | 3.9: expliziter Modul-Check + Xcode-Pin |
| Kleines Kontextfenster | Antwortabbruch bei mehreren Turns/vielen Chunks | 3.4 Chunk-Größe, 3.6 Score-Schwelle, 3.7 Truncation |
| `@Generable` erzwingt nur Struktur, nicht Wahrheit | Quellen könnten trotz Schema halluziniert werden | 3.6 natives Grounding-Gate |
| Geräte-Whitelist unzuverlässig/wartungsintensiv | Falsch positive/negative Gate-Entscheidungen | 3.5: `SystemLanguageModel.availability` ersetzt Whitelist |
| Deutsche Antwortqualität bei Verbandsjargon unbekannt | Ggf. viel Nacharbeit in Prompt-Design | 3.3 Spike vor Vollinvestition |
| Ordnung-PDF-Struktur uneinheitlich | Gröbere Zitate als bei Satzung | 3.4: zweigleisige Chunking-Strategie, "erste Version" bewusst akzeptiert |

### 3.11 Verifikation
Automatisiert, kein Gerät nötig: `flutter test`, `xcodebuild test` für `NamiAiRetrievalTests.swift`/`NamiAiCorpusTests.swift` — ab 3.9 auch tatsächlich in CI verdrahtet. Manuell, echtes Gerät/Simulator mit Apple Intelligence nötig: Phase-0-Spike, Verfügbarkeits-Zustände, End-to-End-Antwortqualität inkl. Zitatkorrektheit, Guardrail-Verhalten bei Grenzfällen.

## 4) Roadmap Erster Test

### Meilenstein T1: Architektur- und Gate-Basis
- Chat UI als interner Testscreen aktivierbar.
- App Intent für einen sicheren Lese-Use-Case.
- Gates umgesetzt: Plattform, Gerät, Mindest-iOS, Env-Flag default false.
- Minimales Audit-Logging für jede Anfrage.
- → Details zur technischen Umsetzung siehe Abschnitt 3.2, 3.5.

### Meilenstein T2: Wissensfragen mit Quellen
- Document Pipeline für DPSG-Ordnung und Satzung in erster Version.
- Retrieval mit Quellennachweis und Datumsstand.
- Sicherheitsregel: keine schreibenden Aktionen im ersten Test.
- → Details zur technischen Umsetzung siehe Abschnitt 3.3, 3.4, 3.6, 3.7, 3.8.

### Meilenstein T3: Erste App- und Mitgliedsabfragen
- Lesender Zugriff auf Basis-Mitgliedsinfos mit Rechteprüfung.
- Einfache App-Fragen und Bedienhinweise über denselben Orchestrator.
- Definierte Fehlerbilder und Nutzerhinweise bei fehlenden Rechten.

### Meilenstein T4: Auswertung und Go oder No-Go
- Test mit begrenzter Pilotgruppe.
- Messung der Qualitätsziele und Auswertung von Audit-Logs.
- Entscheidung über Übergang in MVP-Umsetzung.

## 5) Roadmap MVP

### Meilenstein M1: Stabile Kernplattform
- Robuster Orchestrator mit standardisierten Tool-Verträgen.
- Erweiterte Siri und App Intents für häufige Leseaufgaben.
- Vollständige Gate- und Rollout-Steuerung pro Zielgruppe.

### Meilenstein M2: Fachwissen und App-Hilfe produktiv
- Abdeckung DPSG, Ordnung, Satzung und App-Hilfe mit Quellenpflicht.
- Qualitätskontrollen für Halluzinationsreduktion und Antwortkonsistenz.
- Redaktioneller Pflegeprozess für Dokumentaktualisierungen.

### Meilenstein M3: Sichere Basis-Aktionen
- Lesen und Bearbeiten von Basis-Mitgliedsinfos mit starker Rechteprüfung.
- Explizite Nutzerbestätigung vor schreibenden Änderungen.
- Auditierbare Änderungsprotokolle mit Vorher-Nachher-Bezug.

### Meilenstein M4: Statistik und komplexe Anfragen
- Basis-Statistikfragen mit belastbaren Zahlen und Filtertransparenz.
- Mehrschritt-Orchestrierung für komplexe Multi-Mitgliedsanfragen.
- Serverseitige Job-Ausführung für lange Berechnungen.

### Meilenstein M5: Export und Betriebsreife
- Exporterstellung in der App als eigener Export-Service.
- Klarer Hinweis im UX-Text: Generierte Inhalte sind nicht automatisch Dateien.
- Optionaler Paywall-Rollout für erweiterte Funktionen.

## 6) MVP-Funktionskatalog

### Prioritätslegende
- Muss: zwingend für MVP.
- Soll: hoher Nutzen, nach Kernfunktionen.
- Kann: sinnvoll, wenn Kapazität vorhanden ist.
- Später: nach MVP oder in Folgeversion.

| Funktion | Priorität | Kurzbeschreibung | Gates und Bedingungen |
|---|---|---|---|
| DPSG, Ordnung, Satzung Fragen | Muss | Verlässliche Antworten mit Quellen und Versionsstand | Nur lesend, Quellenpflicht, Audit aktiv |
| App-Fragen | Muss | Hilfe zu Navigation, Bedienung, Einstellungen | In-App und Siri, keine sensiblen Daten ohne Rechte |
| Rechte-Grundlagen | Muss | Erklärt, welche Rolle welche Aktion darf | Rollenmodell als harte Prüfgrundlage |
| Basis-Mitgliedsinfos lesen | Muss | Stammdaten lesend abrufen, kontextgebunden | Rechteprüfung je Feld, Protokollierung |
| Basis-Mitgliedsinfos bearbeiten | Soll | Kernfelder gezielt ändern mit Bestätigung | Doppelte Bestätigung, Audit Vorher und Nachher |
| Basis-Statistikfragen | Muss | Standardzahlen zu Mitgliedern und Strukturen | Transparente Filter und Stichtag |
| Komplexe Multi-Mitgliedsanfragen, z. B. 1 km | Soll | Kombinierte Filter über mehrere Mitglieder und Kontext | Asynchroner Job bei Laufzeitrisiko |
| Komplexe Statistikkombinationen ohne bestehende Schnittstelle | Kann | Orchestrierte Berechnung aus mehreren Quellen | Zusätzliche Validierung und Ergebniswarnung |
| Export erstellen | Soll | Erzeugt Datei-Ausgabe aus Ergebnissen in App-Exportservice | Apple Foundation generiert Inhalte, Datei und Export macht die App |
| Und mehr: kontextsensitive Rückfragen | Soll | KI stellt Rückfragen bei Unklarheit statt falscher Aktion | Pflicht bei Mehrdeutigkeit |
| Und mehr: Favoriten und Schnellaktionen | Kann | Wiederkehrende Anfragen als Vorlagen speichern | Optional je Rolle |
| Und mehr: Teamweite Vorlagen | Später | Freigabefähige Prompt und Intent Vorlagen | Governance und Freigabeprozess nötig |

### Nicht-funktionale MVP-Kriterien
- Antwortzeit für Standardfragen im Zielbereich produktiv nutzbar.
- Fehlerfälle führen zu sicheren, klaren und hilfreichen Rückmeldungen.
- Alle schreibenden Aktionen sind durch Rechte, Bestätigung und Audit abgesichert.

## 7) Offene Fragen und Entscheidungen

- ~~Welche Mindestgeräteklassen gelten verbindlich für Apple Foundation im Feld?~~ Beantwortet: keine feste Geräteklassenliste, sondern Laufzeitprüfung via `SystemLanguageModel.default.availability` (siehe 2.6, 3.5).
- ~~Inkonsistenz beheben: `.env.example` setzt `NAMI_AI_MIN_IOS_MAJOR=26`, der Dart-Fallback in `nami_ai_env.dart` ist aktuell `27`~~ Beantwortet: Fallback war bereits in Commit `173a7bd` auf 26 vereinheitlicht; der Env-Key `NAMI_AI_MIN_IOS_MAJOR` wurde in 3.5 danach ganz entfernt und die Mindestversion als Konstante fest codiert (kein Rollout-Hebel, sondern reales FoundationModels-API-Faktum).
- CI-Runner-/Xcode-Pin (3.9) muss zum tatsächlichen Umsetzungszeitpunkt neu verifiziert werden, da sich CI-Infrastruktur schnell ändert.
- Welche Rollen dürfen schreibende Mitgliedsänderungen via KI auslösen?
- Welche Datenfelder sind für Basis-Mitgliedsinfos im MVP enthalten?
- Wie wird die optionale Paywall funktional und rechtlich abgegrenzt?
- Welche Exportformate sind Pflicht zum MVP, welche folgen später?
- Welche Schwellenwerte entscheiden Go oder No-Go nach dem ersten Test?
- Wie wird bei widersprüchlichen Quellen priorisiert und kommuniziert?

## Entscheidungsbedarf bis Start Umsetzung

- Produktentscheidung zu Pilotgruppe, Rollout-Reihenfolge und optionaler Paywall.
- Technikentscheidung zu Tool-Verträgen, Audit-Schema und Exportservice.
- Fachentscheidung zu zulässigen Schreibaktionen und Freigabeprozess.

## Kurzfazit

- Der erste Test validiert kontrolliert den Nutzen bei minimalem Risiko.
- Der MVP baut darauf auf und erweitert gezielt um sichere Aktionen, Statistik und Export.
- Gates bleiben durchgängig aktiv, mit Env-Flag default false als zentrale Sicherheitslinie.
- Die technische Machbarkeit von T1/T2 ist bestätigt (Abschnitt 3.1); nichts Grundsätzliches steht mehr aus. Der Sprachqualitäts- und Guardrail-Spike (Abschnitt 3.3) ist mit Go-Ergebnis abgeschlossen. Phase 1 (Abschnitt 3.4, Dokumenten-Pipeline) und Phase 2 (Abschnitt 3.5, natives Verfügbarkeits-Gate inkl. `checkAvailability`-MethodChannel) sind umgesetzt. Nächster konkreter Schritt: Phase 3 (Abschnitt 3.6), Retrieval-Tool und technisch erzwungene Quellenpflicht — der im Spike gefundene Multi-Chunk-Synthese-Schwachpunkt gehört in dieses Grounding-Gate-Design.
