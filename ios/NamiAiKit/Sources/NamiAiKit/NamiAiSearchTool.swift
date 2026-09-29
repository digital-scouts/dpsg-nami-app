import Foundation

#if canImport(FoundationModels)
  import FoundationModels

  /// Retrieval tool per specs/nami-ai-roadmap.md section 3.6: the model must call this to see
  /// any corpus content at all — there is no longer a fixed set of chunks preloaded into the
  /// session instructions (that was the 3.1 pilot's deliberate shortcut, superseded here).
  /// Ranking is plain BM25 (topMatches, Variante A) - see the TODO in call(arguments:) for why
  /// the embedding hybrid (Variante B/D, topMatchesHybrid) is currently not used.
  @available(iOS 26.0, macOS 26.0, *)
  struct NamiAiSearchTool: Tool {
    let name = "search_regelwerk"
    let description = "Durchsucht Satzung und Ordnung der DPSG nach passenden Abschnitten."

    @Generable
    struct Arguments {
      @Guide(description: "Suchbegriffe oder die Nutzerfrage") var query: String
      @Guide(
        description:
          "Falls aus der Frage eindeutig hervorgeht, nach welchem konkreten Organ/Gremium "
          + "gefragt wird (z. B. Stammesvorstand, Stammesversammlung, Bezirksvorstand, "
          + "Bezirkskonferenz, Diözesanvorstand, Diözesanleitung, Bundesvorstand, "
          + "Hauptausschuss) - der volle, ausgeschriebene Name, keine Abkürzung (löse "
          + "Abkürzungen wie Stavo/SV/DL über das Glossar auf). Leer lassen, wenn die Frage "
          + "kein einzelnes Organ eindeutig benennt."
      ) var organHint: String?
    }

    let recorder: NamiAiRetrievalRecorder

    func call(arguments: Arguments) async throws -> String {
      guard let index = NamiAiCorpus.index() else {
        return "Kein Korpus verfügbar."
      }
      // TODO: Entscheiden, ob die Embedding-Hybrid-Variante (topMatchesHybrid, Variante B/D aus
      // specs/nami-ai-roadmap.md 3.6) repariert oder endgültig entfernt wird. Vorerst
      // abgeschaltet, weil sie gemessen ausschließlich schadet: Diagnoselauf 2026-09-21 über
      // dieselben 32 automatisiert prüfbaren Fragen aus chat_ai/eval/eval_questions.json,
      // identischer Korpus, echte NLContextualEmbedding-Assets geladen - reines BM25 30/32,
      // Hybrid 23/32. Sieben Fragen bestehen nur mit BM25 (u. a. jargon-sv-mitglieder,
      // general-bundesvorstand-aufgaben), KEINE einzige besteht nur mit Hybrid - die
      // RRF-Fusion verdrängt also korrekte BM25-Treffer, ohne je einen eigenen beizusteuern.
      // Das ist die in 3.6 offen gelassene, datengetriebene B/D-Entscheidung. topMatchesHybrid
      // und seine Tests bleiben bewusst erhalten, bis das geklärt ist (mögliche Ursachen:
      // Mean-Pooling über ganze Chunks zu grob, RRF-k=60 bei nur 20 Kandidaten zu flach,
      // fehlende Gewichtung zugunsten des lexikalischen Rankings).
      let matches = index.topMatches(
        for: arguments.query, organHint: arguments.organHint)
      guard !matches.isEmpty else {
        return "Keine passenden Abschnitte gefunden."
      }
      await recorder.record(matches)
      // section_title is appended as an explicitly labelled trailing field, NOT as a fourth
      // bare comma-separated value: inserting it unlabelled between docTitle and sectionNumber
      // made the model mis-assign which value is the section number to cite, so
      // NamiAiGroundingGate rejected every single source and forced unclear=true on all 43
      // turns of a full nami-ai-eval run. The leading "[<docTitle>, <sectionNumber>, Stand
      // <docStand>" shape the model learned to cite from therefore has to stay byte-identical.
      return matches.enumerated()
        .map { offset, chunk in
          "\(offset + 1). [\(chunk.docTitle), \(chunk.sectionNumber), Stand \(chunk.docStand); Thema: \(chunk.sectionTitle)]\n\(chunk.text)"
        }
        .joined(separator: "\n\n")
    }
  }
#endif
