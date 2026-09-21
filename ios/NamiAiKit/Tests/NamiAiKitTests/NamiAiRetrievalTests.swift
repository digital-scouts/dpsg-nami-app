import XCTest

@testable import NamiAiKit

final class NamiAiRetrievalTests: XCTestCase {
  private func makeChunk(
    docTitle: String = "Satzung Stamm",
    sectionNumber: String,
    sectionTitle: String = "Test",
    text: String
  ) -> NamiAiChunk {
    NamiAiChunk(
      docId: "satzung_stamm",
      ebene: "Stamm",
      docTitle: docTitle,
      docStand: "Mai 2024",
      sectionNumber: sectionNumber,
      sectionTitle: sectionTitle,
      pageStart: 1,
      pageEnd: 1,
      text: text,
      sourceFile: "test.pdf"
    )
  }

  func testTopMatchesRanksExactTermMatchFirst() {
    let chunks = [
      makeChunk(sectionNumber: "1", text: "Die Stammesversammlung wählt den Stammesvorstand."),
      makeChunk(sectionNumber: "2", text: "Der Bezirk gliedert sich in mehrere Stämme."),
      makeChunk(
        sectionNumber: "3",
        text: "Die Stammesversammlung tritt mindestens einmal jährlich zusammen."
      ),
    ]
    let index = NamiAiRetrievalIndex(chunks: chunks)

    let matches = index.topMatches(for: "Stammesversammlung", limit: 5)

    XCTAssertEqual(matches.count, 2)
    XCTAssertEqual(Set(matches.map(\.sectionNumber)), ["1", "3"])
  }

  func testTopMatchesReturnsEmptyForUnrelatedQuery() {
    let chunks = [
      makeChunk(sectionNumber: "1", text: "Die Stammesversammlung wählt den Stammesvorstand."),
      makeChunk(sectionNumber: "2", text: "Der Bezirk gliedert sich in mehrere Stämme."),
    ]
    let index = NamiAiRetrievalIndex(chunks: chunks)

    let matches = index.topMatches(for: "Vulkanausbruch Island")

    XCTAssertTrue(matches.isEmpty)
  }

  func testTopMatchesRespectsLimit() {
    let chunks = (1...10).map {
      makeChunk(sectionNumber: "\($0)", text: "Die Stammesversammlung regelt Ziffer \($0).")
    }
    let index = NamiAiRetrievalIndex(chunks: chunks)

    let matches = index.topMatches(for: "Stammesversammlung", limit: 3)

    XCTAssertEqual(matches.count, 3)
  }

  func testEmptyCorpusReturnsNoMatches() {
    let index = NamiAiRetrievalIndex(chunks: [])

    XCTAssertTrue(index.topMatches(for: "Stammesversammlung").isEmpty)
  }

  // The two inflection patterns from eval_questions.json's known_limitations / NamiAiEvalTests.swift
  // that motivated adding stemming (section 3.8 finding): a query wording didn't literally match
  // the corpus chunk's wording, even though it's the same word.

  func testTopMatchesFindsDativePluralAgainstNominativePluralQuery() {
    let chunks = [
      makeChunk(
        sectionNumber: "20",
        text: "Zur Stammesversammlung gehören die stimmberechtigten Mitgliedern."
      )
    ]
    let index = NamiAiRetrievalIndex(chunks: chunks)

    let matches = index.topMatches(for: "Wer gehört zur Stammesversammlung? Mitglieder")

    XCTAssertEqual(matches.map(\.sectionNumber), ["20"])
  }

  func testTopMatchesFindsGenitiveAgainstNominativeQuery() {
    let chunks = [
      makeChunk(
        sectionNumber: "30",
        text: "Der Bezirksvorstand besteht aus drei gleichberechtigten Mitgliedern."
      )
    ]
    let index = NamiAiRetrievalIndex(chunks: chunks)

    let matches = index.topMatches(for: "Wie viele Mitglieder hat des Bezirksvorstands?")

    XCTAssertEqual(matches.map(\.sectionNumber), ["30"])
  }

  func testStemStripsDativePluralErnSuffix() {
    XCTAssertEqual(NamiAiRetrievalIndex.stem("mitgliedern"), "mitglieder")
  }

  func testStemStripsGenitiveSAfterValidConsonant() {
    XCTAssertEqual(NamiAiRetrievalIndex.stem("bezirksvorstands"), "bezirksvorstand")
  }

  func testStemLeavesVowelPrecededSUnchanged() {
    // "s" preceded by a vowel is not a German genitive/plural marker (e.g. loanwords) - must not
    // be stripped, unlike the consonant-preceded case above.
    XCTAssertEqual(NamiAiRetrievalIndex.stem("fokus"), "fokus")
  }

