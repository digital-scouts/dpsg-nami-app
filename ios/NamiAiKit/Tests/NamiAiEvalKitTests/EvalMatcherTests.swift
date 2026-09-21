import XCTest

@testable import NamiAiEvalKit
@testable import NamiAiKit

final class EvalMatcherTests: XCTestCase {

  private func makeTitleIndex() throws -> EvalCorpusTitleIndex {
    try EvalCorpusTitleIndex(chunks: [
      ("satzung_stamm", "Satzung Stamm"),
      ("satzung_bezirk", "Satzung Bezirk"),
    ])
  }

  // MARK: - matchSources

  func testMatchSourcesAllModeSucceedsWhenEveryExpectedSourceIsCited() throws {
    let titleIndex = try makeTitleIndex()
    let cited = [
      NamiAiSourceRef(docTitle: "Satzung Stamm", sectionNumber: "20", docStand: "Mai 2024")
    ]
    let expected = [EvalExpectedSource(docId: "satzung_stamm", sectionNumber: "20")]

    let result = EvalMatcher.matchSources(
      citedSources: cited, expected: expected, matchMode: "all", titleIndex: titleIndex)

    XCTAssertTrue(result.ok)
    XCTAssertEqual(result.matchedExpected, expected)
    XCTAssertTrue(result.missingExpected.isEmpty)
  }

  func testMatchSourcesAllModeFailsWhenOneExpectedSourceIsMissing() throws {
    let titleIndex = try makeTitleIndex()
    let cited = [
      NamiAiSourceRef(docTitle: "Satzung Stamm", sectionNumber: "20", docStand: "Mai 2024")
    ]
    let expected = [
      EvalExpectedSource(docId: "satzung_stamm", sectionNumber: "20"),
      EvalExpectedSource(docId: "satzung_stamm", sectionNumber: "21"),
    ]

    let result = EvalMatcher.matchSources(
      citedSources: cited, expected: expected, matchMode: "all", titleIndex: titleIndex)

    XCTAssertFalse(result.ok)
    XCTAssertEqual(
      result.missingExpected, [EvalExpectedSource(docId: "satzung_stamm", sectionNumber: "21")])
  }

  func testMatchSourcesAnyModeSucceedsWithOneOfSeveralExpectedSources() throws {
    let titleIndex = try makeTitleIndex()
    let cited = [
      NamiAiSourceRef(docTitle: "Satzung Bezirk", sectionNumber: "23", docStand: "Mai 2024")
    ]
    let expected = [
      EvalExpectedSource(docId: "satzung_stamm", sectionNumber: "20"),
      EvalExpectedSource(docId: "satzung_bezirk", sectionNumber: "23"),
    ]

    let result = EvalMatcher.matchSources(
      citedSources: cited, expected: expected, matchMode: "any", titleIndex: titleIndex)

    XCTAssertTrue(result.ok)
  }

  func testMatchSourcesEmptyExpectedSucceedsOnlyWhenNothingWasCited() throws {
    let titleIndex = try makeTitleIndex()
    let noCitations: [NamiAiSourceRef] = []
    let someCitation = [
      NamiAiSourceRef(docTitle: "Satzung Stamm", sectionNumber: "20", docStand: "Mai 2024")
    ]

    XCTAssertTrue(
      EvalMatcher.matchSources(
        citedSources: noCitations, expected: [], matchMode: "all", titleIndex: titleIndex
      ).ok)
    XCTAssertFalse(
      EvalMatcher.matchSources(
        citedSources: someCitation, expected: [], matchMode: "all", titleIndex: titleIndex
      ).ok)
  }

  func testMatchSourcesReportsUnresolvableCitedTitleSeparately() throws {
    let titleIndex = try makeTitleIndex()
    let cited = [
      NamiAiSourceRef(docTitle: "Erfundenes Dokument", sectionNumber: "1", docStand: "n/a")
    ]
    let expected = [EvalExpectedSource(docId: "satzung_stamm", sectionNumber: "20")]

    let result = EvalMatcher.matchSources(
      citedSources: cited, expected: expected, matchMode: "all", titleIndex: titleIndex)

    XCTAssertFalse(result.ok)
    XCTAssertEqual(result.citedTitlesUnresolvable, ["Erfundenes Dokument"])
    XCTAssertEqual(result.missingExpected, expected)
  }

  // MARK: - matchGuardrail

  func testMatchGuardrailAllFourCombinations() {
    XCTAssertTrue(EvalMatcher.matchGuardrail(expectsReject: true, answerUnclear: true))
    XCTAssertTrue(EvalMatcher.matchGuardrail(expectsReject: false, answerUnclear: false))
    XCTAssertFalse(EvalMatcher.matchGuardrail(expectsReject: true, answerUnclear: false))
    XCTAssertFalse(EvalMatcher.matchGuardrail(expectsReject: false, answerUnclear: true))
  }

  // MARK: - isConsistent

  func testIsConsistentTrueWhenAllRepeatsAgree() {
    XCTAssertTrue(EvalMatcher.isConsistent([true, true, true]))
    XCTAssertTrue(EvalMatcher.isConsistent([false, false]))
  }

  func testIsConsistentFalseWhenRepeatsDisagree() {
    XCTAssertFalse(EvalMatcher.isConsistent([true, false, true]))
  }

  func testIsConsistentTrueForEmptyOrSingleResult() {
    XCTAssertTrue(EvalMatcher.isConsistent([]))
    XCTAssertTrue(EvalMatcher.isConsistent([true]))
  }
}
