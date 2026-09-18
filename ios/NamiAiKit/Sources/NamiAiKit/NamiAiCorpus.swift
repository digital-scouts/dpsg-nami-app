import Foundation

/// One retrievable unit from the shared DPSG corpus (Satzung Stamm/Bezirk/Diözese/Bund,
/// Ordnung), matching the chunk metadata schema from specs/nami-ai-roadmap.md section 2.4.
struct NamiAiChunk: Decodable {
  let docId: String
  let ebene: String
  let docTitle: String
  let docStand: String
  let sectionNumber: String
  let sectionTitle: String
  let pageStart: Int
  let pageEnd: Int
  let text: String
  let sourceFile: String

  enum CodingKeys: String, CodingKey {
    case docId = "doc_id"
    case ebene
    case docTitle = "doc_title"
    case docStand = "doc_stand"
    case sectionNumber = "section_number"
    case sectionTitle = "section_title"
    case pageStart = "page_start"
    case pageEnd = "page_end"
    case text
    case sourceFile = "source_file"
  }
}

private struct NamiAiCorpusFile: Decodable {
  let chunks: [NamiAiChunk]
}

/// Loads and caches the full corpus produced by chat_ai/build_chunks.py (see specs/nami-ai-
/// roadmap.md section 3.4/3.6). The corpus stays a single Flutter asset (section 3.2) — this
/// type never touches Flutter APIs itself, it only reads whatever file URL NamiAiAssistant.
/// configure(corpusFileURL:) hands it, resolved by the Runner-side bridge.
enum NamiAiCorpus {
  private static var configuredFileURL: URL?
  private static var cachedIndex: NamiAiRetrievalIndex?

  static func configure(fileURL: URL) {
    configuredFileURL = fileURL
    cachedIndex = nil
  }

  /// Returns the retrieval index for the configured corpus, decoding and building it once and
  /// caching afterwards. Returns nil if no corpus was configured or it couldn't be read/parsed.
  static func index() -> NamiAiRetrievalIndex? {
    if let cached = cachedIndex {
      return cached
    }
    guard let url = configuredFileURL,
      let data = try? Data(contentsOf: url),
      let file = try? JSONDecoder().decode(NamiAiCorpusFile.self, from: data),
      !file.chunks.isEmpty
    else {
      return nil
    }
    let index = NamiAiRetrievalIndex(chunks: file.chunks)
    cachedIndex = index
    return index
  }
}
