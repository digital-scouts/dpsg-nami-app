import Foundation

/// One `expected_sources` entry, keyed the same way as the production corpus (`doc_id` +
/// `section_number`) - not by `docTitle`, which is what `NamiAiSourceRef` (the model's actual
/// citation) uses instead. See EvalCorpusTitleIndex for the bridge between the two. Encodable
/// too (not just Decodable) since EvalLogEntry re-serializes the fixture's expected_sources
/// verbatim into the JSONL log line.
public struct EvalExpectedSource: Codable, Equatable, Sendable {
  public let docId: String
  public let sectionNumber: String

  enum CodingKeys: String, CodingKey {
    case docId = "doc_id"
    case sectionNumber = "section_number"
  }

  public init(docId: String, sectionNumber: String) {
    self.docId = docId
    self.sectionNumber = sectionNumber
  }
}

/// Mirrors chat_ai/eval/eval_questions.json's schema field-for-field (same CodingKeys as
/// NamiAiEvalTests.EvalQuestion) so this CLI reuses that single source of truth instead of a
/// second, drifting copy of the question set.
public struct EvalQuestionFixture: Decodable, Equatable, Sendable {
  public let id: String
  public let category: String
  public let question: String
  public let expectedSources: [EvalExpectedSource]
  public let matchMode: String
  public let expectsReject: Bool
  public let automatedCheck: Bool
  public let note: String?

  enum CodingKeys: String, CodingKey {
    case id, category, question, note
    case expectedSources = "expected_sources"
    case matchMode = "match_mode"
    case expectsReject = "expects_reject"
    case automatedCheck = "automated_check"
  }
}

public struct EvalQuestionsFile: Decodable, Sendable {
  public let evalSetVersion: Int?
  public let questions: [EvalQuestionFixture]

  enum CodingKeys: String, CodingKey {
    case evalSetVersion = "eval_set_version"
    case questions
  }
}

public enum EvalQuestionsLoaderError: Error, Equatable {
  case fileNotFound(URL)
}

public enum EvalQuestionsLoader {
  public static func load(from url: URL) throws -> EvalQuestionsFile {
    guard FileManager.default.fileExists(atPath: url.path) else {
      throw EvalQuestionsLoaderError.fileNotFound(url)
    }
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(EvalQuestionsFile.self, from: data)
  }
}
