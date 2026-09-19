import Foundation
import NaturalLanguage

/// Real NLContextualEmbedding-backed NamiAiSemanticScorer (specs/nami-ai-roadmap.md section 3.6,
/// Variante B). Lazily loads the German contextual-embedding model and precomputes/caches a
/// mean-pooled sentence vector per chunk on first use. An actor since that state (loaded model,
/// cached chunk vectors) must be safely shared across concurrent NamiAiSearchTool calls
/// (Tool.call is potentially @concurrent - same reasoning as NamiAiRetrievalRecorder).
///
/// The API usage here was verified by type-checking against the real NaturalLanguage.framework
/// header (NLContextualEmbedding.h) on the installed SDK, not guessed - but the actual runtime
/// behavior (model asset download, embedding quality/latency on real corpus text) can only be
/// confirmed on a real device: the simulator/CI environment has no way to download or run the
/// model, exactly like FoundationModels elsewhere in this package (see NamiAiResponder). Any
/// failure at any step (no model for the language, assets unavailable, load/embedding errors)
/// makes this return nil, which NamiAiRetrievalIndex.topMatchesHybrid treats as "fall back to
/// BM25 only" - never a user-facing error.
///
/// NLContextualEmbedding requires iOS 17/macOS 14 (NS_CLASS_AVAILABLE(14_0, 17_0)) - lower than
/// FoundationModels' iOS 26, but still above this app's actual deployment target (iOS 15, see
/// Runner's IPHONEOS_DEPLOYMENT_TARGET and NamiAiKit's Package.swift `.iOS(.v15)`), so this
/// still needs its own explicit `@available` gate, same pattern as NamiAiResponder/
/// NamiAiSearchTool use for FoundationModels' iOS 26 requirement.
@available(iOS 17.0, macOS 14.0, *)
actor NamiAiContextualEmbeddingScorer: NamiAiSemanticScorer {
  private enum PreparationState {
    case notPrepared
    case ready(NLContextualEmbedding)
    case unavailable
  }

  private let language: NLLanguage
  private var preparationState: PreparationState = .notPrepared
  private var chunkVectorsByChunkKey: [NamiAiChunkKey: [Double]] = [:]

  init(language: NLLanguage = .german) {
    self.language = language
  }

  func similarityScores(for query: String, against chunks: [NamiAiChunk]) async -> [Double]? {
    guard let model = await preparedModel() else {
      return nil
    }
    guard let queryVector = Self.meanPooledVector(for: query, model: model, language: language)
    else {
      return nil
    }

    var scores: [Double] = []
    scores.reserveCapacity(chunks.count)
    for chunk in chunks {
      guard let chunkVector = vector(for: chunk, model: model) else {
        return nil
      }
      scores.append(Self.cosineSimilarity(queryVector, chunkVector))
    }
    return scores
  }

  /// Loads the model and requests its assets on first use, remembering permanent failure for
  /// this scorer's lifetime rather than retrying every call - a device without usable assets
  /// (no network, unsupported language) isn't going to suddenly gain them mid-session.
  private func preparedModel() async -> NLContextualEmbedding? {
    switch preparationState {
    case .ready(let model):
      return model
    case .unavailable:
      return nil
    case .notPrepared:
      break
    }

    guard let model = NLContextualEmbedding(language: language) else {
      preparationState = .unavailable
      return nil
    }
    if !model.hasAvailableAssets {
      guard let downloadResult = try? await model.requestAssets(),
        downloadResult == .available
      else {
        preparationState = .unavailable
        return nil
      }
    }
    do {
      try model.load()
    } catch {
      preparationState = .unavailable
      return nil
    }
    preparationState = .ready(model)
    return model
  }

  private func vector(for chunk: NamiAiChunk, model: NLContextualEmbedding) -> [Double]? {
    let key = NamiAiChunkKey(docTitle: chunk.docTitle, sectionNumber: chunk.sectionNumber)
    if let cached = chunkVectorsByChunkKey[key] {
      return cached
    }
    guard let vector = Self.meanPooledVector(for: chunk.text, model: model, language: language)
    else {
      return nil
    }
    chunkVectorsByChunkKey[key] = vector
    return vector
  }

  /// Mean-pools NLContextualEmbedding's per-subword-token vectors into a single sentence
  /// vector - one of the pooling techniques the framework's own documentation recommends
  /// (NLContextualEmbeddingResult.h) for turning subword embeddings into a single
  /// representation for a whole piece of text.
  private static func meanPooledVector(
    for text: String, model: NLContextualEmbedding, language: NLLanguage
  ) -> [Double]? {
    guard let result = try? model.embeddingResult(for: text, language: language) else {
      return nil
    }

    var sum: [Double] = []
    var tokenCount = 0
    result.enumerateTokenVectors(in: result.string.startIndex..<result.string.endIndex) {
      vector, _ in
      if sum.isEmpty {
        sum = vector
      } else {
        for index in 0..<sum.count {
          sum[index] += vector[index]
        }
      }
      tokenCount += 1
      return true
    }

    guard tokenCount > 0 else {
      return nil
    }
    return sum.map { $0 / Double(tokenCount) }
  }

  /// Standard cosine similarity, pure and testable independently of any real embedding model.
  static func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
    guard a.count == b.count, !a.isEmpty else {
      return 0
    }
    var dotProduct = 0.0
    var normA = 0.0
    var normB = 0.0
    for index in 0..<a.count {
      dotProduct += a[index] * b[index]
      normA += a[index] * a[index]
      normB += b[index] * b[index]
    }
    guard normA > 0, normB > 0 else {
      return 0
    }
    return dotProduct / (normA.squareRoot() * normB.squareRoot())
  }
}
