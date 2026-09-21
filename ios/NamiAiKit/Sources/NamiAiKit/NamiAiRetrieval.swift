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
    let tokenizedChunks = chunks.map { Self.tokenize(Self.indexableText(for: $0)) }
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

  /// How many times section_title is repeated ahead of the chunk's own text when indexing.
  /// section_title (e.g. "Der Stammesvorstand") is the strongest organ/topic signal already
  /// present in the corpus (chat_ai/build_chunks.py inherits it from the nearest preceding
  /// heading), but plain chunk.text never mentions it verbatim - this is the documented
  /// "falsches Organ" root cause (specs/nami-ai-roadmap.md 3.8, chat_ai/eval/eval_questions.json
  /// notes): multiple chunks under the same document legitimately share a query's organ name in
  /// passing, and nothing in the index favored the chunk actually ABOUT that organ. Repeating
  /// the title (rather than a separate weighted sub-score) keeps this a single BM25 pass - the
  /// boost only fires on real word overlap between query and title (BM25's own idf already
  /// favors rare titles), and k1=1.5's term-frequency saturation means going much past a
  /// handful of repetitions buys almost nothing further, which bounds how far a generic/shared
  /// title (e.g. "Organe des Stammes" spanning several unrelated clauses) can distort ranking.
  private static let sectionTitleRepetitions = 3

  /// Caps how much of section_title actually gets repeated. Most section_titles are short
  /// (e.g. "Der Stammesvorstand"), but the "heading_pages" chunking strategy (chat_ai/
  /// build_chunks.py, used for the Ordnung document) occasionally inherits an anomalously long,
  /// even self-duplicated heading (verified against the real corpus: some Ordnung chunks carry
  /// a 150+ character section_title). Repeating that 3x would inflate those chunks' indexed
  /// length far more than the short-title case this boost is designed for, diluting exactly the
  /// query-relevant content the boost is meant to protect - measured to actually regress
  /// several Ordnung-based eval questions before this cap was added. Not a build_chunks.py fix
  /// (out of scope here) - just a defensive bound on how far this indexing-side boost can be
  /// thrown off by a title that doesn't look like the short, clean case it was designed for.
  private static let maxSectionTitleCharsForIndexing = 40

  private static func indexableText(for chunk: NamiAiChunk) -> String {
    let cappedTitle = String(chunk.sectionTitle.prefix(maxSectionTitleCharsForIndexing))
    let repeatedTitle = Array(repeating: cappedTitle, count: sectionTitleRepetitions)
      .joined(separator: " ")
    return "\(repeatedTitle) \(chunk.text)"
  }

  /// German function words with no discriminating power in this corpus - articles, modal/
  /// auxiliary verbs, question words/pronouns, prepositions/conjunctions. Filtered before
  /// stemming (against the raw lowercased token) rather than after: stem()'s minimum-length
  /// guards already leave short stopwords like "des"/"die" untouched either way, but several
  /// longer ones (e.g. "werden", "sollen") DO get stemmed ("werd", "soll") - filtering post-stem
  /// would mean maintaining stemmed forms in this list, unreadable and one accidental collision
  /// with a real content word away from silently eating it. Deliberately excludes DPSG jargon
  /// abbreviations (sv/dl/dv/...) even though they're short - those carry real content.
  private static let stopwords: Set<String> = [
    // Artikel/Determinierer
    "der", "die", "das", "des", "dem", "den", "ein", "eine", "einer", "eines", "einem", "einen",
    "kein", "keine", "keiner", "keines", "keinem", "keinen",
    // Hilfs-/Modalverben
    "ist", "sind", "war", "waren", "wird", "werden", "wurde", "wurden", "hat", "haben", "hatte",
    "hatten", "kann", "können", "konnte", "konnten", "muss", "müssen", "musste", "mussten",
    "soll", "sollen", "sollte", "sollten", "darf", "dürfen", "durfte", "durften", "mag", "mögen",
    "will", "wollen", "wollte", "wollten", "sei", "seien",
    // Frage-/Pronomen
    "was", "wer", "wen", "wem", "wessen", "welche", "welcher", "welches", "welchem", "welchen",
    "wie", "wo", "wann", "warum", "weshalb", "wieso", "sich", "sie", "er", "es", "ich", "du",
    "wir", "ihr", "man", "diese", "dieser", "dieses", "diesem", "diesen", "jede", "jeder",
    "jedes", "jedem", "jeden", "alle", "aller", "alles", "allem", "allen",
    // Präpositionen/Konjunktionen
    "für", "von", "zu", "mit", "bei", "auf", "aus", "in", "an", "um", "über", "unter", "nach",
    "vor", "durch", "gegen", "ohne", "bis", "seit", "als", "wenn", "dass", "weil", "ob", "und",
    "oder", "aber", "sowie", "sowohl", "auch", "noch", "nur", "schon", "so", "dann", "doch",
  ]

  /// Lowercases and splits on anything that isn't a letter/digit, drops stopwords, then stems
  /// each remaining token. Umlaute and ß are letters in Unicode terms, so they stay part of the
  /// token instead of being split off. Applied identically to indexable chunk text at
  /// index-build time (init above) and to every query (scores(for:) below), so stemmed forms
  /// only ever get compared against other stemmed forms.
  static func tokenize(_ text: String) -> [String] {
    text.lowercased()
      .components(separatedBy: CharacterSet.alphanumerics.inverted)
      .filter { !$0.isEmpty && !stopwords.contains($0) }
      .map(stem)
  }

  /// Lightweight, deterministic German suffix stripper - not a full Snowball port, targeted at
  /// the two inflection patterns measured to actually break retrieval (specs/nami-ai-roadmap.md
  /// section 3.8, NamiAiEvalTests.swift's known 40.6% pass-rate finding): dative plural "-ern"
  /// (Mitglieder/Mitgliedern) and genitive "-s" (Bezirksvorstand/Bezirksvorstands). Each rule
  /// keeps a minimum resulting-stem length so short/unrelated words aren't mangled into
  /// accidentally colliding with something else, and only ever strips at most one suffix.
  static func stem(_ token: String) -> String {
    // Valid s-preceding consonants for the genitive/plural "-s" case, same set the German
    // Snowball stemmer uses - deliberately excludes vowels, so vowel+s loanwords/plurals (e.g.
    // "Fokus", "Bonus") are left untouched rather than incorrectly truncated.
    let validSPredecessors: Set<Character> = [
      "b", "d", "f", "g", "h", "k", "l", "m", "n", "r", "t",
    ]

    if token.hasSuffix("ern"), token.count >= 7 {
      return String(token.dropLast())
    }
    if token.hasSuffix("en"), token.count >= 6 {
      return String(token.dropLast(2))
    }
    if token.hasSuffix("es"), token.count >= 6 {
      return String(token.dropLast(2))
    }
    if token.hasSuffix("s"), token.count >= 5,
      let predecessor = token.dropLast().last,
      validSPredecessors.contains(predecessor)
    {
      return String(token.dropLast())
    }
    return token
  }

  /// Additive BM25 score bonus when a caller-supplied organHint (NamiAiSearchTool's optional
  /// organHint argument - the model's own best-effort read of which Organ/Gremium the question
  /// names, resolved from its glossary) overlaps with a chunk's section_title. A soft boost, not
  /// a hard filter: a chunk that doesn't match keeps its normal score untouched, so an
  /// imprecise/absent hint never loses candidates, only reorders them - safer than filtering,
  /// since organHint's wording isn't guaranteed to exactly match section_title's wording.
  /// Bidirectional `contains` because either side can be the more specific one (hint
  /// "Stammesvorstand" vs. title "Der Stammesvorstand", or vice versa). Additive rather than
  /// multiplicative so a chunk with an otherwise-zero BM25 score can still surface purely on the
  /// strength of the hint.
  private static let organHintBoostAmount = 5.0

  private func organHintBoost(for chunk: NamiAiChunk, organHint: String?) -> Double {
    guard
      let organHint = organHint?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
      !organHint.isEmpty
    else {
      return 0
    }
    let title = chunk.sectionTitle.lowercased()
    guard !title.isEmpty, title.contains(organHint) || organHint.contains(title) else {
      return 0
    }
    return Self.organHintBoostAmount
  }

  /// BM25 score of every chunk against the query, standard k1=1.5/b=0.75 defaults, plus the
  /// organHint boost above. Not normalized to a fixed range — thresholds/weights are tuning
  /// knobs for the eval round in section 3.8, not a claim of statistical correctness.
  func scores(
    for query: String, organHint: String? = nil, k1: Double = 1.5, b: Double = 0.75
  ) -> [Double] {
    var scores = [Double](repeating: 0, count: chunks.count)
    let queryTerms = Set(Self.tokenize(query))
    if !queryTerms.isEmpty, !chunks.isEmpty, averageDocumentLength > 0 {
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
    }
    if organHint != nil {
      for index in 0..<chunks.count {
        scores[index] += organHintBoost(for: chunks[index], organHint: organHint)
      }
    }
    return scores
  }

  /// Chunk indices scoring at least minScore, highest BM25 score first. A strictly-positive
  /// default threshold (rather than >= 0) guards against chunks whose only "match" is a term so
  /// common that BM25 assigns it a near-zero or negative idf. Shared by topMatches (BM25-only)
  /// and topMatchesHybrid (BM25 candidate pool for fusion) below.
  private func rankedIndices(for query: String, minScore: Double, organHint: String? = nil)
    -> [Int]
  {
    scores(for: query, organHint: organHint)
      .enumerated()
      .filter { $0.element >= minScore }
      .sorted { $0.element > $1.element }
      .map(\.offset)
  }

  /// Top-k chunks above a minimum score, highest first. Pure BM25, no embedding model involved -
  /// this is what NamiAiEvalTests/NamiAiSearchTool used before section 3.6's Variante B/D
  /// (embedding hybrid), and stays available on its own for automated, device-free testing.
  func topMatches(
    for query: String, limit: Int = 5, minScore: Double = 0.01, organHint: String? = nil
  ) -> [NamiAiChunk] {
    rankedIndices(for: query, minScore: minScore, organHint: organHint)
      .prefix(limit)
      .map { chunks[$0] }
  }

  /// Like topMatches, but additionally consults `semanticScorer` (specs/nami-ai-roadmap.md
  /// section 3.6, Variante B: NLContextualEmbedding) to catch paraphrases/compound-word
  /// mismatches BM25's lexical matching (even with the stemming above) can't. Widens the BM25
  /// candidate pool before fusing, so a chunk that's only mediocre lexically but strongly
  /// matches semantically still has a chance to surface. Falls back to plain topMatches
  /// unchanged whenever no scorer is configured or it reports unavailable (nil) - a device
  /// without usable embedding model assets behaves exactly like before this method existed.
  func topMatchesHybrid(
    for query: String,
    limit: Int = 5,
    minScore: Double = 0.01,
    semanticScorer: NamiAiSemanticScorer?,
    organHint: String? = nil
  ) async -> [NamiAiChunk] {
    let bm25Candidates = rankedIndices(for: query, minScore: minScore, organHint: organHint)
    guard let semanticScorer,
      let semanticScores = await semanticScorer.similarityScores(for: query, against: chunks)
    else {
      return bm25Candidates.prefix(limit).map { chunks[$0] }
    }

    let widenedBM25Candidates = Array(bm25Candidates.prefix(max(limit * 4, 20)))
    let semanticRanking = semanticScores.enumerated()
      .sorted { $0.element > $1.element }
      .map(\.offset)
      .prefix(max(limit * 4, 20))

    let fusedScores = NamiAiRankFusion.reciprocalRankFusion(
      rankings: [widenedBM25Candidates, Array(semanticRanking)])
    return fusedScores.sorted { $0.value > $1.value }
      .prefix(limit)
      .map { chunks[$0.key] }
  }
}
