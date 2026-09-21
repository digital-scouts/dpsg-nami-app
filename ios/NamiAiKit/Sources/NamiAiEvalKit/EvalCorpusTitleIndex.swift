import Foundation

/// NamiAiChunk/NamiAiCorpus are package-internal to NamiAiKit, so this reads the same corpus
/// JSON independently (own minimal Decodable, same approach as NamiAiEvalTests.swift's own
/// EvalQuestion) to build just the (docTitle -> docId) reverse lookup this eval tool needs.
/// NamiAiAnswer.sources cites by docTitle (NamiAiSourceRef), but eval fixtures' expected_sources
/// use doc_id - this index bridges the two. Verified 1:1 in the production corpus (5 doc_id
/// values, one doc_title each); a collision is therefore treated as a hard error rather than
/// silently picking one side, since the whole source-match comparison relies on that 1:1-ness.
public struct EvalCorpusTitleIndex: Sendable {
  public let docIdByTitle: [String: String]

  private struct CorpusChunk: Decodable {
    let docId: String
    let docTitle: String

    enum CodingKeys: String, CodingKey {
      case docId = "doc_id"
      case docTitle = "doc_title"
    }
  }

  private struct CorpusFile: Decodable {
    let chunks: [CorpusChunk]
  }

  public init(corpusFileURL: URL) throws {
    guard FileManager.default.fileExists(atPath: corpusFileURL.path) else {
      throw EvalCorpusTitleIndexError.fileNotFound(corpusFileURL)
    }
    let data = try Data(contentsOf: corpusFileURL)
    let corpus = try JSONDecoder().decode(CorpusFile.self, from: data)
    try self.init(chunks: corpus.chunks.map { ($0.docId, $0.docTitle) })
  }

  init(chunks: [(docId: String, docTitle: String)]) throws {
    var mapping: [String: String] = [:]
    for (docId, docTitle) in chunks {
      if let existing = mapping[docTitle], existing != docId {
        throw EvalCorpusTitleIndexError.ambiguousTitle(docTitle)
      }
      mapping[docTitle] = docId
    }
    self.docIdByTitle = mapping
  }

  /// nil when the cited docTitle doesn't match any known corpus document - a data-quality
  /// signal in its own right (the model cited a title that doesn't exist), not just a lookup
  /// miss, so callers should surface it rather than silently treating it as "no match".
  public func docId(forCitedTitle docTitle: String) -> String? {
    docIdByTitle[docTitle]
  }
}

public enum EvalCorpusTitleIndexError: Error, Equatable {
  case fileNotFound(URL)
  case ambiguousTitle(String)
}
