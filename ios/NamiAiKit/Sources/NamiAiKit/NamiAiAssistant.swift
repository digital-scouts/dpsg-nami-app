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

  public static func respond(
    to prompt: String,
    completion: @escaping (Result<NamiAiAnswer, NamiAiError>) -> Void
  ) {
    if let availabilityError = checkAvailability() {
      completion(.failure(availabilityError))
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
}
