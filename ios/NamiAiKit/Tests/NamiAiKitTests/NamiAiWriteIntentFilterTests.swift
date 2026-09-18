import XCTest

@testable import NamiAiKit

final class NamiAiWriteIntentFilterTests: XCTestCase {
  func testDetectsCommonWriteVerbs() {
    XCTAssertTrue(NamiAiWriteIntentFilter.matches("Lösche den Eintrag von Max Mustermann"))
    XCTAssertTrue(NamiAiWriteIntentFilter.matches("Bitte ändere meine Telefonnummer"))
    XCTAssertTrue(NamiAiWriteIntentFilter.matches("Kannst du mich für die Fahrt eintragen?"))
    XCTAssertTrue(NamiAiWriteIntentFilter.matches("Erstelle einen neuen Stamm"))
  }

  func testIsCaseInsensitive() {
    XCTAssertTrue(NamiAiWriteIntentFilter.matches("LÖSCHE DEN EINTRAG"))
    XCTAssertTrue(NamiAiWriteIntentFilter.matches("Speichere das bitte"))
  }

  func testDetectsEmbeddedOccurrences() {
    XCTAssertTrue(
      NamiAiWriteIntentFilter.matches("Kannst du bitte den Termin verschieben, danke?"))
  }

  func testPlainReadingQuestionsDoNotMatch() {
    XCTAssertFalse(
      NamiAiWriteIntentFilter.matches("Wie oft muss die Stammesversammlung stattfinden?"))
    XCTAssertFalse(
      NamiAiWriteIntentFilter.matches("Wer darf an der Stammesversammlung teilnehmen?"))
    XCTAssertFalse(NamiAiWriteIntentFilter.matches("Was sind die Aufgaben des Stammesvorstands?"))
  }
}
