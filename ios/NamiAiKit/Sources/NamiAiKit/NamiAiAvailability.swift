import Foundation

#if canImport(FoundationModels)
  import FoundationModels

  /// Pure mapping from SystemLanguageModel.Availability to our internal error type.
  /// No side effects, no model access — safe to unit test without a real device by
  /// constructing SystemLanguageModel.Availability enum cases directly.
  @available(iOS 26.0, macOS 26.0, *)
  enum NamiAiAvailabilityMapper {
    /// Returns nil when the model is available and ready; otherwise the mapped error.
    static func error(for availability: SystemLanguageModel.Availability) -> NamiAiError? {
      switch availability {
      case .available:
        return nil
      case .unavailable(.deviceNotEligible):
        return .deviceNotEligible
      case .unavailable(.appleIntelligenceNotEnabled):
        return .appleIntelligenceNotEnabled
      case .unavailable(.modelNotReady):
        return .modelNotReady
      case .unavailable:
        // UnavailableReason is not @frozen — keep a catch-all for forward compatibility.
        return .availabilityUnknown
      }
    }
  }
#endif
