import XCTest

@testable import NamiAiKit

#if canImport(FoundationModels)
  import FoundationModels

  final class NamiAiAvailabilityTests: XCTestCase {
    func testAvailableMapsToNoError() throws {
      guard #available(iOS 26.0, *) else {
        throw XCTSkip("Requires iOS 26 runtime for SystemLanguageModel.Availability")
      }
      XCTAssertNil(NamiAiAvailabilityMapper.error(for: .available))
    }

    func testDeviceNotEligibleMapsCorrectly() throws {
      guard #available(iOS 26.0, *) else {
        throw XCTSkip("Requires iOS 26 runtime for SystemLanguageModel.Availability")
      }
      XCTAssertEqual(
        NamiAiAvailabilityMapper.error(for: .unavailable(.deviceNotEligible)),
        .deviceNotEligible
      )
    }

    func testAppleIntelligenceNotEnabledMapsCorrectly() throws {
      guard #available(iOS 26.0, *) else {
        throw XCTSkip("Requires iOS 26 runtime for SystemLanguageModel.Availability")
      }
      XCTAssertEqual(
        NamiAiAvailabilityMapper.error(for: .unavailable(.appleIntelligenceNotEnabled)),
        .appleIntelligenceNotEnabled
      )
    }

    func testModelNotReadyMapsCorrectly() throws {
      guard #available(iOS 26.0, *) else {
        throw XCTSkip("Requires iOS 26 runtime for SystemLanguageModel.Availability")
      }
      XCTAssertEqual(
        NamiAiAvailabilityMapper.error(for: .unavailable(.modelNotReady)),
        .modelNotReady
      )
    }
  }
#endif
