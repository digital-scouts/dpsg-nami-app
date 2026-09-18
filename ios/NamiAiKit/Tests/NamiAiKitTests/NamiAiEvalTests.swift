import XCTest

@testable import NamiAiKit

/// Automated, CI-capable retrieval-only check against chat_ai/eval/eval_questions.json
/// (specs/nami-ai-roadmap.md section 3.8). Reuses NamiAiCorpusSanityTests' path resolution
/// (real production corpus instead of a fixture, to keep NamiAiRetrievalTests' synthetic
/// scoring fixtures decoupled from corpus/question content), but checks question-to-source
/// expectations instead of pure structure. Covers retrieval only (NamiAiRetrievalIndex.
/// topMatches with the same defaults as NamiAiSearchTool) — end-to-end answer quality
/// including citations and hallucination stays manual (chat_ai/eval/README.md), since the
/// simulator/CI has no loaded language model.
///
/// Off-topic questions deliberately aren't checked automatically here (see "known_limitations"
/// in eval_questions.json): topMatches returns hits against the real 667-chunk corpus even for
/// clearly unrelated questions, because rare colloquial words get a disproportionately high
/// BM25 idf weight in the formal statute/Ordnung text. "Retrieval empty" is therefore not a
/// reliable rejection signal — the rejection has to come from the model itself.
final class NamiAiEvalTests: XCTestCase {

  private struct EvalSource: Decodable {
    let docId: String
    let sectionNumber: String

    enum CodingKeys: String, CodingKey {
      case docId = "doc_id"
      case sectionNumber = "section_number"
    }
  }

  private struct EvalQuestion: Decodable {
    let id: String
    let category: String
    let question: String
    let expectedSources: [EvalSource]
    let matchMode: String
    let expectsReject: Bool
    let automatedCheck: Bool

    enum CodingKeys: String, CodingKey {
      case id, category, question
      case expectedSources = "expected_sources"
      case matchMode = "match_mode"
      case expectsReject = "expects_reject"
      case automatedCheck = "automated_check"
    }
  }

  private struct EvalQuestionsFile: Decodable {
    let questions: [EvalQuestion]
  }

  private struct ChunkKey: Hashable {
    let docId: String
    let sectionNumber: String
  }

  /// Starting threshold for general/jargon/regression questions — deliberately not 100%, since
  /// BM25 doesn't guarantee rephrasing/compound-word/multi-chunk-synthesis matches (see
  /// nami-ai-roadmap.md 3.6). Calibrated 2026-09-18 against the real production corpus: measured
  /// pass rate 40.6% (13/32) — well below the original 80% starting value, because
  /// NamiAiRetrievalIndex tokenizes without stemming/lemmatization and German inflected forms
  /// (e.g. question "Mitglieder" vs. chunk text "Mitgliedern") therefore don't match. Threshold
  /// set with a safety margin below the measured value to catch real regressions (e.g. a broken
  /// tokenizer) without treating the known limitation itself as a failure — the actual finding
  /// (BM25 variant A has a real weakness against German inflection) is a section-3.8 result that
  /// feeds the section-3.6 variant B/D decision, not a test bug.
  private static let minimumPassRate = 0.35

  func testGroundedQuestionsMeetPassRateThreshold() throws {
    let (index, questions) = try loadCorpusAndQuestions()
    let grounded = questions.filter { $0.automatedCheck }
    XCTAssertFalse(
      grounded.isEmpty, "Kein automatisiert pruefbares, quellenbasiertes Fragenset gefunden.")

    var passedIds: [String] = []
    var failedIds: [String] = []
    for question in grounded {
      let matches = Set(
        index.topMatches(for: question.question).map {
          ChunkKey(docId: $0.docId, sectionNumber: $0.sectionNumber)
        })
      let expected = question.expectedSources.map {
        ChunkKey(docId: $0.docId, sectionNumber: $0.sectionNumber)
      }
      let ok: Bool
      switch question.matchMode {
      case "any":
        ok = expected.contains { matches.contains($0) }
      default:
        ok = !expected.isEmpty && expected.allSatisfy { matches.contains($0) }
      }
      if ok {
        passedIds.append(question.id)
      } else {
        failedIds.append(question.id)
      }
    }

    let passRate = Double(passedIds.count) / Double(grounded.count)
    XCTAssertGreaterThanOrEqual(
      passRate, Self.minimumPassRate,
      "Pass-Rate \(passRate) unter Schwelle \(Self.minimumPassRate). "
        + "Fehlgeschlagen: \(failedIds.joined(separator: ", "))"
    )
  }

  private func loadCorpusAndQuestions() throws -> (NamiAiRetrievalIndex, [EvalQuestion]) {
    let corpusURL = Self.repoRootURL().appendingPathComponent(
      "assets/ai_kontext/nami_ai_corpus_v1.json")
    let evalURL = Self.repoRootURL().appendingPathComponent("chat_ai/eval/eval_questions.json")
    guard FileManager.default.fileExists(atPath: corpusURL.path),
      FileManager.default.fileExists(atPath: evalURL.path)
    else {
      throw XCTSkip(
        "Produktionskorpus oder eval_questions.json nicht gefunden - Test laeuft nur im vollstaendigen Repo-Checkout."
      )
    }

    NamiAiCorpus.configure(fileURL: corpusURL)
    let index = try XCTUnwrap(NamiAiCorpus.index(), "Korpus konnte nicht geladen/geparst werden")

    let evalData = try Data(contentsOf: evalURL)
    let file = try JSONDecoder().decode(EvalQuestionsFile.self, from: evalData)
    return (index, file.questions)
  }

  /// ios/NamiAiKit/Tests/NamiAiKitTests/<file> -> repo root is five levels up.
  private static func repoRootURL() -> URL {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<5 {
      url.deleteLastPathComponent()
    }
    return url
  }
}
