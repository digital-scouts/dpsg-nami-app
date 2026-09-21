import XCTest

@testable import NamiAiEvalKit

final class EvalCorpusTitleIndexTests: XCTestCase {

  func testBuildsReverseLookupFromDocTitleToDocId() throws {
    let index = try EvalCorpusTitleIndex(chunks: [
      ("satzung_stamm", "Satzung Stamm"),
      ("satzung_stamm", "Satzung Stamm"),
      ("satzung_bezirk", "Satzung Bezirk"),
    ])

    XCTAssertEqual(index.docId(forCitedTitle: "Satzung Stamm"), "satzung_stamm")
    XCTAssertEqual(index.docId(forCitedTitle: "Satzung Bezirk"), "satzung_bezirk")
    XCTAssertNil(index.docId(forCitedTitle: "Unbekanntes Dokument"))
  }

  func testThrowsOnAmbiguousTitleAcrossDifferentDocIds() {
    XCTAssertThrowsError(
      try EvalCorpusTitleIndex(chunks: [
        ("satzung_stamm", "Gleicher Titel"),
        ("satzung_bezirk", "Gleicher Titel"),
      ])
    ) { error in
      XCTAssertEqual(error as? EvalCorpusTitleIndexError, .ambiguousTitle("Gleicher Titel"))
    }
  }

  /// Regression guard for the assumption EvalMatcher relies on: the production corpus must stay
  /// 1:1 between doc_id and doc_title (verified 2026-09-21: 5 doc_id values, one doc_title
  /// each). Mirrors NamiAiCorpusSanityTests'/NamiAiEvalTests' path resolution and skip-if-
  /// missing behavior for the real corpus file.
  func testProductionCorpusHasNoAmbiguousTitles() throws {
    let corpusURL = Self.repoRootURL().appendingPathComponent(
      "assets/ai_kontext/nami_ai_corpus_v1.json")
    guard FileManager.default.fileExists(atPath: corpusURL.path) else {
      throw XCTSkip(
        "Produktionskorpus nicht gefunden - Test laeuft nur im vollstaendigen Repo-Checkout.")
    }

    let index = try EvalCorpusTitleIndex(corpusFileURL: corpusURL)
    XCTAssertFalse(index.docIdByTitle.isEmpty)
  }

  /// ios/NamiAiKit/Tests/NamiAiEvalKitTests/<file> -> repo root is five levels up.
  private static func repoRootURL() -> URL {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<5 {
      url.deleteLastPathComponent()
    }
    return url
  }
}
