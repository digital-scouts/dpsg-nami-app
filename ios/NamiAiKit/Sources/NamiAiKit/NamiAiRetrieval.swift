import Foundation

/// Lexical (BM25-style) retrieval over the corpus, variant (A) from specs/nami-ai-roadmap.md
/// section 3.6 — deterministic, no embeddings/model needed, cheap enough for brute force over
/// a few hundred chunks. Pure algorithm, independent of FoundationModels, so it stays testable
/// without a device.
struct NamiAiRetrievalIndex {
  let chunks: [NamiAiChunk]

  private let termFrequencyPerChunk: [[String: Int]]
  private let documentLengths: [Int]
  private let averageDocumentLength: Double
  private let documentFrequency: [String: Int]

  init(chunks: [NamiAiChunk]) {
    self.chunks = chunks
    let tokenizedChunks = chunks.map { Self.tokenize($0.text) }
    self.documentLengths = tokenizedChunks.map(\.count)
    let totalLength = documentLengths.reduce(0, +)
    self.averageDocumentLength =
      documentLengths.isEmpty ? 0 : Double(totalLength) / Double(documentLengths.count)

    var termFrequencyPerChunk: [[String: Int]] = []
    var documentFrequency: [String: Int] = [:]
    for tokens in tokenizedChunks {
      var frequency: [String: Int] = [:]
      for token in tokens {
        frequency[token, default: 0] += 1
      }
      termFrequencyPerChunk.append(frequency)
      for term in Set(tokens) {
        documentFrequency[term, default: 0] += 1
      }
    }
    self.termFrequencyPerChunk = termFrequencyPerChunk
    self.documentFrequency = documentFrequency
  }

  /// Lowercases and splits on anything that isn't a letter/digit. Umlaute and ß are letters in
  /// Unicode terms, so they stay part of the token instead of being split off.
  static func tokenize(_ text: String) -> [String] {
    text.lowercased()
      .components(separatedBy: CharacterSet.alphanumerics.inverted)
      .filter { !$0.isEmpty }
  }

  /// BM25 score of every chunk against the query, standard k1=1.5/b=0.75 defaults. Not
  /// normalized to a fixed range — thresholds/weights are tuning knobs for the eval round in
  /// section 3.8, not a claim of statistical correctness.
  func scores(for query: String, k1: Double = 1.5, b: Double = 0.75) -> [Double] {
    let queryTerms = Set(Self.tokenize(query))
    var scores = [Double](repeating: 0, count: chunks.count)
    guard !queryTerms.isEmpty, !chunks.isEmpty, averageDocumentLength > 0 else {
      return scores
    }
    let chunkCount = Double(chunks.count)
    for term in queryTerms {
      guard let docFrequency = documentFrequency[term], docFrequency > 0 else { continue }
      let inverseDocFrequency = log(
        1 + (chunkCount - Double(docFrequency) + 0.5) / (Double(docFrequency) + 0.5))
      for index in 0..<chunks.count {
        guard let termFrequency = termFrequencyPerChunk[index][term], termFrequency > 0 else {
          continue
        }
        let normalizedLength = Double(documentLengths[index]) / averageDocumentLength
        let denominator = Double(termFrequency) + k1 * (1 - b + b * normalizedLength)
        scores[index] += inverseDocFrequency * (Double(termFrequency) * (k1 + 1)) / denominator
      }
    }
    return scores
  }

  /// Top-k chunks above a minimum score, highest first. A strictly-positive default threshold
  /// (rather than >= 0) guards against chunks whose only "match" is a term so common that BM25
  /// assigns it a near-zero or negative idf.
  func topMatches(for query: String, limit: Int = 5, minScore: Double = 0.01) -> [NamiAiChunk] {
    scores(for: query)
      .enumerated()
      .filter { $0.element >= minScore }
      .sorted { $0.element > $1.element }
      .prefix(limit)
      .map { chunks[$0.offset] }
  }
}
