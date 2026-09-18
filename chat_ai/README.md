# chat_ai — Dokumenten-Pipeline für NaMi AI

Dieses Verzeichnis enthält die Rohquellen und das Skript, das daraus den
NaMi-AI-Korpus baut: `assets/ai_kontext/nami_ai_corpus_v1.json`. Der Korpus
ist die Grundlage für die on-device Wissensfragen-Funktion (siehe
[`specs/nami-ai-roadmap.md`](../specs/nami-ai-roadmap.md), Abschnitte 2.4 und
3.4).

## Zweck

`build_chunks.py` chunkt alle 5 DPSG-Regelwerke (Satzung Stamm/Bezirk/Diözese/
Bund + Ordnung) aus `chat_ai/files/*.pdf` in ein einziges, metadatentragendes
JSON. Jeder Chunk trägt das verbindliche Schema aus Roadmap §2.4: `doc_id`,
`ebene`, `doc_title`, `doc_stand`, `section_number`, `section_title`,
`page_start`/`page_end`, `text`, `source_file`. Das Korpus wird bisher von
keiner Swift-Retrieval-Komponente konsumiert (das kommt erst in Phase 3,
§3.6) — der aktuelle Stammesversammlung-Pilot liest stattdessen einen kleinen,
kuratierten Subset davon (siehe `chat_ai/pilot_stammesversammlung/`).

## Setup

```
python3 -m venv chat_ai/.venv
source chat_ai/.venv/bin/activate
pip install -r chat_ai/requirements.txt
```

Getestet mit Python 3.14 und pdfplumber 0.11.x.

## Verzeichnisstruktur

- `files/` — Rohquellen (5 PDFs), nicht verändern.
- `build_chunks.py` — die Pipeline (ersetzt das ältere `pdf_phrase_extraction.py`).
- `requirements.txt` — Python-Abhängigkeiten.
- `pilot_stammesversammlung/` — kuratierter 38-Chunk-Subset für den aktuellen
  App-Piloten, gebaut aus dem hier erzeugten Korpus (siehe eigener Abschnitt
  unten).
- Output-Ziel (außerhalb dieses Ordners): `assets/ai_kontext/nami_ai_corpus_v1.json`.

## Nutzung / CLI

```
python3 chat_ai/build_chunks.py build [--doc-id ID] [--dry-run] [--output PFAD]
python3 chat_ai/build_chunks.py validate [--input PFAD]
```

- `build` chunkt alle 5 Dokumente neu und schreibt den Korpus. `--doc-id`
  baut nur ein einzelnes Dokument neu (die anderen bleiben im bestehenden
  Output unverändert erhalten). `--dry-run` schreibt nichts, gibt nur
  Statistiken aus (Chunk-Anzahl/Größen pro Dokument) — nützlich zum Kalibrieren
  neuer Schwellenwerte, bevor man tatsächlich schreibt.
- `validate` prüft ein vorhandenes Korpus-JSON, ohne PDFs neu zu parsen.

## Konfigurationsschema

Jedes Dokument ist ein Eintrag in der `DOCS`-Liste am Kopf von
`build_chunks.py` (`DocConfig`-Dataclass): `doc_id`, `ebene`, `doc_title`,
`doc_stand`, `source_file`, `strategy` (`numbered_clauses` oder
`heading_pages`), `expected_chunk_range` (grobe Plausibilitätsgrenze für die
Validierung).

**Neues Dokument oder neue PDF-Version hinzufügen:** PDF nach `chat_ai/files/`
legen, neuen `DocConfig`-Eintrag ergänzen (oder `doc_stand`/`source_file` eines
bestehenden Eintrags aktualisieren), dann `python3 chat_ai/build_chunks.py
build --doc-id <id> --dry-run` zur Kalibrierung, danach echten Lauf.

## Chunking-Strategie im Detail

