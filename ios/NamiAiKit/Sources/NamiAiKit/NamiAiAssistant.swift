import Foundation

#if canImport(FoundationModels)
  import FoundationModels
#endif

/// Public facade of NamiAiKit — the only entry point a host app needs to know about.
/// No Flutter dependency anywhere in this package; callers pass a plain String prompt
/// and get a NamiAiAnswer (text + the context chunks that grounded it) or a NamiAiError back.
public enum NamiAiAssistant {
  /// Points NamiAiKit at the shared corpus JSON (specs/nami-ai-roadmap.md section 3.2: single
  /// Flutter asset, no second copy). NamiAiKit stays Flutter-agnostic, so resolving the actual
  /// asset path via FlutterDartProject is the Runner-side bridge's job, not this package's.
  public static func configure(corpusFileURL: URL) {
    NamiAiCorpus.configure(fileURL: corpusFileURL)
  }

  /// Fixed, non-model rejection text for explicit write intents (specs/nami-ai-roadmap.md
  /// section 3.7). unclear is false here: this is a deliberate, correct rejection, not a
  /// grounding failure — callers should be able to tell the two apart.
  private static let writeIntentRejection = NamiAiAnswer(
    text:
      "Ich kann aktuell keine Änderungen in NaMi vornehmen, sondern nur Fragen beantworten. "
      + "Bitte nutze dafür die passende Stelle in der App.",
    contextChunks: [],
    sources: [],
    unclear: false,
    contextTruncated: false
  )

  public static func respond(
    to prompt: String,
    completion: @escaping (Result<NamiAiAnswer, NamiAiError>) -> Void
  ) {
    if let availabilityError = checkAvailability() {
      completion(.failure(availabilityError))
      return
    }
    if NamiAiWriteIntentFilter.matches(prompt) {
      completion(.success(writeIntentRejection))
      return
    }
    #if canImport(FoundationModels)
      // checkAvailability() already ran this exact check at runtime, but the compiler can't
      // infer that from its return value — NamiAiResponder itself requires iOS 26 statically.
      guard #available(iOS 26.0, macOS 26.0, *) else {
        completion(.failure(.unsupportedOS))
        return
      }
      NamiAiResponder.respond(to: prompt, completion: completion)
    #endif
  }

  /// Synchronous availability check, exposed so the Flutter bridge can offer a dedicated
  /// checkAvailability MethodChannel call instead of gating solely on a device whitelist.
  /// Returns nil when the model is available and ready; otherwise the mapped error.
  public static func checkAvailability() -> NamiAiError? {
    #if canImport(FoundationModels)
      guard #available(iOS 26.0, macOS 26.0, *) else {
        return .unsupportedOS
      }
      return NamiAiAvailabilityMapper.error(for: SystemLanguageModel.default.availability)
    #else
      return .apiUnavailable
    #endif
  }

  #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private static let sessionStore = NamiAiChatSessionStore()
  #endif

  /// Starts a new held chat session for follow-up questions (specs/nami-ai-roadmap.md section
  /// 3.7): the returned id is opaque to callers and must be passed to respond(sessionId:to:)/
  /// endSession(sessionId:). Keying by id instead of one implicit session guards against races
  /// from screen navigation/hot restart, see NamiAiChatSessionStore.
  public static func startSession(completion: @escaping (Result<String, NamiAiError>) -> Void) {
    if let availabilityError = checkAvailability() {
      completion(.failure(availabilityError))
      return
    }
    #if canImport(FoundationModels)
      guard #available(iOS 26.0, macOS 26.0, *) else {
        completion(.failure(.unsupportedOS))
        return
      }
      Task {
        let id = await sessionStore.startSession()
        completion(.success(id))
      }
    #else
      completion(.failure(.apiUnavailable))
    #endif
  }

  /// Releases a held chat session. Best-effort: a missing/already-gone id is not reported as an
  /// error, since a session can legitimately be gone already (e.g. process restart).
  public static func endSession(sessionId: String) {
    #if canImport(FoundationModels)
      guard #available(iOS 26.0, macOS 26.0, *) else { return }
      Task { await sessionStore.endSession(sessionId) }
    #endif
  }

  /// Runs one turn against a previously started session, reusing the same LanguageModelSession
  /// instead of rebuilding it per turn (specs/nami-ai-roadmap.md section 3.7 follow-up
  /// questions).
  public static func respond(
    sessionId: String,
    to prompt: String,
    completion: @escaping (Result<NamiAiAnswer, NamiAiError>) -> Void
  ) {
    if let availabilityError = checkAvailability() {
      completion(.failure(availabilityError))
      return
    }
    if NamiAiWriteIntentFilter.matches(prompt) {
      completion(.success(writeIntentRejection))
      return
    }
    #if canImport(FoundationModels)
      guard #available(iOS 26.0, macOS 26.0, *) else {
        completion(.failure(.unsupportedOS))
        return
      }
      Task {
        guard let chatSession = await sessionStore.session(for: sessionId) else {
          completion(.failure(.sessionNotFound))
          return
        }
        chatSession.respond(to: prompt, completion: completion)
      }
    #else
      completion(.failure(.apiUnavailable))
    #endif
  }

  /// Streaming counterpart of respond(sessionId:to:completion:) (specs/nami-ai-roadmap.md
  /// section 3.7: session.streamResponse over a new EventChannel instead of a plain
  /// MethodChannel). onPartial delivers only the growing answer text; the final,
  /// grounding-gate-verified NamiAiAnswer (with sources/unclear/contextTruncated) is only ever
  /// passed to onComplete.
  public static func streamRespond(
    sessionId: String,
    to prompt: String,
    onPartial: @escaping (String) -> Void,
    onComplete: @escaping (Result<NamiAiAnswer, NamiAiError>) -> Void
  ) {
    if let availabilityError = checkAvailability() {
      onComplete(.failure(availabilityError))
      return
    }
    if NamiAiWriteIntentFilter.matches(prompt) {
      onComplete(.success(writeIntentRejection))
      return
    }
    #if canImport(FoundationModels)
      guard #available(iOS 26.0, macOS 26.0, *) else {
        onComplete(.failure(.unsupportedOS))
        return
      }
      Task {
        guard let chatSession = await sessionStore.session(for: sessionId) else {
          onComplete(.failure(.sessionNotFound))
          return
        }
        chatSession.streamRespond(to: prompt, onPartial: onPartial, completion: onComplete)
      }
    #else
      onComplete(.failure(.apiUnavailable))
    #endif
  }
}
