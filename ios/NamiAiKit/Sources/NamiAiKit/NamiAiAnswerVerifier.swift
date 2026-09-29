import Foundation

#if canImport(FoundationModels)
  import FoundationModels

  /// Second, independent model pass that checks a generated answer against the source texts that
  /// actually grounded it (specs/nami-ai-roadmap.md section 3.12) - goes beyond
  /// NamiAiGroundingGate, which only checks that cited sources were really retrieved, not whether
  /// the answer's content is actually supported by them. Deliberately tool-less: the relevant
  /// source texts are passed directly in the prompt, so a second search_regelwerk call would only
  /// add latency and risk a second, possibly different source selection.
  @available(iOS 26.0, macOS 26.0, *)
  enum NamiAiAnswerVerifier {
    static let instructions = """
      Du bist ein Prüfschritt für Antworten eines anderen KI-Systems zu Fragen rund um DPSG- \
      Satzung und Ordnung. Du beantwortest die Frage NICHT selbst und nutzt ausschließlich die \
      unten mitgegebenen Quellentexte, keine anderen Quellen oder eigenes Wissen. Prüfe anhand \
      von Frage, Antwort und Quellentexten: (1) Welche Antwortform erwartet die Frage - Liste, \
      Vergleich, Definition, Begründung oder etwas Sonstiges - und entspricht die tatsächliche \
      Antwortform dem? (2) Ist jede Tatsachenaussage der Antwort inhaltlich durch die \
      Quellentexte gedeckt, nicht nur durch eine formal passende Zitatangabe? (3) Enthält die \
      Antwort Zusatzinformationen, die nicht zur gestellten Frage gehören? Sei bei diesen drei \
      Einschätzungen streng und begründe im Feedback konkret, was zu ändern ist.
      """

    /// Always builds a fresh session per call instead of reusing one: the check is independent
    /// per turn (different question/answer/sources each time), and a held session would offer no
    /// benefit while introducing the same transcript-hygiene concern that NamiAiResponder's
    /// self-correction loop deliberately solves for the main session - avoided here entirely by
    /// keeping no state across calls.
    static func verify(
      question: String,
      answerText: String,
      deliveredChunks: [NamiAiChunk]
    ) async throws -> NamiAiVerificationResult {
      let session = LanguageModelSession(instructions: instructions)
      let prompt = buildPrompt(question: question, answerText: answerText, chunks: deliveredChunks)
      let response = try await session.respond(
        to: prompt, generating: NamiAiAnswerVerification.self)
      return NamiAiVerificationResult(generated: response.content)
    }

    static func buildPrompt(question: String, answerText: String, chunks: [NamiAiChunk]) -> String {
      let sourcesBlock =
        chunks.isEmpty
        ? "Keine Quellentexte vorhanden."
        : chunks.enumerated()
          .map { offset, chunk in
            "\(offset + 1). [\(chunk.docTitle), \(chunk.sectionNumber), Stand \(chunk.docStand)]\n\(chunk.text)"
          }
          .joined(separator: "\n\n")
      return """
        Nutzerfrage:
        \(question)

        Zu prüfende Antwort:
        \(answerText)

        Tatsächlich für diese Antwort abgerufene Quellentexte:
        \(sourcesBlock)
        """
    }
  }
#endif

/// FoundationModels-independent view of NamiAiAnswerVerification, analogous to NamiAiSourceRef
/// vs. NamiAiGeneratedSourceRef. `passed` is computed here, never taken from the model (see
/// NamiAiAnswerVerification's doc comment for why).
struct NamiAiVerificationResult: Equatable {
  let expectedIntent: String
  let intentMatches: Bool
  let factsSupportedBySources: Bool
  let containsIrrelevantInformation: Bool
  let feedbackForRetry: String

  var passed: Bool {
    intentMatches && factsSupportedBySources && !containsIrrelevantInformation
  }

  init(
    expectedIntent: String, intentMatches: Bool, factsSupportedBySources: Bool,
    containsIrrelevantInformation: Bool, feedbackForRetry: String
  ) {
    self.expectedIntent = expectedIntent
    self.intentMatches = intentMatches
    self.factsSupportedBySources = factsSupportedBySources
    self.containsIrrelevantInformation = containsIrrelevantInformation
    self.feedbackForRetry = feedbackForRetry
  }
}

#if canImport(FoundationModels)
  @available(iOS 26.0, macOS 26.0, *)
  extension NamiAiVerificationResult {
    init(generated: NamiAiAnswerVerification) {
      self.init(
        expectedIntent: generated.expectedIntent.rawValue,
        intentMatches: generated.intentMatches,
        factsSupportedBySources: generated.factsSupportedBySources,
        containsIrrelevantInformation: generated.containsIrrelevantInformation,
        feedbackForRetry: generated.feedbackForRetry)
    }
  }
#endif

/// One logged self-correction attempt (specs/nami-ai-roadmap.md section 3.12), kept for the
/// Flutter-side debug log (NamiAiDebugLogService) - never for user-facing UI. Defined outside any
/// FoundationModels guard, like NamiAiVerificationResult above, since it's part of the
/// unrestricted NamiAiAnswer facade.
public struct NamiAiVerificationAttempt: Equatable {
  public let attemptNumber: Int
  public let answerText: String
  public let expectedIntent: String?
  public let intentMatches: Bool?
  public let factsSupportedBySources: Bool?
  public let containsIrrelevantInformation: Bool?
  public let passed: Bool
  public let feedback: String
  /// nil when this attempt was accepted (passed, or the last allowed attempt); otherwise the
  /// concrete reason a retry was triggered - the user-requested "log why a retry happened".
  public let retryReason: String?

  public init(
    attemptNumber: Int, answerText: String, expectedIntent: String?, intentMatches: Bool?,
    factsSupportedBySources: Bool?, containsIrrelevantInformation: Bool?, passed: Bool,
    feedback: String, retryReason: String?
  ) {
    self.attemptNumber = attemptNumber
    self.answerText = answerText
    self.expectedIntent = expectedIntent
    self.intentMatches = intentMatches
    self.factsSupportedBySources = factsSupportedBySources
    self.containsIrrelevantInformation = containsIrrelevantInformation
    self.passed = passed
    self.feedback = feedback
    self.retryReason = retryReason
  }
}
