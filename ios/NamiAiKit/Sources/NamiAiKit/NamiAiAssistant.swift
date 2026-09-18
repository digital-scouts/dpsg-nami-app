import Foundation

#if canImport(FoundationModels)
  import FoundationModels
#endif

/// Public facade of NamiAiKit — the only entry point a host app needs to know about.
/// No Flutter dependency anywhere in this package; callers pass a plain String prompt
/// and get a NamiAiAnswer (text + the context chunks that grounded it) or a NamiAiError back.
public enum NamiAiAssistant {
  public static func respond(
    to prompt: String,
    completion: @escaping (Result<NamiAiAnswer, NamiAiError>) -> Void
  ) {
    #if canImport(FoundationModels)
      guard #available(iOS 26.0, macOS 26.0, *) else {
        completion(.failure(.unsupportedOS))
        return
      }
      if let availabilityError = NamiAiAvailabilityMapper.error(
        for: SystemLanguageModel.default.availability
      ) {
        completion(.failure(availabilityError))
        return
      }
      NamiAiResponder.respond(to: prompt, completion: completion)
    #else
      completion(.failure(.apiUnavailable))
    #endif
  }
}
