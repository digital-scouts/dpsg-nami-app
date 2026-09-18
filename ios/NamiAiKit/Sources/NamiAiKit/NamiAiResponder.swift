import Foundation

#if canImport(FoundationModels)
  import FoundationModels

  @available(iOS 26.0, macOS 26.0, *)
  enum NamiAiResponder {
    /// DPSG-Verbandsjargon, das Nutzer:innen typischerweise statt der ausgeschriebenen
    /// Begriffe aus den Satzungsauszügen verwenden. Bewusst final für den engen
    /// Stammesversammlung-Piloten (siehe specs/nami-ai-roadmap.md Abschnitt 3.3) -
    /// keine weitere Erweiterung vor Abschnitt 3.4 (vollständiger Korpus).
    static let glossary = """
      Verbandsjargon-Glossar (Abkürzung = Bedeutung):
      SV = Stammesversammlung
      Stavo = Stammesvorstand
      StaLei = Stammesleitung
      LR = Leiter*innenrunde (im Stamm: Stammesleiter*innenrunde)
      Wö = Wölflinge (jüngste reguläre Stufe, Gruppe: Meute)
      Jufi = Jungpfadfinder*innen (Gruppe: Trupp)
      Pfadi = Pfadfinder*innen (Gruppe: Trupp)
      Rover = älteste Stufe (Gruppe: Runde)
      Biber = jüngste, optionale Gruppenform (Bibergruppe)
      Kurat*in = geistliche Begleitung im Stammesvorstand
      BDKJ = Bund der Deutschen Katholischen Jugend
      rdp = Ring deutscher Pfadfinder*innenverbände e. V.
      StuKo = Stufenkonferenz (Bezirks-/Diözesanebene je Altersstufe)
      DV = Diözesanverband
      DL = Diözesanleitung
      """

    private static let systemInstructions = """
      Du beantwortest Fragen zur DPSG (Satzung, Ordnung, Vereinsstrukturen) \
      ausschließlich auf Basis der unten aufgeführten Auszüge. Das Glossar erklärt \
      dir nur Abkürzungen, die Nutzer:innen in ihrer Frage verwenden könnten - es ist \
      keine zusätzliche Quelle für Inhalte. Wenn sich eine Frage nicht anhand der \
      Auszüge beantworten lässt, lehne die Antwort höflich ab und weise darauf hin, \
      dass dir dazu keine passende Quelle vorliegt. Erfinde keine Inhalte, die nicht \
      in den Auszügen stehen.
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
        systemInstructions + "\n\n" + glossary + "\n\nSatzungsauszüge:\n"
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
