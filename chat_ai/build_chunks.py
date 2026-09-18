"""Dokumenten-Pipeline fuer den NaMi-AI-Korpus (nami-ai-roadmap.md, Abschnitt 3.4).

Chunkt alle 5 DPSG-Regelwerke (Satzung Stamm/Bezirk/Diözese/Bund + Ordnung) aus
chat_ai/files/*.pdf in ein einziges, metadatentragendes Korpus-JSON
(assets/ai_kontext/nami_ai_corpus_v1.json), zweigleisig je nach Dokumentstruktur:

- numbered_clauses (die vier Satzungen): nummerierte Ziffern sind die primaere
  Chunk-Grenze; TOC-Seiten werden heuristisch erkannt statt hartcodiert
  uebersprungen; nicht-nummerierte Zwischenueberschriften werden ueber
  Schriftgroesse erkannt und an nachfolgende Chunks als section_title vererbt.
- heading_pages (die Ordnung): zweistufige Ueberschriften-Erkennung ueber
  Schriftgroesse (Kapitelebene) und fette Schrift (Unterebene); faellt bei zu
  duenner Ueberschriftendichte pro Dokument auf ein Chunk pro Seite zurueck.

Nutzung:
    python3 chat_ai/build_chunks.py build [--doc-id ID] [--dry-run]
    python3 chat_ai/build_chunks.py validate [--input PFAD]

Siehe chat_ai/README.md fuer den Pflegeprozess (neue PDF-Version -> Skript neu
laufen lassen -> Diff sichten -> corpus_version bumpen -> normales Release).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Literal, Optional

import pdfplumber

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = REPO_ROOT / "assets" / "ai_kontext" / "nami_ai_corpus_v1.json"

CORPUS_VERSION = "2026.09.1"

MIN_CHUNK_CHARS = 600
MAX_CHUNK_CHARS = 1600
OVERLAP_RATIO = 0.15
MIN_TEXT_CHARS = 20

MAIN_CLAUSE_RE = re.compile(r"^(\d+[a-z]?)\.\s+")
DOTTED_LEADER_RE = re.compile(r"\.{3,}\s*\d{1,4}\s*$")
SENTENCE_SPLIT_RE = re.compile(r"(?<=[.!?])\s+")
# Seitenfusszeile ("Seite 3 von 15"), kleiner als der Fliesstext und daher ueber
# die Groessen-Heuristik nicht als Nicht-Inhalt erkennbar -- separater Filter,
# sonst rutscht sie mitten in den Chunk-Text.
PAGE_FOOTER_RE = re.compile(r"^Seite\s+\d+\s+von\s+\d+$", re.IGNORECASE)


@dataclass(frozen=True)
class DocConfig:
    doc_id: str
    ebene: str
    doc_title: str
    doc_stand: str
    source_file: str  # repo-relativer Pfad
    strategy: Literal["numbered_clauses", "heading_pages"]
    expected_chunk_range: tuple[int, int] = (5, 1000)


DOCS: list[DocConfig] = [
    DocConfig(
        doc_id="satzung_stamm",
        ebene="Stamm",
        doc_title="Satzung Stamm",
        doc_stand="Mai 2024",
        source_file="chat_ai/files/00_satzung_der_dpsg_-_stamm_mai_2024.pdf",
        strategy="numbered_clauses",
        expected_chunk_range=(40, 100),
    ),
    DocConfig(
        doc_id="satzung_bezirk",
        ebene="Bezirk",
        doc_title="Satzung Bezirk",
        doc_stand="Mai 2023",
        source_file="chat_ai/files/02_satzung_der_dpsg_-_bezirksebene_mai_2023_0.pdf",
        strategy="numbered_clauses",
        expected_chunk_range=(40, 100),
    ),
    DocConfig(
        doc_id="satzung_dioezese",
        ebene="Diözese",
        doc_title="Satzung Diözese",
        doc_stand="Mai 2023",
        source_file="chat_ai/files/03_satzung_der_dpsg_-_dioezesanebene_mai_2023.pdf",
        strategy="numbered_clauses",
        expected_chunk_range=(40, 100),
    ),
    DocConfig(
        doc_id="satzung_bund",
        ebene="Bund",
        doc_title="Satzung Bund",
        doc_stand="Mai 2024",
        source_file="chat_ai/files/04_satzung_der_dpsg_-_bundesebene_mai_2024.pdf",
        strategy="numbered_clauses",
        expected_chunk_range=(40, 100),
    ),
    DocConfig(
        doc_id="ordnung",
        ebene="Verband",
        doc_title="Ordnung",
        doc_stand="23. April 2023",
        source_file="chat_ai/files/20230423_ordnung_neu-digital.pdf",
        strategy="heading_pages",
        expected_chunk_range=(50, 1200),
    ),
]


@dataclass
class RawChunk:
    section_number: str
    section_title: Optional[str]
    text_parts: list[str] = field(default_factory=list)
    page_start: int = 0
    page_end: int = 0

    def text(self) -> str:
        return " ".join(p.strip() for p in self.text_parts if p.strip()).strip()


# ---------------------------------------------------------------------------
# Gemeinsame Hilfsfunktionen
# ---------------------------------------------------------------------------


def is_toc_page(text: str) -> bool:
    """Erkennt Inhaltsverzeichnis-Seiten anhand des Worts oder eines hohen
    Anteils an Punkt-Fuehrungslinien-Zeilen (".... 12"). Kalibriert an allen
    vier Satzungs-PDFs (siehe chat_ai/README.md)."""
    if "inhaltsverzeichnis" in text.lower():
        return True
    lines = [l for l in text.split("\n") if l.strip()]
    if not lines:
        return False
    dotted = sum(1 for l in lines if DOTTED_LEADER_RE.search(l))
    return dotted / len(lines) > 0.3


def find_body_start_page_index(pages_text: list[str], scan_limit: int = 10) -> int:
    """Findet die erste Body-Seite (0-basiert), indem die letzte erkannte
    TOC-Seite gesucht wird. Fallback: struktureller Re-Anchor auf eine Zeile
    '1. ' gefolgt von '2. ' auf einer der naechsten Seiten. Wenn beides
    unsicher ist: konservativ nichts ueberspringen (Skip=0)."""
    last_toc = -1
    for i, text in enumerate(pages_text[:scan_limit]):
        if is_toc_page(text):
            last_toc = i
    if last_toc >= 0:
        return last_toc + 1

    for i, text in enumerate(pages_text[:scan_limit]):
        lines = [l.strip() for l in text.split("\n")]
        if any(re.match(r"^1\.\s", l) for l in lines):
            lookahead = " ".join(pages_text[i : i + 3])
            if re.search(r"(?m)^2\.\s", lookahead):
                return i
    print("    WARNUNG: TOC/Body-Start-Heuristik unsicher, ueberspringe keine Seiten.", file=sys.stderr)
    return 0


def dominant_line_size(line_chars: list[dict]) -> float:
    sizes = Counter(round(c["size"], 1) for c in line_chars)
    return sizes.most_common(1)[0][0]


def dominant_line_font(line_chars: list[dict]) -> str:
    fonts = Counter(c["fontname"] for c in line_chars)
    return fonts.most_common(1)[0][0]


def is_bold_font(fontname: str) -> bool:
    return bool(re.search(r"bold|semibold|-bd\b|-b$", fontname, re.IGNORECASE))


def reference_body_size(pdf: pdfplumber.PDF, page_indices: range) -> float:
    """Haeufigste Zeichengroesse ueber die gegebenen Seiten -- der Fliesstext."""
    counter: Counter[float] = Counter()
    for i in page_indices:
        for c in pdf.pages[i].chars:
            counter[round(c["size"], 1)] += 1
    if not counter:
        return 11.0
    return counter.most_common(1)[0][0]


def split_oversized(text: str, max_chars: int, overlap_ratio: float) -> list[str]:
    """Splittet nur, wenn ein Abschnitt das Groessenziel ueberschreitet, immer
    an Satzgrenzen, mit Overlap zum Vorgaenger-Teil. Semantische Grenzen
    (eine Ziffer/ein Abschnitt) werden nie zusammengelegt, nur gesplittet."""
    if len(text) <= max_chars:
        return [text]
    sentences = SENTENCE_SPLIT_RE.split(text)
    parts: list[str] = []
    current = ""
    for sentence in sentences:
        if current and len(current) + len(sentence) + 1 > max_chars:
            parts.append(current.strip())
            overlap_len = int(len(current) * overlap_ratio)
            current = (current[-overlap_len:] + " " + sentence).strip() if overlap_len else sentence
        else:
            current = (current + " " + sentence).strip()
    if current:
        parts.append(current.strip())
    return parts if parts else [text]


# ---------------------------------------------------------------------------
# Strategie 1: numbered_clauses (Satzungen)
# ---------------------------------------------------------------------------


def chunk_numbered_clauses(pdf_path: Path) -> list[RawChunk]:
    with pdfplumber.open(pdf_path) as pdf:
        pages_text = [p.extract_text() or "" for p in pdf.pages]
        body_start = find_body_start_page_index(pages_text)
        print(f"    TOC/Front-Matter bis Seite {body_start} uebersprungen, Body beginnt Seite {body_start + 1}")

        ref_size = reference_body_size(pdf, range(body_start, len(pdf.pages)))

        chunks: list[RawChunk] = []
        current: Optional[RawChunk] = None
        current_section_title: Optional[str] = None
        last_main_number = 0

        for page_index in range(body_start, len(pdf.pages)):
            page_number = page_index + 1
            for line in pdf.pages[page_index].extract_text_lines():
                text = line["text"].strip()
                if not text or PAGE_FOOTER_RE.match(text):
                    continue
                size = dominant_line_size(line["chars"])

                is_heading = size > ref_size * 1.15
                if is_heading:
                    current_section_title = text
                    continue

                match = MAIN_CLAUSE_RE.match(text)
                # Nur akzeptieren, wenn die Ziffer die laufende Zaehlung
                # fortsetzt (>= letzte Hauptziffer). Kleinere Zahlen sind
                # eingebettete Aufzaehlungen innerhalb eines Absatzes (z.B.
                # "19. Organe des Stammes sind: 1. ... 2. ... 3. ..."), keine
                # neuen Ziffern -- sonst wuerden sie faelschlich eigene
                # Chunks mit kollidierenden section_numbers erzeugen.
                is_new_clause = False
                clause_number = 0
                if match:
                    clause_number = int(re.match(r"\d+", match.group(1)).group())
                    is_new_clause = clause_number >= last_main_number

                if is_new_clause:
                    if current is not None:
                        chunks.append(current)
                    current = RawChunk(
                        section_number=match.group(1),
                        section_title=current_section_title,
                        page_start=page_number,
                        page_end=page_number,
                    )
                    current.text_parts.append(text)
                    last_main_number = clause_number
                elif current is not None:
                    current.text_parts.append(text)
                    current.page_end = page_number
                # Text vor der ersten erkannten Ziffer (sollte nach TOC-Skip
                # nicht mehr vorkommen) wird bewusst verworfen.

        if current is not None:
            chunks.append(current)

    return chunks


# ---------------------------------------------------------------------------
# Strategie 2: heading_pages (Ordnung)
# ---------------------------------------------------------------------------


PURE_NUMBER_RE = re.compile(r"^\d{1,4}$")


def _classify_line(text: str, size: float, font: str, ref_size: float, big_threshold: float) -> str:
    if size > big_threshold:
        return "big"
    if is_bold_font(font) and size >= ref_size:
        return "sub"
    return "body"


def chunk_heading_pages(pdf_path: Path) -> list[RawChunk]:
    with pdfplumber.open(pdf_path) as pdf:
        page_indices = range(len(pdf.pages))
        ref_size = reference_body_size(pdf, page_indices)
        big_heading_threshold = ref_size * 1.8

        # Erster Durchlauf: Zeilen cachen + klassifizieren, um wiederkehrende
        # Kopfzeilen/Randziffern (z.B. "Ordnung der DPSG" auf fast jeder
        # Seite, isolierte Seitenzahlen in grosser Schrift) als Boilerplate
        # zu erkennen -- diese sind KEINE echten Ueberschriften, treffen aber
        # die reinen Groessen-/Fett-Kriterien.
        cached_pages: list[list[tuple[str, float, str, str]]] = []
        heading_text_counts: Counter[str] = Counter()
        text_pages = 0

        for page_index in page_indices:
            page = pdf.pages[page_index]
            if not page.chars:
                cached_pages.append([])
                continue
            text_pages += 1
            lines_out = []
            for line in page.extract_text_lines():
                text = line["text"].strip()
                if not text or PAGE_FOOTER_RE.match(text):
                    continue
                size = dominant_line_size(line["chars"])
                font = dominant_line_font(line["chars"])
                tier = _classify_line(text, size, font, ref_size, big_heading_threshold)
                lines_out.append((text, size, font, tier))
                if tier in ("big", "sub"):
                    heading_text_counts[text] += 1
            cached_pages.append(lines_out)

        boilerplate_threshold = max(3, int(0.1 * text_pages))
        boilerplate_texts = {t for t, n in heading_text_counts.items() if n > boilerplate_threshold}
        if boilerplate_texts:
            print(f"    Boilerplate-Kopfzeilen erkannt und ausgefiltert: {sorted(boilerplate_texts)[:5]}...")

        def is_noise(text: str, tier: str) -> bool:
            if tier not in ("big", "sub"):
                return False
            return text in boilerplate_texts or bool(PURE_NUMBER_RE.match(text))

        chunks: list[RawChunk] = []
        current: Optional[RawChunk] = None
        chapter_title: Optional[str] = None
        chapter_num = 0
        sub_num = 0
        heading_lines = 0

        pending_tier: Optional[str] = None
        pending_texts: list[str] = []
        pending_page_start = 0

        def flush_pending(next_page_number: int) -> None:
            nonlocal current, chapter_title, chapter_num, sub_num, pending_tier, pending_texts
            if not pending_texts:
                return
            combined = " ".join(pending_texts)
            tier = pending_tier
            pending_tier = None
            pending_texts = []

            if tier == "big":
                # Wiederholte/umgebrochene Kapitel-Ueberschrift (z.B. Randziffer
                # + Titel auf jeder Seite eines Kapitels erneut gesetzt) ist
                # keine neue Sektion -- sonst zerfaellt ein Kapitel in einen
                # Chunk pro Seite ohne inhaltlichen Grund.
                if chapter_title == combined:
                    return
                if current is not None:
                    chunks.append(current)
                chapter_num += 1
                sub_num = 0
                chapter_title = combined
                section_title = chapter_title
                section_number = f"Kapitel {chapter_num}"
            else:
                candidate_section_title = f"{chapter_title} – {combined}" if chapter_title else combined
                # Wiederholte Zitat-/Deko-Elemente (z.B. ein als Fettdruck
                # gesetztes Leitmotiv, das auf mehreren Folgeseiten identisch
                # als Randspalte wiederholt wird) sind keine echte neue
                # Unterueberschrift, wenn sie Wort-fuer-Wort dem Titel des
                # gerade offenen Chunks entsprechen.
                if current is not None and current.section_title == candidate_section_title:
                    return
                if current is not None:
                    chunks.append(current)
                sub_num += 1
                section_title = candidate_section_title
                section_number = f"Kapitel {chapter_num}.{sub_num}" if chapter_num else f"Abschnitt {sub_num}"

            current = RawChunk(
                section_number=section_number,
                section_title=section_title,
                page_start=pending_page_start,
                page_end=next_page_number,
            )

        for page_index in page_indices:
            page_number = page_index + 1
            for text, size, font, tier in cached_pages[page_index]:
                if is_noise(text, tier):
                    continue

                if tier in ("big", "sub"):
                    heading_lines += 1
                    if pending_tier is not None and pending_tier != tier:
                        flush_pending(page_number)
                    if not pending_texts:
                        pending_page_start = page_number
                    pending_texts.append(text)
                    pending_tier = tier
                    continue

                # Body-Zeile: eine offene Ueberschrift wird jetzt final dem
                # naechsten Chunk zugeordnet, bevor der Fliesstext angehaengt wird.
                if pending_texts:
                    flush_pending(page_number)
                if current is None:
                    current = RawChunk(
                        section_number=f"Kapitel {max(chapter_num, 1)}",
                        section_title=chapter_title,
                        page_start=page_number,
                        page_end=page_number,
                    )
                current.text_parts.append(text)
                current.page_end = page_number

        flush_pending(len(pdf.pages))
        if current is not None:
            chunks.append(current)

    heading_density = heading_lines / text_pages if text_pages else 0
    if heading_density < 0.2:
        print(
            f"    WARNUNG: Heading-Dichte {heading_density:.2f}/Seite zu niedrig, "
            "falle auf Seiten-Chunking zurueck.",
            file=sys.stderr,
        )
        return chunk_pages_fallback(pdf_path)

    return chunks


def chunk_pages_fallback(pdf_path: Path) -> list[RawChunk]:
    chunks: list[RawChunk] = []
    with pdfplumber.open(pdf_path) as pdf:
        for page_index, page in enumerate(pdf.pages):
            text = (page.extract_text() or "").strip()
            if not text:
                continue
            page_number = page_index + 1
            chunk = RawChunk(
                section_number=f"S. {page_number}",
                section_title=None,
                page_start=page_number,
                page_end=page_number,
            )
            chunk.text_parts.append(text)
            chunks.append(chunk)
    return chunks


# ---------------------------------------------------------------------------
# Orchestrierung
# ---------------------------------------------------------------------------


def build_doc_chunks(doc: DocConfig) -> list[dict]:
    pdf_path = REPO_ROOT / doc.source_file
    print(f"  -> {doc.source_file}")
    if doc.strategy == "numbered_clauses":
        raw_chunks = chunk_numbered_clauses(pdf_path)
    else:
        raw_chunks = chunk_heading_pages(pdf_path)

    entries: list[dict] = []
    for raw in raw_chunks:
        text = raw.text()
        if len(text) < MIN_TEXT_CHARS:
            continue
        parts = split_oversized(text, MAX_CHUNK_CHARS, OVERLAP_RATIO)
        for idx, part in enumerate(parts):
            section_number = raw.section_number if len(parts) == 1 else f"{raw.section_number}-{idx + 1}"
            entries.append(
                {
                    "doc_id": doc.doc_id,
                    "ebene": doc.ebene,
                    "doc_title": doc.doc_title,
                    "doc_stand": doc.doc_stand,
                    "section_number": section_number,
                    "section_title": raw.section_title,
                    "page_start": raw.page_start,
                    "page_end": raw.page_end,
                    "text": part,
                    "source_file": doc.source_file,
                }
            )
    print(f"     {len(entries)} Chunks erzeugt (aus {len(raw_chunks)} Rohabschnitten)")
    return entries


def build(doc_id_filter: Optional[str], dry_run: bool, output_path: Path) -> int:
    docs = [d for d in DOCS if doc_id_filter is None or d.doc_id == doc_id_filter]
    if not docs:
        print(f"Kein Dokument mit doc_id={doc_id_filter!r} in der Konfiguration.", file=sys.stderr)
        return 1

    all_chunks: list[dict] = []
    for doc in docs:
        all_chunks.extend(build_doc_chunks(doc))

    hard_fails, warnings = validate_chunks(all_chunks, docs)
    for w in warnings:
        print(f"  WARNUNG: {w}")
    for f in hard_fails:
        print(f"  FEHLER: {f}", file=sys.stderr)

    if dry_run:
        print("\n--dry-run: nichts geschrieben.")
        print_stats(all_chunks)
        return 1 if hard_fails else 0

    corpus = {
        "corpus_version": CORPUS_VERSION,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source_pipeline": "chat_ai/build_chunks.py",
        "chunk_count": len(all_chunks),
        "chunks": all_chunks,
    }

    if doc_id_filter is not None and output_path.exists():
        existing = json.loads(output_path.read_text(encoding="utf-8"))
        kept = [c for c in existing.get("chunks", []) if c["doc_id"] != doc_id_filter]
        merged = kept + all_chunks
        corpus["chunks"] = merged
        corpus["chunk_count"] = len(merged)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(corpus, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"\n{corpus['chunk_count']} Chunks geschrieben nach {output_path}")

    return 1 if hard_fails else 0


def print_stats(chunks: list[dict]) -> None:
    by_doc: dict[str, list[dict]] = {}
    for c in chunks:
        by_doc.setdefault(c["doc_id"], []).append(c)
    for doc_id, doc_chunks in by_doc.items():
        lengths = [len(c["text"]) for c in doc_chunks]
        avg_tokens = sum(lengths) / len(lengths) / 4 if lengths else 0
        print(
            f"  {doc_id}: {len(doc_chunks)} Chunks, "
            f"~{avg_tokens:.0f} Tokens/Chunk im Schnitt, "
            f"min={min(lengths, default=0)} max={max(lengths, default=0)} Zeichen"
        )


# ---------------------------------------------------------------------------
# Validierung
# ---------------------------------------------------------------------------

REQUIRED_FIELDS = [
    "doc_id",
    "ebene",
    "doc_title",
    "doc_stand",
    "section_number",
    "page_start",
    "page_end",
    "text",
    "source_file",
]

SPLIT_SUFFIX_RE = re.compile(r"^(.*)-(\d+)$")


def validate_chunks(chunks: list[dict], docs: list[DocConfig]) -> tuple[list[str], list[str]]:
    hard_fails: list[str] = []
    warnings: list[str] = []

    if not chunks:
        hard_fails.append("Keine Chunks erzeugt.")
        return hard_fails, warnings

    seen_keys: dict[tuple[str, str], int] = {}
    counts: Counter[str] = Counter()

    for c in chunks:
        loc = f"{c.get('doc_id', '?')}/{c.get('section_number', '?')}"
        for field_name in REQUIRED_FIELDS:
            value = c.get(field_name)
            if field_name == "section_title":
                continue
            if value is None or value == "":
                hard_fails.append(f"{loc}: Pflichtfeld '{field_name}' fehlt/leer.")

        if not c.get("section_title"):
            doc_cfg = next((d for d in docs if d.doc_id == c.get("doc_id")), None)
            if doc_cfg is not None and doc_cfg.strategy != "heading_pages":
                hard_fails.append(f"{loc}: section_title fehlt (nur im Seiten-Fallback erlaubt).")

        text = c.get("text", "")
        if len(text) < MIN_TEXT_CHARS:
            hard_fails.append(f"{loc}: Text zu kurz ({len(text)} Zeichen).")
        elif len(text) > MAX_CHUNK_CHARS * 2:
            hard_fails.append(f"{loc}: Text extrem lang ({len(text)} Zeichen), deutet auf Chunking-Bug hin.")
        elif not (MIN_CHUNK_CHARS <= len(text) <= MAX_CHUNK_CHARS):
            warnings.append(f"{loc}: Chunk-Groesse {len(text)} Zeichen ausserhalb Zielband ({MIN_CHUNK_CHARS}-{MAX_CHUNK_CHARS}).")

        if c.get("page_start", 0) > c.get("page_end", 0):
            hard_fails.append(f"{loc}: page_start > page_end.")

        counts[c.get("doc_id", "?")] += 1
        key = (c.get("doc_id", "?"), c.get("section_number", "?"))
        seen_keys[key] = seen_keys.get(key, 0) + 1

    for (doc_id, section_number), count in seen_keys.items():
        if count > 1:
            hard_fails.append(f"{doc_id}/{section_number}: doppelte (doc_id, section_number)-Kombination ({count}x).")

    present_doc_ids = {c.get("doc_id") for c in chunks}
    for doc in docs:
        if doc.doc_id not in present_doc_ids:
            hard_fails.append(f"{doc.doc_id}: kein einziger Chunk erzeugt (Parsing-Totalausfall?).")
        else:
            n = counts[doc.doc_id]
            lo, hi = doc.expected_chunk_range
            if not (lo <= n <= hi):
                warnings.append(f"{doc.doc_id}: {n} Chunks ausserhalb Plausibilitaetsbereich [{lo},{hi}].")

    return hard_fails, warnings


def validate_command(input_path: Path) -> int:
    if not input_path.exists():
        print(f"Datei nicht gefunden: {input_path}", file=sys.stderr)
        return 1
    corpus = json.loads(input_path.read_text(encoding="utf-8"))
    for top_field in ("corpus_version", "generated_at", "chunks"):
        if top_field not in corpus:
            print(f"FEHLER: Top-Level-Feld '{top_field}' fehlt.", file=sys.stderr)
            return 1
    if not corpus["chunks"]:
        print("FEHLER: 'chunks' ist leer.", file=sys.stderr)
        return 1

    hard_fails, warnings = validate_chunks(corpus["chunks"], DOCS)
    for w in warnings:
        print(f"WARNUNG: {w}")
    for f in hard_fails:
        print(f"FEHLER: {f}", file=sys.stderr)

    print_stats(corpus["chunks"])

    if hard_fails:
        print(f"\n{len(hard_fails)} Hard-Fail(s), {len(warnings)} Warnung(en).", file=sys.stderr)
        return 1
    print(f"\nValidierung ok ({len(warnings)} Warnung(en)).")
    return 0


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    build_parser = subparsers.add_parser("build", help="PDFs neu chunken und Korpus schreiben")
    build_parser.add_argument("--doc-id", default=None, help="Nur dieses Dokument neu bauen")
    build_parser.add_argument("--dry-run", action="store_true", help="Nur Statistik ausgeben, nichts schreiben")
    build_parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)

    validate_parser = subparsers.add_parser("validate", help="Vorhandenes Korpus-JSON pruefen")
    validate_parser.add_argument("--input", type=Path, default=DEFAULT_OUTPUT)

    args = parser.parse_args()

    if args.command == "build":
        return build(args.doc_id, args.dry_run, args.output)
    if args.command == "validate":
        return validate_command(args.input)
    parser.print_help()
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
