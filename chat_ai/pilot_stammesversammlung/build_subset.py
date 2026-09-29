"""Verifizierter Chunk-Subset fuer den Stammesversammlung-Piloten (Abschnitt 3.1 der
nami-ai-roadmap.md).

Filtert assets/ai_kontext/nami_ai_corpus_v1.json (Ausgabe von chat_ai/build_chunks.py,
Abschnitt 3.4) auf die Ziffern der Satzung Stamm, die inhaltlich zur Stammesversammlung
gehoeren. Kein reiner Keyword-Filter: enthaelt zusaetzlich manuell verifizierte
Fortsetzungs-Ziffern ohne woertliche Erwaehnung sowie einen Bindestrich-Kurzform-Fall
("Stammes- und Bezirksversammlung"), die ein reiner Substring-Filter auf
"Stammesversammlung" verlieren wuerde.

Migriert von der fruehreren Quelle assets/ai_kontext/satzung_stamm_2024.json (Array-Index-
basiert, ohne Metadaten, ein Chunk pro nummerierter Ziffer INKLUSIVE gefalteter
Buchstaben-Fortsetzungen wie "42a"/"42b"). Die neue Pipeline fuehrt Buchstaben-Ziffern
(z.B. "42a") als eigene, praezise zitierfaehige section_number statt sie in die
vorherige Ziffer zu falten -- deshalb enthaelt LETTERED_EXPANSIONS unten die Zuordnung,
welche Buchstaben-Ziffern zu einer bereits kuratierten Basis-Ziffer gehoeren (identische
Aufnahme-Begruendung wie die Basis-Ziffer, da im alten Schema textlich mitenthalten).

Ausgabe:
- stammesversammlung_pilot_chunks.json neben diesem Skript (reiches Kuratierungs-Artefakt
  mit section_number/reason/note, nicht fuer den App-Bundle gedacht).
- ios/NamiAiKit/Sources/NamiAiKit/Resources/stammesversammlung_pilot_chunks.json (gestrippt
  auf ein reines Array von Chunk-Texten, keine internen Metadaten) -- das ist die Resource,
  die das NamiAiKit-Swift-Package zur Laufzeit via Bundle.module laedt.
"""

import json
import re
from pathlib import Path

SOURCE = Path(__file__).resolve().parents[2] / "assets" / "ai_kontext" / "nami_ai_corpus_v1.json"
OUTPUT = Path(__file__).resolve().parent / "stammesversammlung_pilot_chunks.json"
APP_ASSET_OUTPUT = (
    Path(__file__).resolve().parents[2]
    / "ios"
    / "NamiAiKit"
    / "Sources"
    / "NamiAiKit"
    / "Resources"
    / "stammesversammlung_pilot_chunks.json"
)

DOC_ID = "satzung_stamm"
DOC_TITLE = "Satzung Stamm"
DOC_STAND = "Mai 2024"
SOURCE_FILE = "chat_ai/files/00_satzung_der_dpsg_-_stamm_mai_2024.pdf"

# Basis-Ziffer (int) -> Grund der Aufnahme. Unveraendert gegenueber der urspruenglichen
# Kuration, nur auf die neue section_number-Nomenklatur (str statt "ziffer"-int) bezogen.
DIRECT_MATCH = {
    3, 18, 19, 20, 21, 22, 23, 24, 26, 29, 34, 42, 43, 44, 46, 47,
    50, 51, 52, 53, 55, 56, 59, 62, 64, 67,
}
CONTINUATION = {
    48: "Fortsetzung des Wahl-Regelungskomplexes (Ziffer 47-50) - Wahlmodus, u.a. fuer Wahlen der Stammesversammlung",
    49: "Fortsetzung des Wahl-Regelungskomplexes (Ziffer 47-50) - Wahlmodus, u.a. fuer Wahlen der Stammesversammlung",
    54: "Fortsetzung von Ziffer 53 (Antraege an die Stammesversammlung) - Formvorschrift",
    57: "Fortsetzung von Ziffer 55/56 (Einladungsfristen zur Stammesversammlung)",
    63: "Fortsetzung vor Ziffer 64 (Oeffentlichkeitsausschluss in der Stammesversammlung)",
}
HYPHENATION_ELISION = {
    60: "Bindestrich-Kurzform 'Stammes- und Bezirksversammlung' - Substring-Filter auf "
        "'Stammesversammlung' findet dies nicht, Ziffer regelt Stimmrechtsdelegation auch "
        "fuer die Stammesversammlung",
}

