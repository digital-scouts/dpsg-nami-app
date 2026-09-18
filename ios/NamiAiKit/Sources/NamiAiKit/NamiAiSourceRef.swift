import Foundation

/// Plain, FoundationModels-independent representation of a cited source. Kept separate from
/// the @Generable type the model actually produces (NamiAiGeneratedSourceRef) so this can
/// cross the Flutter bridge and be unit-tested regardless of platform/availability.
public struct NamiAiSourceRef: Equatable {
  public let docTitle: String
  public let sectionNumber: String
  public let docStand: String

  public init(docTitle: String, sectionNumber: String, docStand: String) {
    self.docTitle = docTitle
    self.sectionNumber = sectionNumber
    self.docStand = docStand
  }
}
