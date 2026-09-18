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

    static let systemInstructions = """
      Du beantwortest Fragen zur DPSG (Satzung, Ordnung, Vereinsstrukturen) ausschließlich auf \
      Basis der Ergebnisse des Tools "search_regelwerk". Rufe das Tool für jede inhaltliche \
      Frage auf, bevor du antwortest - bei Bedarf mehrfach mit unterschiedlichen \
      Suchbegriffen, wenn eine Antwort mehrere Abschnitte zusammenführen muss. Das Glossar \
      erklärt dir nur Abkürzungen, die Nutzer:innen in ihrer Frage verwenden könnten - es ist \
      keine zusätzliche Quelle für Inhalte. Wenn sich eine Frage nicht anhand der \
      Tool-Ergebnisse beantworten lässt, setze unclear auf true und lasse sources leer. \
      Erfinde keine Inhalte und keine Quellenangaben, die nicht aus den Tool-Ergebnissen \
      stammen.
      """

    /// Builds a fresh session with its bound recorder, ready for a first turn. Both the one-shot
    /// respond() below and NamiAiChatSession (section 3.7, holds session/recorder across
    /// multiple follow-up turns instead of rebuilding them per turn) use this, so session
    /// construction and instructions stay in exactly one place.
    static func makeSession() -> (session: LanguageModelSession, recorder: NamiAiRetrievalRecorder)
    {
      let recorder = NamiAiRetrievalRecorder()
      let session = LanguageModelSession(
        tools: [NamiAiSearchTool(recorder: recorder)],
        instructions: systemInstructions + "\n\n" + glossary
      )
      return (session, recorder)
    }

    /// Runs one turn with retrieval via NamiAiSearchTool and technically enforces the citation
    /// requirement afterwards (NamiAiGroundingGate) - @Generable alone only guarantees
    /// structure, not that a cited source was actually retrieved. Never surfaces raw framework
    /// error text: all failure modes are mapped to NamiAiError.
    static func respond(
      to prompt: String,
      completion: @escaping (Result<NamiAiAnswer, NamiAiError>) -> Void
    ) {
      guard NamiAiCorpus.index() != nil else {
        completion(.failure(.contextMissing))
        return
      }

      let (session, recorder) = makeSession()
      Task {
        do {
          let answer = try await runTurn(
            session: session, recorder: recorder, prompt: prompt, contextTruncated: false)
          completion(.success(answer))
        } catch {
          completion(.failure(Self.mapGenerationError(error)))
        }
      }
    }

    /// Runs one turn against an already-built session/recorder pair and wraps the result through
    /// NamiAiGroundingGate. Shared by respond() above (throwaway session) and NamiAiChatSession
    /// (held session across turns) so the grounding-gate wiring can't drift between the two.
    static func runTurn(
      session: LanguageModelSession,
      recorder: NamiAiRetrievalRecorder,
      prompt: String,
      contextTruncated: Bool
    ) async throws -> NamiAiAnswer {
      let response = try await session.respond(to: prompt, generating: NamiAiGeneratedAnswer.self)
      let generated = response.content
      let sources = generated.sources.map {
        NamiAiSourceRef(
          docTitle: $0.docTitle, sectionNumber: $0.sectionNumber, docStand: $0.docStand)
      }
      return NamiAiGroundingGate.verify(
        text: generated.answer,
        sources: sources,
        unclear: generated.unclear,
        deliveredKeys: await recorder.deliveredKeys,
        contextChunks: await recorder.deliveredChunkTexts,
        contextTruncated: contextTruncated
      )
    }

    /// Maps FoundationModels' GenerationError cases to the small, stable NamiAiError surface -
    /// never forwards raw framework error text to the UI. GenerationError itself is deprecated
    /// starting iOS/macOS 27 in favor of LanguageModelError, but LanguageModelError is only
    /// available from iOS/macOS 27 onward while this app's minimum target is iOS 26 (see
    /// NamiAiAccessService._minIosMajorVersion) - GenerationError therefore stays the correct
    /// type to catch here despite the deprecation warning under newer SDKs.
    static func mapGenerationError(_ error: Error) -> NamiAiError {
      guard let generationError = error as? LanguageModelSession.GenerationError else {
        return .generationFailed
      }
      switch generationError {
      case .guardrailViolation:
        return .guardrailViolation
      case .exceededContextWindowSize:
        return .contextWindowExceeded
      default:
        return .generationFailed
      }
    }
  }
#endif
