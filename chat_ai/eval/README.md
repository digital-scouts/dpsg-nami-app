# chat_ai/eval — Eval-Set und manuelles Runbook für NaMi AI

Dieses Verzeichnis enthält das kuratierte Fragenset für die Qualitätsprüfung
der on-device Wissensfragen-Funktion sowie das Runbook für die manuelle
End-to-End-Prüfung auf echtem Gerät (siehe
[`specs/nami-ai-roadmap.md`](../../specs/nami-ai-roadmap.md), Abschnitt 3.8).

## Zweck

`eval_questions.json` ist die einzige Quelle der Wahrheit für Testfragen mit
erwarteten Dokument-/Abschnittsreferenzen. Zwei unterschiedliche Prüfungen
nutzen dieselbe Datei, aber nicht dieselben Fragen:

- **Retrieval-only, automatisiert, CI-fähig:** `NamiAiEvalTests.swift`
  (`ios/NamiAiKit/Tests/NamiAiKitTests/`) prüft für jede Frage mit
  `automated_check: true`, ob `NamiAiRetrievalIndex.topMatches` (dieselben
  Defaults wie `NamiAiSearchTool` in Produktion) die erwarteten Quellen
  liefert. Läuft ohne Gerät und ohne geladenes Sprachmodell.
- **End-to-End, manuell, dieses Runbook:** Antworttext, Zitate und
  Halluzination lassen sich nicht automatisiert prüfen — Simulator/CI haben
  kein geladenes FoundationModels-Modell. Das gilt für **alle** Fragen aus
  `eval_questions.json`, nicht nur für die mit `automated_check: false`.

`automated_check: false` markiert Fragen, bei denen schon die
Retrieval-Prüfung allein nicht sinnvoll automatisierbar ist (siehe
`known_limitations` und die einzelnen `note`-Felder in `eval_questions.json`)
— das eigentliche Problem liegt dort nicht im Retrieval, sondern im
Modellverhalten danach.

## Voraussetzungen

- Echtes iPhone mit iOS 26+, geeigneter Hardware und aktivierter Apple
  Intelligence — oder ein Simulator auf einem Mac, der selbst Apple
  Intelligence unterstützt (Apple-Silicon M1 Pro/Max oder neuer, passende
  macOS-Version, Toggle aktiviert). Ein gewöhnlicher Simulator auf nicht
  unterstützter Hardware liefert kein Modell (siehe Roadmap §3.1, Schritt 5).
- Aktueller Build mit `NamiAiKit`, `NAMI_AI_ENABLED` aktiviert.
- `eval_questions.json` als Referenz griffbereit (z. B. zweites Fenster/Gerät).
- Solange Abschnitt 3.7 (Flutter-Chat-UI mit sichtbaren §-Referenzen) noch
  nicht abgeschlossen ist: Zitate/`sources`/`unclear` ggf. über Xcode-Konsole
  bzw. Debug-Logging von `NamiAiAssistant.respond` ablesen statt aus der
  Chat-UI. Runde in diesem Fall unten als "vor 3.7" kennzeichnen.

## Ablauf pro Runde

1. Alle Fragen aus `eval_questions.json` der Reihe nach in der App stellen
   (Kategorie und `id` mitführen).
2. Pro Frage protokollieren:
   - `id`
   - Antworttext (gekürzt/paraphrasiert reicht, wörtliche Halluzinationen
     möglichst exakt zitieren)
   - zitierte Quellen laut UI/Log vs. `expected_sources`
   - **Korrektheit:** korrekt / teilweise korrekt / halluziniert
   - **Zitate:** vollständig+korrekt / unvollständig / falsch/keine
   - nur bei `expects_reject: true`: **Guardrail-Verhalten** — sauber
     abgelehnt / vermischt (Kern korrekt abgelehnt, aber unpassende
     Zusatzinfos angehängt) / fälschlich beantwortet
   - Freitext-Notiz (auffällige Formulierungen, Markdown-Rohzeichen,
     Antwortzeit, alles Ungewöhnliche)
