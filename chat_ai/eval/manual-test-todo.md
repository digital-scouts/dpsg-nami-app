# Aufgabenliste: Manuelle Eval-Runde (§3.8)

Vorbereitung: siehe [`chat_ai/eval/README.md`](../README.md) für Voraussetzungen
(echtes iOS-26(+)-Gerät oder Apple-Intelligence-fähiger Simulator) und das
Bewertungsschema.

## Vorbereitung

- [ ] Aktuellen Build auf Testgerät installieren (`NAMI_AI_ENABLED` aktiv)
- [ ] Apple Intelligence auf dem Gerät aktiviert prüfen
- [ ] `chat_ai/eval/eval_questions.json` griffbereit (zweites Fenster/Gerät)
- [ ] Neue Ergebnisdatei anlegen: `chat_ai/eval/results/<YYYY-MM-DD>-<kürzel>.md`
- [ ] §3.7 ist seit 2026-09-19 umgesetzt (Chat-UI mit Streaming, Quellenanzeige, Markdown, Verlauf) — Fragenrunde unten direkt in der finalen UI durchführen, kein Xcode-Konsolen-Workaround mehr nötig

## Fragenrunden (37 Fragen aus eval_questions.json)

Pro Frage: Antwort stellen, Korrektheit/Zitate/(bei Bedarf Guardrail-Verhalten) bewerten, in der Ergebnisdatei protokollieren.

- [ ] **Jargon (4 Fragen)** — `jargon-sv-mitglieder`, `jargon-woe-jufi-vertretung-sv`, `jargon-stalei-vs-lr`, `jargon-stavo-zusammensetzung`
- [ ] **Regression (1 Frage, besonders wichtig)** — `regression-stavo-aufgaben-sv`: prüfen, ob das Modell jetzt korrekt die Stavo-Aufgaben (Ziffer 31) statt der SV-Aufgaben (Ziffer 24) nennt
- [ ] **General Satzung Stamm (3 Fragen)** — `general-sv-frequenz`, `general-stavo-aufgaben`, `general-stavo-mitgliederzahl`
- [ ] **Guardrail-negative (2 Fragen, Grenzfälle)** — `guardrail-elternbeirat-frequenz`, `guardrail-ausschluss-mehrheitsbeschluss`: genau beobachten, ob sauber abgelehnt oder unpassende Zusatzinfos angehängt werden
- [ ] **General Satzung Bezirk (5 Fragen)** — `general-bezirksvorstand-aufgaben`, `general-bezirksvorstand-mitgliederzahl`, `general-bezirksversammlung-frequenz`, `general-bezirksversammlung-aufgaben`, `general-bezirkskonferenzen-frequenz`
- [ ] **General Satzung Diözese (5 Fragen)** — `general-dioezesanvorstand-aufgaben`, `general-dioezesanvorstand-mitgliederzahl`, `general-dioezesanversammlung-aufgaben`, `general-dioezesanleitung-aufgaben`, `general-dioezesankonferenzen-frequenz`
- [ ] **General Satzung Bund (5 Fragen)** — `general-bundesvorstand-aufgaben`, `general-bundesvorstand-mitgliederzahl`, `general-bundesversammlung-aufgaben`, `general-bundesleitung-aufgaben`, `general-bund-hauptausschuss`
- [ ] **General Ordnung (9 Fragen)** — `general-woelflingsstufe-alter`, `general-jungpfadfinderstufe-alter`, `general-pfadfinderstufe-alter`, `general-roverstufe-alter`, `general-bibergruppe-groesse`, `general-verweildauer-altersstufe`, `general-altersstufen-anzahl`, `general-bibergruppe-leitungsschluessel`, `general-gesetz-versprechen-einheit`
- [ ] **Off-Topic (3 Fragen, nur manuell prüfbar)** — `offtopic-wetter`, `offtopic-kochrezept`, `offtopic-fussball-wm`: prüfen, ob das Modell trotz Retrieval-Treffern korrekt ablehnt (`unclear`)

## Zusätzliche, freie Beobachtungen (nicht Teil des Fragensets)

- [ ] Markdown-Rohzeichen in Antworten sichtbar? (bekannter UI-Fund aus 3.3, seit 3.7 über `flutter_markdown_plus` gerendert — hier nur noch als Regressionscheck)
- [ ] Auffällige Antwortzeiten/Hänger
- [ ] Verhalten bei Folgefragen im selben Gespräch (3.7-Session-Handling)

## §3.7-Verifikation: gehaltene Session, Streaming, Persistenz, UI (nur echtes Gerät)

Diese Punkte sind spezifisch für §3.7 und ergänzen die Fragenrunde oben — laut Plan bewusst nicht automatisierbar (siehe `specs/nami-ai-roadmap.md` §3.7/§3.11).