  func testStemLeavesShortWordsUnchanged() {
    // Below each rule's minimum length guard - stemming these would either be meaningless or
    // risk colliding a short, unrelated word with something else.
    XCTAssertEqual(NamiAiRetrievalIndex.stem("des"), "des")
    XCTAssertEqual(NamiAiRetrievalIndex.stem("fern"), "fern")
  }

  func testStemDoesNotMangleAlreadyBaseFormWord() {
    // "Verein" is already the singular base form and must not be truncated just because it ends
    // in "n" - only "en"/"ern" suffixes are stripped, not a bare trailing "n".
    XCTAssertEqual(NamiAiRetrievalIndex.stem("verein"), "verein")
  }

  // MARK: - Stoppwortfilter

  func testTokenizeDropsStopwordsButKeepsStemmedContentWords() {
    let tokens = NamiAiRetrievalIndex.tokenize("Was sind die Aufgaben des Stammesvorstands?")

    XCTAssertFalse(tokens.contains("was"))
    XCTAssertFalse(tokens.contains("sind"))
    XCTAssertFalse(tokens.contains("die"))
    XCTAssertFalse(tokens.contains("des"))
    XCTAssertTrue(tokens.contains("aufgab"))
    XCTAssertTrue(tokens.contains("stammesvorstand"))
  }

  // MARK: - section_title boost ("falsches Organ" root cause)

  func testTopMatchesRanksChunkWithMatchingSectionTitleAboveOneThatOnlyMentionsTermInPassing() {
    // Nachbau des echten Produktionsbefunds (satzung_stamm#31 vs. #34): der "falsche" Chunk
    // erwaehnt "Aufgaben" haeufiger im Fliesstext und wuerde bei reiner Text-Indexierung (ohne
    // section_title-Boost) hoeher scoren, obwohl er inhaltlich von einem anderen Thema handelt.
    // Nur section_title des "richtigen" Chunks benennt tatsaechlich den Stammesvorstand.
    let correctChunk = makeChunk(
      sectionNumber: "correct", sectionTitle: "Der Stammesvorstand",
      text: "Der Stammesvorstand hat folgende Aufgaben: Leitung, Vertretung, Berufung.")
    let wrongChunk = makeChunk(
      sectionNumber: "wrong", sectionTitle: "Leitungsteams der Gruppen",
      text:
        "Die Aufgaben der Leitungsteams ergeben sich aus der Ordnung. Sie arbeiten mit dem "
        + "Stammesvorstand zusammen. Aufgaben, Aufgaben, Aufgaben.")
    let index = NamiAiRetrievalIndex(chunks: [correctChunk, wrongChunk])

    let matches = index.topMatches(for: "Aufgaben des Stammesvorstands", limit: 2)

    XCTAssertEqual(matches.first?.sectionNumber, "correct")
  }

  // MARK: - organHint

  func testOrganHintBoostsChunkWithMatchingSectionTitleOverAHigherRawBM25Match() {
    let hintedChunk = makeChunk(
      sectionNumber: "hinted", sectionTitle: "Der Stammesvorstand",
      text: "Der Stammesvorstand ist zuständig.")
    let higherRawScoreChunk = makeChunk(
      sectionNumber: "higherRaw", sectionTitle: "Sonstiges",
      text: "Zuständig zuständig zuständig zuständig zuständig.")
    let index = NamiAiRetrievalIndex(chunks: [hintedChunk, higherRawScoreChunk])
    let query = "Wer ist zuständig?"

    // Sanity check on the premise: without a hint, the chunk with more raw term repetitions
    // wins, even though it's not the one whose section_title names the asked-about organ.
    XCTAssertEqual(index.topMatches(for: query, limit: 1).first?.sectionNumber, "higherRaw")

    let hintedMatches = index.topMatches(
      for: query, limit: 1, organHint: "Stammesvorstand")

    XCTAssertEqual(hintedMatches.first?.sectionNumber, "hinted")
  }

  func testOrganHintWithNoSectionTitleMatchFallsBackToNormalRanking() {
    let chunks = [
      makeChunk(sectionNumber: "1", text: "Die Stammesversammlung wählt den Stammesvorstand.")
    ]
    let index = NamiAiRetrievalIndex(chunks: chunks)

    let matches = index.topMatches(
      for: "Stammesversammlung", organHint: "Ein Organ, das es gar nicht gibt")

    XCTAssertEqual(matches.map(\.sectionNumber), ["1"])
  }

