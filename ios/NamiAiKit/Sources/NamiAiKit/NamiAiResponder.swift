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

      Bei Fragen nach Aufgaben, Zusammensetzung oder Zuständigkeiten eines konkreten Organs \
      (z. B. Stammesvorstand, Stammesversammlung, Bezirksvorstand, Bezirksversammlung, \
      Bezirkskonferenz, Diözesanvorstand, Diözesanversammlung, Bundesvorstand) prüfe bei jedem \
      Treffer zuerst, ob er tatsächlich von genau diesem Organ und dieser Ebene handelt, bevor \
      du ihn verwendest. Die Satzungen mehrerer Ebenen (Stamm, Bezirk, Diözese, Bund) enthalten \
      strukturell fast identische Abschnitte für unterschiedliche Organe (z. B. "hat folgende \
      Aufgaben" sowohl für ein Organ als auch für ein anderes, ähnlich benanntes Gremium \
      derselben oder einer anderen Ebene) - übernimm nie den erstbesten strukturell passenden \
      Treffer, ohne Organ und Ebene gegen die Frage abzugleichen. Wenn die ersten Treffer ein \
      anderes Organ oder eine andere Ebene betreffen als gefragt, suche erneut mit \
      präziseren Suchbegriffen (Organname und Ebene explizit nennen). Fasse für die Antwort \
      alle passenden Treffer zum richtigen Organ zusammen, statt nur den ersten zu nutzen. \
      Fülle beim Aufruf von search_regelwerk zusätzlich den Parameter organHint mit dem \
      vollständig ausgeschriebenen Organnamen, wenn die Frage eindeutig ein einzelnes Organ \
      benennt (löse dabei Abkürzungen aus dem Glossar auf, z. B. Stavo → Stammesvorstand). \
      Lasse organHint leer, wenn die Frage kein Organ eindeutig benennt oder mehrdeutig ist.
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
    /// error text: all failure modes are mapped to NamiAiError. Wrapped in the verifier-pass
    /// self-correction loop (section 3.12) - each retry gets a brand-new throwaway session via
    /// makeSession(), since this session is discarded after the call anyway (no transcript-
    /// hygiene concern here, unlike the held NamiAiChatSession case).
    static func respond(
      to prompt: String,
      completion: @escaping (Result<NamiAiAnswer, NamiAiError>) -> Void
    ) {
      guard NamiAiCorpus.index() != nil else {
        completion(.failure(.contextMissing))
        return
      }

      Task {
        do {
          var (session, recorder) = makeSession()
          let (answer, verificationFailed, attempts) = try await performSelfCorrection(
            question: prompt
          ) { attemptPrompt, attemptNumber in
            if attemptNumber > 1 {
              (session, recorder) = makeSession()
            }
            let answer = try await runTurn(
              session: session, recorder: recorder, prompt: attemptPrompt, contextTruncated: false)
            return (answer, await recorder.deliveredChunks)
          }
          completion(
            .success(answer.withVerification(failed: verificationFailed, attempts: attempts)))
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
        contextChunks: await recorder.deliveredChunkRefs,
        contextTruncated: contextTruncated
      )
    }

    /// Max. number of retries after a failed verifier pass (user decision, specs/nami-ai-
    /// roadmap.md section 3.12) - so at most 3 generation attempts total per user question (1
    /// initial + 2 retries).
    static let maxSelfCorrectionRetries = 2

    /// Shared verify-and-retry policy for the one-shot path (respond() above) and
    /// NamiAiChatSession - the policy itself (attempt cap, stop criterion, retry-prompt wording,
    /// logging shape) must not drift between the two, exactly like runTurn already keeps the
    /// grounding-gate wiring from drifting. HOW the session is managed between attempts (rebuild
    /// a throwaway session vs. roll back a held one) is the caller's job via the `attempt`
    /// closure - this function only decides WHETHER another attempt happens and WHAT prompt it
    /// gets.
    ///
    /// `verify` is injectable so this policy is unit-testable without any FoundationModels
    /// runtime (see NamiAiSelfCorrectionTests.swift), the same reason NamiAiSlidingWindow takes
    /// its entry classification via closures instead of depending on Transcript.Entry directly.
    ///
    /// Fail-open on a verifier error: if NamiAiAnswerVerifier itself throws (e.g. a transient
    /// generation error in the *second* model pass), that is treated as passed rather than
    /// blocking delivery of an answer that otherwise cleared the grounding gate - the verifier is
    /// an additional quality layer on top of the grounding gate, not a second hard gate with its
    /// own failure risk.
    static func performSelfCorrection(
      question: String,
      attempt: (_ prompt: String, _ attemptNumber: Int) async throws -> (
        answer: NamiAiAnswer, deliveredChunks: [NamiAiChunk]
      ),
      verify: (_ question: String, _ answerText: String, _ deliveredChunks: [NamiAiChunk])
        async throws -> NamiAiVerificationResult = NamiAiAnswerVerifier.verify
    ) async throws -> (
      answer: NamiAiAnswer, verificationFailed: Bool, attempts: [NamiAiVerificationAttempt]
    ) {
      var attempts: [NamiAiVerificationAttempt] = []
      var currentPrompt = question
      var attemptNumber = 1

      while true {
        let (answer, deliveredChunks) = try await attempt(currentPrompt, attemptNumber)

        let verification: NamiAiVerificationResult?
        do {
          verification = try await verify(question, answer.text, deliveredChunks)
        } catch {
          verification = nil
        }
        let passed = verification?.passed ?? true
        let isLastAllowedAttempt = attemptNumber == maxSelfCorrectionRetries + 1
        let reason =
          (passed || verification == nil) ? nil : Self.retryReason(for: verification!)

        attempts.append(
          NamiAiVerificationAttempt(
            attemptNumber: attemptNumber,
            answerText: answer.text,
            expectedIntent: verification?.expectedIntent,
            intentMatches: verification?.intentMatches,
            factsSupportedBySources: verification?.factsSupportedBySources,
            containsIrrelevantInformation: verification?.containsIrrelevantInformation,
            passed: passed,
            feedback: verification?.feedbackForRetry ?? "Verifier nicht verfügbar/fehlgeschlagen.",
            retryReason: isLastAllowedAttempt ? nil : reason))

        if passed || isLastAllowedAttempt {
          return (answer, !passed, attempts)
        }

        currentPrompt = Self.retryPrompt(
          original: question, feedback: verification?.feedbackForRetry ?? "")
        attemptNumber += 1
      }
    }

    private static func retryReason(for verification: NamiAiVerificationResult) -> String {
      var reasons: [String] = []
      if !verification.intentMatches {
        reasons.append(
          "Antwortform passt nicht zum erwarteten Typ (\(verification.expectedIntent))")
      }
      if !verification.factsSupportedBySources {
        reasons.append("Nicht alle Fakten durch Quellen gedeckt")
      }
      if verification.containsIrrelevantInformation {
        reasons.append("Enthält nicht zur Frage gehörende Zusatzinfos")
      }
      return reasons.joined(separator: "; ")
    }

    private static func retryPrompt(original: String, feedback: String) -> String {
      """
      \(original)

      [Interner Korrekturhinweis, nicht Teil der ursprünglichen Nutzerfrage: Eine vorherige \
      eigene Antwort auf genau diese Frage wurde geprüft und hatte folgendes Problem: \
      \(feedback) Beantworte die Frage oben erneut und behebe dieses Problem.]
      """
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
