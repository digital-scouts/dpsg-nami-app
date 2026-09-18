import XCTest

@testable import NamiAiKit

#if canImport(FoundationModels)
  import FoundationModels

  final class NamiAiResponderTests: XCTestCase {
    func testGlossaryContainsAllExpectedAbbreviations() throws {
      guard #available(iOS 26.0, macOS 26.0, *) else {
        throw XCTSkip("Requires iOS 26 runtime for NamiAiResponder")
      }
      let expectedAbbreviations = [
        "SV", "Stavo", "StaLei", "LR", "Wö", "Jufi", "Pfadi", "Rover", "Biber",
        "Kurat*in", "BDKJ", "rdp", "StuKo", "DV", "DL",
      ]
      for abbreviation in expectedAbbreviations {
        XCTAssertTrue(
          NamiAiResponder.glossary.contains(abbreviation),
          "Glossar sollte \(abbreviation) enthalten"
        )
      }
    }
  }
#endif
