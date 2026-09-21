import XCTest

@testable import NamiAiKit

#if canImport(FoundationModels)
  import FoundationModels

  /// Exercises NamiAiResponder.performSelfCorrection (specs/nami-ai-roadmap.md section 3.12)
  /// entirely through injected attempt/verify closures, so the retry policy itself is testable
  /// without any on-device FoundationModels runtime - the same reason NamiAiSlidingWindow takes
  /// its entry classification via closures.
  final class NamiAiSelfCorrectionTests: XCTestCase {
    private func makeAnswer(text: String) -> NamiAiAnswer {
      NamiAiAnswer(
        text: text, contextChunks: [], sources: [], unclear: false, contextTruncated: false,
        verificationFailed: false, verificationAttempts: [])
    }

    private func passingVerification() -> NamiAiVerificationResult {
      NamiAiVerificationResult(
        expectedIntent: "Definition", intentMatches: true, factsSupportedBySources: true,
        containsIrrelevantInformation: false, feedbackForRetry: "")
    }

    private func failingVerification(feedback: String = "zu viele Zusatzinfos")
      -> NamiAiVerificationResult
    {
      NamiAiVerificationResult(
        expectedIntent: "Liste", intentMatches: false, factsSupportedBySources: true,
        containsIrrelevantInformation: true, feedbackForRetry: feedback)
    }

    func testFirstAttemptPassingReturnsImmediatelyWithoutRetry() async throws {
      guard #available(iOS 26.0, macOS 26.0, *) else {
        throw XCTSkip("Requires iOS 26 runtime for NamiAiResponder")
      }
      var attemptCount = 0
      let (answer, verificationFailed, attempts) = try await NamiAiResponder.performSelfCorrection(
        question: "Wer gehört zur Stammesversammlung?",
        attempt: { _, attemptNumber in
          attemptCount += 1
          return (self.makeAnswer(text: "Antwort \(attemptNumber)"), [])
        },
        verify: { _, _, _ in self.passingVerification() }
      )
      XCTAssertEqual(attemptCount, 1)
      XCTAssertEqual(answer.text, "Antwort 1")
      XCTAssertFalse(verificationFailed)
      XCTAssertEqual(attempts.count, 1)
      XCTAssertTrue(attempts[0].passed)
      XCTAssertNil(attempts[0].retryReason)
    }

    func testFailingFirstAttemptTriggersExactlyOneRetryWithFeedbackInPrompt() async throws {
      guard #available(iOS 26.0, macOS 26.0, *) else {
        throw XCTSkip("Requires iOS 26 runtime for NamiAiResponder")
      }
      var seenPrompts: [String] = []
      var callCount = 0
      _ = try await NamiAiResponder.performSelfCorrection(
        question: "Was sind die Aufgaben des Bezirksvorstands?",
        attempt: { prompt, attemptNumber in
          seenPrompts.append(prompt)
          callCount += 1
          return (self.makeAnswer(text: "Antwort \(attemptNumber)"), [])
        },
        verify: { _, _, _ in
          callCount == 1
            ? self.failingVerification(feedback: "falsches Organ") : self.passingVerification()
        }
      )
      XCTAssertEqual(seenPrompts.count, 2)
      XCTAssertTrue(seenPrompts[1].contains("falsches Organ"))
      XCTAssertTrue(seenPrompts[1].contains("Was sind die Aufgaben des Bezirksvorstands?"))
    }

    func testExhaustingAllThreeAttemptsSetsVerificationFailedTrueAndReturnsLastAnswer()
      async throws
    {
      guard #available(iOS 26.0, macOS 26.0, *) else {
        throw XCTSkip("Requires iOS 26 runtime for NamiAiResponder")
      }
      var attemptCount = 0
      let (answer, verificationFailed, attempts) = try await NamiAiResponder.performSelfCorrection(
        question: "Frage",
        attempt: { _, attemptNumber in
          attemptCount += 1
          return (self.makeAnswer(text: "Antwort \(attemptNumber)"), [])
        },
        verify: { _, _, _ in self.failingVerification() }
      )
      XCTAssertEqual(attemptCount, 3)
      XCTAssertTrue(verificationFailed)
      XCTAssertEqual(answer.text, "Antwort 3")
      XCTAssertEqual(attempts.count, 3)
      XCTAssertNil(attempts.last?.retryReason)
      XCTAssertFalse(attempts.last!.passed)
    }

    func testAttemptClosureIsCalledAtMostThreeTimesEvenIfAlwaysFailing() async throws {
      guard #available(iOS 26.0, macOS 26.0, *) else {
        throw XCTSkip("Requires iOS 26 runtime for NamiAiResponder")
      }
      var attemptCount = 0
      _ = try await NamiAiResponder.performSelfCorrection(
        question: "Frage",
        attempt: { _, _ in
          attemptCount += 1
          return (self.makeAnswer(text: "x"), [])
        },
        verify: { _, _, _ in self.failingVerification() }
      )
      XCTAssertLessThanOrEqual(attemptCount, NamiAiResponder.maxSelfCorrectionRetries + 1)
    }

    func testVerifierThrowingIsTreatedAsPassed() async throws {
      guard #available(iOS 26.0, macOS 26.0, *) else {
        throw XCTSkip("Requires iOS 26 runtime for NamiAiResponder")
      }
      struct DummyError: Error {}
      var attemptCount = 0
      let (_, verificationFailed, attempts) = try await NamiAiResponder.performSelfCorrection(
        question: "Frage",
        attempt: { _, attemptNumber in
          attemptCount += 1
          return (self.makeAnswer(text: "Antwort \(attemptNumber)"), [])
        },
        verify: { _, _, _ in throw DummyError() }
      )
      XCTAssertEqual(attemptCount, 1)
      XCTAssertFalse(verificationFailed)
      XCTAssertTrue(attempts[0].passed)
    }

    func testAttemptsLogContainsRetryReasonForEveryNonFinalFailedAttempt() async throws {
      guard #available(iOS 26.0, macOS 26.0, *) else {
        throw XCTSkip("Requires iOS 26 runtime for NamiAiResponder")
      }
      let (_, _, attempts) = try await NamiAiResponder.performSelfCorrection(
        question: "Frage",
        attempt: { _, attemptNumber in
          (self.makeAnswer(text: "Antwort \(attemptNumber)"), [])
        },
        verify: { _, _, _ in self.failingVerification(feedback: "zu viele Zusatzinfos") }
      )
      XCTAssertEqual(attempts.count, 3)
      XCTAssertNotNil(attempts[0].retryReason)
      XCTAssertNotNil(attempts[1].retryReason)
      XCTAssertNil(attempts[2].retryReason)
    }
  }
#endif
