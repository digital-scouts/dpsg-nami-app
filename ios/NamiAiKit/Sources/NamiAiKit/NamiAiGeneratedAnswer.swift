import Foundation

#if canImport(FoundationModels)
  import FoundationModels

  /// Structured output the model must produce, per specs/nami-ai-roadmap.md section 3.6. Kept
  /// separate from the public NamiAiAnswer/NamiAiSourceRef facade (which has no FoundationModels
  /// dependency) since @Generable output is only ever an intermediate value — NamiAiResponder
  /// runs it through NamiAiGroundingGate before it becomes a NamiAiAnswer.
  @available(iOS 26.0, macOS 26.0, *)
  @Generable
  struct NamiAiGeneratedSourceRef {
    @Guide(description: "Kurztitel, z. B. 'Satzung Stamm'") var docTitle: String
    @Guide(description: "Abschnitts-/Paragraphennummer") var sectionNumber: String
    @Guide(description: "Stand des Dokuments, z. B. 'Mai 2024'") var docStand: String
  }

  @available(iOS 26.0, macOS 26.0, *)
  @Generable
  struct NamiAiGeneratedAnswer {
    @Guide(description: "Antwort ausschließlich basierend auf gefundenen Quellen") var answer:
      String
    @Guide(description: "Belegte Quellen; leer, wenn keine passende Quelle gefunden wurde")
    var sources: [NamiAiGeneratedSourceRef]
    @Guide(
      description:
        "true, wenn keine passende Quelle gefunden wurde oder Frage außerhalb Satzung/Ordnung liegt"
    ) var unclear: Bool
  }
#endif