# Buchstaben-Ziffern, die im alten Array-Index-Schema in ihre Basis-Ziffer gefaltet waren
# (z.B. "42a"/"42b" als Teil des alten Chunks "42") und in der neuen Pipeline als eigene
# section_number auftauchen. Erben die Aufnahme-Begruendung ihrer Basis-Ziffer, da die
# gefaltete Kombination im alten Schema genau deswegen aufgenommen wurde.
LETTERED_EXPANSIONS: dict[int, list[str]] = {
    19: ["19a"],
    42: ["42a", "42b"],
    43: ["43a"],
    47: ["47a"],
    50: ["50a"],
}


def build():
    corpus = json.loads(SOURCE.read_text(encoding="utf-8"))
    by_section_number = {
        c["section_number"]: c for c in corpus["chunks"] if c["doc_id"] == DOC_ID
    }

    base_numbers = sorted(DIRECT_MATCH | set(CONTINUATION) | set(HYPHENATION_ELISION))
    selected: list[tuple[str, str, str]] = []  # (section_number, reason, note)
    for base in base_numbers:
        if base in CONTINUATION:
            reason, note = "continuation", CONTINUATION[base]
        elif base in HYPHENATION_ELISION:
            reason, note = "hyphenation_elision", HYPHENATION_ELISION[base]
        else:
            reason, note = "direct_match", "Enthaelt 'Stammesversammlung' woertlich"
        selected.append((str(base), reason, note))
        for lettered in LETTERED_EXPANSIONS.get(base, []):
            selected.append(
                (
                    lettered,
                    reason,
                    f"Fortsetzung von Ziffer {base} (im alten Array-Index-Schema in "
                    f"Ziffer {base} gefaltet, jetzt eigene section_number): {note}",
                )
            )

    entries = []
    missing = []
    for section_number, reason, note in selected:
        chunk = by_section_number.get(section_number)
        if chunk is None:
            missing.append(section_number)
            continue
        entries.append(
            {
                "section_number": section_number,
                "doc_title": DOC_TITLE,
                "doc_stand": DOC_STAND,
                "source_file": SOURCE_FILE,
                "reason": reason,
                "note": note,
                "text": chunk["text"],
            }
        )

    if missing:
        raise SystemExit(
            f"section_number(s) nicht im Korpus gefunden, Kuration pruefen: {missing}"
        )

    # Sortierung nach numerischem Ziffernwert (dann Buchstaben-Suffix), fuer eine
    # sinnvolle Lesereihenfolge in der gestrippten App-Ressource.
    def sort_key(entry):
        match = re.match(r"(\d+)([a-z]*)", entry["section_number"])
        return int(match.group(1)), match.group(2)

    entries.sort(key=sort_key)

    OUTPUT.write_text(
        json.dumps(entries, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"{len(entries)} Chunks geschrieben nach {OUTPUT}")
    reason_counts = {}
    for e in entries:
        reason_counts[e["reason"]] = reason_counts.get(e["reason"], 0) + 1
    print(f"davon: {reason_counts}")

    # Gestrippte App-Asset-Resource: nur Chunk-Texte, keine internen Metadaten/Notizen.
    app_asset = [entry["text"] for entry in entries]
    APP_ASSET_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    APP_ASSET_OUTPUT.write_text(
        json.dumps(app_asset, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"{len(app_asset)} Chunk-Texte (ohne Metadaten) geschrieben nach {APP_ASSET_OUTPUT}")


if __name__ == "__main__":
    build()