  func testCallsWithoutOrganHintBehaveExactlyAsBefore() {
    let chunks = [
      makeChunk(sectionNumber: "1", text: "Die Stammesversammlung wählt den Stammesvorstand."),
      makeChunk(sectionNumber: "2", text: "Der Bezirk gliedert sich in mehrere Stämme."),
    ]
    let index = NamiAiRetrievalIndex(chunks: chunks)

    let withoutHintArgument = index.topMatches(for: "Stammesversammlung")
    let withExplicitNilHint = index.topMatches(for: "Stammesversammlung", organHint: nil)

    XCTAssertEqual(
      withoutHintArgument.map(\.sectionNumber), withExplicitNilHint.map(\.sectionNumber))
  }

  // MARK: - topMatchesHybrid (section 3.6 Variante B/D: semantic-embedding fusion)

  private struct FakeSemanticScorer: NamiAiSemanticScorer {
    let scoresByChunkText: [String: Double]

    func similarityScores(for query: String, against chunks: [NamiAiChunk]) async -> [Double]? {
      chunks.map { scoresByChunkText[$0.text] ?? 0 }
    }
  }

  private struct UnavailableSemanticScorer: NamiAiSemanticScorer {
    func similarityScores(for query: String, against chunks: [NamiAiChunk]) async -> [Double]? {
      nil
    }
  }

  func testTopMatchesHybridFallsBackToBM25WhenNoScorerConfigured() async {
    let chunks = [
      makeChunk(sectionNumber: "1", text: "Die Stammesversammlung wählt den Stammesvorstand.")
    ]
    let index = NamiAiRetrievalIndex(chunks: chunks)

    let matches = await index.topMatchesHybrid(
      for: "Stammesversammlung", semanticScorer: nil)

    XCTAssertEqual(
      matches.map(\.sectionNumber), index.topMatches(for: "Stammesversammlung").map(\.sectionNumber)
    )
  }

  func testTopMatchesHybridFallsBackToBM25WhenScorerReportsUnavailable() async {
    let chunks = [
      makeChunk(sectionNumber: "1", text: "Die Stammesversammlung wählt den Stammesvorstand.")
    ]
    let index = NamiAiRetrievalIndex(chunks: chunks)

    let matches = await index.topMatchesHybrid(
      for: "Stammesversammlung", semanticScorer: UnavailableSemanticScorer())

    XCTAssertEqual(matches.map(\.sectionNumber), ["1"])
  }

  func testTopMatchesHybridSurfacesLexicallyWeakButSemanticallyStrongChunk() async {
    // "distractor" shares every query term (highest possible BM25 rank) but is off-topic
    // content-wise; "paraphrase" shares only two of the five query terms (a mediocre, not the
    // worst, BM25 rank) but is the actually relevant paragraph, reflected by a much higher
    // semantic score. Two filler chunks occupy the remaining BM25/semantic ranks so this isn't
    // just a clean two-item rank swap (which would tie exactly under Reciprocal Rank Fusion).
    // Without semantic fusion (plain topMatches), "distractor" would win top-1 purely on
    // lexical overlap.
    let distractorText =
      "Die sonnenblume und die rakete und die gitarre und die tulpe und der anker sind Beispiele."
    let fillerAText = "Die sonnenblume und die rakete und die gitarre sind Beispiele."
    let paraphraseText = "Die tulpe und der anker sind Beispiele."
    let fillerBText = "Die sonnenblume ist ein Beispiel."
    let unrelatedText = "Nichts davon kommt hier vor."
    let chunks = [
      makeChunk(sectionNumber: "distractor", text: distractorText),
      makeChunk(sectionNumber: "fillerA", text: fillerAText),
      makeChunk(sectionNumber: "paraphrase", text: paraphraseText),
      makeChunk(sectionNumber: "fillerB", text: fillerBText),
      makeChunk(sectionNumber: "unrelated", text: unrelatedText),
    ]
    let index = NamiAiRetrievalIndex(chunks: chunks)
    let query = "sonnenblume rakete gitarre tulpe anker"

    // Sanity check on the premise: plain BM25 ranks the off-topic distractor first, not the
    // actually relevant paraphrase.
    XCTAssertEqual(
      index.topMatches(for: query, limit: 1, minScore: 0).first?.sectionNumber, "distractor")

    let scorer = FakeSemanticScorer(scoresByChunkText: [
      paraphraseText: 0.99,
      fillerBText: 0.6,
      fillerAText: 0.4,
      unrelatedText: 0.2,
      distractorText: 0.05,
    ])

    let hybridMatches = await index.topMatchesHybrid(
      for: query, limit: 1, minScore: 0, semanticScorer: scorer)

    XCTAssertEqual(hybridMatches.map(\.sectionNumber), ["paraphrase"])
  }
}
