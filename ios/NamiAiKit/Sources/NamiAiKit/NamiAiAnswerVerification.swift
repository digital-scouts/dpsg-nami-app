import Foundation

#if canImport(FoundationModels)
  import FoundationModels

  /// Answer-intent categories for the verifier pass (specs/nami-ai-roadmap.md section 3.12).
  /// Modeled as a fixed @Generable enum rather than a free-form string so the model picks from a
  /// closed set instead of inventing arbitrary phrasing.
  @available(iOS 26.0, macOS 26.0, *)
  @Generable
  enum NamiAiAnswerIntent: String, CaseIterable, Sendable {
    case liste = "Liste"
    case vergleich = "Vergleich"
    case definition = "Definition"
    case begruendung = "Begründung"
    case sonstiges = "Sonstiges"
  }

  /// Structured output the verifier model pass must produce (NamiAiAnswerVerifier). Deliberately
  /// has NO overall "passed" field - the combined verdict is computed deterministically in Swift
  /// from the three checks below (see NamiAiVerificationResult.passed) rather than left to the
  /// model, mirroring how NamiAiGroundingGate never lets the model's own `unclear` value be the
  /// last word either.
  @available(iOS 26.0, macOS 26.0, *)
  @Generable
  struct NamiAiAnswerVerification {
    @Guide(description: "Antworttyp, den die Nutzerfrage erwartet")
    var expectedIntent: NamiAiAnswerIntent
    @Guide(
      description:
        "true, wenn die tatsächliche Form der Antwort (Liste/Vergleich/Definition/Begründung/...) zum erwarteten Antworttyp passt"
    ) var intentMatches: Bool
    @Guide(
      description:
        "true, wenn jede in der Antwort genannte Tatsachenaussage inhaltlich durch die mitgegebenen Quellentexte gedeckt ist, nicht nur formal zitiert"
    ) var factsSupportedBySources: Bool
    @Guide(
      description:
        "true, wenn die Antwort Zusatzinformationen enthält, die nicht zur gestellten Frage gehören"
    ) var containsIrrelevantInformation: Bool
    @Guide(
      description:
        "Kurzes, konkretes Korrekturfeedback für einen erneuten Antwortversuch; leer, wenn keines der obigen Probleme vorliegt"
    ) var feedbackForRetry: String
  }
#endif
