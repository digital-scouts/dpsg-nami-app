"""Verifizierter Chunk-Subset fuer den Stammesversammlung-Piloten (Abschnitt 3.1 der nami-ai-roadmap).

Filtert assets/ai_kontext/satzung_stamm_2024.json (69 Chunks, ein Chunk pro
nummerierter Ziffer) auf die Ziffern, die inhaltlich zur Stammesversammlung
gehoeren. Kein reiner Keyword-Filter: enthaelt zusaetzlich manuell verifizierte
Fortsetzungs-Ziffern ohne woertliche Erwaehnung sowie einen Bindestrich-
Kurzform-Fall ("Stammes- und Bezirksversammlung"), die ein reiner
Substring-Filter auf "Stammesversammlung" verlieren wuerde.

Ausgabe:
- stammesversammlung_pilot_chunks.json neben diesem Skript (reiches Kuratierungs-Artefakt
  mit Ziffer/reason/note, nicht fuer den App-Bundle gedacht).
- ios/NamiAiKit/Sources/NamiAiKit/Resources/stammesversammlung_pilot_chunks.json (gestrippt
  auf ein reines Array von Chunk-Texten, keine internen Metadaten) -- das ist die Resource,
  die das NamiAiKit-Swift-Package zur Laufzeit via Bundle.module laedt.
"""

import json
from pathlib import Path

SOURCE = Path(__file__).resolve().parents[2] / "assets" / "ai_kontext" / "satzung_stamm_2024.json"
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

DOC_TITLE = "Satzung Stamm"
DOC_STAND = "Mai 2024"
SOURCE_FILE = "chat_ai/files/00_satzung_der_dpsg_-_stamm_mai_2024.pdf"

# 0-basierter Chunk-Index -> Grund der Aufnahme.
# Ziffer = Index + 1 (ein Chunk pro nummerierter Ziffer, siehe pdf_phrase_extraction.py).
DIRECT_MATCH = {
    2, 17, 18, 19, 20, 21, 22, 23, 25, 28, 33, 41, 42, 43, 45, 46,
    49, 50, 51, 52, 54, 55, 58, 61, 63, 66,
}
CONTINUATION = {
    47: "Fortsetzung von Ziffer 47 (Beschlussfaehigkeit) - Mehrheitsregel gilt auch fuer die Stammesversammlung",
    48: "Fortsetzung des Wahl-Regelungskomplexes (Ziffer 47-50) - Wahlmodus, u.a. fuer Wahlen der Stammesversammlung",
    53: "Fortsetzung von Ziffer 53 (Antraege an die Stammesversammlung) - Formvorschrift",
    56: "Fortsetzung von Ziffer 55/56 (Einladungsfristen zur Stammesversammlung)",
    62: "Fortsetzung vor Ziffer 64 (Oeffentlichkeitsausschluss in der Stammesversammlung)",
}
HYPHENATION_ELISION = {
    59: "Bindestrich-Kurzform 'Stammes- und Bezirksversammlung' - Substring-Filter auf "
        "'Stammesversammlung' findet dies nicht, Ziffer regelt Stimmrechtsdelegation auch "
        "fuer die Stammesversammlung",
}


def build():
    chunks = json.loads(SOURCE.read_text(encoding="utf-8"))
    entries = []
    all_indices = sorted(DIRECT_MATCH | set(CONTINUATION) | set(HYPHENATION_ELISION))
    for idx in all_indices:
        if idx in CONTINUATION:
            reason = "continuation"
            note = CONTINUATION[idx]
        elif idx in HYPHENATION_ELISION:
            reason = "hyphenation_elision"
            note = HYPHENATION_ELISION[idx]
        else:
            reason = "direct_match"
            note = "Enthaelt 'Stammesversammlung' woertlich"
        entries.append(
            {
                "ziffer": idx + 1,
                "doc_title": DOC_TITLE,
                "doc_stand": DOC_STAND,
                "source_file": SOURCE_FILE,
                "reason": reason,
                "note": note,
                "text": chunks[idx],
            }
        )

    OUTPUT.write_text(
        json.dumps(entries, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"{len(entries)} Chunks geschrieben nach {OUTPUT}")
    print(f"davon direct_match={len(DIRECT_MATCH)}, continuation={len(CONTINUATION)}, "
          f"hyphenation_elision={len(HYPHENATION_ELISION)}")

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
