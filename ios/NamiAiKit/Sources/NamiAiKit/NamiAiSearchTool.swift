import Foundation

#if canImport(FoundationModels)
  import FoundationModels

  /// Retrieval tool per specs/nami-ai-roadmap.md section 3.6: the model must call this to see
  /// any corpus content at all — there is no longer a fixed set of chunks preloaded into the
  /// session instructions (that was the 3.1 pilot's deliberate shortcut, superseded here).
  /// Ranking is BM25 fused with NLContextualEmbedding semantic similarity when the embedding
  /// model/assets are available (topMatchesHybrid, Variante B/D), and silently pure-BM25
  /// otherwise - see NamiAiRetrievalIndex.
  @available(iOS 26.0, macOS 26.0, *)
  struct NamiAiSearchTool: Tool {
    let name = "search_regelwerk"
    let description = "Durchsucht Satzung und Ordnung der DPSG nach passenden Abschnitten."

    @Generable
    struct Arguments {
      @Guide(description: "Suchbegriffe oder die Nutzerfrage") var query: String
    }

    let recorder: NamiAiRetrievalRecorder

    func call(arguments: Arguments) async throws -> String {
      guard let index = NamiAiCorpus.index() else {
        return "Kein Korpus verfügbar."
      }
      let matches = await index.topMatchesHybrid(
        for: arguments.query, semanticScorer: NamiAiCorpus.semanticScorer())
      guard !matches.isEmpty else {
        return "Keine passenden Abschnitte gefunden."
      }
      await recorder.record(matches)
      return matches.enumerated()
        .map { offset, chunk in
          "\(offset + 1). [\(chunk.docTitle), \(chunk.sectionNumber), Stand \(chunk.docStand)]\n\(chunk.text)"
        }
        .joined(separator: "\n\n")
    }
  }
#endif