- [ ] **Folgefragen im selben Gespräch**: 3-4 Fragen hintereinander stellen, die aufeinander aufbauen (z. B. erst "Was sind die Aufgaben des Stammesvorstands?", dann "Und wie oft muss er sich treffen?") — prüft, ob die gehaltene `LanguageModelSession` echten Konversationskontext behält, nicht nur Einzelfragen beantwortet
- [ ] **Streaming + Tool-Aufruf im selben Turn**: beobachten, ob der Antworttext sichtbar inkrementell wächst, während/nachdem das Modell intern `search_regelwerk` aufruft, oder ob es zu Hängern/unvollständigen Zwischenständen kommt (unbelegtes Verhalten laut Plan, siehe Risiko 1)
- [ ] **Schreibverben-Vorfilter im echten Chat**: 2-3 Anfragen mit Schreibverben stellen (z. B. „Lösche den Eintrag von Max Mustermann", „Trage mich für die Fahrt ein") — feste Ablehnungsantwort muss sofort erscheinen, ohne sichtbare Modell-Ladezeit
- [ ] **Manueller „Neue Unterhaltung"-Button**: während eines laufenden Gesprächs antippen, prüfen dass Verlauf geleert wird und die nächste Frage nachweislich in einer neuen Session läuft (kein Bezug mehr auf vorherige Fragen)
- [ ] **Kontextüberlauf/Sliding-Window-Truncation**: eine sehr lange Folgefragen-Kette führen, bis ein Kontextüberlauf auftritt; prüfen dass die einmalige Snackbar „Ältere Nachrichten sind für neue Antworten nicht mehr sichtbar." erscheint und das Gespräch danach normal weiterläuft (nicht abbricht)
- [ ] **Sauberes Verlassen während Streaming**: mitten in einer laufenden Antwort die Chat-Seite verlassen (zurück-navigieren) — kein Crash, keine sichtbare Fehlermeldung beim nächsten Öffnen
- [ ] **Verlauf nach App-Neustart**: nach mindestens einem abgeschlossenen Gespräch die App vollständig beenden und neu starten, dann „Verlauf" öffnen — Eintrag mit korrektem Titel (erste Frage) und Datum/Uhrzeit muss erscheinen, Antippen zeigt read-only Transkript ohne Eingabefeld
- [ ] **§-Referenzen sichtbar**: bei mind. einer Antwort mit Quellen prüfen, dass die kompakte Quellenzeile (`Dokument § Abschnitt`) unter der Bot-Bubble erscheint, sowohl im aktiven Chat als auch im Verlauf-Detail
- [ ] **unclear-Hinweis sichtbar**: bei einer Off-Topic- oder Guardrail-Frage prüfen, dass der Hinweis „Nicht eindeutig belegt" korrekt angezeigt wird

## §3.5-Verifikation: Verfügbarkeits-Gate (nur echtes Gerät)

Laut `specs/nami-ai-roadmap.md` §3.5-Zwischenergebnis und §3.11 steht der manuelle Test des `checkAvailability`-Gates mit echtem Toggle noch aus (bisher nur mit gemocktem `MethodChannel` unit-getestet) — beim System-Check am 2026-09-19 aufgefallen, hier ergänzt, da bisher in keiner Testliste erfasst.

- [ ] Apple Intelligence auf dem Gerät in den Einstellungen deaktivieren, App öffnen: korrekter, verständlicher Block-Hinweis (kein Rohfehlertext) statt Chat-Zugriff
- [ ] Apple Intelligence wieder aktivieren, App neu starten: Chat wird ohne Neuinstallation wieder nutzbar

## §3.12-Verifikation: Verifier-Pass mit Selbstkorrektur (nur echtes Gerät, `NAMI_AI_SELF_CORRECTION_ENABLED=true`)

Neu seit 2026-09-21, standardmäßig per Feature-Flag aus — für diese Runde lokal in `.env` auf `true` setzen. Ziel: prüfen, ob der zweite Modelldurchlauf (`NamiAiAnswerVerifier`) das wiederkehrende „falsches Organ"-Muster (siehe `chat_ai/eval/results/2026-09-19.md`) tatsächlich reduziert, und ob die Retry-Mechanik in der UI sauber wirkt.

- [ ] Gezielt Fragen aus der letzten Runde wiederholen, bei denen ein falsches Organ genannt wurde (`general-bezirksvorstand-aufgaben`, `general-bezirksversammlung-aufgaben`, `general-dioezesanvorstand-aufgaben`, `general-dioezesanleitung-aufgaben`, `general-bundesvorstand-aufgaben`, `regression-stavo-aufgaben-sv`) — prüfen, ob jetzt ein Retry ausgelöst wird und die finale Antwort das richtige Organ nennt
- [ ] Bei ausgelöstem Retry im Streaming-Chat beobachten: erscheint der „wird überprüft"-Zwischenzustand statt eines ruckartigen Textersatzes?
- [ ] Fragen stellen, die eine Liste/einen Vergleich erwarten (z. B. `jargon-stalei-vs-lr`) und prüfen, ob die Antwortform dazu passt
- [ ] Debug-Log exportieren (Menü → Log exportieren) und stichprobenartig prüfen, dass `attempts` pro Anfrage vorhanden ist, mit plausiblem `retryReason` bei mehr als einem Versuch
- [ ] Antwortzeiten bei ausgelöstem Retry im Vergleich zum Normalfall grob einschätzen (subjektiv, für die Latenz-Einschätzung vor einem projektweiten Rollout)
- [ ] Stichprobe wiederholen, bei der bereits im Erstversuch alles korrekt war — sicherstellen, dass dort **kein** sichtbarer Unterschied zum bisherigen Verhalten auftritt (kein unnötiger Retry, kein Performance-Einbruch)

## Auswertung

- [ ] Kurz-Fazit der Runde in der Ergebnisdatei ergänzen (Auffälligkeiten je Kategorie)
- [ ] Prüfen gegen Entscheidungskriterien in `chat_ai/eval/README.md` (Stavo/SV-Regression über 2 Runden? Korrektheitsrate < 80 %? Guardrail-Fehlrate > 10 %?)
- [ ] Bei Bedarf: zweite Runde an anderem Tag/Gerät ansetzen, um Reproduzierbarkeit zu prüfen
