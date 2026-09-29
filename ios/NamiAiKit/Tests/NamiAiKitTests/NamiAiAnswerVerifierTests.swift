import XCTest

@testable import NamiAiKit

final class NamiAiAnswerVerifierTests: XCTestCase {
  private func makeChunk(sectionNumber: String, text: String) -> NamiAiChunk {
    NamiAiChunk(
      docId: "satzung_stamm",
      ebene: "Stamm",
      docTitle: "Satzung Stamm",
      docStand: "Mai 2024",
      sectionNumber: sectionNumber,
      sectionTitle: "Test",
      pageStart: 1,
      pageEnd: 1,
      text: text,
      sourceFile: "test.pdf"
    )
  }

  func testPassedIsTrueOnlyWhenAllThreeChecksPass() {
    let allGood = NamiAiVerificationResult(
      expectedIntent: "Definition", intentMatches: true, factsSupportedBySources: true,
      containsIrrelevantInformation: false, feedbackForRetry: "")
    XCTAssertTrue(allGood.passed)

    let wrongIntent = NamiAiVerificationResult(
      expectedIntent: "Liste", intentMatches: false, factsSupportedBySources: true,
      containsIrrelevantInformation: false, feedbackForRetry: "sollte eine Liste sein")
    XCTAssertFalse(wrongIntent.passed)

    let unsupportedFacts = NamiAiVerificationResult(
      expectedIntent: "Definition", intentMatches: true, factsSupportedBySources: false,
      containsIrrelevantInformation: false, feedbackForRetry: "Fakt X nicht belegt")
    XCTAssertFalse(unsupportedFacts.passed)

    let irrelevantInfo = NamiAiVerificationResult(
      expectedIntent: "Definition", intentMatches: true, factsSupportedBySources: true,
      containsIrrelevantInformation: true, feedbackForRetry: "enthält Zusatzinfos")
    XCTAssertFalse(irrelevantInfo.passed)
  }

  #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    func testBuildPromptContainsQuestionAnswerAndSourceTexts() throws {
      guard #available(iOS 26.0, macOS 26.0, *) else {
        throw XCTSkip("Requires iOS 26 runtime for NamiAiAnswerVerifier")
      }
      let prompt = NamiAiAnswerVerifier.buildPrompt(
        question: "Wer gehört zur Stammesversammlung?",
        answerText: "Zur Stammesversammlung gehören alle Mitglieder.",
        chunks: [makeChunk(sectionNumber: "20", text: "Quellentext zur Stammesversammlung")]
      )

      XCTAssertTrue(prompt.contains("Wer gehört zur Stammesversammlung?"))
      XCTAssertTrue(prompt.contains("Zur Stammesversammlung gehören alle Mitglieder."))
      XCTAssertTrue(prompt.contains("Quellentext zur Stammesversammlung"))
      XCTAssertTrue(prompt.contains("Satzung Stamm"))
      XCTAssertTrue(prompt.contains("20"))
    }

    @available(iOS 26.0, macOS 26.0, *)
    func testBuildPromptWithoutChunksStatesNoneAvailable() throws {
      guard #available(iOS 26.0, macOS 26.0, *) else {
        throw XCTSkip("Requires iOS 26 runtime for NamiAiAnswerVerifier")
      }
      let prompt = NamiAiAnswerVerifier.buildPrompt(
        question: "Frage", answerText: "Antwort", chunks: [])

      XCTAssertTrue(prompt.contains("Keine Quellentexte vorhanden."))
    }
  #endif
}
