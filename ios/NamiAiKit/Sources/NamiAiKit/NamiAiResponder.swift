import Foundation

#if canImport(FoundationModels)
  import FoundationModels

  @available(iOS 26.0, *)
  enum NamiAiResponder {
    private static let systemInstructions = """
      Du beantwortest ausschließlich Fragen zur Stammesversammlung laut der Satzung \
      Stamm (DPSG, Stand Mai 2024). Nutze für deine Antwort ausschließlich die unten \
      aufgeführten Satzungsauszüge. Wenn eine Frage nicht die Stammesversammlung \
      betrifft oder sich nicht anhand der Auszüge beantworten lässt, lehne die Antwort \
      höflich ab und weise darauf hin, dass du nur zur Stammesversammlung laut Satzung \
      Stamm antworten kannst. Erfinde keine Inhalte, die nicht in den Auszügen stehen.
      """

    /// Runs one turn against the fixed context. Never surfaces raw framework error text:
    /// all failure modes are mapped to NamiAiError.
    static func respond(
      to prompt: String,
      completion: @escaping (Result<NamiAiAnswer, NamiAiError>) -> Void
    ) {
      guard let chunks = NamiAiContext.loadChunks() else {
        completion(.failure(.contextMissing))
        return
      }

      let instructions =
        systemInstructions + "\n\nSatzungsauszüge:\n"
        + chunks.enumerated()
          .map { "\($0.offset + 1). \($0.element)" }
          .joined(separator: "\n\n")

      Task {
        do {
          let session = LanguageModelSession(instructions: instructions)
          let response = try await session.respond(to: prompt)
          completion(.success(NamiAiAnswer(text: response.content, contextChunks: chunks)))
        } catch {
          completion(.failure(.generationFailed))
        }
      }
    }
  }
#endif