- **`numbered_clauses`** (die vier Satzungen): nummerierte Ziffern
  (`^\d+[a-z]?\.\s`) sind die primäre Chunk-Grenze. TOC-Seiten werden
  heuristisch erkannt (Wort „Inhaltsverzeichnis" oder hoher Anteil an
  Punkt-Führungslinien-Zeilen), nicht über eine hartcodierte Seitenzahl.
  Nicht-nummerierte Zwischenüberschriften (z. B. „Mitgliedschaft“, „Die
  Stammesversammlung“) werden über Schriftgröße erkannt (> 1,15× der
  häufigsten/Fließtext-Schriftgröße des Dokuments) und als `section_title` an
  alle nachfolgenden Chunks bis zur nächsten Überschrift vererbt. Eine
  erkannte Ziffer wird nur als neue Chunk-Grenze akzeptiert, wenn ihr
  Zahlenwert die laufende Zählung fortsetzt (`>=` letzte Hauptziffer) — sonst
  ist es eine eingebettete Aufzählung innerhalb eines Absatzes (z. B. "19.
  Organe des Stammes sind: 1. ... 2. ... 3. ...") und wird als Fortsetzung des
  aktuellen Chunks behandelt.
- **`heading_pages`** (die Ordnung): zweistufige Überschriften-Erkennung —
  großer Schriftgrößen-Sprung (> 1,8× Referenzgröße) markiert eine
  Kapitel-Ebene, fette Schrift bei Referenzgröße markiert eine Unterebene.
  Wiederkehrende Kopfzeilen (z. B. „Ordnung der DPSG" auf fast jeder Seite)
  und isolierte Seitenzahlen werden als Boilerplate erkannt (Text, der auf
  mehr als ~10 % aller Textseiten identisch wiederkehrt) und ausgefiltert.
  Mehrzeilige Überschriften (Titel, der über mehrere Zeilen umbricht) werden
  zu einem Titel zusammengeführt. Eine Überschrift, die wortgleich mit dem
  Titel des gerade offenen Chunks ist, erzeugt keine neue Sektion (typischer
  Fall: ein als Fettdruck gesetztes Leitmotiv/Zitat, das über mehrere
  Folgeseiten identisch als Randspalte wiederholt wird). Fällt die
  Überschriften-Dichte für ein Dokument unter ~1 pro 5 Seiten, wird komplett
  auf ein Chunk pro Seite zurückgefallen (`section_number = "S. {n}"`,
  `section_title = null`).
- **Größe/Overlap** (beide Strategien): Zielgröße 150–400 Tokens
  (Zeichen/4-Heuristik, konsistent zur Korpus-Analyse in Roadmap §3.1), ~15 %
  Overlap bei zu langen Abschnitten, Split ausschließlich an Satzgrenzen.
  Semantische Grenzen (eine Ziffer/ein Abschnitt) haben Vorrang vor dem
  Größenziel — es wird nur gesplittet, nie zusammengelegt. Bei Split:
  Suffix-Notation am `section_number` (`"24-1"`, `"24-2"`).
- Seitenfußzeilen („Seite 5 von 15“) werden unabhängig von Überschriften-
  Erkennung als Zeilenmuster gefiltert, da sie kleiner als der Fließtext sind
  und sonst mitten im Chunk-Text landen würden.

## Validierungsregeln

Hard-Fail (Skript beendet sich mit Exit-Code 1): fehlende Pflichtfelder,
`section_title` fehlt außerhalb des `heading_pages`-Seiten-Fallbacks, Text
< 20 Zeichen, Text > 2× Zielgröße (deutet auf Chunking-Bug hin),
`page_start > page_end`, doppelte `(doc_id, section_number)`-Kombination ohne
gültiges Split-Suffix-Muster, ein konfiguriertes Dokument liefert gar keinen
Chunk.

Warning (nur Hinweis, kein Fehlschlag): Chunk-Größe außerhalb des
150–400-Token-Zielbands (viele Satzungs-Ziffern sind legitim kürzer),
Chunk-Anzahl pro Dokument außerhalb der groben `expected_chunk_range`.

## Pflegeprozess

Satzungen und Ordnung ändern sich selten (Bundesversammlungs-Rhythmus). Kein
Server-Sync nötig:

1. Neue PDF-Version nach `chat_ai/files/` legen (alte ersetzen oder Pfad in
   der Config aktualisieren, `doc_stand` anpassen).
2. `python3 chat_ai/build_chunks.py build --doc-id <id> --dry-run`, Statistik
   gegenprüfen.
3. Echten Lauf ohne `--dry-run`, Diff der erzeugten JSON gegen die vorherige
   Version sichten.
4. Stichprobe: pro geändertem Dokument 5 zufällige Chunks gegen das
   Original-PDF gegenlesen.
5. `corpus_version` in `build_chunks.py` (`CORPUS_VERSION`-Konstante) bumpen.
6. Falls sich die Stammesversammlung-Piloten-relevanten Ziffern der Satzung
   Stamm geändert haben: `python3 chat_ai/pilot_stammesversammlung/
   build_subset.py` neu laufen lassen (siehe Abschnitt unten).
7. Normales App-Release.

## Stammesversammlung-Pilot (`pilot_stammesversammlung/`)

Der aktuelle App-Pilot beantwortet nur Fragen zur Stammesversammlung
(Satzung Stamm) und lädt dafür nicht den vollen Korpus, sondern einen
kuratierten 38-Chunk-Subset (`build_subset.py`, gebaut aus diesem Korpus,
gefiltert über `doc_id`/`section_number`). Das ist bewusst ein eigenständiges
Artefakt und noch nicht an eine native Retrieval-Tool-Implementierung (§3.6)
angebunden. Details und Kuration-Begründung stehen im Docstring von
`build_subset.py`.

## Bekannte Grenzen / offene Punkte

- **Ordnung-Erkennung ist eine erste Version.** Roadmap-Risiko akzeptiert:
  „Ordnung-PDF-Struktur uneinheitlich → gröbere Zitate als bei Satzung“.
  Konkret beobachtet: (a) eine ~25-seitige Chronik im Anhang ohne
  Jahres-Überschriften wird zu einem einzigen, großen Abschnitt
  zusammengefasst und dann rein größenbasiert in viele Teile gesplittet
  (`section_number`-Suffix `-1` bis `-40`), ohne dass die Teile inhaltlich an
  einem Jahr/Ereignis ausgerichtet sind; (b) vereinzelt werden fett gesetzte
  Leitsätze/Zitate innerhalb eines Absatzes (redaktionelles Stilmittel, kein
  echter Section-Header) als eigene Unterüberschrift erkannt, was zu einem
  unpassenden `section_title` führt. Beides betrifft nur die Ordnung, nicht
  die vier Satzungen (dort ist die Erkennung sauber). Iterative Verfeinerung
  ist für eine spätere Phase vorgesehen, kein Blocker für Phase 1.
- **Fortsetzungs-Ziffern ohne Wortwiederholung bleiben ein generelles
  Restrisiko** bei automatisiertem Chunking (Roadmap §3.1) — die
  Section-Header-Vererbung mindert das für Zwischenüberschriften, ersetzt
  aber keine inhaltliche Themen-Prüfung.
- Buchstaben-Ziffern (z. B. „11a“, „42a“) werden als eigene, präzise
  zitierfähige `section_number` geführt statt sie stillschweigend in die
  vorherige Ziffer zu falten (Abweichung/Verbesserung gegenüber dem
  ursprünglichen `pdf_phrase_extraction.py`).
