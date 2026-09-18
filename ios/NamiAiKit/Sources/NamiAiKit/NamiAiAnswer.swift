import Foundation

/// A successful NamiAiAssistant response, including the context chunks actually used so
/// callers can log/debug what grounded the answer.
public struct NamiAiAnswer: Equatable {
  public let text: String
  public let contextChunks: [String]
}
