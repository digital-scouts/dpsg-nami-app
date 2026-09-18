import Foundation

/// Internal, stable error surface for the native NaMi AI pipeline. Deliberately decoupled
/// from FoundationModels-specific types (e.g. SystemLanguageModel.Availability,
/// LanguageModelSession's thrown errors) so this enum compiles and is unit-testable even
/// when FoundationModels isn't imported, and never leaks raw framework error text to callers.
public enum NamiAiError: Error, Equatable {
  case unsupportedOS
  case apiUnavailable
  case deviceNotEligible
  case appleIntelligenceNotEnabled
  case modelNotReady
  case availabilityUnknown
  case contextMissing
  case generationFailed

  public var flutterErrorCode: String {
    switch self {
    case .unsupportedOS: return "unsupported_ios"
    case .apiUnavailable: return "ai_api_missing"
    case .deviceNotEligible: return "ai_device_not_eligible"
    case .appleIntelligenceNotEnabled: return "ai_intelligence_not_enabled"
    case .modelNotReady: return "ai_model_not_ready"
    case .availabilityUnknown: return "ai_availability_unknown"
    case .contextMissing: return "ai_context_missing"
    case .generationFailed: return "ai_generation_failed"
    }
  }

  public var userMessage: String {
    switch self {
    case .unsupportedOS:
      return "Apple-On-Device-AI erfordert iOS 26 oder neuer."
    case .apiUnavailable:
      return "Die Apple-On-Device-AI-API ist im aktuellen Build nicht verfügbar."
    case .deviceNotEligible:
      return "Dieses Gerät unterstützt Apple Intelligence nicht."
    case .appleIntelligenceNotEnabled:
      return "Apple Intelligence ist auf diesem Gerät nicht aktiviert."
    case .modelNotReady:
      return "Das Sprachmodell wird noch vorbereitet. Bitte später erneut versuchen."
    case .availabilityUnknown:
      return "Apple-On-Device-AI ist derzeit nicht verfügbar."
    case .contextMissing:
      return "Der Satzungskontext konnte nicht geladen werden."
    case .generationFailed:
      return "Bei der Antworterstellung ist ein Fehler aufgetreten."
    }
  }
}