3. Kurz-Fazit der Runde: Auffälligkeiten je Kategorie (`jargon`, `regression`,
   `guardrail-negative`, `off-topic`, `general`), insbesondere ob der
   Stavo/SV-Regressionsfall (`regression-stavo-aufgaben-sv`) weiterhin
   fehlerhaft beantwortet wird.

## Ergebnis-Dokumentation

Eine neue Datei pro Runde unter `chat_ai/eval/results/`, nicht überschreiben
— Trends über mehrere Runden sind Voraussetzung für die
Retrieval-Upgrade-Entscheidung unten:

```
chat_ai/eval/results/<YYYY-MM-DD>-<gerät-oder-kürzel>.md
```

Format: freie Markdown-Tabelle oder Liste, mindestens `id`, Bewertung,
Notiz. Optional zusätzlich eine schlanke, laufend aktualisierte
`chat_ai/eval/results/SUMMARY.md` mit nur den Kennzahlen (Pass-Raten je
Kategorie) der jeweils letzten Runde, damit nicht jede Detaildatei geöffnet
werden muss.

## Entscheidungskriterien Retrieval-Upgrade (Variante B/D)

Startheuristik, kalibrierbar nach den ersten echten Runden (siehe Roadmap
§3.6 für die Varianten selbst):

- **Hartes Signal:** der Stavo/SV-Regressionsfall oder ein strukturell
  gleichartiger Multi-Chunk-Synthese-Fehler tritt über zwei aufeinanderfolgende
  Runden reproduzierbar auf, obwohl das Grounding-Gate technisch korrekt
  funktioniert.
- **Weiches Signal:** End-to-End-Korrektheitsrate (korrekt UND korrekt
  zitiert UND nicht halluziniert) über alle bewerteten Fragen einer Runde
  < 80 %.
- Guardrail-Fehlrate (falsches Ablehnen einer beantwortbaren Frage oder
  falsches Beantworten einer Ablehnungsfrage) > 10 % ist primär ein
  Prompt-/Guardrail-Thema, kein automatischer Retrieval-Upgrade-Auslöser.

## Bekannte Grenzen

- **BM25 ohne Stemming/Lemmatisierung matchte keine deutschen Flexionsformen**
  außerhalb der im Chunk vorkommenden Wortform (z. B. Frage "Mitglieder" vs.
  Chunk-Text "Mitgliedern"; "des Bezirksvorstands" vs. "Der Bezirksvorstand").
  Im ersten automatisierten Testlauf (2026-09-18) lag die Pass-Rate der
  automatisiert prüfbaren general/jargon/regression-Fragen bei ca. 41 %.
  Seit 2026-09-19 stemmt `NamiAiRetrievalIndex.tokenize` leichtgewichtig genau
  gegen diese beiden Muster (siehe `NamiAiRetrieval.swift`); neu gemessene
  Pass-Rate ca. 44 % (14/32) — ein echter, aber moderater Gewinn, da die
  meisten verbleibenden Fehlschläge Multi-Chunk-Synthese-/"falsches
  Organ"-Fälle oder Vokabular-Mismatches sind, die Stemming allein nicht löst
  (siehe `known_limitations` in `eval_questions.json` und Kommentar in
  `NamiAiEvalTests.swift`). Das bleibt ein realer Befund für die
  B/D-Entscheidung, keine falsch formulierte Testfrage.
- **Retrieval-Score allein ist kein verlässlicher Ablehnungs-Indikator.**
  `topMatches` liefert auch für klar fachfremde Fragen Treffer, teils mit
  höherem BM25-Score als bei echten Satzungsfragen (seltene Alltagswörter
  bekommen im förmlichen Satzungs-/Ordnungstext eine unverhältnismäßig hohe
  IDF-Gewichtung). Die eigentliche Ablehnung muss vom Modell kommen
  (`unclear: true`), nicht aus einer leeren Trefferliste — deshalb sind
  Off-Topic-Fragen hier nur manuell geprüft.
- Simulator-Verfügbarkeit von Apple Intelligence schwankt je nach
  Xcode-/macOS-Version.
- Modellantworten sind nicht deterministisch — Wiederholung derselben Frage
  kann leicht unterschiedliche Formulierungen/Bewertungen ergeben.
